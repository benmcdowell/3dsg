import Foundation
import Testing
@testable import ThreeDSGCore

@Suite
struct CommandLineParserTests {
    private let root = URL(fileURLWithPath: "/tmp/3dsg-tests", isDirectory: true)

    @Test
    func parsesRenderCommandWithDefaults() throws {
        let command = try CommandLineParser.parse([
            "render",
            "--device", "iphone-17-pro",
            "--screen", "screen.png",
            "--output", "out/render.png",
            "--size", "1200x900"
        ], currentDirectory: root)

        guard case .render(let options) = command else {
            Issue.record("expected render command")
            return
        }

        #expect(options.device == .iPhone17Pro)
        #expect(options.orientation == .portrait)
        #expect(options.color == .cosmicOrange)
        #expect(options.screenFit == .cover)
        #expect(options.screenFitWasSpecified == false)
        let expectedSize = try Dimensions(width: 1200, height: 900)
        #expect(options.outputSize == expectedSize)
    }

    @Test
    func parsesExplicitOptions() throws {
        let command = try CommandLineParser.parse([
            "render",
            "--device=iphone-17-pro-max",
            "--orientation=landscape",
            "--color=deep-blue",
            "--rotation", "12,0,-45",
            "--screen", "/tmp/screen.png",
            "--output", "/tmp/render.png",
            "--size", "800x600",
            "--assets-dir", "/tmp/assets",
            "--screen-fit", "contain"
        ], currentDirectory: root)

        guard case .render(let options) = command else {
            Issue.record("expected render command")
            return
        }

        #expect(options.device == .iPhone17ProMax)
        #expect(options.orientation == .landscape)
        #expect(options.color == .deepBlue)
        #expect(options.rotation == Rotation(x: 12, y: 0, z: -45))
        #expect(options.screenFit == .contain)
        #expect(options.screenFitWasSpecified == true)
        #expect(options.assetsDirectoryURL.path == "/tmp/assets")
    }

    @Test
    func rotatesScreenshotIntoAssetNativeOrientation() {
        #expect(DeviceOrientation.portrait.rotationQuarterTurns(toNativeOrientation: .portrait) == 0)
        #expect(DeviceOrientation.landscape.rotationQuarterTurns(toNativeOrientation: .landscape) == 0)
        #expect(DeviceOrientation.landscape.rotationQuarterTurns(toNativeOrientation: .portrait) == 1)
        #expect(DeviceOrientation.portrait.rotationQuarterTurns(toNativeOrientation: .landscape) == 1)
    }

    @Test
    func rejectsIPadColor() throws {
        #expect(throws: ThreeDSGError.self) {
            try CommandLineParser.parse([
                "render",
                "--device", "ipad",
                "--color", "silver",
                "--screen", "screen.png",
                "--output", "render.png",
                "--size", "800x600"
            ], currentDirectory: root)
        }
    }

    @Test
    func rejectsBadSize() throws {
        #expect(throws: ThreeDSGError.self) {
            try CommandLineParser.parse([
                "render",
                "--device", "ipad",
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
                "--device", "ipad",
                "--screen", "screen.png",
                "--output", "render.png",
                "--size", "800x600",
                "--rotation", "1,2"
            ], currentDirectory: root)
        }
    }
}
