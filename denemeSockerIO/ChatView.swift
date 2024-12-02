//
//  ChatView.swift
//  denemeSockerIO
//
//  Created by Emre Aşcı on 21.11.2024.
//


import SwiftUI
import PhotosUI

struct ChatView: View {
    @StateObject private var socketManager = SocketIOManager.shared
    @State private var messageText = ""
    @State private var username: String
    @State private var showUserList = false
    @State private var showLogs = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingAudioRecorder = false
    @State private var showingVideoPicker = false
    @StateObject private var audioRecorder = AudioRecorder()
    
    init(defaultUsername: String) {
        _username = State(initialValue: defaultUsername)
    }
    
    var body: some View {
            NavigationView {
                if let selectedUser = socketManager.selectedUser {
                    VStack {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading) {
                                    ForEach(Array(groupedMessages.enumerated()), id: \.element.id) { index, message in
                                        MessageBubble(
                                            message: message,
                                            isCurrentUser: message.username == username,
                                            showUsername: shouldShowUsername(at: index)
                                        )
                                        .id(message.id)
                                    }
                                    .padding(.leading, 8)
                                }
                                .padding(.trailing, 8)
                                .padding(.leading, 8)
                            }
                            .onChange(of: socketManager.messages) { _ in
                                if let lastMessage = chatMessages.last {
                                    withAnimation {
                                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    
                    Divider()
                    
                        
                        HStack {
                            Menu {
                                Button(action: {
                                    showImagePicker = true
                                }) {
                                    Label("Fotoğraf", systemImage: "photo")
                                }
                                
                                Button(action: {
                                    showingAudioRecorder = true
                                }) {
                                    Label("Ses Kaydı", systemImage: "mic.fill")
                                }
                                
                                Button(action: {
                                    showingVideoPicker = true
                                }) {
                                    Label("Video", systemImage: "video.fill")
                                }
                            } label: {
                                Image(systemName: "paperclip")
                                    .foregroundColor(.blue)
                                    .padding(8)
                            }
                            .padding(.leading, 8)
                            
                            TextField("Mesaj...", text: $messageText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                            
                            Button(action: sendMessage) {
                                Image(systemName: "paperplane.fill")
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(messageText.isEmpty ? Color.gray : Color.blue)
                                    .cornerRadius(8)
                            }
                            
                            .disabled(messageText.isEmpty)
                            .padding(.trailing)
                        }
                        .padding(.vertical, 8)
                }
                .navigationTitle(selectedUser)
                .navigationBarItems(trailing:
                    HStack {
                        Button("Logs") {
                            showLogs.toggle()
                        }
                        Button("Yeni Sohbet") {
                            socketManager.selectedUser = nil
                            showUserList = true
                        }
                    }
                )
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker(image: $selectedImage, completion: { image in
                        if let image = image {
                            sendImage(image)
                        }
                    })
                }
                    
                
                .sheet(isPresented: $showingAudioRecorder) {
                    AudioRecorderView(socketManager: socketManager)
                }
                    
                .sheet(isPresented: $showingVideoPicker) {
                    VideoPickerView(socketManager: socketManager)
                }
                
                
                .sheet(isPresented: $showLogs) {
                    LogViewer()
                }
            } else {
                // Kullanıcı seçme ekranı
                VStack {
                    List(socketManager.users) { user in
                        Button(action: { socketManager.selectUser(user.username) }) {
                            VStack(alignment: .leading) {
                                Text(user.username)
                                    .font(.headline)
                                Text(user.isOnline ? "Online" : "Offline")
                                    .font(.caption)
                                    .foregroundColor(user.isOnline ? .green : .gray)
                            }
                        }
                    }
                }
                .navigationTitle("Sohbet Başlat")
                .navigationBarItems(trailing:
                    Button("Logs") {
                        showLogs.toggle()
                    }
                )
                .sheet(isPresented: $showLogs) {
                    LogViewer()
                }
                .onAppear {
                    socketManager.connect()
                    socketManager.joinChat(username: username)
                }
            }
        }
    }
    
    private var chatMessages: [Message] {
        socketManager.messages.filter { message in
            (message.username == username && message.toUsername == socketManager.selectedUser) ||
            (message.username == socketManager.selectedUser && message.toUsername == username)
        }
    }
        
    private var groupedMessages: [Message] {
        chatMessages.sorted { $0.timestamp < $1.timestamp }
    }
        
    private func shouldShowUsername(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let currentMessage = groupedMessages[index]
        let previousMessage = groupedMessages[index - 1]
        return currentMessage.username != previousMessage.username
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        socketManager.sendMessage(message: messageText)
        messageText = ""
    }
    
    
    private func sendImage(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else { return }
        socketManager.sendImage(imageData: imageData)
    }

}





struct LogViewer: View {
    @State private var logs = ""
    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(logs)
                    .padding()
                    .font(.system(.body, design: .monospaced))
            }
            .navigationTitle("Notification Logs")
            .navigationBarItems(trailing: Button("Clear") {
                NotificationLogReader.shared.clearLogs()
                logs = "Logs cleared"
            })
            .onAppear {
                logs = NotificationLogReader.shared.readLogs()
            }
            .onReceive(timer) { _ in
                logs = NotificationLogReader.shared.readLogs()
            }
        }
    }
}


