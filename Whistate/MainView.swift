// Code edited from https://gist.github.com/bfolkens/d5749c28830f02aadbf688ebe84fa6b7

import SwiftUI
import AVFoundation

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
                ScrollView {
                    Text(audioRecorder.transcribing ? "Transcribing..." : (audioRecorder.transcriptionText ?? "Record an audio to have it transcribed!"))
                }.frame(height: geometry.size.height * 8/10, alignment: .leading)
                Divider()
                HStack {
                    Toggle(isOn: $audioPlaying) {
                        Image(systemName: audioPlaying ? "stop.fill" : "play.fill").resizable().frame(width: geometry.size.height/15, height: geometry.size.height/15)
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
                    }.frame(width: geometry.size.height/12.5, height: geometry.size.height/12.5)
                    .disabled(!audioRecorder.downloadCompleted)
                    Spacer().frame(width: geometry.size.height/18.75)
                    GeometryReader { recordButtonGeometry in
                        ZStack {
                            Circle()
                                .stroke(colorScheme == .dark ? .white : .gray, lineWidth: 3)
                            recordButton(size: recordButtonGeometry.size.height - borderSpacing)
                                .animation(.easeInOut(duration: 1), value: audioRecorder.recording)
                                .foregroundColor(audioRecorder.downloadCompleted ? .red: .gray)
                        }
                    }.frame(width: geometry.size.height/12.5, height: geometry.size.height/12.5)
                    .disabled(!audioRecorder.downloadCompleted)
                    Spacer().frame(width: geometry.size.height/18.75)
                    GeometryReader { downloadButtonGeometry in
                        let fontSize = downloadButtonGeometry.size.height / 5
                        Button(action: {
                            Task {
                                do {
                                    try await audioRecorder.downloadAndPrepareModel()
                                } catch {
                                    print("Error preparing and downloading models for WhisperKit pipe! \(error.localizedDescription)")
                                }
                            }
                        }, label: {
                            ZStack {
                                audioRecorder.downloadCompleted ? Text("Done!").font(.system(size: fontSize)) : Text(String(format: "%.2f", audioRecorder.downloadProgress*100) + "%").font(.system(size: fontSize))
                                CircularProgressView(progress: audioRecorder.downloadCompleted ? 1 : audioRecorder.downloadProgress)
                            }
                        }).frame(width: downloadButtonGeometry.size.height, height: downloadButtonGeometry.size.height)
                    }.frame(width: geometry.size.height/12.5, height: geometry.size.height/12.5)
                }.padding(15)
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

