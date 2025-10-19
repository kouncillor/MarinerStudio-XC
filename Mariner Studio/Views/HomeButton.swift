import SwiftUI

struct HomeButton: View {
    var body: some View {
        NavigationLink(destination: MainView(shouldClearNavigation: true)) {
            Image(systemName: "house.fill")
                .foregroundColor(.black)
        }
        .simultaneousGesture(TapGesture().onEnded {
            // Provide haptic feedback
            let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
            impactGenerator.prepare()
            impactGenerator.impactOccurred()
        })
    }
}

struct NotificationButton: View {
    @State private var showFeedback = false
    let sourceView: String

    var body: some View {
        Button(action: {
            showFeedback = true
        }) {
            Image(systemName: "pencil.and.list.clipboard")
                .foregroundColor(.black)
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView(sourceView: sourceView)
        }
    }
}

// MARK: - Toolbar Extensions
extension View {
    @ViewBuilder
    func withHomeButton() -> some View {
        self.modifier(HomeButtonModifier())
    }

    @ViewBuilder
    func withNotificationAndHome(sourceView: String) -> some View {
        self.modifier(NotificationAndHomeModifier(sourceView: sourceView))
    }
}

struct HomeButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HomeButton()
            }
        }
    }
}

struct NotificationAndHomeModifier: ViewModifier {
    let sourceView: String

    func body(content: Content) -> some View {
        content.toolbar {
            // Notification button (leftmost of the two)
            ToolbarItem(placement: .topBarTrailing) {
                NotificationButton(sourceView: sourceView)
            }

            // Home button (rightmost)
            ToolbarItem(placement: .topBarTrailing) {
                HomeButton()
            }
        }
    }
}
