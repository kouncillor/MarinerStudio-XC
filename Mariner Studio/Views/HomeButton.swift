
import SwiftUI

struct HomeButton: View {
    var body: some View {
        NavigationLink(destination: MainView(shouldClearNavigation: true)) {
            Image(systemName: "house.fill")
                .foregroundColor(.blue)
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
    func withHomeButton() -> some View {
        self.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HomeButton()
            }
        }
    }
}