struct AudioRecorderView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var audioRecorder = AudioRecorder()
    let socketManager: SocketIOManager
    @State private var recordingURL: URL?
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                Text(formatTime(audioRecorder.recordingTime))
                    .font(.system(size: 54, weight: .light, design: .monospaced))
                    .padding()
                
                HStack(spacing: 40) {
                    Button(action: cancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.red)
                    }
                    
                    Button(action: toggleRecording) {
                        Image(systemName: audioRecorder.isRecording ? "stop.circle.fill" : "circle.fill")
                            .font(.system(size: 84))
                            .foregroundColor(.red)
                    }
                    
                    if !audioRecorder.isRecording && recordingURL != nil {
                        Button(action: sendRecording) {
                            Image(systemName: "paperplane.circle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Ses Kaydı")
            .navigationBarTitleDisplayMode(.inline)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Hata"), message: Text(alertMessage), dismissButton: .default(Text("Tamam")))
            }
            .onAppear {
                checkMicrophonePermission()
            }
        }
    }
    
    private func checkMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if !granted {
                DispatchQueue.main.async {
                    alertMessage = "Ses kaydı için mikrofon izni gerekiyor"
                    showAlert = true
                }
            }
        }
    }
    
    private func toggleRecording() {
        if audioRecorder.isRecording {
            if let (url, duration) = audioRecorder.stopRecording() {
                recordingURL = url
            }
        } else {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                recordingURL = audioRecorder.startRecording()
            } catch {
                alertMessage = "Ses kaydı başlatılamadı: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func sendRecording() {
        guard let url = recordingURL else { return }
        
        do {
            let audioData = try Data(contentsOf: url)
            socketManager.sendAudio(audioData: audioData, duration: audioRecorder.recordingTime)
            try FileManager.default.removeItem(at: url)
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Ses gönderme hatası:", error)
        }
    }
    
    private func cancel() {
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
        presentationMode.wrappedValue.dismiss()
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let tenths = Int((time * 10).truncatingRemainder(dividingBy: 10))
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}

struct VideoPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    let socketManager: SocketIOManager
    @State private var videoItem: PhotosPickerItem?
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                PhotosPicker(selection: $videoItem, matching: .videos) {
                    VStack {
                        Image(systemName: "video.fill")
                            .font(.system(size: 60))
                        Text("Video Seç")
                            .font(.title2)
                    }
                    .foregroundColor(.blue)
                }
                .onChange(of: videoItem) { newValue in
                    if let item = newValue {
                        handleVideoSelection(item)
                    }
                }
            }
            .navigationTitle("Video Seç")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("İptal") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Hata"), message: Text(alertMessage), dismissButton: .default(Text("Tamam")))
            }
        }
    }
    
    private func handleVideoSelection(_ item: PhotosPickerItem) {
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let videoData):
                    if let data = videoData {
                        print("Video seçildi, boyut: \(data.count / 1024)KB")
                        socketManager.sendVideo(videoData: data)
                        presentationMode.wrappedValue.dismiss()
                    } else {
                        alertMessage = "Video verisi alınamadı"
                        showAlert = true
                    }
                case .failure(let error):
                    alertMessage = "Video seçilemedi: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}
