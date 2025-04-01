import Foundation
import Command

struct TuistCommandImpl {
    static func run() async {
        let runner = CommandRunner()
        do {
            for try await event in runner.run(
                arguments: ["/bin/echo", "Hello, World!"],
                environment: [:]
            ) {
                switch event {
                case let .standardOutput(bytes):
                    if let str = String(data: Data(bytes), encoding: .utf8) {
                        print("[Stdout] \(str)", terminator: "")
                    }
                case let .standardError(bytes):
                    if let str = String(data: Data(bytes), encoding: .utf8) {
                        print("[Stderr] \(str)", terminator: "")
                    }
                }
            }
        } catch {
            print("Error running command: \(error)")
        }
        print("Finished running command.")
    }
}
