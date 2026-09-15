import Combine
import FeatTranscription
import FeatVoiceTyping
import UIKit

/// Retain this one object and the overlay stays alive; drop it and the view, its
/// view model and the event subscription all go with it.
///
/// The availability sits on `init`, not on the type: a stored property may not
/// have a potentially-unavailable type, and `ChatControllerNode` holds one.
@preconcurrency @MainActor
public final class VoiceRecordingOverlay {
    public enum OutputEvent {
        case onCancel
        case onRecognizingFinished(text: String)
        case onRecordingFinished
    }

    public let view: UIView

    private var cancellable: AnyCancellable?
    private let viewModel: VoiceRecordingViewModel

    /// iOS 16+ because the embedded SwiftUI view is built with
    /// `UIHostingConfiguration`. `VoiceTypingHelper.isEnabled()` gates the entry
    /// point on the same version, so the button never appears without this.
    @available(iOS 16.0, *)
    public init(eventsHandler: @escaping (OutputEvent) -> Void) {
        let viewModel = VoiceRecordingViewModel(
            surface: FeatVoiceTyping.TranscriptionSurface()
        )
        self.viewModel = viewModel

        view = makeVoiceRecordingView(viewModel: viewModel)
        view.backgroundColor = .clear

        cancellable = viewModel.eventsPublisher.sink { event in
            switch event {
            case .onCancel:
                eventsHandler(.onCancel)
            case let .onRecognizingFinished(text):
                eventsHandler(.onRecognizingFinished(text: text))
            case .onRecordingFinished:
                eventsHandler(.onRecordingFinished)
            }
        }
    }
}

public extension VoiceRecordingOverlay {
    /// Reaches the host as `.onCancel`, so the overlay is dropped too. A no-op
    /// once the recording has been handed to transcription, so a result already
    /// on its way still lands.
    func cancel() {
        viewModel.onCancel()
    }
}
