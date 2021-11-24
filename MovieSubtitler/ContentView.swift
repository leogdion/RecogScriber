//
//  ContentView.swift
//  MovieSubtitler
//
//  Created by Leo Dion on 11/23/21.
//

import SwiftUI
import Speech
import Combine


extension Result {
  init(_ error: Failure?, _ success: Success?, _ neither: @autoclosure () -> Failure) {
    if let error = error {
      self = .failure(error)
    } else if let success = success {
      self = .success(success)
    } else {
      self = .failure(neither())
    }
  }
  
}
enum InternalError : Error {
  case missingRecognizer
  case noResult
}

struct IdentifiableSegment : Identifiable {
  let id : Int
  let content : SFTranscriptionSegment
}

class SpeechRecognizer : ObservableObject {
  @Published var recognizer : SFSpeechRecognizer?
  @Published var result : Result<SFSpeechRecognitionResult, Error>?
  @Published var segments = [IdentifiableSegment]()
  @Published var text : String = ""
  @Published var error : LocalizedError?
  var subject = PassthroughSubject<Void,Never>()
  
  var isPresentingAlert: Binding<Bool> {
          return Binding<Bool>(get: {
              return self.error != nil
          }, set: { newValue in
              guard !newValue else { return }
              self.error = nil
          })
      }
  
  init () {
    subject.flatMap {
      Future { completed in
        SFSpeechRecognizer.requestAuthorization { status in
          completed(.success(status))
        }
      }
    }.compactMap{ status in
      guard status == .authorized else {
        return nil
      }
      return SFSpeechRecognizer()
    }.receive(on: DispatchQueue.main).assign(to: &self.$recognizer)
    
    self.$result.map { result in
      return try? result?.get()
    }.map { result in
      result?.bestTranscription.segments ?? .init()
    }.map{ segments in
      segments.enumerated().map(IdentifiableSegment.init)
    }.receive(on: DispatchQueue.main).assign(to: &self.$segments)
    
    self.$result.map { result in
      guard case let .failure(error) = result else {
        return nil
      }
      
      return error as? LocalizedError
    }.receive(on: DispatchQueue.main).assign(to: &self.$error)
  }
  
  func beginRecognitionAt(_ url: URL) {
    guard let recognizer = self.recognizer else {
      self.result = .failure(InternalError.missingRecognizer)
      return
    }
    let request = SFSpeechURLRecognitionRequest(url: url)
    recognizer.recognitionTask(with: request) { result, error in
      self.result = .init(error, result, InternalError.noResult)
    }
  }
  
  func verifyAuthorization () {
    self.subject.send()
  }
}

extension Alert {
    init(localizedError: LocalizedError) {
        self = Alert(nsError: localizedError as NSError)
    }
     
    init(nsError: NSError) {
        let message: Text? = {
            let message = [nsError.localizedFailureReason, nsError.localizedRecoverySuggestion].compactMap({ $0 }).joined(separator: "\n\n")
            return message.isEmpty ? nil : Text(message)
        }()
        self = Alert(title: Text(nsError.localizedDescription),
                     message: message,
                     dismissButton: .default(Text("OK")))
    }
}

struct ContentView: View {
  @ObservedObject var object = SpeechRecognizer()
  @State var isOpening : Bool = false
    var body: some View {
      VStack{
        Button("Open file") {
          DispatchQueue.main.async {
            isOpening = true
          }
        }
        List(self.object.segments) { segment in
          HStack{
            Text("\(segment.content.timestamp)")
            Text("\(segment.content.alternativeSubstrings.count)")
            Text("\(segment.content.confidence)")
            Text(segment.content.substring)
          }
        }
      }.padding(20.0).fileImporter(isPresented: self.$isOpening, allowedContentTypes: [.audio, .movie]) { result in
        if let url = try? result.get() {
          self.object.beginRecognitionAt(url)
        }
      }.disabled(self.object.recognizer == nil)
        .onAppear(perform: self.object.verifyAuthorization)
        .alert(isPresented: object.isPresentingAlert, content: {
                    Alert(localizedError: object.error!)
                })
      
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
