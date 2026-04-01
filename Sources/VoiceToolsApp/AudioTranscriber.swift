import AVFoundation
import Foundation
import Speech

final class AudioTranscriber {
    var onPartialText: ((String) -> Void)?
    var onAudioLevel: ((CGFloat) -> Void)?

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    private var latestText = ""
    private var completion: ((String) -> Void)?
    private var stopFallbackWorkItem: DispatchWorkItem?

    static func requestPermissions(_ completion: @escaping () -> Void) {
        let group = DispatchGroup()

        group.enter()
        SFSpeechRecognizer.requestAuthorization { _ in group.leave() }

        group.enter()
        AVCaptureDevice.requestAccess(for: .audio) { _ in group.leave() }

        group.notify(queue: .main) { completion() }
    }

    func start(locale: Locale) throws {
        stopFallbackWorkItem?.cancel()
        latestText = ""

        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw NSError(domain: "VoiceHub", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer unavailable"])
        }

        self.recognizer = recognizer
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.recognitionRequest?.append(buffer)
            let rms = self.computeRMS(from: buffer)
            DispatchQueue.main.async {
                self.onAudioLevel?(rms)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                self.latestText = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.onPartialText?(self.latestText)
                }

                if result.isFinal {
                    self.finish()
                    return
                }
            }

            if error != nil {
                self.finish()
            }
        }
    }

    func stop(completion: @escaping (String) -> Void) {
        self.completion = completion

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()

        let work = DispatchWorkItem { [weak self] in
            self?.finish()
        }
        stopFallbackWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    private func finish() {
        stopFallbackWorkItem?.cancel()
        stopFallbackWorkItem = nil

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        let text = latestText.trimmingCharacters(in: .whitespacesAndNewlines)
        let callback = completion
        completion = nil

        if let callback {
            DispatchQueue.main.async {
                callback(text)
            }
        }
    }

    private func computeRMS(from buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return 0 }

        var sum: Float = 0
        for i in 0..<frameCount {
            let sample = data[i]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frameCount))
        let boosted = min(max(rms * 8.5, 0), 1)
        return CGFloat(boosted)
    }
}
