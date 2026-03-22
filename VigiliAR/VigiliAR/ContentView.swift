import SwiftUI

struct ContentView : View {
    @EnvironmentObject private var userProfileStore: UserProfileStore
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
                    DashboardView()
                } else {
                    LoginView()
                }
            }
            .navigationTitle("")
        }
    }
}

private struct IntroSplashView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.18, blue: 0.35), Color(red: 0.03, green: 0.08, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(18)
                    .background(Color.white.opacity(0.16), in: Circle())

                Text("VigiliAR")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Supporto operativo per il controllo su strada con realtà aumentata.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 10) {
                    Label("Riconoscimento e visura rapida del veicolo", systemImage: "car.fill")
                    Label("Pannelli informativi in sovraimpressione", systemImage: "view.3d")
                    Label("Posizionamento con raycast e anchors", systemImage: "dot.scope")
                    Label("Acquisizione scena con tecnologia ARKit", systemImage: "arkit")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 20)

                Spacer()

                Button(action: onContinue) {
                    Text("Inizia")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(Color(red: 0.05, green: 0.18, blue: 0.35))
                .padding(.horizontal, 20)
                .padding(.bottom, 26)
            }
        }
    }
}

private struct LoginView: View {
    @EnvironmentObject private var userProfileStore: UserProfileStore

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.97, blue: 1.0), Color(red: 0.88, green: 0.93, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                VStack(spacing: 8) {
                    Text("VigiliAR")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Accesso Operatore")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 14) {
                    RoundedInputField(
                        title: "Nome",
                        systemImage: "person.fill",
                        text: $userProfileStore.name,
                        capitalization: .words,
                        disableAutocorrection: false
                    )

                    RoundedInputField(
                        title: "Cognome",
                        systemImage: "person.text.rectangle.fill",
                        text: $userProfileStore.surname,
                        capitalization: .words,
                        disableAutocorrection: false
                    )

                    RoundedInputField(
                        title: "Identificativo",
                        systemImage: "number.square.fill",
                        text: $userProfileStore.identifier,
                        capitalization: .never,
                        disableAutocorrection: true
                    )

                    if !userProfileStore.authStatusMessage.isEmpty {
                        Text(userProfileStore.authStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }

                    Button {
                        userProfileStore.login()
                    } label: {
                        HStack(spacing: 10) {
                            if userProfileStore.isAuthenticating {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text("Accedi")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .background(Color(red: 0.07, green: 0.28, blue: 0.52), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .foregroundStyle(.white)
                    .disabled(!userProfileStore.canAttemptLogin || userProfileStore.isAuthenticating)
                    .opacity((!userProfileStore.canAttemptLogin || userProfileStore.isAuthenticating) ? 0.65 : 1.0)
                    .padding(.top, 6)
                }
                .padding(18)
                .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
                .padding(.horizontal, 16)

                Spacer()
            }
        }
    }
}

private struct RoundedInputField: View {
    let title: String
    let systemImage: String
    @Binding var text: String
    let capitalization: TextInputAutocapitalization
    let disableAutocorrection: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(Color(red: 0.07, green: 0.28, blue: 0.52))
                .frame(width: 18)

            TextField(title, text: $text)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled(disableAutocorrection)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(red: 0.82, green: 0.87, blue: 0.94), lineWidth: 1)
        )
    }
}

private struct DashboardView: View {
    @EnvironmentObject private var userProfileStore: UserProfileStore

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.97, blue: 1.0), Color(red: 0.88, green: 0.93, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ciao, \(userProfileStore.greetingName)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Dashboard operativa")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 12) {
                    Label("Presa Servizio", systemImage: "calendar.badge.clock")
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.07, green: 0.28, blue: 0.52))

                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.secondary)
                        Text(userProfileStore.formattedServiceStartDateTime)
                            .font(.subheadline.weight(.semibold))
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.secondary)
                            .padding(.top, 1)
                        if userProfileStore.isResolvingServiceLocation {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Ricerca via in corso...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text(userProfileStore.serviceStreet)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }

                    if shouldShowServiceStatusMessage {
                        Text(userProfileStore.serviceStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.8), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 8)

                VStack(spacing: 12) {
                    NavigationLink(destination: VehiclesView()) {
                        Label("Visura Veicoli", systemImage: "car.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color(red: 0.82, green: 0.87, blue: 0.94), lineWidth: 1)
                    )

                    NavigationLink(destination: ARTrackingView()) {
                        Label("Inizia Rilevazione", systemImage: "camera.viewfinder")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .background(Color(red: 0.07, green: 0.28, blue: 0.52), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .foregroundStyle(.white)

                    NavigationLink(destination: ServiceTrackView()) {
                        Label("Tracciato Operatore", systemImage: "map.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color(red: 0.82, green: 0.87, blue: 0.94), lineWidth: 1)
                    )
                }
                Spacer()
            }
            .padding(16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    userProfileStore.logout()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.headline)
                }
            }
        }
        .onAppear {
            userProfileStore.startServiceSessionIfNeeded()
        }
    }

    private var shouldShowServiceStatusMessage: Bool {
        if userProfileStore.serviceStatusMessage.isEmpty { return false }
        if userProfileStore.isResolvingServiceLocation { return true }
        if userProfileStore.serviceStatusMessage.contains("non salvata") { return true }
        return userProfileStore.serviceStreet == "Via non disponibile" || userProfileStore.serviceStreet == "Posizione non autorizzata"
    }
}

#Preview {
    ContentView()
        .environmentObject(VehicleStore())
        .environmentObject(ARTrackingSceneStore())
        .environmentObject(UserProfileStore())
}
