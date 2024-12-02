// MediaMessageViews.swift - Medya mesajları için view'lar
import SwiftUI
import AVKit
import PhotosUI

struct AudioMessageView: View {
    let audioData: Data
    let duration: Double
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    
    var body: some View {
        HStack {
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
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
                            .frame(width: geometry.size.width * progress, height: 3)
                    }
                }
            }
        }
        .frame(width: 200)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(16)
        .onAppear(perform: setupAudioPlayer)
        .onDisappear {
            audioPlayer?.stop()
        }
    }
    
    private func setupAudioPlayer() {
        do {
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
        } catch {
            print("Audio player setup failed:", error)
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
        } else {
            audioPlayer?.play()
            startProgressUpdates()
        }
        isPlaying.toggle()
    }
    
    private func startProgressUpdates() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            guard let player = audioPlayer else {
                timer.invalidate()
                return
            }
            
            progress = player.currentTime / player.duration
            
            if !player.isPlaying {
                timer.invalidate()
                isPlaying = false
                progress = 0
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
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
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("temp_video.mp4")
        try? videoData.write(to: tempURL)
        return AVPlayer(url: tempURL)
    }
}