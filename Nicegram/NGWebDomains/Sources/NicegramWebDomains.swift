import Foundation

public enum NicegramWebDomains {}

public extension NicegramWebDomains {
    /// Every domain the app claims, `primary` included.
    static var all: [String] { nicegramAllDomains }

    /// The one domain the app links to.
    static var primary: String { nicegramPrimaryDomain }

    static func contains(_ host: String?) -> Bool {
        guard let host else { return false }
        return all.contains(host.lowercased())
    }
}
