import AppKit
import Foundation

public struct PixelSize: Equatable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) throws {
        guard width > 0, height > 0 else {
            throw ThreeDSGError.invalidValue("pixel size must be positive")
        }
        self.width = width
        self.height = height
    }
}

public enum ImageFitter {
    public static func orientation(ofImageAt inputURL: URL) throws -> DeviceOrientation {
        guard let image = NSImage(contentsOf: inputURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ThreeDSGError.imageLoadFailed(inputURL)
        }

        if cgImage.width > cgImage.height {
            return .landscape
        }
        if cgImage.height > cgImage.width {
            return .portrait
        }
        throw ThreeDSGError.invalidValue("--screen image must be portrait or landscape; square images cannot infer orientation")
    }

    public static func fittedImage(
        from inputURL: URL,
        fit: ScreenFit,
        targetSize: PixelSize,
        rotateQuarterTurns: Int = 0
    ) throws -> NSImage {
        guard let image = NSImage(contentsOf: inputURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ThreeDSGError.imageLoadFailed(inputURL)
        }
        let source = try rotatedImage(cgImage, quarterTurns: rotateQuarterTurns)
        return try fittedImage(source, fit: fit, targetSize: targetSize)
    }

    public static func fittedImage(
        _ source: CGImage,
        fit: ScreenFit,
        targetSize: PixelSize
    ) throws -> NSImage {
        let targetRect = CGRect(x: 0, y: 0, width: targetSize.width, height: targetSize.height)
        let drawRect: CGRect
        let sourceSize = CGSize(width: source.width, height: source.height)
        let targetSizeCG = CGSize(width: targetSize.width, height: targetSize.height)

        switch fit {
        case .stretch:
            drawRect = targetRect
        case .cover:
            let scale = max(targetSizeCG.width / sourceSize.width, targetSizeCG.height / sourceSize.height)
            let width = sourceSize.width * scale
            let height = sourceSize.height * scale
            drawRect = CGRect(
                x: (targetSizeCG.width - width) / 2,
                y: (targetSizeCG.height - height) / 2,
                width: width,
                height: height
            )
        case .contain:
            let scale = min(targetSizeCG.width / sourceSize.width, targetSizeCG.height / sourceSize.height)
            let width = sourceSize.width * scale
            let height = sourceSize.height * scale
            drawRect = CGRect(
                x: (targetSizeCG.width - width) / 2,
                y: (targetSizeCG.height - height) / 2,
                width: width,
                height: height
            )
        }

        guard let context = CGContext(
            data: nil,
            width: targetSize.width,
            height: targetSize.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ThreeDSGError.renderFailed("could not create bitmap context")
        }

        context.clear(targetRect)
        context.interpolationQuality = .high
        context.draw(source, in: drawRect)

        guard let output = context.makeImage() else {
            throw ThreeDSGError.renderFailed("could not create fitted image")
        }
        return NSImage(cgImage: output, size: NSSize(width: targetSize.width, height: targetSize.height))
    }

    public static func fittedTrimmedImage(
        _ source: CGImage,
        targetSize: PixelSize,
        alphaThreshold: UInt8 = 0
    ) throws -> NSImage {
        let trimmed = try trimmedTransparentImage(source, alphaThreshold: alphaThreshold)
        return try scaledImage(trimmed, maxSize: targetSize)
    }

    public static func scaledImage(
        _ source: CGImage,
        maxSize: PixelSize
    ) throws -> NSImage {
        let scale = min(
            Double(maxSize.width) / Double(source.width),
            Double(maxSize.height) / Double(source.height)
        )
        let targetWidth = min(maxSize.width, max(1, Int((Double(source.width) * scale).rounded())))
        let targetHeight = min(maxSize.height, max(1, Int((Double(source.height) * scale).rounded())))
        let targetRect = CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight)

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ThreeDSGError.renderFailed("could not create scale context")
        }

        context.clear(targetRect)
        context.interpolationQuality = .high
        context.draw(source, in: targetRect)

        guard let output = context.makeImage() else {
            throw ThreeDSGError.renderFailed("could not create scaled image")
        }
        return NSImage(cgImage: output, size: NSSize(width: targetWidth, height: targetHeight))
    }

    public static func trimmedTransparentImage(
        _ source: CGImage,
        alphaThreshold: UInt8 = 0
    ) throws -> CGImage {
        let width = source.width
        let height = source.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ThreeDSGError.renderFailed("could not create trim context")
        }

        let fullRect = CGRect(x: 0, y: 0, width: width, height: height)
        context.clear(fullRect)
        context.draw(source, in: fullRect)

        guard let rawData = context.data else {
            throw ThreeDSGError.renderFailed("could not read trim context")
        }

        let buffer = rawData.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            let rowOffset = y * bytesPerRow
            for x in 0..<width {
                let alpha = buffer[rowOffset + x * bytesPerPixel + 3]
                if alpha > alphaThreshold {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard maxX >= minX, maxY >= minY else {
            return source
        }
        guard let normalized = context.makeImage(),
              let cropped = normalized.cropping(to: CGRect(
                  x: minX,
                  y: minY,
                  width: maxX - minX + 1,
                  height: maxY - minY + 1
              )) else {
            throw ThreeDSGError.renderFailed("could not crop transparent pixels")
        }
        return cropped
    }

    public static func pngData(from image: NSImage) throws -> Data {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else {
            throw ThreeDSGError.renderFailed("could not encode PNG")
        }
        return data
    }

    private static func rotatedImage(_ source: CGImage, quarterTurns: Int) throws -> CGImage {
        let turns = ((quarterTurns % 4) + 4) % 4
        guard turns != 0 else {
            return source
        }

        let sourceWidth = source.width
        let sourceHeight = source.height
        let targetWidth = turns == 2 ? sourceWidth : sourceHeight
        let targetHeight = turns == 2 ? sourceHeight : sourceWidth

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ThreeDSGError.renderFailed("could not create rotation context")
        }

        switch turns {
        case 1:
            context.translateBy(x: CGFloat(targetWidth), y: 0)
            context.rotate(by: .pi / 2)
        case 2:
            context.translateBy(x: CGFloat(targetWidth), y: CGFloat(targetHeight))
            context.rotate(by: .pi)
        case 3:
            context.translateBy(x: 0, y: CGFloat(targetHeight))
            context.rotate(by: -.pi / 2)
        default:
            break
        }

        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: sourceWidth, height: sourceHeight))

        guard let rotated = context.makeImage() else {
            throw ThreeDSGError.renderFailed("could not create rotated image")
        }
        return rotated
    }
}
