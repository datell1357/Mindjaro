import MaeumjaroDomain
import MaeumjaroShared

public enum MaeumjaroPersistenceModule {
    public static let name = "MaeumjaroPersistence"
    public static let dependencies = [MaeumjaroDomainModule.name, MaeumjaroSharedModule.name]
}
