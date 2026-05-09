import AppKit
import Foundation
import Testing
@testable import ThreeDSGCore

@Suite
struct RenderIntegrationTests {
    @Test(.timeLimit(.minutes(2)))
    func rendersCurrentAppleAssets() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("3dsg-integration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let portraitScreenURL = temporaryDirectory.appendingPathComponent("screen-portrait.png")
        let landscapeScreenURL = temporaryDirectory.appendingPathComponent("screen-landscape.png")
        let assetCacheDirectory = temporaryDirectory.appendingPathComponent("asset-cache", isDirectory: true)
        let renderer = DeviceRenderer(assetCache: AssetCache(directoryURL: assetCacheDirectory, reportDownload: { _, _ in }))
        try writeQuadrantImage(to: portraitScreenURL, width: 900, height: 1200)
        try writeQuadrantImage(to: landscapeScreenURL, width: 1200, height: 900)

        let cases: [RenderOptions] = [
            RenderOptions(
                device: .iPhone17Pro,
                color: .deepBlue,
                screenURL: portraitScreenURL,
                outputPNGURL: temporaryDirectory.appendingPathComponent("iphone-pro.png"),
                outputSize: try Dimensions(width: 360, height: 480)
            ),
            RenderOptions(
                device: .iPhone17ProMax,
                color: .silver,
                rotation: Rotation(x: 8, y: -12, z: 0),
                screenURL: landscapeScreenURL,
                outputPNGURL: temporaryDirectory.appendingPathComponent("iphone-pro-max.png"),
                outputSize: try Dimensions(width: 480, height: 360)
            ),
            RenderOptions(
                device: .iPad,
                screenURL: portraitScreenURL,
                outputPNGURL: temporaryDirectory.appendingPathComponent("ipad-portrait.png"),
                outputSize: try Dimensions(width: 360, height: 480)
            ),
            RenderOptions(
                device: .iPad,
                screenURL: landscapeScreenURL,
                outputPNGURL: temporaryDirectory.appendingPathComponent("ipad.png"),
                outputSize: try Dimensions(width: 480, height: 360)
            ),
            RenderOptions(
                device: .iPad,
                screenURL: landscapeScreenURL,
                outputPNGURL: temporaryDirectory.appendingPathComponent("ipad-accessories.png"),
                outputSize: try Dimensions(width: 480, height: 360),
                showKeyboard: true,
                showPencil: true
            )
        ]

        for renderCase in cases {
            let result = try renderer.render(renderCase)
            #expect(FileManager.default.fileExists(atPath: result.pngURL.path))
            let sidecarUSDZ = result.pngURL.deletingPathExtension().appendingPathExtension("usdz")
            #expect(!FileManager.default.fileExists(atPath: sidecarUSDZ.path))
            guard let outputSize = renderCase.outputSize else {
                Issue.record("expected explicit output size")
                continue
            }
            try assertPNG(result.pngURL, fitsWithin: outputSize)
        }

        let defaultSizeRender = RenderOptions(
            device: .iPhone17Pro,
            screenURL: portraitScreenURL,
            outputPNGURL: temporaryDirectory.appendingPathComponent("iphone-default-size.png")
        )
        let defaultSizeResult = try renderer.render(defaultSizeRender)
        try assertPNG(defaultSizeResult.pngURL, fitsWithin: Dimensions(width: 900, height: 1200))

        #expect(FileManager.default.fileExists(atPath: assetCacheDirectory.appendingPathComponent("iphone17pro-cosmicorange-ar-202509_GEO_US.usdz").path))
        #expect(FileManager.default.fileExists(atPath: assetCacheDirectory.appendingPathComponent("ipad-pro-m5-13in-spaceblack-mgk-black-pencil-pro-ios26.usdz").path))
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
