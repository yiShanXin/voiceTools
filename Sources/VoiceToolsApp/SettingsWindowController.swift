import AppKit

final class SettingsWindowController: NSWindowController {
    var onSaved: (() -> Void)?

    private let config = AppConfig.shared
    private let refiner = LLMRefiner()

    private let baseURLField = NSTextField(string: "")
    private let apiKeyField = NSSecureTextField(string: "")
    private let modelField = NSTextField(string: "")

    convenience init() {
        let contentRect = NSRect(x: 0, y: 0, width: 560, height: 220)
        let style: NSWindow.StyleMask = [.titled, .closable]
        let window = NSWindow(contentRect: contentRect, styleMask: style, backing: .buffered, defer: false)
        window.title = "LLM Settings"
        window.center()
        self.init(window: window)
        setupUI()
        loadValues()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let baseLabel = makeLabel("API Base URL")
        let keyLabel = makeLabel("API Key")
        let modelLabel = makeLabel("Model")

        [baseLabel, keyLabel, modelLabel, baseURLField, apiKeyField, modelField].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveTapped))
        let testButton = NSButton(title: "Test", target: self, action: #selector(testTapped))

        saveButton.translatesAutoresizingMaskIntoConstraints = false
        testButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(saveButton)
        contentView.addSubview(testButton)

        baseURLField.placeholderString = "https://api.openai.com/v1"
        modelField.placeholderString = "gpt-4o-mini"

        NSLayoutConstraint.activate([
            baseLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            baseLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            baseLabel.widthAnchor.constraint(equalToConstant: 100),

            baseURLField.leadingAnchor.constraint(equalTo: baseLabel.trailingAnchor, constant: 12),
            baseURLField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            baseURLField.centerYAnchor.constraint(equalTo: baseLabel.centerYAnchor),

            keyLabel.leadingAnchor.constraint(equalTo: baseLabel.leadingAnchor),
            keyLabel.topAnchor.constraint(equalTo: baseLabel.bottomAnchor, constant: 24),
            keyLabel.widthAnchor.constraint(equalTo: baseLabel.widthAnchor),

            apiKeyField.leadingAnchor.constraint(equalTo: baseURLField.leadingAnchor),
            apiKeyField.trailingAnchor.constraint(equalTo: baseURLField.trailingAnchor),
            apiKeyField.centerYAnchor.constraint(equalTo: keyLabel.centerYAnchor),

            modelLabel.leadingAnchor.constraint(equalTo: baseLabel.leadingAnchor),
            modelLabel.topAnchor.constraint(equalTo: keyLabel.bottomAnchor, constant: 24),
            modelLabel.widthAnchor.constraint(equalTo: baseLabel.widthAnchor),

            modelField.leadingAnchor.constraint(equalTo: baseURLField.leadingAnchor),
            modelField.trailingAnchor.constraint(equalTo: baseURLField.trailingAnchor),
            modelField.centerYAnchor.constraint(equalTo: modelLabel.centerYAnchor),

            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),

            testButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -10),
            testButton.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor)
        ])
    }

    private func makeLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        label.alignment = .right
        return label
    }

    private func loadValues() {
        baseURLField.stringValue = config.apiBaseURL
        apiKeyField.stringValue = config.apiKey
        modelField.stringValue = config.model
    }

    @objc private func saveTapped() {
        config.apiBaseURL = baseURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        config.apiKey = apiKeyField.stringValue
        config.model = modelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        onSaved?()

        let alert = NSAlert()
        alert.messageText = "Saved"
        alert.informativeText = "LLM settings have been saved."
        alert.runModal()
    }

    @objc private func testTapped() {
        let settings = LLMSettings(
            baseURL: baseURLField.stringValue,
            apiKey: apiKeyField.stringValue,
            model: modelField.stringValue
        )

        refiner.testConnection(settings: settings) { result in
            DispatchQueue.main.async {
                let alert = NSAlert()
                switch result {
                case .success(let text):
                    alert.messageText = "Test Success"
                    alert.informativeText = "Sample output: \(text)"
                case .failure(let error):
                    alert.messageText = "Test Failed"
                    alert.informativeText = error.localizedDescription
                }
                alert.runModal()
            }
        }
    }
}
