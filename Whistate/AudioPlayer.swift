import Foundation
import AVFoundation

class AudioPlayer {
    var player: AVPlayer?

    func startAudio() {
        let recordingSession = AVAudioSession.sharedInstance()
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsDirectory.appendingPathComponent("audio.m4a")
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("Audio file does not exist at the specified path")
            return
        }

        do {
            try recordingSession.setCategory(.playback, mode: .default)
            try recordingSession.setActive(true)
            
            player = AVPlayer(url: audioURL)
            player?.play()
        } catch {
            print("Failed to set up playback session")
            return
        }
        
        
    }
    
    func stopAudio() {
        player?.replaceCurrentItem(with: nil)
    }
}
