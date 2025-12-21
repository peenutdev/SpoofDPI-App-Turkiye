//
//  Locale.swift
//  SpoofDPI App
//

import Foundation

extension Locale {
    static func getSupportedLanguage() -> SupportedLanguage {
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
    
    enum SupportedLanguage {
        case turkish
    }
}
