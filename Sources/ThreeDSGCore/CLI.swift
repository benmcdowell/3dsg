import Foundation

public enum Command: Equatable, Sendable {
    case render(RenderOptions)
    case help
    case version
}

public struct CommandLineParser: Sendable {
    public static func parse(_ arguments: [String], currentDirectory: URL) throws -> Command {
        guard let firstArgument = arguments.first else {
            throw ThreeDSGError.usage(Self.usage)
        }

        if firstArgument == "-h" || firstArgument == "--help" {
            return .help
        }
        if firstArgument == "-v" || firstArgument == "--version" || firstArgument == "version" {
            return .version
        }

        let renderArguments: [String]
        if firstArgument == "render" {
            renderArguments = Array(arguments.dropFirst())
        } else if firstArgument.hasPrefix("-") {
            renderArguments = arguments
        } else {
            throw ThreeDSGError.usage("unknown command: \(firstArgument)\n\n\(Self.usage)")
        }

        var parser = OptionParser(renderArguments)
        var device: Device?
        var color: IPhoneColor?
        var colorWasProvided = false
        var rotation = Rotation.zero
        var screenURL: URL?
        var outputPNGURL: URL?
        var outputSize: Dimensions?

        while let option = parser.nextOption() {
            switch option {
            case "-h", "--help":
                return .help
            case "-v", "--version":
                return .version
            case "--device":
                let value = try parser.requiredValue(for: option)
                guard let parsed = Device(rawValue: value) else {
                    throw ThreeDSGError.invalidValue("--device must be one of: \(Device.allCases.map(\.rawValue).joined(separator: ", "))")
                }
                device = parsed
            case "--orientation":
                throw ThreeDSGError.unsupportedOption("--orientation has been removed; orientation is inferred from the --screen image dimensions")
            case "--color":
                let value = try parser.requiredValue(for: option)
                guard let parsed = IPhoneColor(rawValue: value) else {
                    throw ThreeDSGError.invalidValue("--color must be one of: \(IPhoneColor.allCases.map(\.rawValue).joined(separator: ", "))")
                }
                color = parsed
                colorWasProvided = true
            case "--rotation":
                rotation = try Rotation.parse(try parser.requiredValue(for: option))
            case "--screen":
                screenURL = resolvePath(try parser.requiredValue(for: option), currentDirectory: currentDirectory)
            case "--output":
                outputPNGURL = resolvePath(try parser.requiredValue(for: option), currentDirectory: currentDirectory)
            case "--size":
                outputSize = try Dimensions.parse(try parser.requiredValue(for: option))
            case "--assets-dir":
                throw ThreeDSGError.unsupportedOption("--assets-dir has been removed; USDZ assets are managed in ~/Library/Application Support/com.benmcdowell.3dsg/usdz")
            default:
                throw ThreeDSGError.usage("unknown option: \(option)\n\n\(Self.usage)")
            }
        }

        guard let device else {
            throw ThreeDSGError.missingRequiredOption("missing required option: --device")
        }
        guard let screenURL else {
            throw ThreeDSGError.missingRequiredOption("missing required option: --screen")
        }
        guard let outputPNGURL else {
            throw ThreeDSGError.missingRequiredOption("missing required option: --output")
        }

        if !device.isIPhone && colorWasProvided {
            throw ThreeDSGError.unsupportedOption("--color is only supported for iPhone renders")
        }

        let options = RenderOptions(
            device: device,
            color: color ?? .cosmicOrange,
            rotation: rotation,
            screenURL: screenURL,
            outputPNGURL: outputPNGURL,
            outputSize: outputSize
        )
        return .render(options)
    }

    public static let usage = """
    Usage:
      3dsg --device iphone-17-pro|iphone-17-pro-max|ipad-pro-13-inch --screen path --output path.png [options]

    Options:
      --color cosmic-orange|deep-blue|silver iPhone only. Default: cosmic-orange.
      --rotation X,Y,Z                       Extra device rotation in degrees. Default: 0,0,0.
      --size WIDTHxHEIGHT                    Max output dimensions after transparent edge trimming. Default: --screen dimensions.
      -v, --version                          Show the 3dsg version.
      -h, --help                             Show this help.

    Output:
      The requested PNG.
    """

    private static func resolvePath(_ value: String, currentDirectory: URL) -> URL {
        if value.hasPrefix("/") {
            return URL(fileURLWithPath: value).standardizedFileURL
        }
        return currentDirectory.appendingPathComponent(value).standardizedFileURL
    }
}

private struct OptionParser {
    private var arguments: [String]
    private var index = 0
    private var pendingInlineValue: String?

    init(_ arguments: [String]) {
        self.arguments = arguments
    }

    mutating func nextOption() -> String? {
        guard index < arguments.count else {
            return nil
        }
        let raw = arguments[index]
        index += 1
        if let separator = raw.firstIndex(of: "=") {
            pendingInlineValue = String(raw[raw.index(after: separator)...])
            return String(raw[..<separator])
        }
        pendingInlineValue = nil
        return raw
    }

    mutating func requiredValue(for option: String) throws -> String {
        if let pendingInlineValue {
            self.pendingInlineValue = nil
            guard !pendingInlineValue.isEmpty else {
                throw ThreeDSGError.invalidValue("\(option) requires a value")
            }
            return pendingInlineValue
        }
        guard index < arguments.count else {
            throw ThreeDSGError.invalidValue("\(option) requires a value")
        }
        let value = arguments[index]
        guard !value.hasPrefix("--") else {
            throw ThreeDSGError.invalidValue("\(option) requires a value")
        }
        index += 1
        return value
    }
}
