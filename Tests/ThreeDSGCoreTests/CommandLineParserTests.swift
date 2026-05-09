import Foundation
import Testing
@testable import ThreeDSGCore

@Suite
struct CommandLineParserTests {
    private let root = URL(fileURLWithPath: "/tmp/3dsg-tests", isDirectory: true)

    @Test
    func parsesVersionCommands() throws {
        #expect(try CommandLineParser.parse(["--version"], currentDirectory: root) == .version)
        #expect(try CommandLineParser.parse(["-v"], currentDirectory: root) == .version)
        #expect(try CommandLineParser.parse(["version"], currentDirectory: root) == .version)
        #expect(try CommandLineParser.parse(["render", "--version"], currentDirectory: root) == .version)
    }

    @Test
    func parsesOptionsWithoutRenderCommandWithDefaults() throws {
        let command = try CommandLineParser.parse([
            "--device", "iphone-17-pro",
            "--screen", "screen.png",
            "--output", "out/render.png"
        ], currentDirectory: root)

        guard case .render(let options) = command else {
            Issue.record("expected render command")
            return
        }

        #expect(options.device == .iPhone17Pro)
        #expect(options.color == .cosmicOrange)
        #expect(options.screenFit == .cover)
        #expect(options.screenFitWasSpecified == false)
        #expect(options.outputSize == nil)
    }

    @Test
    func parsesExplicitOptions() throws {
        let command = try CommandLineParser.parse([
            "--device=iphone-17-pro-max",
            "--color=deep-blue",
            "--rotation", "12,0,-45",
            "--screen", "/tmp/screen.png",
            "--output", "/tmp/render.png",
            "--size", "800x600"
        ], currentDirectory: root)

        guard case .render(let options) = command else {
            Issue.record("expected render command")
            return
        }

        #expect(options.device == .iPhone17ProMax)
        #expect(options.color == .deepBlue)
        #expect(options.rotation == Rotation(x: 12, y: 0, z: -45))
        #expect(options.screenFit == .cover)
        #expect(options.screenFitWasSpecified == false)
        let expectedSize = try Dimensions(width: 800, height: 600)
        #expect(options.outputSize == expectedSize)
    }

    @Test
    func acceptsLegacyRenderCommandAlias() throws {
        let command = try CommandLineParser.parse([
            "render",
            "--device", "iphone-17-pro",
            "--screen", "screen.png",
            "--output", "out/render.png"
        ], currentDirectory: root)

        guard case .render(let options) = command else {
            Issue.record("expected render command")
            return
        }

        #expect(options.device == .iPhone17Pro)
    }

    @Test
    func rotatesScreenshotIntoAssetNativeOrientation() {
        #expect(DeviceOrientation.portrait.rotationQuarterTurns(toNativeOrientation: .portrait) == 0)
        #expect(DeviceOrientation.landscape.rotationQuarterTurns(toNativeOrientation: .landscape) == 0)
        #expect(DeviceOrientation.landscape.rotationQuarterTurns(toNativeOrientation: .portrait) == 1)
        #expect(DeviceOrientation.portrait.rotationQuarterTurns(toNativeOrientation: .landscape) == 1)
    }

    @Test
    func normalizesIPhone17ProSourceRotation() {
        #expect(Device.iPhone17Pro.assetNormalizationRotation == Rotation(x: 0, y: 180, z: 0))
        #expect(Device.iPhone17ProMax.assetNormalizationRotation == .zero)
        #expect(Device.iPad.assetNormalizationRotation == .zero)
    }

    @Test
    func parsesIPadPro13InchDeviceName() throws {
        let command = try CommandLineParser.parse([
            "render",
            "--device", "ipad-pro-13-inch",
            "--screen", "screen.png",
            "--output", "render.png",
            "--size", "800x600"
        ], currentDirectory: root)

        guard case .render(let options) = command else {
            Issue.record("expected render command")
            return
        }

        #expect(options.device == .iPad)
    }

    @Test
    func rejectsLegacyIPadDeviceName() throws {
        #expect(throws: ThreeDSGError.self) {
            try CommandLineParser.parse([
                "render",
                "--device", "ipad",
                "--screen", "screen.png",
                "--output", "render.png",
                "--size", "800x600"
            ], currentDirectory: root)
        }
    }

    @Test
    func rejectsIPadColor() throws {
        #expect(throws: ThreeDSGError.self) {
            try CommandLineParser.parse([
                "render",
                "--device", "ipad-pro-13-inch",
                "--color", "silver",
                "--screen", "screen.png",
                "--output", "render.png",
                "--size", "800x600"
            ], currentDirectory: root)
        }
    }

    @Test
    func rejectsAccessoryFlags() throws {
        #expect(throws: ThreeDSGError.self) {
            try CommandLineParser.parse([
                "render",
                "--device", "ipad-pro-13-inch",
                "--screen", "screen.png",
                "--output", "render.png",
                "--size", "800x600",
                "--show-keyboard"
            ], currentDirectory: root)
        }

        #expect(throws: ThreeDSGError.self) {
            try CommandLineParser.parse([
                "render",
                "--device", "ipad-pro-13-inch",
                "--screen", "screen.png",
                "--output", "render.png",
                "--size", "800x600",
                "--show-pencil"
            ], currentDirectory: root)
        }
    }

    @Test
    func rejectsOrientationOption() throws {
        #expect(throws: ThreeDSGError.self) {
            try CommandLineParser.parse([
                "render",
                "--device", "iphone-17-pro",
                "--orientation", "portrait",
                "--screen", "screen.png",
                "--output", "render.png",
                "--size", "800x600"
            ], currentDirectory: root)
        }
    }

    @Test
    func rejectsScreenFitOption() throws {
        #expect(throws: ThreeDSGError.self) {
            try CommandLineParser.parse([
                "render",
                "--device", "iphone-17-pro",
                "--screen", "screen.png",
                "--output", "render.png",
                "--size", "800x600",
                "--screen-fit", "contain"
            ], currentDirectory: root)
        }
    }

    @Test
    func rejectsAssetsDirectoryOption() throws {
        #expect(throws: ThreeDSGError.self) {
            try CommandLineParser.parse([
                "--device", "iphone-17-pro",
                "--screen", "screen.png",
                "--output", "render.png",
                "--assets-dir", "/tmp/assets"
            ], currentDirectory: root)
        }
    }

    @Test
    func rejectsBadSize() throws {
        #expect(throws: ThreeDSGError.self) {
            try CommandLineParser.parse([
                "render",
                "--device", "ipad-pro-13-inch",
                "--screen", "screen.png",
                "--output", "render.png",
                "--size", "800"
            ], currentDirectory: root)
        }
    }

    @Test
    func rejectsBadRotation() throws {
        #expect(throws: ThreeDSGError.self) {
            try CommandLineParser.parse([
                "render",
                "--device", "ipad-pro-13-inch",
                "--screen", "screen.png",
                "--output", "render.png",
                "--size", "800x600",
                "--rotation", "1,2"
            ], currentDirectory: root)
        }
    }
}
