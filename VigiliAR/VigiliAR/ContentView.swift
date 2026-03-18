import SwiftUI

struct ContentView : View {
    @EnvironmentObject private var userProfileStore: UserProfileStore

    var body: some View {
        NavigationStack {
            Group {
                if userProfileStore.isAuthenticated {
                    DashboardView()
                } else {
                    LoginView()
                }
            }
            .navigationTitle("")
        }
    }
}

private struct LoginView: View {
    @EnvironmentObject private var userProfileStore: UserProfileStore

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Text("VigiliAR")
                .font(.largeTitle).bold()

            Text("Accesso Operatore")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                TextField("Nome", text: $userProfileStore.name)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)

                TextField("Cognome", text: $userProfileStore.surname)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)

                TextField("Identificativo", text: $userProfileStore.identifier)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }

            if !userProfileStore.authStatusMessage.isEmpty {
                Text(userProfileStore.authStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                userProfileStore.login()
            } label: {
                HStack {
                    if userProfileStore.isAuthenticating {
                        ProgressView()
                    }
                    Text("Accedi")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!userProfileStore.canAttemptLogin || userProfileStore.isAuthenticating)

            Spacer()
        }
        .padding()
    }
}

private struct DashboardView: View {
    @EnvironmentObject private var userProfileStore: UserProfileStore

    var body: some View {
        VStack(spacing: 24) {
            Text("👋🏻 Hello, \(userProfileStore.greetingName)")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Text("Benvenuto, operatore")
                .font(.largeTitle).bold()

            NavigationLink(destination: VehiclesView()) {
                Text("Visura Veicoli")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            NavigationLink(destination: ARTrackingView()) {
                Text("Inizia Rilevazione")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button(role: .destructive) {
                userProfileStore.logout()
            } label: {
                Text("Logout")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(VehicleStore())
        .environmentObject(ARTrackingSceneStore())
        .environmentObject(UserProfileStore())
}
