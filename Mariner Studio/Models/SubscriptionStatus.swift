import Foundation

enum SubscriptionStatus: Equatable {
    case unknown
    case firstLaunch
    case skippedTrial
    case inTrial(daysRemaining: Int)
    case trialExpired
    case subscribed(expiryDate: Date?)
    case expired
    
    var hasAccess: Bool {
        switch self {
        case .inTrial, .subscribed:
            return true
        case .unknown, .firstLaunch, .skippedTrial, .trialExpired, .expired:
            return false
        }
    }
    
    var needsPaywall: Bool {
        switch self {
        case .trialExpired, .expired:
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
            return "Welcome! Your 3-day trial starts now."
        case .skippedTrial:
            return "Limited access - Subscribe for full features"
        case .inTrial(let days):
            return "Trial: \(days) days remaining"
        case .trialExpired:
            return "Trial expired - Subscribe to continue"
        case .subscribed:
            return "Subscribed"
        case .expired:
            return "Subscription expired"
        }
    }
}