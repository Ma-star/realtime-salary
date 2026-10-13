import SwiftUI

@main
struct RealtimeSalaryApp: App {
    @StateObject private var store = SalaryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(store.preferredColorScheme)
        }
    }
}
