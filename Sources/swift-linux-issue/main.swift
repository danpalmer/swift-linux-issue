// main.swift
import Foundation

// Helper extension similar to FileHandle+Extras.swift [cite: uploaded:Command.zip/FileHandle+Extras.swift]
// to asynchronously read data using readabilityHandler
extension FileHandle {
    func byteStream() -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            // Ensure the handler is released on termination
            let terminationHandler = continuation.onTermination
            continuation.onTermination = { @Sendable reason in
                // Call original termination handler if any
                terminationHandler?(reason)
                // Release the readability handler by setting it to nil
                self.readabilityHandler = nil
                 // Add a print statement for debugging when termination occurs
                 // print("[Debug] FileHandle (\(self.fileDescriptor)) byteStream terminated: \(reason)")
            }

            self.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    // EOF reached or pipe closed
                    // print("[Debug] FileHandle (\(handle.fileDescriptor)) received empty data, finishing stream.")
                    continuation.finish()
                    // Release the handler
                    handle.readabilityHandler = nil
                } else {
                    // Yield the available data
                    // print("[Debug] FileHandle (\(handle.fileDescriptor)) yielding \(data.count) bytes.")
                    continuation.yield(data)
                }
            }
        }
    }
}

@main
struct Reproducer {
    static func main() async {
        print("Starting reproducer program.")

        let arguments = ["/bin/ls", "-la", "."] // Command to run

        // Process setup
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        guard let executableURL = URL(string: "file:///bin/ls") else {
            print("Error: Could not create executable URL.")
            return
        }
        process.executableURL = executableURL
        process.arguments = Array(arguments.dropFirst())
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = FileHandle.nullDevice // Don't need stdin

        print("Process configured. Setting up async readers...")

        // --- Asynchronous Pipe Reading Tasks ---
        let stdoutTask = Task {
            var byteCount = 0
            print("[Stdout Task] Started.")
            do {
                for try await data in stdoutPipe.fileHandleForReading.byteStream() {
                    byteCount += data.count
                    if let str = String(data: data, encoding: .utf8) {
                        print("[Stdout] \(str)", terminator: "")
                    }
                }
                print("[Stdout Task] Finished reading \(byteCount) bytes.")
            } catch {
                print("[Stdout Task] Error reading stream: \(error)")
            }
        }

        let stderrTask = Task {
            var byteCount = 0
            print("[Stderr Task] Started.")
            do {
                for try await data in stderrPipe.fileHandleForReading.byteStream() {
                    byteCount += data.count
                    if let str = String(data: data, encoding: .utf8) {
                         print("[Stderr] \(str)", terminator: "")
                    }
                }
                print("[Stderr Task] Finished reading \(byteCount) bytes.")
            } catch {
                print("[Stderr Task] Error reading stream: \(error)")
            }
        }

        // --- Launch and Wait ---
        do {
            print("Launching process: \(arguments.joined(separator: " "))")
            try process.run()
            print("Process is running (PID: \(process.processIdentifier)). Calling waitUntilExit()...")

            // *** This is the critical call suspected of causing the hang ***
            // *** when used concurrently with the async readers above.  ***
            process.waitUntilExit()

            print("waitUntilExit() returned. Process terminated.")
            print("Termination Reason: \(process.terminationReason.rawValue), Status: \(process.terminationStatus)")

        } catch {
            print("Error running process: \(error)")
            // Ensure tasks are cleaned up on error
            stdoutTask.cancel()
            stderrTask.cancel()
        }

        // --- Wait for Async Readers to Finish ---
        print("Awaiting stdout reader task completion...")
        await stdoutTask.value
        print("Awaiting stderr reader task completion...")
        await stderrTask.value

        // --- Cleanup ---
        // Close pipe handles (optional, as they should close when deallocated)
        try? stdoutPipe.fileHandleForReading.close()
        try? stderrPipe.fileHandleForReading.close()

        print("Program finished.")
    }
}
