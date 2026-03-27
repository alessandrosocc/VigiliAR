import SwiftUI
import UIKit

struct EnableSwipeBackModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(SwipeBackEnablerView())
    }
}

extension View {
    func enableSwipeBack() -> some View {
        modifier(EnableSwipeBackModifier())
    }
}

private struct SwipeBackEnablerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> SwipeBackEnablerViewController {
        SwipeBackEnablerViewController()
    }

    func updateUIViewController(_ uiViewController: SwipeBackEnablerViewController, context: Context) {}
}

private final class SwipeBackEnablerViewController: UIViewController, UIGestureRecognizerDelegate {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableSwipeBackIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        enableSwipeBackIfNeeded()
    }

    private func enableSwipeBackIfNeeded() {
        guard let navigationController = navigationController else { return }
        guard let gesture = navigationController.interactivePopGestureRecognizer else { return }

        gesture.isEnabled = true
        gesture.delegate = self
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigationController = navigationController else { return false }
        return navigationController.viewControllers.count > 1
    }
}
