import SwiftUI

@main
struct I2pdGUIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .help) {
                Button("О программе") {
                    // TODO: Открыть окно "О программе"
                }
            }
        }
    }
}
