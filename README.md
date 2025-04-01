This repo contains two implementations, one as basic as I can make it, and one
using an open source package [tuist/Command](https://github.com/tuist/Command),
each in a separate file. The tuist implementation can be run by passing `tuist`
to the binary.

## Running

| Platform            | Implementation | Command                                                                            |
| ------------------- | -------------- | ---------------------------------------------------------------------------------- |
| macOS (Working)     | raw            | swift run                                                                          |
| Linux (Non-working) | raw            | docker run --rm -v $(pwd):/code -w /code swift:6 swift run swift-linux-issue       |
| macOS (Working)     | tuist          | swift run tuist                                                                    |
| Linux (Non-working) | tuist          | docker run --rm -v $(pwd):/code -w /code swift:6 swift run swift-linux-issue tuist |
