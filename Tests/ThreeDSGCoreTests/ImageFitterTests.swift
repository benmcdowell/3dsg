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
