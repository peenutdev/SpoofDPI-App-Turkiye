//
//  UpdateService.swift
//  SpoofDPI App
//
//

import AppKit
import SwiftUI

#if canImport(Sparkle)
    import Sparkle
#endif

final class UpdateService: NSObject, ObservableObject {
    static let instance = UpdateService()

    private lazy var settingsService = SettingsService.instance
    private lazy var windowService = WindowService.instance

    #if canImport(Sparkle)
        private var updaterController: SPUStandardUpdaterController!
    #endif

    override init() {
        super.init()
        #if canImport(Sparkle)
            let controller = SPUStandardUpdaterController(
                startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
            self.updaterController = controller
        #else
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
        #endif
    }

    func checkAvailability() {
        #if canImport(Sparkle)
            updaterController.checkForUpdates(nil)
        #else
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 10

            let session = URLSession(configuration: configuration)

            session.dataTask(with: Constants.actualBuildNumberURL) { [weak self] data, _, _ in
                guard
                    let self,
                    let data,
                    let text = String(data: data, encoding: .utf8),
                    let actualBuildNumber = Int(
                        text.trimmingCharacters(in: .whitespacesAndNewlines))
                else {
                    return
                }

                DispatchQueue.main.async {
                    self.settingsService.latestKnownActualBuildNumber = actualBuildNumber
                    self.showAlertIfNeeded()
                }
            }.resume()
        #endif
    }

    #if !canImport(Sparkle)
        private func showAlertIfNeeded() {
            guard
                let currentBuildNumber = Bundle.main.buildNumber,
                currentBuildNumber < settingsService.latestKnownActualBuildNumber
            else {
                return
            }

            windowService.isMainWindowVisible = true

            let alert = NSAlert().with {
                typealias LocalizedString = SpoofDPI_App.LocalizedString.Updates.Alert

                $0.messageText = LocalizedString.title(appName: Bundle.main.name)
                $0.informativeText = LocalizedString.description

                $0.addButton(withTitle: LocalizedString.Buttons.update)
                $0.addButton(withTitle: LocalizedString.Buttons.close)

                $0.alertStyle = .warning
            }

            switch alert.runModal() {
            case .alertFirstButtonReturn:
                NSWorkspace.shared.open(Constants.repositoryURL)

            default:
                break
            }
        }
    #endif
}

#if canImport(Sparkle)
    extension UpdateService: SPUUpdaterDelegate {
        func feedURLString(for updater: SPUUpdater) -> String? {
            return Constants.appcastURL.absoluteString
        }
    }
#endif
