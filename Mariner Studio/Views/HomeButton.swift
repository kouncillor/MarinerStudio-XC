
import SwiftUI

struct HomeButton: View {
    var body: some View {
        NavigationLink(destination: MainView(shouldClearNavigation: true)) {
            Image(systemName: "house.fill")
                .foregroundColor(.white)
        }
        .simultaneousGesture(TapGesture().onEnded {
            // Provide haptic feedback
            let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
            impactGenerator.prepare()
            impactGenerator.impactOccurred()
        })
    }
}

// MARK: - Toolbar Extension
extension View {
    @ViewBuilder
    func withHomeButton() -> some View {
        self.modifier(HomeButtonModifier())
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
