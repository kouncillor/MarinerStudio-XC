import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        DebugLogger.shared.log("💰 SIMPLE SUB: App starting with dead-simple subscription system", category: "SIMPLE_SUBSCRIPTION")
        DebugLogger.shared.log("💰 No servers. No RevenueCat. No bullshit.", category: "SIMPLE_SUBSCRIPTION")

        return true
    }
}
