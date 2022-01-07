import ComposableArchitecture
import Speech
import SwiftUI

struct AppState: Equatable {
    var isRecording = false
    var transcribedText = ""
}

enum AppAction: Equatable {
    case recordButtonTapped
}

struct AppEnvironment {}

let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
    switch action {
    case .recordButtonTapped:
        state.isRecording.toggle()
        state.transcribedText = state.isRecording ? "Recording..." : ":("
        return .none
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
        }
    }
}

enum SpeechRecognitionView_Previews: PreviewProvider {
    static var previews: some View {
        SpeechRecognitionView(
            store: .init(
                initialState: .init(transcribedText: "Transcribed Text"),
                reducer: appReducer,
                environment: AppEnvironment()
            )
        )
    }
}
