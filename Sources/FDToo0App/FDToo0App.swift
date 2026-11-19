//
//  FDToo0App.swift
//  FD_too0 — Joe SmoLLey 3D Spatial Deck (FLipPing Dice + AxLe Yahtzee + HoLy SmoLLey + z404 M00N Buggy)
//
//  Gravity Wizards, Inc. / akapps / Twisted23 Heritage
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct FDToo0App: App {
    init() {
        #if os(macOS)
        NSApplication.shared.setActivationPolicy(.regular)
        #endif
    }

    var body: some Scene {
        WindowGroup("FD_too0 • Joe SmoLLey 3D Spatial Deck") {
            FDToo0RootView()
                #if os(macOS)
                .frame(minWidth: 520, minHeight: 740)
                .onAppear {
                    NSApplication.shared.activate()
                }
                #endif
        }
    }
}
