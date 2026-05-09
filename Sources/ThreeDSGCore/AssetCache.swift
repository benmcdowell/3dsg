import Foundation

protocol AssetDownloading: Sendable {
    func download(from sourceURL: URL, to destinationURL: URL) throws
}

struct AssetDescriptor: Equatable, Sendable {
    var fileName: String
    var downloadURL: URL
}

struct AssetCache: Sendable {
    static let applicationIdentifier = "com.benmcdowell.3dsg"
    static let usdzDirectoryName = "usdz"

    var directoryURL: URL
    var downloader: any AssetDownloading

    init(
        directoryURL: URL = Self.defaultDirectoryURL,
        downloader: any AssetDownloading = URLSessionAssetDownloader()
    ) {
        self.directoryURL = directoryURL
        self.downloader = downloader
    }

    static var `default`: AssetCache {
        AssetCache()
    }

    static var defaultDirectoryURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Self.applicationIdentifier, isDirectory: true)
            .appendingPathComponent(Self.usdzDirectoryName, isDirectory: true)
    }

    func assetURL(for descriptor: AssetDescriptor) throws -> URL {
        let assetURL = directoryURL.appendingPathComponent(descriptor.fileName, isDirectory: false)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: assetURL.path) {
            return assetURL
        }

        let temporaryURL = directoryURL
            .appendingPathComponent(".\(descriptor.fileName).download-\(UUID().uuidString)", isDirectory: false)
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try downloader.download(from: descriptor.downloadURL, to: temporaryURL)
            if fileManager.fileExists(atPath: assetURL.path) {
                try? fileManager.removeItem(at: temporaryURL)
            } else {
                try fileManager.moveItem(at: temporaryURL, to: assetURL)
            }
            return assetURL
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw ThreeDSGError.assetDownloadFailed(
                descriptor.fileName,
                assetURL,
                descriptor.downloadURL,
                error.localizedDescription
            )
        }
    }
}

struct URLSessionAssetDownloader: AssetDownloading {
    func download(from sourceURL: URL, to destinationURL: URL) throws {
        let semaphore = DispatchSemaphore(value: 0)
        let resultBox = DownloadResultBox()

        let task = URLSession.shared.downloadTask(with: sourceURL) { temporaryURL, response, error in
            defer {
                semaphore.signal()
            }

            if let error {
                resultBox.set(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                resultBox.set(.failure(ThreeDSGError.renderFailed("HTTP \(httpResponse.statusCode)")))
                return
            }

            guard let temporaryURL else {
                resultBox.set(.failure(ThreeDSGError.renderFailed("download did not produce a file")))
                return
            }

            do {
                try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
                resultBox.set(.success(()))
            } catch {
                resultBox.set(.failure(error))
            }
        }
        task.resume()
        semaphore.wait()

        try resultBox.get()
    }
}

private final class DownloadResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Void, Error>?

    func set(_ result: Result<Void, Error>) {
        lock.withLock {
            self.result = result
        }
    }

    func get() throws {
        try lock.withLock {
            try result?.get() ?? {
                throw ThreeDSGError.renderFailed("download failed without an error")
            }()
        }
    }
}
