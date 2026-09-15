import AccountContext
import Display
import FeatTranscription
import Foundation
import ItemListUI
import PresentationDataUtils
import SwiftSignalKit
import TelegramPresentationData

private final class TranscriptionModelControllerArguments {
    let selectModel: (String) -> Void

    init(selectModel: @escaping (String) -> Void) {
        self.selectModel = selectModel
    }
}

private enum TranscriptionModelControllerSection: Int32 {
    case models
}

private enum TranscriptionModelControllerEntry: ItemListNodeEntry {
    case model(Int32, FeatTranscription.Model, Bool)

    var section: ItemListSectionId {
        switch self {
        case .model:
            return TranscriptionModelControllerSection.models.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case let .model(index, _, _):
            return index
        }
    }

    static func < (lhs: TranscriptionModelControllerEntry, rhs: TranscriptionModelControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! TranscriptionModelControllerArguments
        switch self {
        case let .model(_, model, checked):
            return ItemListCheckboxItem(presentationData: presentationData, title: model.name, style: .left, checked: checked, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.selectModel(model.id)
            })
        }
    }
}

private func transcriptionModelControllerEntries(models: [FeatTranscription.Model], selectedModelId: String) -> [TranscriptionModelControllerEntry] {
    var entries: [TranscriptionModelControllerEntry] = []

    var index: Int32 = 0
    for model in models {
        entries.append(.model(index, model, model.id == selectedModelId))
        index += 1
    }

    return entries
}

public func transcriptionModelController(context: AccountContext) -> ViewController {
    var popImpl: (() -> Void)?

    let models = FeatTranscription.Module.shared.getConfigUseCase()().availableModels
    let selectedModelId = FeatTranscription.Module.shared.getSettingsUseCase()().selectedModel.id

    let arguments = TranscriptionModelControllerArguments(
        selectModel: { id in
            Task {
                await FeatTranscription.Module.shared.updateSettingsUseCase().setModel(id: id)
            }
            popImpl?()
        }
    )

    let signal = context.sharedContext.presentationData
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(FeatTranscription.strings.modelPickerTitle()), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: transcriptionModelControllerEntries(models: models, selectedModelId: selectedModelId), style: .blocks, animateChanges: false)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    popImpl = { [weak controller] in
        let _ = (controller?.navigationController as? NavigationController)?.popViewController(animated: true)
    }
    return controller
}
