import FeatAuth
import FeatTranscription
import PaywallCore

struct VoiceMessageSurface: FeatTranscription.Surface {
    func loginSource() -> LoginSource { .transcription }

    /// No card of its own on the paywall, so it opens wherever the paywall
    /// starts rather than scrolling somewhere arbitrary.
    func premiumFeature() -> PremiumFeatureKind? { nil }

    func premiumSource() -> PremiumSource { .speechToText }
}
