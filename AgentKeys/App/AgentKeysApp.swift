import SwiftUI

@main
struct AgentKeysApp: App {
    @State private var store = AgentStore()

    var body: some Scene {
        WindowGroup {
            ControlDeckView(store: store)
                .preferredColorScheme(.light)
        }
    }
}

