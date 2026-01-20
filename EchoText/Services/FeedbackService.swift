import Foundation
import AppKit

/// Types of feedback
enum FeedbackType: String, CaseIterable, Identifiable {
    case bug = "Bug Report"
    case feature = "Feature Request"
    case general = "General Feedback"
    case question = "Question"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .bug: return "ladybug"
        case .feature: return "lightbulb"
        case .general: return "bubble.left"
        case .question: return "questionmark.circle"
        }
    }

    var placeholder: String {
        switch self {
        case .bug: return "Please describe what happened and steps to reproduce..."
        case .feature: return "Describe the feature you'd like to see..."
        case .general: return "Share your thoughts..."
        case .question: return "What would you like to know?"
        }
    }
}

/// Feedback submission model
struct FeedbackSubmission: Codable {
    let type: String
    let message: String
    let email: String?
    let appVersion: String
    let buildNumber: String
    let macOSVersion: String
    let timestamp: String
    let systemInfo: SystemInfo

    struct SystemInfo: Codable {
        let modelIdentifier: String
        let processorCount: Int
        let memoryGB: Int
        let locale: String
    }
}

/// Response from feedback API
struct FeedbackResponse: Codable {
    let success: Bool
    let message: String?
    let ticketId: String?
}

/// Service for submitting user feedback
@MainActor
final class FeedbackService: ObservableObject {
    /// Shared instance
    static let shared = FeedbackService()

    /// Whether feedback is being submitted
    @Published var isSubmitting = false

    /// Last submission result
    @Published var lastResult: Result<FeedbackResponse, Error>?

    private let feedbackURL = Constants.Feedback.serverURL

    private init() {}

    /// Submit feedback to the server
    func submitFeedback(
        type: FeedbackType,
        message: String,
        email: String? = nil,
        includeSystemInfo: Bool = true
    ) async throws -> FeedbackResponse {
        isSubmitting = true
        defer { isSubmitting = false }

        let submission = FeedbackSubmission(
            type: type.rawValue,
            message: message,
            email: email?.isEmpty == true ? nil : email,
            appVersion: Constants.appVersion,
            buildNumber: Constants.buildNumber,
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            systemInfo: includeSystemInfo ? gatherSystemInfo() : FeedbackSubmission.SystemInfo(
                modelIdentifier: "hidden",
                processorCount: 0,
                memoryGB: 0,
                locale: "hidden"
            )
        )

        guard let url = URL(string: "\(feedbackURL)/submit") else {
            throw FeedbackError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(submission)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedbackError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(FeedbackResponse.self, from: data) {
                throw FeedbackError.serverError(errorResponse.message ?? "Unknown error")
            }
            throw FeedbackError.serverError("HTTP \(httpResponse.statusCode)")
        }

        let feedbackResponse = try JSONDecoder().decode(FeedbackResponse.self, from: data)
        lastResult = .success(feedbackResponse)

        // Track feedback submission
        TelemetryService.shared.trackFeatureUsed("feedback.submitted.\(type.rawValue)")

        return feedbackResponse
    }

    /// Gather non-identifying system information
    private func gatherSystemInfo() -> FeedbackSubmission.SystemInfo {
        let processInfo = ProcessInfo.processInfo

        // Get model identifier (e.g., "MacBookPro18,1")
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let modelIdentifier = String(cString: model)

        // Get memory in GB (rounded)
        let memoryGB = Int(processInfo.physicalMemory / 1_073_741_824)

        return FeedbackSubmission.SystemInfo(
            modelIdentifier: modelIdentifier,
            processorCount: processInfo.processorCount,
            memoryGB: memoryGB,
            locale: Locale.current.identifier
        )
    }

    /// Open email client as fallback
    func openEmailFallback(type: FeedbackType, message: String) {
        let subject = "[\(type.rawValue)] EchoText Feedback"
        let body = """
        \(message)

        ---
        App Version: \(Constants.appVersion) (\(Constants.buildNumber))
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        """

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:support@echotext.app?subject=\(encodedSubject)&body=\(encodedBody)") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Feedback-related errors
enum FeedbackError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid feedback server URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}
