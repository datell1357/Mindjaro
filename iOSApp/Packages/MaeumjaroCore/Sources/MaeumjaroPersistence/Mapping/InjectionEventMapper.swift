import Foundation
import MaeumjaroDomain

public enum InjectionEventMapper {
    public static func makeModel(from event: InjectionEvent) -> MaeumjaroSchemaV1.Event {
        MaeumjaroSchemaV1.Event(
            id: event.id,
            startedAtUTC: event.startedAtUTC,
            completedAtUTC: event.completedAtUTC,
            createdAtUTC: event.createdAtUTC,
            eventLocalDate: event.eventLocalDate,
            timezoneOffsetMinutes: event.timezoneOffsetMinutes,
            intensityRawValue: event.intensity.rawValue,
            sourceRawValue: event.source.rawValue,
            phraseID: event.phraseID,
            animationDurationMilliseconds: event.animationDurationMilliseconds,
            interruptedCount: event.interruptedCount,
            appVersion: event.appVersion
        )
    }

    public static func toModel(_ event: InjectionEvent) -> MaeumjaroSchemaV1.Event {
        makeModel(from: event)
    }

    public static func makeDomain(from model: MaeumjaroSchemaV1.Event) throws -> InjectionEvent {
        guard let intensity = Intensity(rawValue: model.intensityRawValue) else {
            throw PersistenceError.invalidStoredValue(entity: "event", field: "intensity")
        }
        guard let source = EventSource(rawValue: model.sourceRawValue) else {
            throw PersistenceError.invalidStoredValue(entity: "event", field: "source")
        }
        guard !model.eventLocalDate.isEmpty,
              !model.phraseID.isEmpty,
              model.animationDurationMilliseconds >= 0,
              model.interruptedCount >= 0,
              !model.appVersion.isEmpty else {
            throw PersistenceError.invalidStoredValue(entity: "event", field: "completion")
        }
        return InjectionEvent(
            id: model.id,
            startedAtUTC: model.startedAtUTC,
            completedAtUTC: model.completedAtUTC,
            createdAtUTC: model.createdAtUTC,
            eventLocalDate: model.eventLocalDate,
            timezoneOffsetMinutes: model.timezoneOffsetMinutes,
            intensity: intensity,
            source: source,
            phraseID: model.phraseID,
            animationDurationMilliseconds: model.animationDurationMilliseconds,
            interruptedCount: model.interruptedCount,
            appVersion: model.appVersion
        )
    }

    public static func toDomain(_ model: MaeumjaroSchemaV1.Event) throws -> InjectionEvent {
        try makeDomain(from: model)
    }
}
