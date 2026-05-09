import AppKit
import Foundation
import Testing
@testable import ThreeDSGCore

@Suite
struct ImageFitterTests {
    @Test
    func coverFillsTargetAndCrops() throws {
        let source = try makeImage(width: 400, height: 200, color: .red)
        let output = try ImageFitter.fittedImage(source, fit: .cover, targetSize: PixelSize(width: 100, height: 100))
        let rep = try bitmap(output)
        #expect(rep.pixelsWide == 100)
        #expect(rep.pixelsHigh == 100)
        #expect(alpha(atX: 50, y: 50, in: rep) > 200)
    }

    @Test
    func containLetterboxes() throws {
        let source = try makeImage(width: 400, height: 200, color: .red)
        let output = try ImageFitter.fittedImage(source, fit: .contain, targetSize: PixelSize(width: 100, height: 100))
        let rep = try bitmap(output)
        #expect(alpha(atX: 50, y: 50, in: rep) > 200)
        #expect(alpha(atX: 50, y: 5, in: rep) < 20)
    }

    @Test
    func stretchFillsWholeTarget() throws {
        let source = try makeImage(width: 400, height: 200, color: .red)
        let output = try ImageFitter.fittedImage(source, fit: .stretch, targetSize: PixelSize(width: 100, height: 100))
        let rep = try bitmap(output)
        #expect(alpha(atX: 50, y: 5, in: rep) > 200)
    }

    @Test
    func trimsTransparentEdges() throws {
        let source = try makeTransparentImage(
            width: 120,
            height: 80,
            fillRect: CGRect(x: 15, y: 10, width: 70, height: 45)
        )

        let output = try ImageFitter.trimmedTransparentImage(source)

        #expect(output.width == 70)
        #expect(output.height == 45)
    }

    @Test
    func fitsTrimmedImageWithinMaxSizeWithoutPadding() throws {
        let source = try makeTransparentImage(
            width: 120,
            height: 80,
            fillRect: CGRect(x: 10, y: 20, width: 100, height: 40)
        )

        let output = try ImageFitter.fittedTrimmedImage(source, targetSize: PixelSize(width: 100, height: 100))
        let rep = try bitmap(output)

        #expect(rep.pixelsWide == 100)
        #expect(rep.pixelsHigh == 40)
        #expect(alpha(atX: 50, y: 20, in: rep) > 200)
        #expect(alpha(atX: 50, y: 0, in: rep) > 200)
        #expect(alpha(atX: 50, y: 39, in: rep) > 200)
    }

    @Test
    func infersOrientationFromImageDimensions() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("3dsg-image-fitter-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let portraitURL = temporaryDirectory.appendingPathComponent("portrait.png")
        let landscapeURL = temporaryDirectory.appendingPathComponent("landscape.png")
        let squareURL = temporaryDirectory.appendingPathComponent("square.png")
        try writeImage(to: portraitURL, width: 400, height: 800)
        try writeImage(to: landscapeURL, width: 800, height: 400)
        try writeImage(to: squareURL, width: 500, height: 500)

        #expect(try ImageFitter.orientation(ofImageAt: portraitURL) == .portrait)
        #expect(try ImageFitter.orientation(ofImageAt: landscapeURL) == .landscape)
        #expect(throws: ThreeDSGError.self) {
            try ImageFitter.orientation(ofImageAt: squareURL)
        }
    }

    private func writeImage(to url: URL, width: Int, height: Int) throws {
        let image = try makeImage(width: width, height: height, color: .red)
        let nsImage = NSImage(cgImage: image, size: NSSize(width: width, height: height))
        try ImageFitter.pngData(from: nsImage).write(to: url)
    }

    private func makeImage(width: Int, height: Int, color: NSColor) throws -> CGImage {
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
        context.setFillColor(color.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else {
            throw ThreeDSGError.renderFailed("test image failed")
        }
        return image
    }

    private func makeTransparentImage(width: Int, height: Int, fillRect: CGRect) throws -> CGImage {
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
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(NSColor.red.cgColor)
        context.fill(fillRect)
        guard let image = context.makeImage() else {
            throw ThreeDSGError.renderFailed("test image failed")
        }
        return image
    }

    private func bitmap(_ image: NSImage) throws -> NSBitmapImageRep {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            throw ThreeDSGError.renderFailed("could not read test bitmap")
        }
        return rep
    }

    private func alpha(atX x: Int, y: Int, in rep: NSBitmapImageRep) -> Int {
        Int((rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) * 255)
    }
}
