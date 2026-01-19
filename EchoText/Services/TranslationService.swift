import Foundation
import NaturalLanguage
import Translation

/// Supported translation languages matching Apple's Translation framework
enum TranslationLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case russian = "ru"
    case arabic = "ar"
    case hindi = "hi"
    case dutch = "nl"
    case polish = "pl"
    case turkish = "tr"
    case vietnamese = "vi"
    case thai = "th"
    case indonesian = "id"
    case swedish = "sv"
    case danish = "da"
    case norwegian = "no"
    case finnish = "fi"
    case czech = "cs"
    case greek = "el"
    case hebrew = "he"
    case ukrainian = "uk"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .chinese: return "Chinese"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .russian: return "Russian"
        case .arabic: return "Arabic"
        case .hindi: return "Hindi"
        case .dutch: return "Dutch"
        case .polish: return "Polish"
        case .turkish: return "Turkish"
        case .vietnamese: return "Vietnamese"
        case .thai: return "Thai"
        case .indonesian: return "Indonesian"
        case .swedish: return "Swedish"
        case .danish: return "Danish"
        case .norwegian: return "Norwegian"
        case .finnish: return "Finnish"
        case .czech: return "Czech"
        case .greek: return "Greek"
        case .hebrew: return "Hebrew"
        case .ukrainian: return "Ukrainian"
        }
    }

    var nativeName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .portuguese: return "Português"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .russian: return "Русский"
        case .arabic: return "العربية"
        case .hindi: return "हिन्दी"
        case .dutch: return "Nederlands"
        case .polish: return "Polski"
        case .turkish: return "Türkçe"
        case .vietnamese: return "Tiếng Việt"
        case .thai: return "ภาษาไทย"
        case .indonesian: return "Bahasa Indonesia"
        case .swedish: return "Svenska"
        case .danish: return "Dansk"
        case .norwegian: return "Norsk"
        case .finnish: return "Suomi"
        case .czech: return "Čeština"
        case .greek: return "Ελληνικά"
        case .hebrew: return "עברית"
        case .ukrainian: return "Українська"
        }
    }

    /// Get flag emoji for the language
    var flag: String {
        switch self {
        case .english: return "GB"
        case .spanish: return "ES"
        case .french: return "FR"
        case .german: return "DE"
        case .italian: return "IT"
        case .portuguese: return "PT"
        case .chinese: return "CN"
        case .japanese: return "JP"
        case .korean: return "KR"
        case .russian: return "RU"
        case .arabic: return "SA"
        case .hindi: return "IN"
        case .dutch: return "NL"
        case .polish: return "PL"
        case .turkish: return "TR"
        case .vietnamese: return "VN"
        case .thai: return "TH"
        case .indonesian: return "ID"
        case .swedish: return "SE"
        case .danish: return "DK"
        case .norwegian: return "NO"
        case .finnish: return "FI"
        case .czech: return "CZ"
        case .greek: return "GR"
        case .hebrew: return "IL"
        case .ukrainian: return "UA"
        }
    }

    /// Convert country code to flag emoji
    var flagEmoji: String {
        let base: UInt32 = 127397
        var emoji = ""
        for scalar in flag.uppercased().unicodeScalars {
            if let flagScalar = UnicodeScalar(base + scalar.value) {
                emoji.append(String(flagScalar))
            }
        }
        return emoji
    }

    /// Convert to Locale.Language for Apple Translation framework
    var localeLanguage: Locale.Language {
        Locale.Language(identifier: rawValue)
    }

    /// Initialize from language code string
    static func from(code: String?) -> TranslationLanguage? {
        guard let code = code?.lowercased().prefix(2) else { return nil }
        return TranslationLanguage(rawValue: String(code))
    }
}

/// Errors that can occur during translation
enum TranslationError: LocalizedError {
    case translationNotAvailable
    case languagePairNotSupported(source: String, target: String)
    case translationFailed(String)
    case downloadRequired
    case cancelled
    case sessionNotAvailable

    var errorDescription: String? {
        switch self {
        case .translationNotAvailable:
            return "Translation service is not available on this device"
        case .languagePairNotSupported(let source, let target):
            return "Translation from \(source) to \(target) is not supported"
        case .translationFailed(let message):
            return "Translation failed: \(message)"
        case .downloadRequired:
            return "Language pack download required"
        case .cancelled:
            return "Translation was cancelled"
        case .sessionNotAvailable:
            return "Translation session not available. Please try again."
        }
    }
}

/// Service for managing translation state and configuration
/// Uses Apple's Translation framework for on-device translation
@MainActor
final class TranslationService: ObservableObject {

    // MARK: - Singleton
    static let shared = TranslationService()

    // MARK: - Published Properties
    @Published private(set) var isTranslating: Bool = false
    @Published private(set) var translationProgress: Double = 0.0
    @Published private(set) var isLanguageAvailable: Bool = true
    @Published var lastError: TranslationError?

