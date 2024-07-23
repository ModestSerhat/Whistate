// Code edited from https://gist.github.com/bfolkens/d5749c28830f02aadbf688ebe84fa6b7

import SwiftUI

struct MainView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @ObservedObject var audioRecorder: AudioRecorder = AudioRecorder()
    var audioPlayer: AudioPlayer = AudioPlayer()
    
    @State var borderSpacing: CGFloat = 7.5
    @State var stoppedStateCornerRadius: CGFloat = 0.10
    @State var stoppedStateSize: CGFloat = 0.5
    @State var audioPlaying = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(colorScheme == .dark ? .white : .gray, lineWidth: 2)
                    ScrollView {
                        Text(audioRecorder.transcribing ? "Transcribing..." : (audioRecorder.transcriptionText ?? "Record an audio to have it transcribed!"))
                    }.padding(9)
                }.frame(height: geometry.size.height * 8/10)
                Spacer()
                HStack {
                    Toggle(isOn: $audioPlaying) {
                        Image(systemName: audioPlaying ? "stop.fill" : "play.fill").resizable().frame(width: geometry.size.height/12.5, height: geometry.size.height/12.5)
                    }
                    .toggleStyle(.button)
                    .labelStyle(.iconOnly)
                    .tint(.blue)
                    .onChange(of: audioPlaying) { _, newValue in
                        if newValue {
                            audioPlayer.startAudio()
                        } else {
                            audioPlayer.stopAudio()
                        }
                    }.frame(width: geometry.size.height/10, height: geometry.size.height/10)
                    GeometryReader { recordButtonGeometry in
                        ZStack {
                            Circle()
                                .stroke(colorScheme == .dark ? .white : .gray, lineWidth: 3)
                            recordButton(size: recordButtonGeometry.size.height - borderSpacing)
                                .animation(.easeInOut(duration: 1), value: audioRecorder.recording)
                                .foregroundColor(.red)
                        }
                    }.frame(width: geometry.size.height/10, height: geometry.size.height/10)
                    Button(action: {
                        
                    }, label: {
                        ZStack {
                            Text(String(format: "%.2f", audioRecorder.downloadProgress*100) + "%").frame(width: geometry.size.height/10, height: geometry.size.height/10)
                            CircularProgressView(progress: audioRecorder.downloadProgress)
                        }
                        
                    }).frame(width: geometry.size.height/10, height: geometry.size.height/10)
                }
                Spacer()
            }.padding(15)
        }
        .task {
            await audioRecorder.getMicrophonePermission()
        }.alert(isPresented: $audioRecorder.showPermissionAlert, content: {
            Alert(title: Text("Permission Denied"), message: Text("Microphone permissions must be on in Settings > Privacy and Security > Microphone > Whistate to dictate recorded audio."), dismissButton: .default(Text("OK")))
        })
    }
    
    
    
    private func recordButton(size: CGFloat) -> some View {
        if !audioRecorder.recording {
            return Button(action: {
                audioRecorder.recording = true
                Task {
                    await audioRecorder.startRecording()
                }
            }, label: {
                RoundedRectangle(cornerRadius: size)
                    .frame(width: size, height: size)
            })
        } else {
            return Button(action: {
                Task {
                    await audioRecorder.stopRecording()
                }
            }, label: {
                RoundedRectangle(cornerRadius: size * stoppedStateCornerRadius)
                    .frame(width: size * stoppedStateSize, height: size * stoppedStateSize)
            })
        }
    }
}

