//
//  Bundle.swift
//  SpoofDPI App
//

import Foundation

extension Bundle {
    public var name: String {
        return infoDictionary?[kCFBundleNameKey as String] as? String ?? ""
    }

    public var buildNumber: Int? {
        guard let string = infoDictionary?[kCFBundleVersionKey as String] as? String else {
            return nil
        }

        return .init(string)
    }
}
