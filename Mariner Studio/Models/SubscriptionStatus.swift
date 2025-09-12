import Foundation

enum SubscriptionStatus: Equatable {
    case unknown
    case firstLaunch
    case subscribed(expiryDate: Date?)
    case expired
    
    var hasAccess: Bool {
        switch self {
        case .subscribed:
            return true
        case .unknown, .firstLaunch, .expired:
            return false
        }
    }
    
    var needsPaywall: Bool {
        switch self {
        case .expired, .firstLaunch:
            return true
        default:
            return false
        }
    }
    
    var displayMessage: String {
        switch self {
        case .unknown:
            return "Checking subscription status..."
        case .firstLaunch:
            return "Subscribe for full access"
        case .subscribed:
            return "Subscribed"
        case .expired:
            return "Subscription expired"
        }
    }
}