import SwiftUI

@main
struct SpeechRecognitionWithTCAApp: App {
    var body: some Scene {
        WindowGroup {
            SpeechRecognitionView(
                store: .init(
                    initialState: .init(),
                    reducer: appReducer,
                    environment: AppEnvironment(
                        mainQueue: .main,
                        speechClient: .live
                    )
                )
            )
        }
    }
}
