import SwiftUI

struct RoundedInputField: View {
    let title: String
    let systemImage: String
    @Binding var text: String
    let capitalization: TextInputAutocapitalization
    let disableAutocorrection: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.primary)
                .frame(width: 20)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(title)
                        .foregroundStyle(AppTheme.textMuted)
                }

                TextField("", text: $text)
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled(disableAutocorrection)
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }
}

#Preview("Rounded Input Field") {
    struct PreviewWrapper: View {
        @State private var text: String = "Alessandro"

        var body: some View {
            ZStack {
                AppBackground()

                RoundedInputField(
                    title: "Nome",
                    systemImage: "person.fill",
                    text: $text,
                    capitalization: .words,
                    disableAutocorrection: false
                )
                .padding(24)
            }
        }
    }

    return PreviewWrapper()
}
