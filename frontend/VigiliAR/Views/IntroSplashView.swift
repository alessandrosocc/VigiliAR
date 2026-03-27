import SwiftUI

struct IntroSplashView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 22) {
                Spacer()

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(20)
                    .background(Color.white.opacity(0.10), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                Text("VigiliAR")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Supporto operativo per il controllo su strada con realtà aumentata.")
                    .font(.body)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                VStack(alignment: .leading, spacing: 12) {
                    Label("Riconoscimento e visura rapida del veicolo", systemImage: "car.fill")
                    Label("Pannelli informativi in sovraimpressione", systemImage: "view.3d")
                    Label("Posizionamento con raycast e anchors", systemImage: "dot.scope")
                    Label("Acquisizione scena con ARKit", systemImage: "arkit")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
                .padding(.horizontal, 20)

                Spacer()

                Button(action: onContinue) {
                    Text("Inizia")
                        .font(.headline)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 26)
            }
        }
    }
}

#Preview("Intro Splash") {
    IntroSplashView {}
}
