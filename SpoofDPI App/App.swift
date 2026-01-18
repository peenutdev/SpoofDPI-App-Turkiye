//
//  App.swift
//  SpoofDPI App
//
import SwiftUI

@main
struct App: SwiftUI.App {
    @NSApplicationDelegateAdaptor(Delegate.self) private var delegate

    var body: some Scene {
        MainScene()
    }
}

extension App {
    fileprivate final class Delegate: NSObject, NSApplicationDelegate {
        func applicationDidFinishLaunching(_ notification: Notification) {

            DispatchQueue.main.async {
                _ = AutoLaunchService.instance
                _ = MenuBarIconService.instance
                _ = ProtectionService.instance
                _ = UpdateService.instance
                _ = WindowService.instance
            }
        }

        func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
            return false
        }

        func applicationWillTerminate(_ notification: Notification) {
            ProtectionService.instance.prepareForTermination()
        }
    }
}
