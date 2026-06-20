import Foundation

enum OperationLogStore {
    private static var logURL: URL {
        AppConstants.applicationSupportDirectory.appendingPathComponent("trash-operations.json")
    }

    static func load() -> [TrashOperationLog] {
        guard let data = try? Data(contentsOf: logURL) else { return [] }
        return (try? JSONDecoder.cleaner.decode([TrashOperationLog].self, from: data)) ?? []
    }

    static func append(_ entry: TrashOperationLog) {
        var entries = load()
        entries.insert(entry, at: 0)
        if entries.count > 80 {
            entries = Array(entries.prefix(80))
        }
        save(entries)
    }

    static func clear() {
        save([])
    }

    private static func save(_ entries: [TrashOperationLog]) {
        do {
            let data = try JSONEncoder.cleaner.encode(entries)
            try data.write(to: logURL, options: [.atomic])
        } catch {
            assertionFailure("Unable to save operation log: \(error)")
        }
    }
}

extension JSONEncoder {
    static var cleaner: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var cleaner: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
