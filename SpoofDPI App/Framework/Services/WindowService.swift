//
//  WindowService.swift
//  SpoofDPI App
//

import AppKit
import Combine

final class WindowService {
    static let instance = WindowService()

    private var mainWindow: NSWindow? {
        NSApp.windows.first { $0.hasCloseBox && $0.title == Bundle.main.name }
            ?? NSApp.windows.first
    }

    private var mainWindowVisibilityObservation: NSKeyValueObservation?
    private var isDockIconEnabledObservation: AnyCancellable?

    private init() {
        setupObservationIfPossible()

        isDockIconEnabledObservation = SettingsService.instance.$isDockIconEnabled.sink {
            [weak self] _ in
            self?.updateActivationPolicy()
        }
    }

    private func setupObservationIfPossible() {
        guard let window = mainWindow, mainWindowVisibilityObservation == nil else {
            // Try again later if window is missing
            if mainWindowVisibilityObservation == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.setupObservationIfPossible()
                }
            }
            return
        }

        mainWindowVisibilityObservation = window.observe(\.isVisible, options: [.initial, .new]) {
            [weak self] _, _ in
            self?.updateActivationPolicy()
        }
    }

    private func updateActivationPolicy() {
        DispatchQueue.main.async {
            let isVisible = self.mainWindow?.isVisible ?? false
            let isDockEnabled = SettingsService.instance.isDockIconEnabled

            // Show dock icon if explicitly enabled OR if window is visible
            let shouldShowDock = isDockEnabled || isVisible
            NSApp.setActivationPolicy(shouldShowDock ? .regular : .accessory)

            if isVisible {
                NSApp.activate(ignoringOtherApps: true)
            } else {
                NSApp.windows
                    .filter { $0 != self.mainWindow && $0.hasCloseBox }
                    .forEach { $0.setIsVisible(false) }
            }
        }
    }

    var isMainWindowVisible: Bool {
        get {
            mainWindow?.isVisible ?? false
        }
        set {
            if let window = mainWindow {
                window.setIsVisible(newValue)
            } else {
                // If window doesn't exist yet and we want to show it,
                // it's likely SwiftUI will create it soon.
                // If we want to hide it, it might not even have been shown yet.
            }
        }
    }
}
