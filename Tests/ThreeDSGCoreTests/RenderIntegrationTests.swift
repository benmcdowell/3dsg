import AppKit
import Foundation
import Testing
@testable import ThreeDSGCore

@Suite
struct RenderIntegrationTests {
    private let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)

    @Test(.timeLimit(.minutes(2)))
    func rendersCurrentAppleAssets() throws {
        let assetsDirectory = root.appendingPathComponent("Assets", isDirectory: true)
        try skipUnlessAssetsExist(assetsDirectory)

        let beforeHashes = try assetHashes(in: assetsDirectory)
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("3dsg-integration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let portraitScreenURL = temporaryDirectory.appendingPathComponent("screen-portrait.png")
        let landscapeScreenURL = temporaryDirectory.appendingPathComponent("screen-landscape.png")
        try writeQuadrantImage(to: portraitScreenURL, width: 900, height: 1200)
        try writeQuadrantImage(to: landscapeScreenURL, width: 1200, height: 900)

        let cases: [RenderOptions] = [
            RenderOptions(
                device: .iPhone17Pro,
                color: .deepBlue,
                screenURL: portraitScreenURL,
                outputPNGURL: temporaryDirectory.appendingPathComponent("iphone-pro.png"),
                outputSize: try Dimensions(width: 360, height: 480),
                assetsDirectoryURL: assetsDirectory
            ),
            RenderOptions(
                device: .iPhone17ProMax,
                color: .silver,
                rotation: Rotation(x: 8, y: -12, z: 0),
                screenURL: landscapeScreenURL,
                outputPNGURL: temporaryDirectory.appendingPathComponent("iphone-pro-max.png"),
                outputSize: try Dimensions(width: 480, height: 360),
                assetsDirectoryURL: assetsDirectory
            ),
            RenderOptions(
                device: .iPad,
                screenURL: portraitScreenURL,
                outputPNGURL: temporaryDirectory.appendingPathComponent("ipad-portrait.png"),
                outputSize: try Dimensions(width: 360, height: 480),
                assetsDirectoryURL: assetsDirectory
            ),
            RenderOptions(
                device: .iPad,
                screenURL: landscapeScreenURL,
                outputPNGURL: temporaryDirectory.appendingPathComponent("ipad.png"),
                outputSize: try Dimensions(width: 480, height: 360),
                assetsDirectoryURL: assetsDirectory
            ),
            RenderOptions(
                device: .iPad,
                screenURL: landscapeScreenURL,
                outputPNGURL: temporaryDirectory.appendingPathComponent("ipad-accessories.png"),
                outputSize: try Dimensions(width: 480, height: 360),
                assetsDirectoryURL: assetsDirectory,
                showKeyboard: true,
                showPencil: true
            )
        ]

        for renderCase in cases {
            let result = try DeviceRenderer().render(renderCase)
            #expect(FileManager.default.fileExists(atPath: result.pngURL.path))
            let sidecarUSDZ = result.pngURL.deletingPathExtension().appendingPathExtension("usdz")
            #expect(!FileManager.default.fileExists(atPath: sidecarUSDZ.path))
            try assertPNG(result.pngURL, fitsWithin: renderCase.outputSize)
        }

        let afterHashes = try assetHashes(in: assetsDirectory)
        #expect(beforeHashes == afterHashes)
    }

    private func skipUnlessAssetsExist(_ assetsDirectory: URL) throws {
        let required = [
            "iphone17pro-cosmicorange-ar-202509_GEO_US.usdz",
            "ipad-pro-m5-13in-spaceblack-mgk-black-pencil-pro-ios26.usdz"
        ]
        for fileName in required {
            let url = assetsDirectory.appendingPathComponent(fileName)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw ThreeDSGError.assetNotFound(fileName, url)
            }
        }
    }

    private func assetHashes(in assetsDirectory: URL) throws -> [String: Data] {
        let required = [
            "iphone17pro-cosmicorange-ar-202509_GEO_US.usdz",
            "ipad-pro-m5-13in-spaceblack-mgk-black-pencil-pro-ios26.usdz"
        ]
        var hashes: [String: Data] = [:]
        for fileName in required {
            let url = assetsDirectory.appendingPathComponent(fileName)
            hashes[fileName] = try Data(contentsOf: url)
        }
        return hashes
    }

    private func writeQuadrantImage(to url: URL, width: Int, height: Int) throws {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ThreeDSGError.renderFailed("test image context failed")
        }

        let halfWidth = CGFloat(width) / 2
        let halfHeight = CGFloat(height) / 2
        context.setFillColor(NSColor.systemRed.cgColor)
        context.fill(CGRect(x: 0, y: halfHeight, width: halfWidth, height: halfHeight))
        context.setFillColor(NSColor.systemGreen.cgColor)
        context.fill(CGRect(x: halfWidth, y: halfHeight, width: halfWidth, height: halfHeight))
        context.setFillColor(NSColor.systemBlue.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: halfWidth, height: halfHeight))
        context.setFillColor(NSColor.systemYellow.cgColor)
        context.fill(CGRect(x: halfWidth, y: 0, width: halfWidth, height: halfHeight))

        guard let image = context.makeImage() else {
            throw ThreeDSGError.renderFailed("test image creation failed")
        }
        let nsImage = NSImage(cgImage: image, size: NSSize(width: width, height: height))
        try ImageFitter.pngData(from: nsImage).write(to: url)
    }

    private func assertPNG(_ url: URL, fitsWithin size: Dimensions) throws {
        let data = try Data(contentsOf: url)
        guard let rep = NSBitmapImageRep(data: data) else {
            throw ThreeDSGError.imageLoadFailed(url)
        }
        #expect(rep.pixelsWide <= size.width)
        #expect(rep.pixelsHigh <= size.height)
        #expect(rep.pixelsWide == size.width || rep.pixelsHigh == size.height)
    }
}
