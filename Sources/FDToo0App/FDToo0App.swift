//
//  FDToo0App.swift
//  FD_too0 — Joe SmoLLey 3D Spatial Deck (FLipPing Dice + AxLe Yahtzee + HoLy SmoLLey + z404 M00N Buggy)
//
//  Gravity Wizards, Inc. / akapps / Twisted23 Heritage
//

import SwiftUI

@main
struct FDToo0App: App {
    var body: some Scene {
        WindowGroup("FD_too0 • Joe SmoLLey 3D Spatial Deck") {
            FDToo0RootView()
                #if os(macOS)
                .frame(minWidth: 520, minHeight: 740)
                #endif
        }
    }
}
