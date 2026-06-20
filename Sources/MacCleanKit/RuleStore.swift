import Foundation

enum RuleStore {
    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cachedRules: [RemovalRule]?

    static func loadRules(refresh: Bool = false) -> [RemovalRule] {
        cacheLock.lock()
        if !refresh, let cachedRules {
            cacheLock.unlock()
            return cachedRules
        }
        cacheLock.unlock()

        let urls = [
            Bundle.module.url(forResource: "RemovalRules", withExtension: "json"),
            userRulesURL
        ].compactMap { $0 }

        let rules = urls.flatMap(loadRules)
        let validRules = rules.filter { RuleValidator.validate($0).isEmpty }

        cacheLock.lock()
        cachedRules = validRules
        cacheLock.unlock()
        return validRules
    }

    static func rules(for bundleIdentifier: String?) -> [RemovalRule] {
        guard let bundleIdentifier else { return [] }
        return loadRules().filter {
            $0.bundleIdentifier.caseInsensitiveCompare(bundleIdentifier) == .orderedSame
        }
    }

    static func category(from rawValue: String) -> FileCategory {
        FileCategory(rawValue: rawValue) ?? .other
    }

    static var userRulesURL: URL {
        AppConstants.applicationSupportDirectory.appendingPathComponent("RemovalRules.json")
    }

    private static func loadRules(from url: URL) -> [RemovalRule] {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url)
        else { return [] }

        return (try? JSONDecoder.cleaner.decode([RemovalRule].self, from: data)) ?? []
    }
}

enum RuleValidator {
    static func validate(_ rule: RemovalRule) -> [String] {
        var errors: [String] = []
        if rule.schemaVersion < 1 {
            errors.append("schemaVersion must be >= 1")
        }
        if rule.bundleIdentifier.split(separator: ".").count < 2 {
            errors.append("bundleIdentifier is invalid")
        }

        for path in rule.paths {
            if path.defaultSelected || path.recommended {
                let expanded = (path.path as NSString).expandingTildeInPath
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                let forbiddenDefaults = [
                    "\(home)/Desktop",
                    "\(home)/Documents",
                    "\(home)/Downloads",
                    "\(home)/Pictures",
                    "\(home)/Movies",
                    "\(home)/Music"
                ]
                if forbiddenDefaults.contains(where: { expanded == $0 || expanded.hasPrefix($0 + "/") }) {
                    errors.append("default-selected rule cannot target user content: \(path.path)")
                }
            }
            if path.risk == .protected, path.defaultSelected || path.recommended {
                errors.append("protected rules cannot be default selected: \(path.path)")
            }
        }

        return errors
    }
}
