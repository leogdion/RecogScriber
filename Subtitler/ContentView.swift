//
//  ContentView.swift
//  Subtitler
//
//  Created by Leo Dion on 11/23/21.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: SubtitlerDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(document: .constant(SubtitlerDocument()))
    }
}
