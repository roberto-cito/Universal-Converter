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
                // Aumentiamo l'altezza fissa da 300 a 400 per accomodare i nuovi bottoni e messaggi
                .frame(width: 400, height: 400)
        }
        .windowResizability(.contentSize)
        .commands{
            CommandGroup(replacing: .windowSize) {}
        }
    }
}
