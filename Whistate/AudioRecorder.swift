import Foundation
import SwiftUI
import Combine
import AVFoundation
import WhisperKit

@MainActor
class AudioRecorder: ObservableObject {
    let objectWillChange = PassthroughSubject<AudioRecorder, Never>()
    var audioRecorder: AVAudioRecorder!
    
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
            
            let pipe = try await WhisperKit()
            
            guard let transcription = try await pipe.transcribe(audioPath: audioPath)?.text else {
                print("Failed to transcribe text from audio in WhisperKit")
                transcribing = false
                return
            }
            
            transcriptionText = transcription
            transcribing = false
            
        } catch {
            print("An error has occurred! \(error)")
            transcribing = false
        }
    }
}
