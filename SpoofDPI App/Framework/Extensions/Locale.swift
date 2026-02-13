//
//  Locale.swift
//  SpoofDPI App
//
//

import Foundation

extension Locale {
    public static func getSupportedLanguage() -> SupportedLanguage {
        let codes: [String: SupportedLanguage] = [
            "tr": .turkish
        ]

        return preferredLanguages.compactMap {
            let code = String(
                $0.prefix(2)
            )

            return codes[code]
        }.first ?? Constants.defaultLanguage
    }

    public enum SupportedLanguage {
        case turkish
    }
}
