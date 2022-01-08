import ComposableArchitecture
import Speech
import SwiftUI

struct AppState: Equatable {
    var alert: AlertState<AppAction>?
    var isRecording = false
    var transcribedText = ""
}

enum AppAction: Equatable {
    case dismissAuthorizationStateAlert
    case recordButtonTapped
    case speechRecognizerAuthorizationStatusResponse(SFSpeechRecognizerAuthorizationStatus)
    case speech(Result<SpeechClient.RecognitionTaskAction, SpeechClient.RecognitionTaskError>)
}

struct AppEnvironment {
    var mainQueue: AnySchedulerOf<DispatchQueue>
    var speechClient: SpeechClient
}

let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
    switch action {
    case .dismissAuthorizationStateAlert:
        state.alert = nil
        return .none

    case .recordButtonTapped:
        state.isRecording.toggle()
        if state.isRecording {
            return environment.speechClient.requestAuthorization()
                .receive(on: environment.mainQueue)
                .map(AppAction.speechRecognizerAuthorizationStatusResponse)
                .eraseToEffect()
        } else {
            // ToDo: Finish to speech
            return .none
        }

    case let .speechRecognizerAuthorizationStatusResponse(status):
        state.isRecording = status == .authorized

        switch status {
        case .notDetermined:
            state.alert = .init(title: .init("Try again."))
            return .none

        case .denied:
            state.alert = .init(
                title: .init(
                    """
                    You denied access to speech recognition. This app needs access to transcribe your speech.
                    """
                )
            )
            return .none

        case .restricted:
            state.alert = .init(title: .init("Your device does not allow speech recognition."))
            return .none

        case .authorized:
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = false
            return environment.speechClient.recognitionTask(request)
                .catchToEffect(AppAction.speech)

        @unknown default:
            return .none
        }

    case let .speech(.success(action)):
        switch action {
        case .availabilityDidChange:
            return .none

        case let .taskResult(result):
            state.transcribedText = result.bestTranscription.formattedString
            return .none
        }

    case let .speech(.failure(error)):
        switch error {
        case .couldntStartAudioEngine, .couldntConfigureAudioSession:
            state.alert = .init(title: .init("Problem with audio device. Please try again."))
            return .none

        case .taskError:
            state.alert = .init(title: .init("An error occurred while transcribing. Please try again."))
            return .none
        }
    }
}

struct SpeechRecognitionView: View {

    let store: Store<AppState, AppAction>

    var body: some View {
        WithViewStore(self.store) { viewStore in
            VStack {
                Text(viewStore.transcribedText)
                    .font(.largeTitle)
                    .minimumScaleFactor(0.1)
                    .frame(minHeight: 0, maxHeight: .infinity, alignment: .topLeading)

                Spacer()

                Button(action: { viewStore.send(.recordButtonTapped) }) {
                    HStack {
                        Image(
                            systemName: viewStore.isRecording
                                ? "stop.circle.fill" : "arrowtriangle.right.circle.fill"
                        )
                        .font(.title)

                        Text(viewStore.isRecording ? "Stop Recording" : "Start Recording")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(viewStore.isRecording ? .red : .green)
                    .cornerRadius(16)
                }
            }
            .padding()
            .alert(self.store.scope(state: \.alert), dismiss: .dismissAuthorizationStateAlert)
        }
    }
}

enum SpeechRecognitionView_Previews: PreviewProvider {
    static var previews: some View {
        SpeechRecognitionView(
            store: .init(
                initialState: .init(transcribedText: "Transcribed Text"),
                reducer: appReducer,
                environment: AppEnvironment(
                    mainQueue: .main,
                    speechClient: .live
                )
            )
        )
    }
}