    /// Current translation configuration - set this to trigger translation
    @Published var translationConfiguration: TranslationSession.Configuration?

    /// Pending segments to translate
    @Published var pendingSegments: [TranscriptionSegment] = []

    /// Translated segments result
    @Published var translatedSegments: [TranscriptionSegment] = []

    /// Target language for translation
    @Published var targetLanguage: TranslationLanguage = .spanish

    // MARK: - Private Properties
    private var translationCache: [String: String] = [:]

    // MARK: - Initialization
    private init() {}

    // MARK: - Cache Key Generation
    private func cacheKey(for text: String, targetLanguage: String) -> String {
        return "\(text.hashValue)_\(targetLanguage)"
    }

    // MARK: - Public Methods

    /// Detect the language of text using NaturalLanguage framework
    func detectLanguage(of text: String) -> TranslationLanguage? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let languageCode = recognizer.dominantLanguage?.rawValue else {
            return nil
        }

        return TranslationLanguage.from(code: languageCode)
    }

    /// Check if a language pair is supported
    func checkLanguageSupport(
        source: TranslationLanguage?,
        target: TranslationLanguage
    ) async -> Bool {
        let availability = LanguageAvailability()
        let sourceLocale = source?.localeLanguage
        let targetLocale = target.localeLanguage

        let status = await availability.status(
            from: sourceLocale ?? Locale.Language(identifier: "en"),
            to: targetLocale
        )

        switch status {
        case .installed, .supported:
            return true
        case .unsupported:
            return false
        @unknown default:
            return false
        }
    }

    /// Prepare translation configuration for a language pair
    func prepareTranslation(
        sourceLanguage: TranslationLanguage?,
        targetLanguage: TranslationLanguage
    ) {
        self.targetLanguage = targetLanguage

        // Create configuration - nil source means auto-detect
        let config = TranslationSession.Configuration(
            source: sourceLanguage?.localeLanguage,
            target: targetLanguage.localeLanguage
        )

        // Setting this will trigger the translationTask in the view
        self.translationConfiguration = config
    }

    /// Queue segments for translation
    func queueSegmentsForTranslation(_ segments: [TranscriptionSegment]) {
        self.pendingSegments = segments
        self.translatedSegments = []
        self.isTranslating = true
        self.translationProgress = 0.0
    }

    /// Translate segments using the provided session
    func translateWithSession(
        _ session: TranslationSession,
        segments: [TranscriptionSegment]
    ) async throws -> [TranscriptionSegment] {
        guard !segments.isEmpty else { return [] }

        isTranslating = true
        translationProgress = 0.0
        lastError = nil

        defer {
            isTranslating = false
            translationProgress = 1.0
        }

        var translatedSegments: [TranscriptionSegment] = []
        let totalSegments = Double(segments.count)

        // Prepare translation (downloads models if needed)
        try await session.prepareTranslation()

        for (index, segment) in segments.enumerated() {
            // Check for cancellation
            try Task.checkCancellation()

            // Check cache first
            let key = cacheKey(for: segment.text, targetLanguage: targetLanguage.rawValue)

            let translatedText: String
            if let cached = translationCache[key] {
                translatedText = cached
            } else {
                // Translate using Apple's framework
                let response = try await session.translate(segment.text)
                translatedText = response.targetText

                // Cache the translation
                translationCache[key] = translatedText
            }

            let translatedSegment = TranscriptionSegment(
                id: segment.id,
                uuid: segment.uuid,
                text: translatedText,
                startTime: segment.startTime,
                endTime: segment.endTime,
                speakerId: segment.speakerId,
                isFavorite: segment.isFavorite
            )

            translatedSegments.append(translatedSegment)

            // Update progress
            translationProgress = Double(index + 1) / totalSegments
        }

        return translatedSegments
    }

    /// Translate a single text string using the session
    func translateText(
        _ text: String,
        using session: TranslationSession
    ) async throws -> String {
        // Check cache first
        let key = cacheKey(for: text, targetLanguage: targetLanguage.rawValue)

        if let cached = translationCache[key] {
            return cached
        }

        // Translate using Apple's framework
        let response = try await session.translate(text)
        let translatedText = response.targetText

        // Cache the translation
        translationCache[key] = translatedText

        return translatedText
    }

    /// Cancel ongoing translation
    func cancelTranslation() {
        isTranslating = false
        pendingSegments = []
        translationConfiguration = nil
    }

    /// Clear translation cache
    func clearCache() {
        translationCache.removeAll()
    }

    /// Reset translation state
    func reset() {
        isTranslating = false
        translationProgress = 0.0
        pendingSegments = []
        translatedSegments = []
        translationConfiguration = nil
        lastError = nil
    }
}

// MARK: - Convenience Extensions

extension TranscriptionResult {
    /// Get detected source language as TranslationLanguage
    var sourceTranslationLanguage: TranslationLanguage? {
        TranslationLanguage.from(code: language)
    }
}
