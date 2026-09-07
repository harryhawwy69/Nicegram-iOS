import Factory
import MemberwiseInit

@MemberwiseInit(.private)
public final class NicegramSettingsModule: SharedContainer {
    public static var shared = NicegramSettingsModule()
    public let manager: ContainerManager = ContainerManager()
}

extension NicegramSettingsModule {
    public var nicegramSettingsRepository: Factory<NicegramSettingsRepository> {
        self {
            NicegramSettingsRepositoryImpl()
        }.cached
    }
}
