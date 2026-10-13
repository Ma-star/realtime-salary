import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: SalaryStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsSetup = false

    var body: some View {
        Group {
            if let profile = store.profile {
                TabView {
                    NavigationStack {
                        DashboardView(profile: profile, showsSetup: $showsSetup)
                    }
                    .tabItem { Label("回血", systemImage: "bolt.heart.fill") }

                    NavigationStack {
                        InsightsView(profile: profile)
                    }
                    .tabItem { Label("战绩", systemImage: "chart.bar.fill") }
                }
                .sheet(isPresented: $showsSetup) {
                    SetupView(profile: profile)
                }
            } else {
                SetupView(profile: SalaryProfile())
            }
        }
        .tint(.indigo)
        .overlay {
            if scenePhase != .active {
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    VStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill").font(.largeTitle).foregroundStyle(.indigo)
                        Text("薪资隐私已遮挡").font(.headline)
                    }
                }
            }
        }
    }
}
