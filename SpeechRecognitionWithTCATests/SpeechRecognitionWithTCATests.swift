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
}

extension SpeechClient {
    static let failing = SpeechClient(
        finishTask: { .failing("SpeechClient.finishTask") },
        recognitionTask: { _ in .failing("SpeechClient.recognitionTask") },
        requestAuthorization: { .failing("SpeechClient.requestAuthorization") }
    )
}
