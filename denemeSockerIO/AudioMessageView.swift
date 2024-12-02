//
//  AudioMessageView.swift
//  denemeSockerIO
//
//  Created by Emre Aşcı on 29.11.2024.
//

import SwiftUI
import AVKit
import PhotosUI

struct AudioMessageView: View {
    let audioData: Data
    let duration: Double
    @StateObject private var playerManager = AudioPlayerManager()
    
    var body: some View {
        HStack {
            Button(action: { playerManager.togglePlayback() }) {
                Image(systemName: playerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(formatTime(duration))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 3)
                        
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * playerManager.progress, height: 3)
                    }
                }
            }
        }
        .frame(width: 200)
        .padding()
        .background(Color.green.opacity(0.2))
        .cornerRadius(16)
        .onAppear {
            playerManager.setupPlayer(with: audioData)
        }
        .onDisappear {
            playerManager.stopPlayback()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

class AudioPlayerManager: NSObject, ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    @Published var isPlaying = false
    @Published var progress: Double = 0
    private var progressTimer: Timer?
    
    func setupPlayer(with data: Data) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
        } catch {
            print("Audio player setup failed:", error)
        }
    }
    
    func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
            stopProgressTimer()
        } else {
            audioPlayer?.play()
            startProgressTimer()
        }
        isPlaying.toggle()
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        stopProgressTimer()
        isPlaying = false
        progress = 0
    }
    
    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self,
                  let player = self.audioPlayer else {
                self?.stopProgressTimer()
                return
            }
            
            self.progress = player.currentTime / player.duration
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.progress = 0
            self.stopProgressTimer()
        }
    }
}

struct VideoMessageView: View {
    let videoData: Data
    @State private var showFullScreen = false
    
    var body: some View {
        Button(action: { showFullScreen = true }) {
            ZStack {
                if let thumbnail = generateThumbnail() {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 150)
                        .clipped()
                        .cornerRadius(16)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 150)
                        .cornerRadius(16)
                }
                
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
            }
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            VideoPlayerView(videoData: videoData)
        }
    }
    
    private func generateThumbnail() -> UIImage? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_video.mp4")
        try? videoData.write(to: tempURL)
        
        let asset = AVAsset(url: tempURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            try? FileManager.default.removeItem(at: tempURL)
            return UIImage(cgImage: cgImage)
        } catch {
            print("Thumbnail generation failed:", error)
            return nil
        }
    }
}

struct VideoPlayerView: View {
    let videoData: Data
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            VideoPlayer(player: createPlayer())
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
    
    private func createPlayer() -> AVPlayer {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session ayarlama hatası:", error)
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_video.mp4")
        try? videoData.write(to: tempURL)
        return AVPlayer(url: tempURL)
    }
}
