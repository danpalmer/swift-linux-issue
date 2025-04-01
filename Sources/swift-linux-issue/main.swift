// main.swift
import Foundation
#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

// Debug printing util that flushes immediately.
// The hang on Linux prevents print output from making it to stdout.
func debug(_ message: String, terminator: String = "\n") {
    print(message, terminator: terminator)
    fflush(stdout)
}

// Helper to read from a file handle asynchronously.
// This appears to be roughly the idiomatic way to correctly read from a file
// handle, handling edge cases around the pipe closing.
extension FileHandle {
    func byteStream() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let terminationHandler = continuation.onTermination
            continuation.onTermination = { @Sendable reason in
                terminationHandler?(reason)
                // self.readabilityHandler = nil
                 debug("[Debug] FileHandle (\(self.fileDescriptor)) byteStream terminated: \(reason)")
            }

            self.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    debug("[Debug] FileHandle (\(handle.fileDescriptor)) received empty data, finishing stream.")
                    continuation.finish()
                    handle.readabilityHandler = nil
                } else {
                    // Yield the available data
                    debug("[Debug] FileHandle (\(handle.fileDescriptor)) yielding \(data.count) bytes.")
                    continuation.yield(data)
                }
            }
        }
    }
}

@main
struct Reproducer {
    static func main() async {
        debug("Starting reproduction.")

        let arguments = ["/bin/ls", "-la", "."]

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        guard let executableURL = URL(string: "file:///bin/ls") else {
            debug("Error: Could not create executable URL.")
            return
        }
        process.executableURL = executableURL
        process.arguments = Array(arguments.dropFirst())
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice

        debug("Process configured. Setting up async readers...")

        let stdoutTask = Task {
            var byteCount = 0
            debug("[Stdout Task] Started.")
            do {
                for try await data in stdoutPipe.fileHandleForReading.byteStream() {
                    byteCount += data.count
                    if let str = String(data: data, encoding: .utf8) {
                        debug("[Stdout] \(str)", terminator: "")
                    }
                }
                debug("[Stdout Task] Finished reading \(byteCount) bytes.")
            } catch {
                debug("[Stdout Task] Error reading stream: \(error)")
            }
        }

        let stderrTask = Task {
            var byteCount = 0
            debug("[Stderr Task] Started.")
            do {
                for try await data in stderrPipe.fileHandleForReading.byteStream() {
                    byteCount += data.count
                    if let str = String(data: data, encoding: .utf8) {
                         debug("[Stderr] \(str)", terminator: "")
                    }
                }
                debug("[Stderr Task] Finished reading \(byteCount) bytes.")
            } catch {
                debug("[Stderr Task] Error reading stream: \(error)")
            }
        }

        do {
            debug("Launching process: \(arguments.joined(separator: " "))")
            try process.run()
            debug("Process is running (PID: \(process.processIdentifier)). Calling waitUntilExit()...")

            process.waitUntilExit()

            debug("waitUntilExit() returned. Process terminated.")
            debug("Termination Reason: \(process.terminationReason.rawValue), Status: \(process.terminationStatus)")

        } catch {
            debug("Error running process: \(error)")
            // Ensure tasks are cleaned up on error
            stdoutTask.cancel()
            stderrTask.cancel()
        }

        debug("Awaiting stdout reader task completion...")
        await stdoutTask.value
        debug("Awaiting stderr reader task completion...")
        await stderrTask.value

        try? stdoutPipe.fileHandleForReading.close()
        try? stderrPipe.fileHandleForReading.close()

        debug("Program finished.")
    }
}
