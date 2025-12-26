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
        
        // Clean cleanup of potentially orphaned processes from previous runs
        killAllExistingProcesses()
        
        // Initial state check
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
        
        // Give a brief moment for cleanup/file handles to release if necessary
        DispatchQueue.main.async {
            self.startLibrary()
        }
    }
    
    private func startLibrary() {
        // Ensure we don't start multiple instances
        stopLibrary()
        
        self.status = .initializing
        
        let deviceArchitecture = Utils.getDeviceArchitecture()
        
        guard
            let executablePath = Bundle.main.path(
                forResource: Constants.libraryProcessNamePrefix + deviceArchitecture.rawValue,
                ofType: ""
            )
        else {
            print("Error: Could not find library executable.")
            self.status = .stopped
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        
        // Parse parameters: Split by whitespace and remove empty strings
        let parameters = settingsService.libraryParameters
        process.arguments = parameters.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // If the process that terminated is the one we are currently managing
                if self.libraryProcess === process {
                    self.libraryProcess = nil
                    
                    // If protection should be enabled but the process died (crash/external kill)
                    // We interpret a non-zero exit code or unexpected nil as a crash if we didn't intend to stop.
                    // However, `stopLibrary` clears `libraryProcess` before killing, so if we are here and `libraryProcess` was matched (or passed in closure),
                    // it implies an external termination.
                    // Actually, if we call terminate(), the handler is called.
                    // We need to differentiate intentional stop vs crash.
                    // But for now, if status matches .stopped (set by stopLibrary), we are good.
                    // If status is .active, it was a crash.
                    
                    if self.status == .active {
                        print("Process terminated unexpectedly. Restarting...")
                        self.status = .stopped
                        // Optional: Add a backoff delay here to prevent rapid restart loops on persistent failure
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
            print("Failed to launch process: \(error)")
            self.status = .stopped
        }
    }
    
    private func stopLibrary(waitUntilExit: Bool = false) {
        // Update status first so terminationHandler knows it was intentional
        status = .stopped
        
        if let process = libraryProcess {
            // Send SIGINT (interrupt) instead of SIGTERM (terminate) to let the tool run its cleanup handlers (proxy reset)
            process.interrupt()
            
            if waitUntilExit {
                process.waitUntilExit()
            }
            
            // We do not set libraryProcess to nil here immediately because we want to identify it in the terminationHandler
            // effectively 'ignoring' the restart logic.
        }
        libraryProcess = nil
    }
    
    private func killAllExistingProcesses() {
        // Just a safety cleanup for any orphaned processes from before the app update
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
