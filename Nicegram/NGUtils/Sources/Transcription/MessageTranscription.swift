import AccountContext
import Postbox
import SwiftSignalKit
import TelegramCore

extension Message {
    func setTranscription(
        _ text: String,
        context: AccountContext
    ) async {
        let attribute = AudioTranscriptionMessageAttribute(
            id: 0,
            text: text,
            isPending: false,
            didRate: false,
            error: nil
        )

        try? await context.account.postbox.transaction { transaction -> Void in
            transaction.updateMessage(
                self.id,
                update: { currentMessage in
                    let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                    var attributes = currentMessage.attributes.filter { !($0 is AudioTranscriptionMessageAttribute) }
                    attributes.append(attribute)

                    return .update(StoreMessage(
                        id: currentMessage.id,
                        customStableId: nil,
                        globallyUniqueId: currentMessage.globallyUniqueId,
                        groupingKey: currentMessage.groupingKey,
                        threadId: currentMessage.threadId,
                        timestamp: currentMessage.timestamp,
                        flags: StoreMessageFlags(currentMessage.flags),
                        tags: currentMessage.tags,
                        globalTags: currentMessage.globalTags,
                        localTags: currentMessage.localTags,
                        forwardInfo: storeForwardInfo,
                        authorId: currentMessage.author?.id,
                        text: currentMessage.text,
                        attributes: attributes,
                        media: currentMessage.media
                    ))
                }
            )
        }.awaitForCompletion()
    }
}
