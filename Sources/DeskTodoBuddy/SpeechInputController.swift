import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechInputController: ObservableObject {
    @Published private(set) var isRecording = false
    @Published var statusText: String?

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    private let mixedLanguageContext = [
        "todo", "to do", "task", "reminder", "deadline", "meeting", "call", "email",
        "review", "design", "document", "docs", "note", "notes", "plan", "schedule",
        "bug", "fix", "test", "build", "deploy", "release", "PR", "pull request",
        "API", "UI", "UX", "app", "Mac", "iOS", "Swift", "SwiftUI", "Xcode",
        "GitHub", "Slack", "calendar", "OKR", "AI", "ChatGPT", "OpenAI",
        "小Q", "Q"
    ]

    func toggle(onText: @escaping (String) -> Void) async {
        if isRecording {
            stop()
        } else {
            await start(onText: onText)
        }
    }

    func start(onText: @escaping (String) -> Void) async {
        guard !isRecording else { return }

        guard await requestPermissions() else {
            statusText = "需要开启麦克风和语音识别权限"
            return
        }

        guard let recognizer, recognizer.isAvailable else {
            statusText = "当前语音识别不可用"
            return
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        request.taskHint = .dictation
        request.contextualStrings = mixedLanguageContext
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            isRecording = true
            statusText = "正在听..."
        } catch {
            statusText = "启动录音失败：\(error.localizedDescription)"
            inputNode.removeTap(onBus: 0)
            return
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                guard self.isRecording else { return }
                if let text = result?.bestTranscription.formattedString, !text.isEmpty {
                    onText(text)
                }

                if let error {
                    self.statusText = "语音识别结束：\(error.localizedDescription)"
                    self.stop()
                    return
                }

                if result?.isFinal == true {
                    self.statusText = "已识别"
                    self.stop()
                }
            }
        }
    }

    func stop() {
        guard isRecording || audioEngine.isRunning else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        if statusText == "正在听..." {
            statusText = nil
        }
    }

    private func requestPermissions() async -> Bool {
        let speechAllowed = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        guard speechAllowed else { return false }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }
}
