import Foundation
import SwiftUI
import Combine
import AVFoundation
import WhisperKit

@MainActor
class AudioRecorder: ObservableObject {
    var audioRecorder: AVAudioRecorder!
    let modelStorage: String = "huggingface/models/argmaxinc/whisperkit-coreml"
    var localModelPath: String = ""
    var localModels: [String] = []
    var pipe: WhisperKit? = nil
    var folder: URL? = nil

    @AppStorage("repoName") private var repoName: String = "argmaxinc/whisperkit-coreml"
    @AppStorage("downloadCompleted") var downloadCompleted: Bool = false
    
    @Published var downloadProgress: Double = 0
    @Published var recording = false
    @Published var transcriptionText: String? = nil
    @Published var showPermissionAlert: Bool = false
    @Published var transcribing: Bool = false
    
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
    }
    
    func downloadAndPrepareModel() async throws {
        if !downloadCompleted {
            folder = try await WhisperKit.download(variant: "large-v3", from: repoName, progressCallback: { progress in
                DispatchQueue.main.async {
                    self.downloadProgress = progress.fractionCompleted
                }
            })
            try await fetchModels()
        }
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
            guard let transcription: [TranscriptionResult] = try await pipe?.transcribe(audioPath: audioPath) else {
                print("Failed to transcribe text from audio in WhisperKit")
                transcribing = false
                return
            }
            
            for result in transcription {
                if let unwrappedTranscriptionText = transcriptionText {
                    transcriptionText = unwrappedTranscriptionText + result.text
                } else {
                    transcriptionText = result.text
                }
            }
            transcribing = false
            
        } catch {
            print("An error has occurred while stopping recording! \(error)")
            transcribing = false
        }
    }
    
    func fetchModels() async throws {
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let modelPath = documents.appendingPathComponent(modelStorage).path
            let largeModelPath = modelPath.appending("/openai_whisper-large-v3/")
            let filesToCheck = ["AudioEncoder.mlmodelc", "MelSpectrogram.mlmodelc", "TextDecoder.mlmodelc", "config.json", "generation_config.json"]

            if FileManager.default.fileExists(atPath: modelPath) {
                do {
                    localModelPath = modelPath
                    let downloadedModels = try FileManager.default.contentsOfDirectory(atPath: modelPath)
                    for model in downloadedModels where !localModels.contains(model) {
                        localModels.append(model)
                    }
                    
                    var filesFound = 0
                    for file in filesToCheck {
                        let filePath = largeModelPath.appending(file)
                        if FileManager.default.fileExists(atPath: filePath) {
                            filesFound += 1
                        }
                    }
                    if filesFound == filesToCheck.count {
                        downloadCompleted = true
                    }
                } catch {
                    print("Error enumerating files at \(modelPath): \(error.localizedDescription)")
                }
            }
        }
        
        localModels = WhisperKit.formatModelFiles(localModels)
        
        folder = URL(fileURLWithPath: localModelPath).appendingPathComponent("openai_whisper-large-v3")
        if let modelFolder = folder {
            pipe?.modelFolder = modelFolder
            try await pipe?.prewarmModels()
        }

        try await pipe?.loadModels()
    }

    
    init() {
        Task {
            do {
                try await initializePipe()
            } catch {
                print("Error initializing WhisperKit pipe! \(error.localizedDescription)")
            }
        }
    }
}
