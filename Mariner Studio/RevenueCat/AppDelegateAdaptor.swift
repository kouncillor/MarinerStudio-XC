
import SwiftUI
import RevenueCat

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "appl_owWBbZSrntrBRGfXiVahtAozFrk")

        return true
    }
}
