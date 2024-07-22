import Foundation
import SwiftUI
import Combine
import AVFoundation
import WhisperKit

@MainActor
class AudioRecorder: ObservableObject {
    let objectWillChange = PassthroughSubject<AudioRecorder, Never>()
    var audioRecorder: AVAudioRecorder!
    let modelStorage: String = "huggingface/models/argmaxinc/whisperkit-coreml"
    var localModelPath: String = ""
    var localModels: [String] = []
    var pipe: WhisperKit? = nil
    
    @AppStorage("selectedModel") private var selectedModel: String = WhisperKit.recommendedModels().default
    @AppStorage("repoName") private var repoName: String = "argmaxinc/whisperkit-coreml"
    
    var recording = false {
        didSet {
            objectWillChange.send(self)
        }
    }
    
    var transcriptionText: String? = nil {
        didSet {
            objectWillChange.send(self)
        }
    }
    
    var showPermissionAlert: Bool = false {
        didSet {
            objectWillChange.send(self)
        }
    }
    
    var transcribing: Bool = false {
        didSet {
            objectWillChange.send(self)
        }
    }
    
    func getMicrophonePermission() async {
        let status = AVAudioApplication.shared.recordPermission
        switch status {
        case .granted:
            showPermissionAlert = false
        case .denied:
            showPermissionAlert = true
        case .undetermined:
            if await AVAudioApplication.requestRecordPermission() {
                self.showPermissionAlert = false
            } else {
                self.showPermissionAlert = true
            }
        @unknown default:
            break
        }
    }
    
    func initializePipe() async throws {
        pipe = try await WhisperKit(
            prewarm: false,
            load: false,
            download: false
        )
        
        var folder: URL?
        // Check if the model is available locally
        if localModels.contains("large-v3") { // The string to check if a model is contained needs to be changed
            // Get local model folder URL from localModels
            // TODO: Make this configurable in the UI
            folder = URL(fileURLWithPath: localModelPath).appendingPathComponent("large-v3")
        } else {
            // Download the model
            folder = try await WhisperKit.download(variant: "large-v3", from: repoName, progressCallback: { progress in
                print(progress)
            })
        } 

        
        if let modelFolder = folder {

            pipe?.modelFolder = modelFolder
            
            try await pipe?.prewarmModels()
        }
        
        // Prewarm models before transcription
        try await pipe?.loadModels()

    }
    
    func startRecording() async {
        let status = AVAudioApplication.shared.recordPermission
        guard status == .granted else {
            await getMicrophonePermission()
            return
        }
        let recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
        } catch {
            print("Failed to set up recording session")
            return
        }
        
        let docPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFileName = docPath.appendingPathComponent("audio.m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFileName, settings: settings)
            audioRecorder.record()
            recording = true
        } catch {
            print("Couldn't initialize audioRecorder")
            return
        }
    }
    
    func stopRecording() async {
        do {
            let status = AVAudioApplication.shared.recordPermission
            guard status == .granted else {
                await getMicrophonePermission()
                return
            }
            audioRecorder.stop()
            recording = false
            transcribing = true
            
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("Could not access documents directory")
                transcribing = false
                return
            }
            
            let audioURL = documentsDirectory.appendingPathComponent("audio.m4a")
            let audioPath = audioURL.path(percentEncoded: true)
            guard let transcription = try await pipe?.transcribe(audioPath: audioPath) else {
                print("Failed to transcribe text from audio in WhisperKit")
                transcribing = false
                return
            }
            
            transcriptionText = transcription.text
            transcribing = false
            
        } catch {
            print("An error has occurred! \(error)")
            transcribing = false
        }
    }
    
    func fetchModels() {
        // First check what's already downloaded
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let modelPath = documents.appendingPathComponent(modelStorage).path
            
            // Check if the directory exists
            if FileManager.default.fileExists(atPath: modelPath) {
                do {
                    localModelPath = modelPath
                    let downloadedModels = try FileManager.default.contentsOfDirectory(atPath: modelPath)
                    for model in downloadedModels where !localModels.contains(model) {
                        localModels.append(model)
                    }
                } catch {
                    print("Error enumerating files at \(modelPath): \(error.localizedDescription)")
                }
            }
        }
        
        localModels = WhisperKit.formatModelFiles(localModels)
        
        print("Found locally: \(localModels)")
        
        //Task {
        //    let remoteModels = try await WhisperKit.fetchAvailableModels(from: repoName)
        //}
    }
    
    init() {
        self.fetchModels()
        Task {
            do {
                try await self.initializePipe()
            } catch {
                print("Error initializing WhisperKit pipe! \(error.localizedDescription)")
            }
        }
    }
}
