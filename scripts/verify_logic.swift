import Foundation

// Mock AppSettings to test persistence and construction
class MockSettings: Codable {
    var customVocabulary: [String] = []
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "test_settings")
        }
    }
    
    static func load() -> MockSettings {
        if let data = UserDefaults.standard.data(forKey: "test_settings"),
           let settings = try? JSONDecoder().decode(MockSettings.self, from: data) {
            return settings
        }
        return MockSettings()
    }
}

print("--- Testing Custom Vocabulary Logic ---")

let settings = MockSettings()
settings.customVocabulary = ["Apple", "iPhone", "EchoText"]
settings.save()

let loadedSettings = MockSettings.load()
print("Loaded vocabulary: \(loadedSettings.customVocabulary)")

let prompt = loadedSettings.customVocabulary.joined(separator: ", ")
print("Constructed prompt: \"\(prompt)\"")

if prompt == "Apple, iPhone, EchoText" {
    print("✅ Prompt construction successful!")
} else {
    print("❌ Prompt construction failed.")
}

if loadedSettings.customVocabulary == ["Apple", "iPhone", "EchoText"] {
    print("✅ Persistence successful!")
} else {
    print("❌ Persistence failed.")
}
