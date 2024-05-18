import SwiftUI
import CoreMotion
import WatchConnectivity
import WatchKit

class MotionManager: ObservableObject {
    private var motionManager = CMMotionManager()
    @Published var movementCount = 0
    private var movementDetected = false
    private var lastDetectedTime = Date()
    private var timeTolerance: TimeInterval = 0.5
    
    private var rotationRateY: [Double] = []
    private var gravityX: [Double] = []
    private var gravityY: [Double] = []
    private var gravityZ: [Double] = []
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
                guard let self = self, let motion = motion else { return }
                
                // Collect data
                self.rotationRateY.append(motion.rotationRate.y)
                self.gravityX.append(motion.gravity.x)
                self.gravityY.append(motion.gravity.y)
                self.gravityZ.append(motion.gravity.z)
                
                // Limit data collection to a specific window size
                if self.rotationRateY.count > 100 {
                    self.rotationRateY.removeFirst()
                    self.gravityX.removeFirst()
                    self.gravityY.removeFirst()
                    self.gravityZ.removeFirst()
                }
                
                // Check for movement pattern
                self.detectMovement()
            }
        }
    }
    
    private func detectMovement() {
        // Apply smoothing
        let smoothedRotationRateY = smooth(data: self.rotationRateY)
        let smoothedGravityX = smooth(data: self.gravityX)
        let smoothedGravityY = smooth(data: self.gravityY)
        let smoothedGravityZ = smooth(data: self.gravityZ)
        
        // Calculate dynamic thresholds
        let rotationThreshold = -0.5 * stdDev(data: smoothedRotationRateY)
        let gravityXThreshold = 0.75 + 0.5 * stdDev(data: smoothedGravityX)
        let gravityYThreshold = 0.0 + 0.5 * stdDev(data: smoothedGravityY)
        let gravityZThreshold = -0.63 + 0.5 * stdDev(data: smoothedGravityZ)
        
        // Detect troughs in rotationRateY
        let troughsRotationRateY = detectTroughs(data: smoothedRotationRateY, threshold: rotationThreshold)
        // Detect peaks in gravityX, gravityY, and gravityZ
        let peaksGravityX = detectPeaks(data: smoothedGravityX, threshold: gravityXThreshold)
        let peaksGravityY = detectPeaks(data: smoothedGravityY, threshold: gravityYThreshold)
        let peaksGravityZ = detectPeaks(data: smoothedGravityZ, threshold: gravityZThreshold)
        
        let currentTime = Date()
        if troughsRotationRateY && peaksGravityX && peaksGravityY && peaksGravityZ {
            if !self.movementDetected {
                self.movementCount += 1
                self.movementDetected = true
                self.lastDetectedTime = currentTime
                self.triggerHapticFeedback()
            }
        } else {
            if currentTime.timeIntervalSince(self.lastDetectedTime) > self.timeTolerance {
                self.movementDetected = false
            }
        }
    }
    
    private func detectPeaks(data: [Double], threshold: Double) -> Bool {
        guard data.count > 1 else { return false }
        
        for i in 1..<data.count-1 {
            if data[i] > data[i-1] && data[i] > data[i+1] && data[i] > threshold {
                return true
            }
        }
        return false
    }
    
    private func detectTroughs(data: [Double], threshold: Double) -> Bool {
        guard data.count > 1 else { return false }
        
        for i in 1..<data.count-1 {
            if data[i] < data[i-1] && data[i] < data[i+1] && data[i] < threshold {
                return true
            }
        }
        return false
    }
    
    private func smooth(data: [Double], windowSize: Int = 5) -> [Double] {
        guard data.count > windowSize else { return data }
        
        var smoothedData = [Double]()
        for i in 0..<data.count {
            let start = max(i - windowSize / 2, 0)
            let end = min(i + windowSize / 2, data.count - 1)
            let window = Array(data[start...end])
            let average = window.reduce(0, +) / Double(window.count)
            smoothedData.append(average)
        }
        return smoothedData
    }
    
    private func stdDev(data: [Double]) -> Double {
        let mean = data.reduce(0, +) / Double(data.count)
        let variance = data.reduce(0) { $0 + pow($1 - mean, 2) } / Double(data.count)
        return sqrt(variance)
    }
    
    private func triggerHapticFeedback() {
        WKInterfaceDevice.current().play(.success)
    }
    
    func resetCounter() {
        movementCount = 0
    }
}

struct ContentView: View {
    @ObservedObject var motionManager = MotionManager()
    
    var body: some View {
        VStack {
            Text("Count: \(motionManager.movementCount)")
                .font(.headline)
            
            Button(action: {
                motionManager.resetCounter()
            }) {
                Text("Reset")
            }
        }
        .padding()
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
