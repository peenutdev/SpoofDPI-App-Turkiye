//
//  UpdateService.swift
//  SpoofDPI App
//

import AppKit

final class UpdateService: ObservableObject {
    static let instance = UpdateService()
    
    private lazy var settingsService = SettingsService.instance
    private lazy var windowService = WindowService.instance
    
    private init() {
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
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        
        let session = URLSession(configuration: configuration)
        
        session.dataTask(with: Constants.actualBuildNumberURL) { [weak self] data, _, _ in
            guard
                let self,
                let data,
                let text = String(data: data, encoding: .utf8),
                let actualBuildNumber = Int(text.trimmingCharacters(in: .whitespacesAndNewlines))
            else {
                return
            }
            
            DispatchQueue.main.async {
                self.settingsService.latestKnownActualBuildNumber = actualBuildNumber
                self.showAlertIfNeeded()
            }
        }.resume()
    }
    
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
}
