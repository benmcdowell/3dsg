import Foundation
import ThreeDSGCore

do {
    let currentDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    let command = try CommandLineParser.parse(Array(CommandLine.arguments.dropFirst()), currentDirectory: currentDirectory)

    switch command {
    case .help:
        print(CommandLineParser.usage)
    case .render(let options):
        let result = try DeviceRenderer().render(options)
        print("PNG:  \(result.pngURL.path)")
        print("USDZ: \(result.usdzURL.path)")
    }
} catch let error as ThreeDSGError {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(2)
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
