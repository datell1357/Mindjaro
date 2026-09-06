import MaeumjaroDomain
import MaeumjaroShared
import Foundation

func runContractsProbe(_ arguments: ProbeArguments) throws -> ProbeResponse {
    let supportedOptions = Set(["intensity"])
    guard Set(arguments.options.keys).isSubset(of: supportedOptions), arguments.flags.isEmpty else {
        throw ProbeCommandError.invalidArguments(command: "contracts", detail: "unsupported-option")
    }

    let rawInput = arguments.value(for: "intensity") ?? "1,3,5"
    let tokens = rawInput
        .split(separator: ",", omittingEmptySubsequences: false)
        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    guard !tokens.isEmpty, !tokens.contains(where: { $0.isEmpty }) else {
        throw ProbeCommandError.invalidIntensity(value: rawInput)
    }

    let observations = try tokens.map { token -> ProbeJSONValue in
        guard let rawValue = Int(token) else {
            throw ProbeCommandError.invalidIntensity(value: token)
        }
        return .object([
            "input": .integer(rawValue),
            "valid": .boolean(Intensity(rawValue: rawValue) != nil)
        ])
    }

    return ProbeResponse(
        command: "contracts",
        status: "ok",
        data: [
            "defaultIntensity": .integer(Intensity.default.rawValue),
            "intensity": .array(observations),
            "identifiers": .object([
                "appBundleID": .string(AppIdentifiers.appBundleID),
                "widgetBundleID": .string(AppIdentifiers.widgetBundleID),
                "appGroupID": .string(AppIdentifiers.appGroupID),
                "proProductID": .string(AppIdentifiers.proProductID),
                "widgetKind": .string(AppIdentifiers.widgetKind),
                "urlScheme": .string(AppIdentifiers.urlScheme),
                "scheme": .string(AppIdentifiers.scheme)
            ]),
            "sources": .array(EventSource.allCases.map { .string($0.rawValue) }),
            "themes": .array(ThemeID.allCases.map { .string($0.rawValue) })
        ]
    )
}
