import Combine
import ComposableArchitecture
import Speech

struct SpeechClient {
    var finishTask: () -> Effect<Never, Never>
    var recognitionTask: (SFSpeechAudioBufferRecognitionRequest) -> Effect<RecognitionTaskAction, RecognitionTaskError>
    var requestAuthorization: () -> Effect<SFSpeechRecognizerAuthorizationStatus, Never>

    enum RecognitionTaskAction: Equatable {
        case availabilityDidChange(isAvailable: Bool)
        case taskResult(SpeechRecognitionResult)
    }

    enum RecognitionTaskError: Error, Equatable {
        case taskError
        case couldntStartAudioEngine
        case couldntConfigureAudioSession
    }
}

extension SpeechClient {

    static var live: Self {
        var audioEngine: AVAudioEngine?
        var inputNode: AVAudioInputNode?
        var recognitionTask: SFSpeechRecognitionTask?

        return .init(
            finishTask: {
                .fireAndForget {
                    audioEngine?.stop()
                    inputNode?.removeTap(onBus: 0)
                    recognitionTask?.finish()
                }
            },
            recognitionTask: { request in
                .run { subscriber in
                    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-USs"))!
                    let speechRecognizerDelegate = SpeechRecognizerDelegate { available in
                        subscriber.send(.availabilityDidChange(isAvailable: available))
                    }
                    speechRecognizer.delegate = speechRecognizerDelegate

                    let cancellable = AnyCancellable {
                        audioEngine?.stop()
                        inputNode?.removeTap(onBus: 0)
                        recognitionTask?.cancel()
                        _ = speechRecognizer
                        _ = speechRecognizerDelegate
                    }

                    audioEngine = AVAudioEngine()
                    let audioSession = AVAudioSession.sharedInstance()
                    do {
                        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                    } catch {
                        subscriber.send(completion: .failure(.couldntConfigureAudioSession))
                        return cancellable
                    }

                    inputNode = audioEngine?.inputNode

                    recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
                        switch (result, error) {
                        case let (.some(result), _):
                            subscriber.send(.taskResult(SpeechRecognitionResult(result)))
                        case (_, .some):
                            subscriber.send(completion: .failure(.taskError))
                        case (.none, .none):
                            fatalError("It should not be possible to have both a nil result and nil error.")
                        }
                    }

                    inputNode?.installTap(
                        onBus: 0,
                        bufferSize: 1024,
                        format: inputNode!.outputFormat(forBus: 0)
                    ) { buffer, when in
                        request.append(buffer)
                    }

                    audioEngine?.prepare()
                    do {
                        try audioEngine?.start()
                    } catch {
                        subscriber.send(completion: .failure(.couldntStartAudioEngine))
                        return cancellable
                    }

                    return cancellable
                }
            },
            requestAuthorization: {
                .future { callback in
                    SFSpeechRecognizer.requestAuthorization { status in
                        callback(.success(status))
                    }
                }
            }
        )
    }
}

final private class SpeechRecognizerDelegate: NSObject, SFSpeechRecognizerDelegate {
    var availabilityDidChange: (Bool) -> Void

    init(availabilityDidChange: @escaping (Bool) -> Void) {
        self.availabilityDidChange = availabilityDidChange
    }

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        self.availabilityDidChange(available)
    }
}
