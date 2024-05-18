import SwiftUI
import WatchConnectivity // Add WatchConnectivity import

struct ContentView: View {
    @State private var lateralRaiseCount = 0
    
    var body: some View {
        VStack {
            Text("Lateral Raises: \(lateralRaiseCount)")
                .font(.title)
                .padding()
            
            Button("Reset Counter") {
                // Reset the counter to 0
                lateralRaiseCount = 0
                
                // Send message to reset counter on the watch
                sendMessageToWatch()
            }
            .padding()
            
            Spacer()
        }
        .padding()
    }
    
    func sendMessageToWatch() {
        if WCSession.isSupported() {
            let session = WCSession.default
            if session.isReachable {
                let message = ["resetCounter": true]
                session.sendMessage(message, replyHandler: nil, errorHandler: { error in
                    print("Error sending message to watch: \(error.localizedDescription)")
                })
            } else {
                print("Watch is not reachable.")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
