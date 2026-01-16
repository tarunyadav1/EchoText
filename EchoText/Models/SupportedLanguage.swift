import Foundation

/// Represents a language supported by Whisper for transcription
struct SupportedLanguage: Identifiable, Codable, Hashable {
    let code: String
    let name: String
    let nativeName: String

    var id: String { code }

    var displayName: String {
        if nativeName != name {
            return "\(name) (\(nativeName))"
        }
        return name
    }

    static let autoDetect = SupportedLanguage(code: "auto", name: "Auto-detect", nativeName: "Auto-detect")

    static let allLanguages: [SupportedLanguage] = [
        autoDetect,
        SupportedLanguage(code: "en", name: "English", nativeName: "English"),
        SupportedLanguage(code: "zh", name: "Chinese", nativeName: "中文"),
        SupportedLanguage(code: "de", name: "German", nativeName: "Deutsch"),
        SupportedLanguage(code: "es", name: "Spanish", nativeName: "Español"),
        SupportedLanguage(code: "ru", name: "Russian", nativeName: "Русский"),
        SupportedLanguage(code: "ko", name: "Korean", nativeName: "한국어"),
        SupportedLanguage(code: "fr", name: "French", nativeName: "Français"),
        SupportedLanguage(code: "ja", name: "Japanese", nativeName: "日本語"),
        SupportedLanguage(code: "pt", name: "Portuguese", nativeName: "Português"),
        SupportedLanguage(code: "tr", name: "Turkish", nativeName: "Türkçe"),
        SupportedLanguage(code: "pl", name: "Polish", nativeName: "Polski"),
        SupportedLanguage(code: "ca", name: "Catalan", nativeName: "Català"),
        SupportedLanguage(code: "nl", name: "Dutch", nativeName: "Nederlands"),
        SupportedLanguage(code: "ar", name: "Arabic", nativeName: "العربية"),
        SupportedLanguage(code: "sv", name: "Swedish", nativeName: "Svenska"),
        SupportedLanguage(code: "it", name: "Italian", nativeName: "Italiano"),
        SupportedLanguage(code: "id", name: "Indonesian", nativeName: "Bahasa Indonesia"),
        SupportedLanguage(code: "hi", name: "Hindi", nativeName: "हिन्दी"),
        SupportedLanguage(code: "fi", name: "Finnish", nativeName: "Suomi"),
        SupportedLanguage(code: "vi", name: "Vietnamese", nativeName: "Tiếng Việt"),
        SupportedLanguage(code: "he", name: "Hebrew", nativeName: "עברית"),
        SupportedLanguage(code: "uk", name: "Ukrainian", nativeName: "Українська"),
        SupportedLanguage(code: "el", name: "Greek", nativeName: "Ελληνικά"),
        SupportedLanguage(code: "ms", name: "Malay", nativeName: "Bahasa Melayu"),
        SupportedLanguage(code: "cs", name: "Czech", nativeName: "Čeština"),
        SupportedLanguage(code: "ro", name: "Romanian", nativeName: "Română"),
        SupportedLanguage(code: "da", name: "Danish", nativeName: "Dansk"),
        SupportedLanguage(code: "hu", name: "Hungarian", nativeName: "Magyar"),
        SupportedLanguage(code: "ta", name: "Tamil", nativeName: "தமிழ்"),
        SupportedLanguage(code: "no", name: "Norwegian", nativeName: "Norsk"),
        SupportedLanguage(code: "th", name: "Thai", nativeName: "ไทย"),
        SupportedLanguage(code: "ur", name: "Urdu", nativeName: "اردو"),
        SupportedLanguage(code: "hr", name: "Croatian", nativeName: "Hrvatski"),
        SupportedLanguage(code: "bg", name: "Bulgarian", nativeName: "Български"),
        SupportedLanguage(code: "lt", name: "Lithuanian", nativeName: "Lietuvių"),
        SupportedLanguage(code: "la", name: "Latin", nativeName: "Latina"),
        SupportedLanguage(code: "mi", name: "Maori", nativeName: "Māori"),
        SupportedLanguage(code: "ml", name: "Malayalam", nativeName: "മലയാളം"),
        SupportedLanguage(code: "cy", name: "Welsh", nativeName: "Cymraeg"),
        SupportedLanguage(code: "sk", name: "Slovak", nativeName: "Slovenčina"),
        SupportedLanguage(code: "te", name: "Telugu", nativeName: "తెలుగు"),
        SupportedLanguage(code: "fa", name: "Persian", nativeName: "فارسی"),
        SupportedLanguage(code: "lv", name: "Latvian", nativeName: "Latviešu"),
        SupportedLanguage(code: "bn", name: "Bengali", nativeName: "বাংলা"),
        SupportedLanguage(code: "sr", name: "Serbian", nativeName: "Српски"),
        SupportedLanguage(code: "az", name: "Azerbaijani", nativeName: "Azərbaycan"),
        SupportedLanguage(code: "sl", name: "Slovenian", nativeName: "Slovenščina"),
        SupportedLanguage(code: "kn", name: "Kannada", nativeName: "ಕನ್ನಡ"),
        SupportedLanguage(code: "et", name: "Estonian", nativeName: "Eesti"),
        SupportedLanguage(code: "mk", name: "Macedonian", nativeName: "Македонски"),
        SupportedLanguage(code: "br", name: "Breton", nativeName: "Brezhoneg"),
        SupportedLanguage(code: "eu", name: "Basque", nativeName: "Euskara"),
        SupportedLanguage(code: "is", name: "Icelandic", nativeName: "Íslenska"),
        SupportedLanguage(code: "hy", name: "Armenian", nativeName: "Հայերdelays"),
        SupportedLanguage(code: "ne", name: "Nepali", nativeName: "नेपाली"),
        SupportedLanguage(code: "mn", name: "Mongolian", nativeName: "Монгол"),
        SupportedLanguage(code: "bs", name: "Bosnian", nativeName: "Bosanski"),
        SupportedLanguage(code: "kk", name: "Kazakh", nativeName: "Қазақ"),
        SupportedLanguage(code: "sq", name: "Albanian", nativeName: "Shqip"),
        SupportedLanguage(code: "sw", name: "Swahili", nativeName: "Kiswahili"),
        SupportedLanguage(code: "gl", name: "Galician", nativeName: "Galego"),
        SupportedLanguage(code: "mr", name: "Marathi", nativeName: "मराठी"),
        SupportedLanguage(code: "pa", name: "Punjabi", nativeName: "ਪੰਜਾਬੀ"),
        SupportedLanguage(code: "si", name: "Sinhala", nativeName: "සිංහල"),
        SupportedLanguage(code: "km", name: "Khmer", nativeName: "ភាសាខ្មែរ"),
        SupportedLanguage(code: "sn", name: "Shona", nativeName: "chiShona"),
        SupportedLanguage(code: "yo", name: "Yoruba", nativeName: "Yorùbá"),
        SupportedLanguage(code: "so", name: "Somali", nativeName: "Soomaali"),
        SupportedLanguage(code: "af", name: "Afrikaans", nativeName: "Afrikaans"),
        SupportedLanguage(code: "oc", name: "Occitan", nativeName: "Occitan"),
        SupportedLanguage(code: "ka", name: "Georgian", nativeName: "ქართული"),
        SupportedLanguage(code: "be", name: "Belarusian", nativeName: "Беларуская"),
        SupportedLanguage(code: "tg", name: "Tajik", nativeName: "Тоҷикӣ"),
        SupportedLanguage(code: "sd", name: "Sindhi", nativeName: "سنڌي"),
        SupportedLanguage(code: "gu", name: "Gujarati", nativeName: "ગુજરાતી"),
        SupportedLanguage(code: "am", name: "Amharic", nativeName: "አማርኛ"),
        SupportedLanguage(code: "yi", name: "Yiddish", nativeName: "ייִדיש"),
        SupportedLanguage(code: "lo", name: "Lao", nativeName: "ລາວ"),
        SupportedLanguage(code: "uz", name: "Uzbek", nativeName: "Oʻzbek"),
        SupportedLanguage(code: "fo", name: "Faroese", nativeName: "Føroyskt"),
        SupportedLanguage(code: "ht", name: "Haitian Creole", nativeName: "Kreyòl ayisyen"),
        SupportedLanguage(code: "ps", name: "Pashto", nativeName: "پښتو"),
        SupportedLanguage(code: "tk", name: "Turkmen", nativeName: "Türkmen"),
        SupportedLanguage(code: "nn", name: "Nynorsk", nativeName: "Nynorsk"),
        SupportedLanguage(code: "mt", name: "Maltese", nativeName: "Malti"),
        SupportedLanguage(code: "sa", name: "Sanskrit", nativeName: "संस्कृतम्"),
        SupportedLanguage(code: "lb", name: "Luxembourgish", nativeName: "Lëtzebuergesch"),
        SupportedLanguage(code: "my", name: "Myanmar", nativeName: "မြန်မာ"),
        SupportedLanguage(code: "bo", name: "Tibetan", nativeName: "བོད་སྐད"),
        SupportedLanguage(code: "tl", name: "Tagalog", nativeName: "Tagalog"),
        SupportedLanguage(code: "mg", name: "Malagasy", nativeName: "Malagasy"),
        SupportedLanguage(code: "as", name: "Assamese", nativeName: "অসমীয়া"),
        SupportedLanguage(code: "tt", name: "Tatar", nativeName: "Татар"),
        SupportedLanguage(code: "haw", name: "Hawaiian", nativeName: "ʻŌlelo Hawaiʻi"),
        SupportedLanguage(code: "ln", name: "Lingala", nativeName: "Lingála"),
        SupportedLanguage(code: "ha", name: "Hausa", nativeName: "Hausa"),
        SupportedLanguage(code: "ba", name: "Bashkir", nativeName: "Башҡорт"),
        SupportedLanguage(code: "jw", name: "Javanese", nativeName: "Basa Jawa"),
        SupportedLanguage(code: "su", name: "Sundanese", nativeName: "Basa Sunda")
    ]

    static func language(forCode code: String) -> SupportedLanguage? {
        allLanguages.first { $0.code == code }
    }
}
