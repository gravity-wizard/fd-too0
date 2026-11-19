//
//  FDToo0App.swift
//  FD_too0 — Joe SmoLLey 3D Spatial Deck (FLipPing Dice + AxLe Yahtzee + HoLy SmoLLey + z404 M00N Buggy)
//
//  Gravity Wizards, Inc. / akapps / Twisted23 Heritage
//

import SwiftUI

#if os(macOS)
import AppKit

@MainActor
final class MacAppBootstrapDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menuBar = NSMenu()
        let appMenuItem = NSMenuItem()
        menuBar.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Quit FD_too0",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        NSApplication.shared.mainMenu = menuBar

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 840),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "FD_too0 • Joe SmoLLey 3D Spatial Deck"
        window.minSize = NSSize(width: 540, height: 740)
        window.contentViewController = NSHostingController(rootView: FDToo0RootView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.mainWindow = window

        NSApplication.shared.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct FDToo0App {
    @MainActor
    private static var retainedDelegate: MacAppBootstrapDelegate?

    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = MacAppBootstrapDelegate()
        retainedDelegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
#else
@main
struct FDToo0App: App {
    var body: some Scene {
        WindowGroup("FD_too0 • Joe SmoLLey 3D Spatial Deck") {
            FDToo0RootView()
        }
    }
}
#endif
