import Foundation

// MARK: - NetworkError Definition
enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)
    case decodingError(Error)
    case parsingError
    case dataError
    case timeoutError

    // MARK: - Initialization

    // Custom initializer for easier creation of network errors
    init(_ code: Int, _ message: String) {
        // Using serverError as a fallback for all custom error cases
        self = .serverError(statusCode: code)
    }

    // MARK: - Properties

    // User-friendly error descriptions
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let statusCode):
            return "Server error with status code: \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .parsingError:
            return "Failed to parse response"
        case .dataError:
            return "Invalid data format"
        case .timeoutError:
            return "Request timed out"
        }
    }

    // More detailed user-friendly description
    var userFriendlyDescription: String {
        switch self {
        case .invalidURL:
            return "The URL for this request was invalid. Please try again later."
        case .invalidResponse:
            return "We received an invalid response from the server. Please try again later."
        case .serverError(let statusCode):
            switch statusCode {
            case 401:
                return "You need to be authenticated to access this resource."
            case 403:
                return "You don't have permission to access this resource."
            case 404:
                return "The requested resource could not be found."
            case 500...599:
                return "The server encountered an error. Please try again later."
            default:
                return "An error occurred (code: \(statusCode)). Please try again later."
            }
        case .decodingError(let error):
            return "Failed to process the data: \(error.localizedDescription)"
        case .parsingError:
            return "Failed to parse the server response. Please try again later."
        case .dataError:
            return "The data format received was invalid. Please try again later."
        case .timeoutError:
            return "The request timed out. Please check your internet connection and try again."
        }
    }
}
