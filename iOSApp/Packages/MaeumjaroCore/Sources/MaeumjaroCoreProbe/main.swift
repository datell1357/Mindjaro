import Darwin
import Foundation

enum MaeumjaroCoreProbeMain {
    @MainActor
    static func main() async {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.isEmpty || arguments.contains("--help") || arguments.contains("-h") {
            print(ProbeSupport.helpText)
            return
        }

        do {
            let parsed = try ProbeArguments(arguments)
            let response: ProbeResponse
            switch parsed.command {
            case "contracts":
                response = try runContractsProbe(parsed)
            case "ritual":
                response = try runRitualProbe(parsed)
            case "phrases":
                response = try runPhrasesProbe(parsed)
            case "analytics":
                response = try runAnalyticsProbe(parsed)
            case "persistence":
                response = try await runPersistenceProbe(parsed)
            case "shared":
                response = try runSharedProbe(parsed)
            case "intent":
                response = try await runIntentProbe(parsed)
            default:
                throw ProbeCommandError.invalidArguments(
                    command: parsed.command,
                    detail: "unknown-command"
                )
            }
            try ProbeSupport.print(response)
        } catch let error as ProbeCommandError {
            try? ProbeSupport.print(error.response)
            exit(2)
        } catch {
            try? ProbeSupport.print(
                ProbeResponse(
                    command: "unknown",
                    status: "error",
                    data: [ProbeJSONKey.error: .string(String(describing: error))]
                )
            )
            exit(2)
        }
    }
}

await MaeumjaroCoreProbeMain.main()
