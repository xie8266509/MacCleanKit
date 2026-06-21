import Foundation

enum SelfTestRunner {
    static func run() -> Int32 {
        var failures: [String] = []

        if RuleStore.bundledRulesURL == nil {
            failures.append("Bundled removal rules file was not found.")
        }

        let rules = RuleStore.loadRules(refresh: true)
        if rules.isEmpty {
            failures.append("Bundled removal rules did not load.")
        }

        for rule in rules {
            let errors = RuleValidator.validate(rule)
            if !errors.isEmpty {
                failures.append("Rule \(rule.bundleIdentifier) failed validation: \(errors.joined(separator: ", "))")
            }
        }

        let unsafeRule = RemovalRule(
            bundleIdentifier: "com.example.Bad",
            displayName: "Bad",
            schemaVersion: 1,
            paths: [
                RulePath(
                    path: "~/Documents",
                    category: "other",
                    recommended: true,
                    risk: .destructive,
                    description: "Unsafe default",
                    defaultSelected: true
                )
            ]
        )
        if RuleValidator.validate(unsafeRule).isEmpty {
            failures.append("Rule validator allowed default-selected user content.")
        }

        let protectedRule = RemovalRule(
            bundleIdentifier: "com.example.Protected",
            displayName: "Protected",
            schemaVersion: 1,
            paths: [
                RulePath(
                    path: "~/Library/Application Support/Protected",
                    category: "applicationSupport",
                    recommended: true,
                    risk: .protected,
                    description: "Protected path",
                    defaultSelected: true
                )
            ]
        )
        if RuleValidator.validate(protectedRule).isEmpty {
            failures.append("Rule validator allowed default-selected protected path.")
        }

        let requiredLocalizationKeys = [
            "app.name",
            "scan",
            "move.trash",
            "confirm.message",
            "permission.onboarding.title",
            "distribution.hint",
            "check.updates",
            "update.available.title",
            "distribution.status",
            "signing",
            "quarantine.clear",
            "distribution.hint"
        ]
        for key in requiredLocalizationKeys where !Localizer.allKeys.contains(key) {
            failures.append("Missing localization key: \(key)")
        }

        let localizers = [Localizer(language: .zh), Localizer(language: .en)]
        for localizer in localizers {
            for key in requiredLocalizationKeys where localizer(key) == key {
                failures.append("Localization key returned fallback: \(key)")
            }
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let unsafeTargets = [
            URL(fileURLWithPath: "/System/Applications"),
            home,
            home.appendingPathComponent("Documents")
        ]
        for url in unsafeTargets where PathSafety.protectionReasons(for: url).isEmpty {
            failures.append("Path safety allowed unsafe target: \(url.path)")
        }

        if !PathSafety.protectionReasons(for: home.appendingPathComponent("Downloads/example.zip")).isEmpty {
            failures.append("Path safety blocked a file inside a user folder instead of only the folder root.")
        }

        if !VersionComparator.isNewer("v0.1.10", than: "0.1.2") {
            failures.append("Version comparator did not order v0.1.10 after 0.1.2.")
        }

        if VersionComparator.isNewer("0.1.2", than: "0.1.10") {
            failures.append("Version comparator ordered 0.1.2 after 0.1.10.")
        }

        if failures.isEmpty {
            print("Self-test passed.")
            return 0
        }

        for failure in failures {
            print("Self-test failure: \(failure)")
        }
        return 1
    }
}
