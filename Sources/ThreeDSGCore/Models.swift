import Foundation

public enum Device: String, CaseIterable, Sendable {
    case iPhone17Pro = "iphone-17-pro"
    case iPhone17ProMax = "iphone-17-pro-max"
    case iPad = "ipad"

    public var isIPhone: Bool {
        switch self {
        case .iPhone17Pro, .iPhone17ProMax:
            true
        case .iPad:
            false
        }
    }

    public var defaultOrientation: DeviceOrientation {
        switch self {
        case .iPhone17Pro, .iPhone17ProMax:
            .portrait
        case .iPad:
            .landscape
        }
    }
}

public enum DeviceOrientation: String, CaseIterable, Sendable {
    case portrait
    case landscape
}

public enum IPhoneColor: String, CaseIterable, Sendable {
    case cosmicOrange = "cosmic-orange"
    case deepBlue = "deep-blue"
    case silver

    var usdVariantName: String {
        switch self {
        case .cosmicOrange:
            "Cosmic_Orange"
        case .deepBlue:
            "Deep_Blue"
        case .silver:
            "Silver"
        }
    }
}

public enum ScreenFit: String, CaseIterable, Sendable {
    case cover
    case contain
    case stretch
}

public struct Dimensions: Equatable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) throws {
        guard width > 0, height > 0 else {
            throw ThreeDSGError.invalidValue("--size must be positive")
        }
        self.width = width
        self.height = height
    }

    public static func parse(_ value: String) throws -> Dimensions {
        let parts = value.lowercased().split(separator: "x", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let width = Int(parts[0]),
              let height = Int(parts[1]) else {
            throw ThreeDSGError.invalidValue("--size must use WIDTHxHEIGHT, for example 1200x900")
        }
        return try Dimensions(width: width, height: height)
    }
}

public struct Rotation: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = Rotation(x: 0, y: 0, z: 0)

    public static func parse(_ value: String) throws -> Rotation {
        let parts = value.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let x = Double(parts[0]),
              let y = Double(parts[1]),
              let z = Double(parts[2]) else {
            throw ThreeDSGError.invalidValue("--rotation must use X,Y,Z degrees, for example 20,0,-12")
        }
        return Rotation(x: x, y: y, z: z)
    }
}

public struct RenderOptions: Equatable, Sendable {
    public var device: Device
    public var orientation: DeviceOrientation
    public var color: IPhoneColor
    public var rotation: Rotation
    public var screenURL: URL
    public var outputPNGURL: URL
    public var outputUSDZURL: URL
    public var outputSize: Dimensions
    public var assetsDirectoryURL: URL
    public var screenFit: ScreenFit
    public var showKeyboard: Bool
    public var showPencil: Bool

    public init(
        device: Device,
        orientation: DeviceOrientation? = nil,
        color: IPhoneColor = .cosmicOrange,
        rotation: Rotation = .zero,
        screenURL: URL,
        outputPNGURL: URL,
        outputUSDZURL: URL? = nil,
        outputSize: Dimensions,
        assetsDirectoryURL: URL,
        screenFit: ScreenFit = .cover,
        showKeyboard: Bool = false,
        showPencil: Bool = false
    ) {
        self.device = device
        self.orientation = orientation ?? device.defaultOrientation
        self.color = color
        self.rotation = rotation
        self.screenURL = screenURL
        self.outputPNGURL = outputPNGURL
        self.outputUSDZURL = outputUSDZURL ?? outputPNGURL.deletingPathExtension().appendingPathExtension("usdz")
        self.outputSize = outputSize
        self.assetsDirectoryURL = assetsDirectoryURL
        self.screenFit = screenFit
        self.showKeyboard = showKeyboard
        self.showPencil = showPencil
    }
}

public struct RenderResult: Equatable, Sendable {
    public var pngURL: URL
    public var usdzURL: URL
}

public enum ThreeDSGError: Error, LocalizedError {
    case usage(String)
    case invalidValue(String)
    case missingRequiredOption(String)
    case missingFile(URL)
    case unsupportedOption(String)
    case assetNotFound(String, URL)
    case sceneNodeNotFound(String)
    case imageLoadFailed(URL)
    case imageWriteFailed(URL)
    case renderFailed(String)
    case exportFailed(URL)

    public var errorDescription: String? {
        switch self {
        case .usage(let message),
             .invalidValue(let message),
             .missingRequiredOption(let message),
             .unsupportedOption(let message),
             .renderFailed(let message):
            message
        case .missingFile(let url):
            "file not found: \(url.path)"
        case .assetNotFound(let name, let url):
            "asset \(name) not found at \(url.path)"
        case .sceneNodeNotFound(let name):
            "required scene node not found: \(name)"
        case .imageLoadFailed(let url):
            "could not load image: \(url.path)"
        case .imageWriteFailed(let url):
            "could not write image: \(url.path)"
        case .exportFailed(let url):
            "could not export USDZ: \(url.path)"
        }
    }
}
