import Foundation
import AVFoundation

class AudioPlayer {
    var player: AVPlayer?

    func startAudio() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsDirectory.appendingPathComponent("audio.m4a")
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            print("Audio file does not exist at the specified path")
            return
        }
        
        player = AVPlayer(url: audioURL)
        player?.play()
    }
    
    func stopAudio() {
        player?.replaceCurrentItem(with: nil)
    }
}
