import Foundation

public struct AtomicFileStore<Value: Codable> {
    public let fileURL: URL
    private let encoder = IPCCodec.encoder
    private let decoder = IPCCodec.decoder

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> Value {
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(Value.self, from: data)
    }

    public func loadIfPresent() throws -> Value? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return try load()
    }

    public func save(_ value: Value) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )

        let tempURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(fileURL.lastPathComponent).tmp-\(UUID().uuidString)")

        let data = try encoder.encode(value)
        try data.write(to: tempURL, options: [.atomic])

        if fileManager.fileExists(atPath: fileURL.path) {
            _ = try fileManager.replaceItemAt(fileURL, withItemAt: tempURL)
        } else {
            try fileManager.moveItem(at: tempURL, to: fileURL)
        }
    }

    public func backupCorruptFile() throws -> URL? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let backupURL = fileURL
            .deletingPathExtension()
            .appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
        try? fileManager.removeItem(at: backupURL)
        try fileManager.moveItem(at: fileURL, to: backupURL)
        return backupURL
    }
}
