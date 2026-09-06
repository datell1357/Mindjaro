import MaeumjaroDomain
import MaeumjaroShared

public enum MaeumjaroIntentsModule {
    public static let name = "MaeumjaroIntents"
    public static let dependencies = [MaeumjaroDomainModule.name, MaeumjaroSharedModule.name]
}
