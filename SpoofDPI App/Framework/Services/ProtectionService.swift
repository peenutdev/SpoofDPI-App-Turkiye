//
//  ProtectionService.swift
//  SpoofDPI App
//

import Combine
import Foundation
import Network
import SwiftUI

class ProtectionService: ObservableObject {
    static let instance = ProtectionService()

    @Published private(set) var status = Status.unknown

    private lazy var settingsService = SettingsService.instance

    private var isEnabledObservation: AnyCancellable?
    private var libraryParametersObservation: AnyCancellable?

    private var libraryProcess: Process?

    private var pathMonitor: NWPathMonitor?
    private var isPausedByVPN = false

    private init() {
        guard !ProcessInfo.isPreview else {
            return
        }

        killAllExistingProcesses()

        if settingsService.isProtectionEnabled {
            startLibrary()
        } else {
            status = .stopped
        }

        isEnabledObservation = settingsService.$isProtectionEnabled.sink { [weak self] isEnabled in
            guard let self else { return }

            if isEnabled {
                self.startLibrary()
            } else {
                self.stopLibrary()
            }
        }

        libraryParametersObservation = settingsService.$libraryParameters.sink { [weak self] _ in
            guard let self else { return }

            if self.status == .active || self.settingsService.isProtectionEnabled {
                self.restartLibrary()
            }
        }

        startPathMonitor()
    }

    func prepareForTermination() {
        stopLibrary(waitUntilExit: true)
    }

    private func restartLibrary() {
        stopLibrary()
        DispatchQueue.main.async {
            self.startLibrary()
        }
    }

    private func startLibrary() {
        if isPausedByVPN { return }

        stopLibrary()
        self.status = .initializing

        let deviceArchitecture = Utils.getDeviceArchitecture()

        guard
            let executablePath = Bundle.main.path(
                forResource: Constants.libraryProcessNamePrefix + deviceArchitecture.rawValue,
                ofType: ""
            )
        else {
            self.status = .stopped
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)

        let parameters = settingsService.libraryParameters
        process.arguments = parameters.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if self.libraryProcess === process {
                    self.libraryProcess = nil
                    if self.status == .active {
                        self.status = .stopped

                        // Add a small delay before restarting to prevent battery drain during crash loops
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            if self.settingsService.isProtectionEnabled {
                                self.startLibrary()
                            }
                        }
                    } else {
                        self.status = .stopped
                    }
                }
            }
        }

        do {
            try process.run()
            self.libraryProcess = process
            self.status = .active
        } catch {
            self.status = .stopped
        }
    }

    private func stopLibrary(waitUntilExit: Bool = false) {
        status = .stopped

        if let process = libraryProcess {
            process.interrupt()

            if waitUntilExit {
                process.waitUntilExit()
            }
        }
        libraryProcess = nil
        disableSystemProxy(waitUntilExit: waitUntilExit)
    }

    private func killAllExistingProcesses() {
        SupportedArchitecture.allCases.forEach {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            process.arguments = [Constants.libraryProcessNamePrefix + $0.rawValue]
            try? process.run()
            process.waitUntilExit()
        }

        disableSystemProxy()
    }

    private func startPathMonitor() {
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self = self else { return }

                // Detailed VPN detection:
                // 1. Most VPNs use utun, ipsec, or ppp interfaces
                // 2. path.isScoped is often true when a VPN is active
                let vpnInterfaceNames = ["utun", "ipsec", "ppp"]
                let hasVPNInterface = path.availableInterfaces.contains { interface in
                    vpnInterfaceNames.contains { name in interface.name.lowercased().hasPrefix(name)
                    }
                }

                let isVPNActive = hasVPNInterface
                let shouldPause = self.settingsService.isVPNSensitivityEnabled && isVPNActive

                if shouldPause && !self.isPausedByVPN {
                    self.isPausedByVPN = true
                    if self.status == .active || self.status == .initializing {
                        self.stopLibrary()
                        self.status = .pausedByVPN
                    }
                } else if !isVPNActive && self.isPausedByVPN {
                    self.isPausedByVPN = false
                    if self.settingsService.isProtectionEnabled {
                        self.status = .initializing
                        self.startLibrary()
                    } else {
                        self.status = .stopped
                    }
                }
            }
        }
        pathMonitor?.start(queue: .global(qos: .background))
    }

    private func disableSystemProxy(waitUntilExit: Bool = false) {
        let script =
            "networksetup -listallnetworkservices | tail -n +2 | sed 's/^\\*//' | while read service; do networksetup -setwebproxystate \"$service\" off; networksetup -setsecurewebproxystate \"$service\" off; done"

        let execute = {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/bash")
            process.arguments = ["-c", script]
            try? process.run()
            process.waitUntilExit()
        }

        if waitUntilExit {
            execute()
        } else {
            DispatchQueue.global(qos: .userInitiated).async(execute: execute)
        }
    }
}

extension ProtectionService {
    enum Status {
        case active
        case initializing
        case stopped
        case pausedByVPN

        case unknown
    }
}
