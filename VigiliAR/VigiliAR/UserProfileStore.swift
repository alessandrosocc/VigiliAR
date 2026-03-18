import Foundation
import Combine

final class UserProfileStore: ObservableObject {
    @Published var name: String = ""

    var greetingName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "there" : trimmed
    }
}
