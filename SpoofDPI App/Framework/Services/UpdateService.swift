//
//  UpdateService.swift
//  SpoofDPI App
//
//

import AppKit
import SwiftUI

struct AppcastItem {
    let shortVersionString: String
    let version: Int
    let downloadURL: URL
    let releaseNotes: String
}

final class UpdateService: NSObject, ObservableObject {
    static let instance = UpdateService()

    private lazy var settingsService = SettingsService.instance
    private lazy var windowService = WindowService.instance

    override init() {
        super.init()
        
        guard !ProcessInfo.isPreview else {
            return
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 1
        ) {
            self.checkAvailability()
        }

        let timer = Timer.scheduledTimer(
            withTimeInterval: Constants.updatesCheckingFrequency,
            repeats: true
        ) { [weak self] _ in
            self?.checkAvailability()
        }

        RunLoop.main.add(timer, forMode: .common)
    }

    func checkAvailability() {
        var urlRequest = URLRequest(url: Constants.appcastURL)
        urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let session = URLSession(configuration: configuration)

        session.dataTask(with: urlRequest) { [weak self] data, _, _ in
            guard
                let self,
                let data,
                let latestItem = self.parseAppcast(data)
            else {
                return
            }

            DispatchQueue.main.async {
                self.showAlertIfNeeded(with: latestItem)
            }
        }.resume()
    }

    private func parseAppcast(_ data: Data) -> AppcastItem? {
        let parser = XMLParser(data: data)
        let delegate = AppcastXMLDelegate()
        parser.delegate = delegate
        parser.parse()
        return delegate.latestItem
    }

    private func showAlertIfNeeded(with item: AppcastItem) {
        guard let currentBuildNumber = Bundle.main.buildNumber else {
            return
        }

        windowService.isMainWindowVisible = true

        let isUpdateAvailable = currentBuildNumber < item.version
        
        let alert = NSAlert().with {
            if isUpdateAvailable {
                typealias LocalizedString = SpoofDPI_App.LocalizedString.Updates.Alert
                $0.messageText = LocalizedString.title(appName: Bundle.main.name)
                $0.informativeText = LocalizedString.description
                $0.addButton(withTitle: LocalizedString.Buttons.update)
                $0.addButton(withTitle: LocalizedString.Buttons.close)
                $0.alertStyle = .warning
            } else {
                typealias LocalizedString = SpoofDPI_App.LocalizedString.Updates.UpToDate
                $0.messageText = LocalizedString.title
                $0.informativeText = LocalizedString.description(version: item.shortVersionString)
                $0.addButton(withTitle: LocalizedString.Buttons.ok)
                $0.alertStyle = .informational
            }
        }

        if isUpdateAvailable {
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                NSWorkspace.shared.open(Constants.releasesURL)
            default:
                break
            }
        } else {
            alert.runModal()
        }
    }
}

private class AppcastXMLDelegate: NSObject, XMLParserDelegate {
    var latestItem: AppcastItem?
    private var currentElement = ""
    private var shortVersionString = ""
    private var version = 0
    private var downloadURL: URL?
    private var releaseNotes = ""
    private var foundFirstItem = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String] = [:]
    ) {
        currentElement = elementName
        
        if elementName == "enclosure", let urlString = attributeDict["url"] {
            downloadURL = URL(string: urlString)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        switch currentElement {
        case "sparkle:shortVersionString", "shortVersionString":
            shortVersionString = trimmed
        case "sparkle:version", "version":
            version = Int(trimmed) ?? 0
        case "description":
            releaseNotes = trimmed
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "item", !foundFirstItem, let downloadURL = downloadURL, version > 0 {
            latestItem = AppcastItem(
                shortVersionString: shortVersionString,
                version: version,
                downloadURL: downloadURL,
                releaseNotes: releaseNotes
            )
            foundFirstItem = true
            
            shortVersionString = ""
            version = 0
            self.downloadURL = nil
            releaseNotes = ""
        }
    }
}
