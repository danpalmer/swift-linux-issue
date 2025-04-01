import Foundation

@main
struct Main {
    static func main() async {
        if CommandLine.arguments.last == "tuist" {
            // This is the raw implementation that hangs on Linux.
            // It is not intended to be run directly.
            await TuistCommandImpl.run()
        } else {
            // By default run the "raw" implementation using only Foundation.
            await RawReproduction.run()
        }
    }
}
