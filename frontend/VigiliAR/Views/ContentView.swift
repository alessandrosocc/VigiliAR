import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject private var userProfileStore: UserProfileStore

    private let serviceTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @AppStorage("hasSeenIntroSplash") private var hasSeenIntroSplash: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if !hasSeenIntroSplash {
                    IntroSplashView {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            hasSeenIntroSplash = true
                        }
                    }
                } else if userProfileStore.isAuthenticated {
                    DashboardView(serviceTimer: serviceTimer)
                } else {
                    LoginView()
                }
            }
            .navigationTitle("")
        }
    }
}

#Preview("App Flow - Login") {
    ContentView()
        .environmentObject(UserProfileStore.previewLogin())
        .environmentObject(VehicleStore())
        .environmentObject(ARTrackingSceneStore())
}
