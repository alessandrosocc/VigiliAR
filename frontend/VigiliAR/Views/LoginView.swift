import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var userProfileStore: UserProfileStore

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 26) {
                    // Header
                    HStack {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 42, height: 42)

                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)

                                Image(systemName: "shield")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .fixedSize()

                            VStack(alignment: .leading, spacing: 2) {
                                Text("VigiliAR")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)

                                Text("Controllo soste")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.textMuted)
                            }
                        }

                        Spacer()
                    }
                    .frame(height: 44)

                    // Welcome block
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ACCESSO")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                            .textCase(.uppercase)

                        Text("Area Operatore")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)

                        Text("Inserisci le credenziali operatore")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Login card
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                AppTheme.primary.opacity(0.28),
                                                Color.cyan.opacity(0.16)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 56, height: 56)

                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)

                                Image(systemName: "person.badge.key.fill")
                                    .font(.system(size: 21, weight: .semibold))
                                    .foregroundStyle(AppTheme.primary)
                            }
                            .fixedSize()

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Accesso Operatore")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(AppTheme.primary)

                                Text("Credenziali identificative per l’avvio sessione")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }

                            Spacer(minLength: 0)
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
                        }

                        if !userProfileStore.authStatusMessage.isEmpty {
                            LoginStatusMessageRow(
                                message: userProfileStore.authStatusMessage,
                                isLoading: userProfileStore.isAuthenticating
                            )
                        }

                        Button {
                            userProfileStore.login()
                        } label: {
                            HStack(spacing: 12) {
                                if userProfileStore.isAuthenticating {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                }

                                Text(userProfileStore.isAuthenticating ? "Verifica in corso..." : "Accedi")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .disabled(!userProfileStore.canAttemptLogin || userProfileStore.isAuthenticating)
                        .opacity((!userProfileStore.canAttemptLogin || userProfileStore.isAuthenticating) ? 0.65 : 1)
                        .padding(.top, 6)
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(.white.opacity(0.10))

                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.05),
                                            AppTheme.primary.opacity(0.08)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.12),
                                            .clear,
                                            .clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: AppTheme.primary.opacity(0.10), radius: 16, x: 0, y: 8)

                    // Support note
                    LoginSupportInfoCard(
                        title: "Accesso protetto",
                        message: "Autenticati con le credenziali operatore per avviare e registrare correttamente il servizio."
                    )
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 36)
            }
            .safeAreaPadding(.top, 14)
        }
    }
}

private struct LoginStatusMessageRow: View {
    enum Tone {
        case info
        case error
    }

    let message: String
    let isLoading: Bool

    private var tone: Tone {
        if isLoading {
            return .info
        }
        return .error
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(AppTheme.primary)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(iconColor)
                }
            }
            .frame(width: 16, height: 16)
            .padding(.top, 1)

            Text(message)
                .font(.footnote.weight(.medium))
                .foregroundStyle(textColor)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var iconName: String {
        switch tone {
        case .info:
            return "info.circle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    private var iconColor: Color {
        switch tone {
        case .info:
            return AppTheme.primary
        case .error:
            return Color.red.opacity(0.95)
        }
    }

    private var textColor: Color {
        switch tone {
        case .info:
            return Color.white.opacity(0.84)
        case .error:
            return Color.white.opacity(0.92)
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .info:
            return Color.white.opacity(0.06)
        case .error:
            return Color.red.opacity(0.12)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .info:
            return Color.white.opacity(0.08)
        case .error:
            return Color.red.opacity(0.22)
        }
    }
}

private struct LoginSupportInfoCard: View {
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.primary.opacity(0.18),
                                Color.cyan.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .frame(width: 42, height: 42)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primary)
            }
            .fixedSize()

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.07))

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.05),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

#Preview("Login") {
    LoginView()
        .environmentObject(UserProfileStore.previewLogin())
}

#Preview("Login - Filled") {
    LoginView()
        .environmentObject(
            UserProfileStore.previewLogin(
                name: "Alessandro",
                surname: "Cocco",
                identifier: "alesoccol2001"
            )
        )
}

#Preview("Login - Loading") {
    LoginView()
        .environmentObject(
            UserProfileStore.previewLogin(
                name: "Alessandro",
                surname: "Cocco",
                identifier: "alesoccol2001",
                authStatusMessage: "Verifica credenziali in corso...",
                isAuthenticating: true
            )
        )
}

#Preview("Login - Message") {
    LoginView()
        .environmentObject(
            UserProfileStore.previewLogin(
                authStatusMessage: "Inserisci Nome, Cognome e Identificativo."
            )
        )
}
