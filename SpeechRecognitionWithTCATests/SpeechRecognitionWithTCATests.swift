import Combine
import ComposableArchitecture
import XCTest

@testable import SpeechRecognitionWithTCA

final class SpeechRecognitionTexts: XCTestCase {

    func testDenyAuthorization() {
        var speechClient = SpeechClient.failing
        speechClient.requestAuthorization = { Effect(value: .denied) }

        let store = TestStore(
            initialState: .init(),
            reducer: appReducer,
            environment: .init(mainQueue: .immediate, speechClient: speechClient)
        )

        store.send(.recordButtonTapped) {
            $0.isRecording = true
        }
        store.receive(.speechRecognizerAuthorizationStatusResponse(.denied)) {
            $0.alert = .init(
                title: .init(
                    """
                    You denied access to speech recognition. This app needs access to transcribe your speech.
                    """
                )
            )
            $0.isRecording = false
        }
    }

    func testRestrictedAuthorization() {
        var speechClient = SpeechClient.failing
        speechClient.requestAuthorization = { Effect(value: .restricted) }

        let store = TestStore(
            initialState: .init(),
            reducer: appReducer,
            environment: .init(mainQueue: .immediate, speechClient: speechClient)
        )

        store.send(.recordButtonTapped) {
            $0.isRecording = true
        }
        store.receive(.speechRecognizerAuthorizationStatusResponse(.restricted)) {
            $0.alert = .init(title: .init("Your device does not allow speech recognition."))
            $0.isRecording = false
        }
    }

    func testNotDeterminedAuthorization() {
        var speechClient = SpeechClient.failing
        speechClient.requestAuthorization = { Effect(value: .notDetermined) }

        let store = TestStore(
            initialState: .init(),
            reducer: appReducer,
            environment: .init(mainQueue: .immediate, speechClient: speechClient)
        )

        store.send(.recordButtonTapped) {
            $0.isRecording = true
        }
        store.receive(.speechRecognizerAuthorizationStatusResponse(.notDetermined)) {
            $0.alert = .init(title: .init("Try again."))
            $0.isRecording = false
        }
    }

    func testAllowAndRecord() {
        let recognitionTaskSubject = PassthroughSubject<SpeechClient.RecognitionTaskAction, SpeechClient.RecognitionTaskError>()

        var speechClient = SpeechClient.failing
        speechClient.finishTask = {
            .fireAndForget { recognitionTaskSubject.send(completion: .finished) }
        }
        speechClient.recognitionTask = { _ in
            recognitionTaskSubject.eraseToEffect()
        }
        speechClient.requestAuthorization = { Effect(value: .authorized) }

        let store = TestStore(
            initialState: .init(),
            reducer: appReducer,
            environment: .init(mainQueue: .immediate, speechClient: speechClient)
        )

        let result = SpeechRecognitionResult(
            bestTranscription: .init(formattedString: "Hello", segments: []),
            isFinal: false,
            speechRecognitionMetadata: nil,
            transcriptions: []
        )
        var finalResult = result
        finalResult.bestTranscription.formattedString = "Hello World"
        finalResult.isFinal = true

        store.send(.recordButtonTapped) {
            $0.isRecording = true
        }
        store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized))

        recognitionTaskSubject.send(.taskResult(result))
        store.receive(.speech(.success(.taskResult(result)))) {
            $0.transcribedText = "Hello"
        }

        recognitionTaskSubject.send(.taskResult(finalResult))
        store.receive(.speech(.success(.taskResult(finalResult)))) {
            $0.transcribedText = "Hello World"
        }
    }

    func testAudioSessionFailure() {
        let recognitionTaskSubject = PassthroughSubject<SpeechClient.RecognitionTaskAction, SpeechClient.RecognitionTaskError>()

        var speechClient = SpeechClient.failing
        speechClient.recognitionTask = { _ in recognitionTaskSubject.eraseToEffect() }
        speechClient.requestAuthorization = { Effect(value: .authorized) }

        let store = TestStore(
            initialState: .init(),
            reducer: appReducer,
            environment: .init(mainQueue: .immediate, speechClient: speechClient)
        )

        store.send(.recordButtonTapped) {
            $0.isRecording = true
        }
        store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized))

        recognitionTaskSubject.send(completion: .failure(.couldntConfigureAudioSession))
        store.receive(.speech(.failure(.couldntConfigureAudioSession))) {
            $0.alert = .init(title: .init("Problem with audio device. Please try again."))
        }
    }

    func testAudioEngineFailure() {
        let recognitionTaskSubject = PassthroughSubject<SpeechClient.RecognitionTaskAction, SpeechClient.RecognitionTaskError>()

        var speechClient = SpeechClient.failing
        speechClient.recognitionTask = { _ in recognitionTaskSubject.eraseToEffect() }
        speechClient.requestAuthorization = { Effect(value: .authorized) }

        let store = TestStore(
            initialState: .init(),
            reducer: appReducer,
            environment: .init(mainQueue: .immediate, speechClient: speechClient)
        )

        store.send(.recordButtonTapped) {
            $0.isRecording = true
        }
        store.receive(.speechRecognizerAuthorizationStatusResponse(.authorized))

        recognitionTaskSubject.send(completion: .failure(.couldntStartAudioEngine))
        store.receive(.speech(.failure(.couldntStartAudioEngine))) {
            $0.alert = .init(title: .init("Problem with audio device. Please try again."))
        }
    }
}

extension SpeechClient {
    static let failing = SpeechClient(
        finishTask: { .failing("SpeechClient.finishTask") },
        recognitionTask: { _ in .failing("SpeechClient.recognitionTask") },
        requestAuthorization: { .failing("SpeechClient.requestAuthorization") }
    )
}
