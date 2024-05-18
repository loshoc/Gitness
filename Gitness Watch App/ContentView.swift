import SwiftUI
import CoreMotion
import WatchConnectivity

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
        // Detect troughs in rotationRateY
        let troughsRotationY = detectTroughs(data: self.rotationRateY, threshold: -0.2)
        // Detect peaks in gravityX, gravityY, and gravityZ
        let peaksGravityX = detectPeaks(data: self.gravityX, threshold: 0.75)
        let peaksGravityY = detectPeaks(data: self.gravityY, threshold: 0.0)
        let peaksGravityZ = detectPeaks(data: self.gravityZ, threshold: -0.63)
        
        let currentTime = Date()
        if troughsRotationY && peaksGravityX && peaksGravityY && peaksGravityZ {
            if !self.movementDetected {
                self.movementCount += 1
                self.movementDetected = true
                self.lastDetectedTime = currentTime
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
