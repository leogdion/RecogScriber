//
//  SubtitlerApp.swift
//  Subtitler
//
//  Created by Leo Dion on 11/23/21.
//

import SwiftUI

@main
struct SubtitlerApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: SubtitlerDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
