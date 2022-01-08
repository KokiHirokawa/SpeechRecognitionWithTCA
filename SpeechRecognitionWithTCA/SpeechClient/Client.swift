import ComposableArchitecture
import Speech

struct SpeechClient {
    var requestAuthorization: () -> Effect<SFSpeechRecognizerAuthorizationStatus, Never>
}

extension SpeechClient {

    static var live: Self {
        .init(
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
