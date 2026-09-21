import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUIPreferences

final class WraithgramShutupManager {
    private let account: Account
    private let engine: TelegramEngine

    private var settingsDisposable: Disposable?
    private var historyDisposables: [PeerId: MetaDisposable] = [:]
    private var rules: [PeerId: WraithgramShutupRule] = [:]
    private var deletingMessageIds = Set<MessageId>()

    init(account: Account, engine: TelegramEngine, isEnabled: Bool) {
        self.account = account
        self.engine = engine

        guard isEnabled else {
            return
        }

        self.settingsDisposable = (account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.wraithgramShutupSettings])
        |> deliverOnMainQueue).start(next: { [weak self] view in
            let settings = view.values[ApplicationSpecificPreferencesKeys.wraithgramShutupSettings]?.get(WraithgramShutupSettings.self) ?? .default
            self?.update(settings: settings)
        })
    }

    deinit {
        self.settingsDisposable?.dispose()
        for disposable in self.historyDisposables.values {
            disposable.dispose()
        }
    }

    private func update(settings: WraithgramShutupSettings) {
        let updatedRules = Dictionary(uniqueKeysWithValues: settings.rules.map { (PeerId($0.key), $0.value) })
        let removedPeerIds = Set(self.historyDisposables.keys).subtracting(updatedRules.keys)
        for peerId in removedPeerIds {
            self.historyDisposables.removeValue(forKey: peerId)?.dispose()
        }

        self.rules = updatedRules

        for peerId in updatedRules.keys where self.historyDisposables[peerId] == nil {
            let disposable = MetaDisposable()
            self.historyDisposables[peerId] = disposable
            disposable.set((self.account.viewTracker.aroundMessageHistoryViewForLocation(
                .peer(peerId: peerId, threadId: nil),
                index: .upperBound,
                anchorIndex: .upperBound,
                count: 64,
                trackHoles: false,
                clipHoles: true,
                ignoreRelatedChats: true,
                fixedCombinedReadStates: nil
            )
            |> deliverOnMainQueue).start(next: { [weak self] view, _, _ in
                self?.process(view: view, peerId: peerId)
            }))
        }
    }

    private func process(view: MessageHistoryView, peerId: PeerId) {
        guard let rule = self.rules[peerId] else {
            return
        }

        let messages = view.entries.map(\.message)
        let commandMessageId: Int32
        if let knownCommandMessageId = rule.commandMessageId {
            commandMessageId = knownCommandMessageId
        } else if let command = messages.reversed().first(where: { message in
            return message.id.peerId == peerId
                && message.id.namespace == Namespaces.Message.Cloud
                && !message.flags.contains(.Incoming)
                && message.timestamp >= rule.activatedAt
                && message.text.trimmingCharacters(in: .whitespacesAndNewlines) == ".shutup"
        }) {
            let _ = updateWraithgramShutupCommandMessageId(engine: self.engine, peerId: EnginePeer.Id(peerId), commandMessageId: command.id.id).startStandalone()
            return
        } else {
            return
        }

        let messageIds = messages.compactMap { message -> MessageId? in
            guard message.id.peerId == peerId,
                  message.id.namespace == Namespaces.Message.Cloud,
                  message.flags.contains(.Incoming),
                  message.id.id > commandMessageId,
                  !self.deletingMessageIds.contains(message.id) else {
                return nil
            }
            return message.id
        }

        guard !messageIds.isEmpty else {
            return
        }

        self.deletingMessageIds.formUnion(messageIds)
        let _ = (self.engine.messages.deleteMessagesInteractively(messageIds: messageIds, type: .forEveryone)
        |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
            self?.deletingMessageIds.subtract(messageIds)
        })
    }
}
