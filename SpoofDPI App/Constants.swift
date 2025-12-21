//
//  Constants.swift
//  SpoofDPI App
//

import Foundation

enum Constants {
    static let defaultLanguage = Locale.SupportedLanguage.turkish
    static let updatesCheckingFrequency: TimeInterval = 259200 // 3 days
    
    static let repositoryURL = URL(string: "https://github.com/renardev/SpoofDPI-Turkiye")!
    static let actualBuildNumberURL = URL(string: "https://raw.githubusercontent.com/SpoofDPIApp/SpoofDPI-App/main/Other/ActualBuildNumber.txt")!
    
    static let supportEmailAddress = "SpoofDPIApp@proton.me"
    static let supportEmailURL = URL(string: "mailto:" + supportEmailAddress)!
    
    static let libraryProcessNamePrefix = "spoofdpi-"
    static let libraryVersion = "0.12.0-TR"
    static let libraryParameters = "-dns-addr 77.88.8.8 -dns-port 1253 -window-size 5"
}
