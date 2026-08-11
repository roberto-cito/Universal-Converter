//
//  UniversalCoverterApp.swift
//  UniversalCoverter
//
//  Created by Roberto Cito on 11/08/2026.
//

import SwiftUI

@main
struct UniversalCoverterApp: App {
    var body: some Scene {
        WindowGroup {
            FileDropZoneView()
                .frame(width: 400, height: 300)
        }
        .windowResizability(.contentSize)
        .commands{
            CommandGroup(replacing: .windowSize) {}
        }
    }
}
