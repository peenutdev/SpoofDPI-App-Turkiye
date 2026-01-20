//
//  MainScene.swift
//  SpoofDPI App
//

import SwiftUI

struct MainScene: Scene {
    private typealias LocalizedString = SpoofDPI_App.LocalizedString.Scene.Main
    
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var updateService = UpdateService.instance
    
    private let id = String(describing: MainScene.self)
    
    var body: some Scene {
        let appName = Bundle.main.name
        
        return Group {
            Window(appName, id: id) {
                ContentView()
            }
            .defaultPosition(.center)
            .windowResizability(.contentSize)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(
                    LocalizedString.MenuBar.aboutButton(appName: appName)
                ) {
                    openAboutWindow()
                }
                
                Button(LocalizedString.MenuBar.updatesButton) {
                    updateService.checkAvailability()
                }
            }
            
            CommandGroup(replacing: .windowSize) { }
            
            CommandGroup(replacing: .help) {
                Button(LocalizedString.MenuBar.repositoryButton) {
                    NSWorkspace.shared.open(Constants.repositoryURL)
                }
            }
        }
    }
    
    private func openAboutWindow() {
        let creditsAttributedString = NSMutableAttributedString()
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        
        let firstLink = LocalizedString.AboutWindow.repositoryButton
        
        [firstLink]
            .map {
                let attributes: [NSAttributedString.Key: Any] = [
                    .paragraphStyle: paragraphStyle,
                    .underlineColor: NSColor.clear,
                    .link: Constants.repositoryURL
                ]
                
                return NSAttributedString(string: $0, attributes: attributes)
            }.forEach {
                creditsAttributedString.append($0)
            }
        
        NSApplication.shared.orderFrontStandardAboutPanel(
            options: [
                .credits: creditsAttributedString,
                .version: Constants.libraryVersion
            ]
        )
    }
}
