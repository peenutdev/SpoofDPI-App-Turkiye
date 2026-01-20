//
//  ProtectionService.swift
//  SpoofDPI App
//

import Foundation
import Combine

class ProtectionService: ObservableObject {
    static let instance = ProtectionService()
    
    @Published private(set) var status = Status.unknown
    
    private lazy var settingsService = SettingsService.instance
    
    private var isEnabledObservation: AnyCancellable?
    private var libraryParametersObservation: AnyCancellable?
    
    private var libraryProcess: Process?
    
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
                        self.startLibrary()
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
    }
    
    private func killAllExistingProcesses() {
        SupportedArchitecture.allCases.forEach {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            process.arguments = [Constants.libraryProcessNamePrefix + $0.rawValue]
            try? process.run()
            process.waitUntilExit()
        }
    }
}

extension ProtectionService {
    enum Status {
        case active
        case initializing
        case stopped
        
        case unknown
    }
}
