//
//  Utils.swift
//  SpoofDPI App
//

import Foundation

final class Utils {
    private init() { }
    

    
    static func getDeviceArchitecture() -> SupportedArchitecture {
        #if arch(arm64)
        return .arm
        #else
        return .x64
        #endif
    }
}

enum SupportedArchitecture: String, CaseIterable {
    case arm
    case x64
}
