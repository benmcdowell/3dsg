import Foundation
import Testing
@testable import ThreeDSGCore

@Suite
struct AssetCacheTests {
    @Test
    func defaultCachePathUsesApplicationSupport() {
        let expected = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.benmcdowell.3dsg", isDirectory: true)
            .appendingPathComponent("usdz", isDirectory: true)

        #expect(AssetCache.defaultDirectoryURL == expected)
    }

    @Test
    func downloadsMissingAssetIntoCacheDirectory() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let data = Data("downloaded asset".utf8)
        let descriptor = try makeDescriptor(fileName: "iphone.usdz")
        let downloader = StubAssetDownloader { _, destinationURL in
            try data.write(to: destinationURL)
        }
        let reporter = DownloadReportRecorder()
        let cache = AssetCache(directoryURL: temporaryDirectory, downloader: downloader, reportDownload: reporter.record)

        let assetURL = try cache.assetURL(for: descriptor)

        #expect(assetURL == temporaryDirectory.appendingPathComponent("iphone.usdz"))
        #expect(try Data(contentsOf: assetURL) == data)
        #expect(downloader.callCount == 1)
        #expect(reporter.reports == [DownloadReport(fileName: "iphone.usdz", assetURL: assetURL)])
    }

    @Test
    func reusesExistingCachedAssetWithoutDownloading() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let descriptor = try makeDescriptor(fileName: "ipad.usdz")
        let assetURL = temporaryDirectory.appendingPathComponent("ipad.usdz")
        let existingData = Data("cached asset".utf8)
        try existingData.write(to: assetURL)
        let downloader = StubAssetDownloader { _, _ in
            throw TestDownloadError.unexpectedDownload
        }
        let reporter = DownloadReportRecorder()
        let cache = AssetCache(directoryURL: temporaryDirectory, downloader: downloader, reportDownload: reporter.record)

        let resolvedURL = try cache.assetURL(for: descriptor)

        #expect(resolvedURL == assetURL)
        #expect(try Data(contentsOf: resolvedURL) == existingData)
        #expect(downloader.callCount == 0)
        #expect(reporter.reports.isEmpty)
    }

    @Test
    func failedDownloadThrowsAssetDownloadFailed() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let descriptor = try makeDescriptor(fileName: "missing.usdz")
        let downloader = StubAssetDownloader { _, _ in
            throw TestDownloadError.expectedFailure
        }
        let reporter = DownloadReportRecorder()
        let cache = AssetCache(directoryURL: temporaryDirectory, downloader: downloader, reportDownload: reporter.record)

        do {
            _ = try cache.assetURL(for: descriptor)
            Issue.record("expected asset download failure")
        } catch let error as ThreeDSGError {
            guard case .assetDownloadFailed(let name, let destinationURL, let sourceURL, _) = error else {
                Issue.record("expected assetDownloadFailed, got \(error)")
                return
            }
            #expect(name == "missing.usdz")
            #expect(destinationURL == temporaryDirectory.appendingPathComponent("missing.usdz"))
            #expect(sourceURL == descriptor.downloadURL)
            #expect(!FileManager.default.fileExists(atPath: destinationURL.path))
        }
        #expect(downloader.callCount == 1)
        #expect(reporter.reports.isEmpty)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("3dsg-asset-cache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeDescriptor(fileName: String) throws -> AssetDescriptor {
        guard let url = URL(string: "https://example.com/\(fileName)") else {
            throw TestDownloadError.badURL
        }
        return AssetDescriptor(fileName: fileName, downloadURL: url)
    }
}

private struct DownloadReport: Equatable {
    var fileName: String
    var assetURL: URL
}

private final class DownloadReportRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [DownloadReport] = []

    func record(_ descriptor: AssetDescriptor, _ assetURL: URL) {
        lock.withLock {
            values.append(DownloadReport(fileName: descriptor.fileName, assetURL: assetURL))
        }
    }

    var reports: [DownloadReport] {
        lock.withLock {
            values
        }
    }
}

private enum TestDownloadError: Error {
    case badURL
    case expectedFailure
    case unexpectedDownload
}

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() {
        lock.withLock {
            count += 1
        }
    }

    var value: Int {
        lock.withLock {
            count
        }
    }
}

private struct StubAssetDownloader: AssetDownloading {
    private let counter = CallCounter()
    private let handler: @Sendable (URL, URL) throws -> Void

    init(_ handler: @escaping @Sendable (URL, URL) throws -> Void) {
        self.handler = handler
    }

    var callCount: Int {
        counter.value
    }

    func download(from sourceURL: URL, to destinationURL: URL) throws {
        counter.increment()
        try handler(sourceURL, destinationURL)
    }
}
