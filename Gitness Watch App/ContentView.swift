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
    
    private var rotationRateY: [(value: Double, time: Date)] = []
    private var gravityX: [(value: Double, time: Date)] = []
    private var gravityY: [(value: Double, time: Date)] = []
    private var gravityZ: [(value: Double, time: Date)] = []
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
                guard let self = self, let motion = motion else { return }
                
                // Collect data with timestamps
                let currentTime = Date()
                self.rotationRateY.append((motion.rotationRate.y, currentTime))
                self.gravityX.append((motion.gravity.x, currentTime))
                self.gravityY.append((motion.gravity.y, currentTime))
                self.gravityZ.append((motion.gravity.z, currentTime))
                
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
        if let troughTime = detectTroughTime(data: self.rotationRateY, threshold: -0.2) {
            // Check for peaks in gravityX, gravityY, and gravityZ within the time tolerance
            let peaksGravityX = detectPeakWithinTime(data: self.gravityX, threshold: 0.75, referenceTime: troughTime)
            let peaksGravityY = detectPeakWithinTime(data: self.gravityY, threshold: 0.0, referenceTime: troughTime)
            let peaksGravityZ = detectPeakWithinTime(data: self.gravityZ, threshold: -0.63, referenceTime: troughTime)
            
            if peaksGravityX && peaksGravityY && peaksGravityZ {
                if !self.movementDetected {
                    self.movementCount += 1
                    self.movementDetected = true
                    self.lastDetectedTime = Date()
                    self.triggerHapticFeedback()
                }
            } else {
                self.movementDetected = false
            }
        }
    }
    
    private func detectTroughTime(data: [(value: Double, time: Date)], threshold: Double) -> Date? {
        guard data.count > 2 else { return nil }
        
        for i in 1..<data.count-1 {
            if data[i].value < data[i-1].value && data[i].value < data[i+1].value && data[i].value < threshold {
                return data[i].time
            }
        }
        return nil
    }
    
    private func detectPeakWithinTime(data: [(value: Double, time: Date)], threshold: Double, referenceTime: Date) -> Bool {
        guard data.count > 1 else { return false }
        
        for datum in data {
            if datum.value > threshold && abs(datum.time.timeIntervalSince(referenceTime)) < self.timeTolerance {
                return true
            }
        }
        return false
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
