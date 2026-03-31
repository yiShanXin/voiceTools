import AppKit
import Foundation

final class AppController: NSObject, NSApplicationDelegate {
    private let config = AppConfig.shared
    private let transcriber = AudioTranscriber()
    private let keyMonitor = FnKeyMonitor()
    private let overlay = OverlayPanelController()
    private let injector = TextInjector()
    private let refiner = LLMRefiner()

    private var statusItem: NSStatusItem?
    private var settingsWindowController: SettingsWindowController?
    private var isRecording = false

    private var languageMenuItem: NSMenuItem?
    private var llmToggleItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupCallbacks()
        keyMonitor.start()
        AudioTranscriber.requestPermissions {}
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyMonitor.stop()
    }

    private func setupCallbacks() {
        transcriber.onPartialText = { [weak self] text in
            self?.overlay.updateText(text)
        }

        transcriber.onAudioLevel = { [weak self] level in
            self?.overlay.updateAudioLevel(level)
        }

        keyMonitor.onPress = { [weak self] in
            self?.beginRecording()
        }

        keyMonitor.onRelease = { [weak self] in
            self?.endRecording()
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "VoiceTools")
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let hint = NSMenuItem(title: "Hold Fn to Talk", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())

        let language = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        language.submenu = makeLanguageSubmenu()
        menu.addItem(language)
        languageMenuItem = language

        let llm = NSMenuItem(title: "LLM Refinement", action: nil, keyEquivalent: "")
        llm.submenu = makeLLMSubmenu()
        menu.addItem(llm)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func makeLanguageSubmenu() -> NSMenu {
        let submenu = NSMenu(title: "Language")

        for option in LanguageOption.allCases {
            let item = NSMenuItem(title: option.menuTitle, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = option.rawValue
            item.state = (config.language == option) ? .on : .off
            submenu.addItem(item)
        }

        return submenu
    }

    private func makeLLMSubmenu() -> NSMenu {
        let submenu = NSMenu(title: "LLM Refinement")

        let toggle = NSMenuItem(title: "Enabled", action: #selector(toggleLLM), keyEquivalent: "")
        toggle.target = self
        toggle.state = config.llmEnabled ? .on : .off
        submenu.addItem(toggle)
        llmToggleItem = toggle

        let settings = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: "")
        settings.target = self
        submenu.addItem(settings)

        return submenu
    }

    private func beginRecording() {
        guard !isRecording else { return }
        isRecording = true

        overlay.show(text: "请讲话…")

        do {
            try transcriber.start(locale: config.language.locale)
        } catch {
            overlay.updateText("Speech unavailable")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.overlay.hide()
            }
            isRecording = false
        }
    }

    private func endRecording() {
        guard isRecording else { return }
        isRecording = false

        transcriber.stop { [weak self] raw in
            guard let self else { return }
            guard !raw.isEmpty else {
                self.overlay.hide()
                return
            }

            if self.config.llmEnabled {
                let settings = LLMSettings(
                    baseURL: self.config.apiBaseURL,
                    apiKey: self.config.apiKey,
                    model: self.config.model
                )

                if settings.isConfigured {
                    self.overlay.updateText("Refining...")
                    self.refiner.refine(raw, settings: settings) { refined in
                        DispatchQueue.main.async {
                            self.overlay.updateText(refined)
                            DispatchQueue.global(qos: .userInitiated).async {
                                self.injector.inject(refined)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                self.overlay.hide()
                            }
                        }
                    }
                    return
                }
            }

            DispatchQueue.global(qos: .userInitiated).async {
                self.injector.inject(raw)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                self.overlay.hide()
            }
        }
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let option = LanguageOption(rawValue: raw) else {
            return
        }
        config.language = option
        rebuildMenu()
    }

    @objc private func toggleLLM() {
        config.llmEnabled.toggle()
        llmToggleItem?.state = config.llmEnabled ? .on : .off
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            let controller = SettingsWindowController()
            controller.onSaved = { [weak self] in
                self?.rebuildMenu()
            }
            settingsWindowController = controller
        }

        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
