import Foundation
import SwiftSignalKit
import TelegramCore

public struct WraithgramShutupRule: Codable, Equatable {
    public var activatedAt: Int32
    public var commandMessageId: Int32?

    public init(activatedAt: Int32, commandMessageId: Int32? = nil) {
        self.activatedAt = activatedAt
        self.commandMessageId = commandMessageId
    }
}

public struct WraithgramShutupSettings: Codable, Equatable {
    public var rules: [Int64: WraithgramShutupRule]

    public static var `default`: WraithgramShutupSettings {
        return WraithgramShutupSettings(rules: [:])
    }

    public init(rules: [Int64: WraithgramShutupRule]) {
        self.rules = rules
    }

    public func withActivated(peerId: EnginePeer.Id, at timestamp: Int32) -> WraithgramShutupSettings {
        var updatedRules = self.rules
        updatedRules[peerId.toInt64()] = WraithgramShutupRule(activatedAt: timestamp)
        return WraithgramShutupSettings(rules: updatedRules)
    }

    public func withCommandMessageId(peerId: EnginePeer.Id, commandMessageId: Int32) -> WraithgramShutupSettings {
        var updatedRules = self.rules
        guard var rule = updatedRules[peerId.toInt64()] else {
            return self
        }
        if rule.commandMessageId == commandMessageId {
            return self
        }
        rule.commandMessageId = commandMessageId
        updatedRules[peerId.toInt64()] = rule
        return WraithgramShutupSettings(rules: updatedRules)
    }
}

public func activateWraithgramShutup(engine: TelegramEngine, peerId: EnginePeer.Id, at timestamp: Int32 = Int32(Date().timeIntervalSince1970)) -> Signal<Never, NoError> {
    return engine.preferences.update(id: ApplicationSpecificPreferencesKeys.wraithgramShutupSettings, { entry in
        let settings = entry?.get(WraithgramShutupSettings.self) ?? .default
        return SharedPreferencesEntry(settings.withActivated(peerId: peerId, at: timestamp))
    })
}

public func updateWraithgramShutupCommandMessageId(engine: TelegramEngine, peerId: EnginePeer.Id, commandMessageId: Int32) -> Signal<Never, NoError> {
    return engine.preferences.update(id: ApplicationSpecificPreferencesKeys.wraithgramShutupSettings, { entry in
        let settings = entry?.get(WraithgramShutupSettings.self) ?? .default
        return SharedPreferencesEntry(settings.withCommandMessageId(peerId: peerId, commandMessageId: commandMessageId))
    })
}
