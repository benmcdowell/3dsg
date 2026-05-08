import Foundation

public enum Command: Equatable, Sendable {
    case render(RenderOptions)
    case help
}

public struct CommandLineParser: Sendable {
    public static func parse(_ arguments: [String], currentDirectory: URL) throws -> Command {
        guard let command = arguments.first else {
            throw ThreeDSGError.usage(Self.usage)
        }

        if command == "-h" || command == "--help" {
            return .help
        }

        guard command == "render" else {
            throw ThreeDSGError.usage("unknown command: \(command)\n\n\(Self.usage)")
        }

        var parser = OptionParser(Array(arguments.dropFirst()))
        var device: Device?
        var orientation: DeviceOrientation?
        var color: IPhoneColor?
        var colorWasProvided = false
        var rotation = Rotation.zero
        var screenURL: URL?
        var outputPNGURL: URL?
        var outputSize: Dimensions?
        var assetsDirectoryURL = currentDirectory.appendingPathComponent("Assets")
        var screenFit = ScreenFit.cover
        var screenFitWasSpecified = false
        var showKeyboard = false
        var showPencil = false

        while let option = parser.nextOption() {
            switch option {
            case "-h", "--help":
                return .help
            case "--device":
                let value = try parser.requiredValue(for: option)
                guard let parsed = Device(rawValue: value) else {
                    throw ThreeDSGError.invalidValue("--device must be one of: \(Device.allCases.map(\.rawValue).joined(separator: ", "))")
                }
                device = parsed
            case "--orientation":
                let value = try parser.requiredValue(for: option)
                guard let parsed = DeviceOrientation(rawValue: value) else {
                    throw ThreeDSGError.invalidValue("--orientation must be portrait or landscape")
                }
                orientation = parsed
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
                assetsDirectoryURL = resolvePath(try parser.requiredValue(for: option), currentDirectory: currentDirectory)
            case "--screen-fit":
                let value = try parser.requiredValue(for: option)
                guard let parsed = ScreenFit(rawValue: value) else {
                    throw ThreeDSGError.invalidValue("--screen-fit must be cover, contain, or stretch")
                }
                screenFit = parsed
                screenFitWasSpecified = true
            case "--show-keyboard":
                showKeyboard = true
            case "--show-pencil":
                showPencil = true
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
        guard let outputSize else {
            throw ThreeDSGError.missingRequiredOption("missing required option: --size")
        }

        if !device.isIPhone && colorWasProvided {
            throw ThreeDSGError.unsupportedOption("--color is only supported for iPhone renders")
        }
        if device.isIPhone && (showKeyboard || showPencil) {
            throw ThreeDSGError.unsupportedOption("--show-keyboard and --show-pencil are only supported for iPad renders")
        }

        let options = RenderOptions(
            device: device,
            orientation: orientation,
            color: color ?? .cosmicOrange,
            rotation: rotation,
            screenURL: screenURL,
            outputPNGURL: outputPNGURL,
            outputSize: outputSize,
            assetsDirectoryURL: assetsDirectoryURL,
            screenFit: screenFit,
            screenFitWasSpecified: screenFitWasSpecified,
            showKeyboard: showKeyboard,
            showPencil: showPencil
        )
        return .render(options)
    }

    public static let usage = """
    Usage:
      3dsg render --device iphone-17-pro|iphone-17-pro-max|ipad --screen path --output path.png --size WIDTHxHEIGHT [options]

    Options:
      --orientation portrait|landscape       Defaults to portrait for iPhone and landscape for iPad.
      --color cosmic-orange|deep-blue|silver iPhone only. Default: cosmic-orange.
      --rotation X,Y,Z                       Extra device rotation in degrees. Default: 0,0,0.
      --assets-dir path                      Default: ./Assets.
      --screen-fit cover|contain|stretch     Default: cover for iPhone; stretch for iPad.
      --show-keyboard                        iPad only. Hidden by default.
      --show-pencil                          iPad only. Hidden by default.
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
