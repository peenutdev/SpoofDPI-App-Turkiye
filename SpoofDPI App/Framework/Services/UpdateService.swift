//
//  UpdateService.swift
//  SpoofDPI App
//
//

import AppKit
import SwiftUI

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
            self.checkAvailability(isManual: false)
        }

        let timer = Timer.scheduledTimer(
            withTimeInterval: Constants.updatesCheckingFrequency,
            repeats: true
        ) { [weak self] _ in
            self?.checkAvailability(isManual: false)
        }

        RunLoop.main.add(timer, forMode: .common)
    }

    func checkAvailability(isManual: Bool) {
        var urlRequest = URLRequest(url: Constants.actualBuildNumberURL)
        urlRequest.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let session = URLSession(configuration: configuration)

        session.dataTask(with: urlRequest) { [weak self] data, _, _ in
            guard
                let self,
                let data,
                let contents = String(data: data, encoding: .utf8)?.trimmingCharacters(
                    in: .whitespacesAndNewlines),
                let latestBuildNumber = Int(contents)
            else {
                return
            }

            DispatchQueue.main.async {
                self.showAlertIfNeeded(latestBuildNumber: latestBuildNumber, isManual: isManual)
            }
        }.resume()
    }

    private func showAlertIfNeeded(latestBuildNumber: Int, isManual: Bool) {
        guard let currentBuildNumber = Bundle.main.buildNumber else {
            return
        }

        let isUpdateAvailable = currentBuildNumber < latestBuildNumber

        if isUpdateAvailable {
            windowService.isMainWindowVisible = true

            let alert = NSAlert()
            typealias Local = LocalizedString.Updates.Alert
            alert.messageText = Local.title(appName: Bundle.main.name)
            alert.informativeText = Local.description
            alert.addButton(withTitle: Local.Buttons.update)
            alert.addButton(withTitle: Local.Buttons.close)
            alert.alertStyle = .warning

            switch alert.runModal() {
            case .alertFirstButtonReturn:
                NSWorkspace.shared.open(Constants.releasesURL)
            default:
                break
            }
        } else if isManual {
            windowService.isMainWindowVisible = true

            let alert = NSAlert()
            typealias Local = LocalizedString.Updates.UpToDate
            alert.messageText = Local.title

            // We don't have the string version anymore with simple check,
            // so we just show the build number or a generic "Up to date"
            let currentVersion =
                Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                ?? ""
            alert.informativeText = Local.description(version: currentVersion)

            alert.addButton(withTitle: Local.Buttons.ok)
            alert.alertStyle = .informational
            alert.runModal()
        }
    }
}
