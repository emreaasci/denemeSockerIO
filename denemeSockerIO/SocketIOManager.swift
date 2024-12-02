//
//  SocketIOManager.swift
//  denemeSockerIO
//
//  Created by Emre Aşcı on 21.11.2024.
//

import Foundation
import SocketIO
import UIKit

struct UserStatus: Identifiable {
    let id: String
    let username: String
    let isOnline: Bool
}

class SocketIOManager: ObservableObject {
    static let shared = SocketIOManager()
    @Published var messages: [Message] = []
    @Published var users: [UserStatus] = []
    @Published var selectedUser: String?
    private var currentUsername: String = ""
    
    private var manager: SocketManager
    var socket: SocketIOClient
    
    init() {
        let serverURL = "http://172.10.40.107:3000"
        
        manager = SocketManager(socketURL: URL(string: serverURL)!, config: [
            .log(true),
            .compress,
            .forceWebsockets(true),
            .reconnects(true),
            .connectParams(["EIO": "4"])
        ])
        
        socket = manager.defaultSocket
        setupSocketEvents()
        setupFCMTokenObserver()
        
        loadSavedMessages()
    }
    
    private func loadSavedMessages() {
        messages = CoreDataManager.shared.fetchMessages()
    }
    
    private func setupSocketEvents() {
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            print("Socket connected!")
            if let username = self?.currentUsername, !username.isEmpty {
                self?.joinChat(username: username)
            }
        }
        
        socket.on("newMessage") { [weak self] data, _ in
            guard let messageData = data[0] as? [String: Any],
                  let self = self else { return }
            
            let id = messageData["id"] as? String ?? UUID().uuidString
            let from = messageData["from"] as? String ?? "Unknown"
            let to = messageData["to"] as? String ?? ""
            let message = messageData["message"] as? String ?? ""
            let timestamp = messageData["timestamp"] as? String ?? ""
            let status = MessageStatus(rawValue: messageData["status"] as? String ?? "sent") ?? .sent
            let type = messageData["type"] as? String ?? "text"
            let image = messageData["image"] as? String
            let audio = messageData["audio"] as? String
            let video = messageData["video"] as? String
            let duration = messageData["duration"] as? Double
            
            DispatchQueue.main.async {
                let newMessage = Message(
                    id: id,
                    username: from,
                    toUsername: to,
                    message: message,
                    timestamp: timestamp,
                    status: status,
                    type: type,
                    image: image,
                    audio: audio,
                    video: video,
                    duration: duration
                    
                )
                self.messages.append(newMessage)
                
                CoreDataManager.shared.saveMessage(newMessage, isCurrentUser: from == self.currentUsername)
                
                if from == self.selectedUser {
                    self.socket.emit("messageRead", id)
                }
            }
        }
        
        socket.on("messageStatus") { [weak self] data, _ in
            guard let statusData = data[0] as? [String: Any],
                  let messageId = statusData["messageId"] as? String,
                  let statusStr = statusData["status"] as? String,
                  let status = MessageStatus(rawValue: statusStr) else { return }
            
            DispatchQueue.main.async {
                self?.updateMessageStatus(messageId: messageId, status: status)
            }
            
        }
        
        socket.on("userList") { [weak self] data, _ in
            guard let userData = data[0] as? [[String: Any]] else { return }
            
            DispatchQueue.main.async {
                self?.users = userData.compactMap { dict in
                    guard let username = dict["username"] as? String,
                          let isOnline = dict["isOnline"] as? Bool else {
                        return nil
                    }
                    return UserStatus(id: username, username: username, isOnline: isOnline)
                }.filter { $0.username != self?.currentUsername }
            }
        }
    }
    
    private func setupFCMTokenObserver() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("FCMToken"),
            object: nil,
            queue: .main) { [weak self] notification in
                if let token = notification.userInfo?["token"] as? String {
                    self?.registerFCMToken(token: token)
                }
            }
    }
    
    private func registerFCMToken(token: String) {
        guard !currentUsername.isEmpty else { return }
        
        socket.emit("registerFCMToken", [
            "username": currentUsername,
            "token": token
        ])
        print("FCM token registered for user: \(currentUsername)")
    }
    
    private func updateMessageStatus(messageId: String, status: MessageStatus) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].status = status
            CoreDataManager.shared.updateMessageStatus(messageId: messageId, status: status)
        }
    }
    
    private func filterMessagesForCurrentChat() {
        guard let selectedUser = selectedUser else { return }
        let filteredMessages = CoreDataManager.shared.fetchMessages().filter { message in
            (message.username == currentUsername && message.toUsername == selectedUser) ||
            (message.username == selectedUser && message.toUsername == currentUsername)
        }
        self.messages = filteredMessages.sorted { $0.timestamp < $1.timestamp }
    }
    
    func connect() {
        if !socket.status.active {
            socket.connect()
            
            socket.on(clientEvent: .disconnect) { [weak self] _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self?.connect()
                }
            }
        }
    }
    
    func disconnect() {
        socket.disconnect()
    }
    
    func joinChat(username: String) {
        self.currentUsername = username
        socket.emit("userJoined", ["username": username])
        loadSavedMessages()
    }

    func selectUser(_ username: String) {
        selectedUser = username
        socket.emit("selectUser", username)
        filterMessagesForCurrentChat()
    }
    
    func sendMessage(message: String) {
        guard let to = selectedUser else { return }
        
        let messageData: [String: Any] = [
            "to": to,
            "message": message,
            "type": "text"
        ]
        socket.emit("privateMessage", messageData)
    }
    
        
    func sendImage(imageData: Data) {
        guard let to = selectedUser else { return }
        
        // Resmi UIImage'e çevir
        guard let originalImage = UIImage(data: imageData) else { return }
        
        // Resmi yeniden boyutlandır
        let maxSize: CGFloat = 1024
        let scale = min(maxSize/originalImage.size.width, maxSize/originalImage.size.height)
        let newWidth = originalImage.size.width * scale
        let newHeight = originalImage.size.height * scale
        let newSize = CGSize(width: newWidth, height: newHeight)
        
        UIGraphicsBeginImageContext(newSize)
        originalImage.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Sıkıştırma yap ve base64'e çevir
        guard let compressedData = resizedImage?.jpegData(compressionQuality: 0.5) else { return }
        let base64Image = compressedData.base64EncodedString()
        
        // Socket üzerinden gönder
        let messageData: [String: Any] = [
            "to": to,
            "type": "image",
            "image": base64Image,
            "message": "📷 Fotoğraf" // Server tarafında bildirimler için
        ]
        
        print("Fotoğraf boyutu: \(compressedData.count / 1024)KB") // Debug için boyut bilgisi
        
        socket.emit("privateImage", messageData)
    }
    
    
    func sendAudio(audioData: Data, duration: TimeInterval) {
            guard let to = selectedUser else { return }
            
            let base64Audio = audioData.base64EncodedString()
            
            let messageData: [String: Any] = [
                "to": to,
                "type": "audio",
                "audio": base64Audio,
                "duration": duration,
                "message": "🎵 Ses mesajı" // Bildirimler için
            ]
            
            socket.emit("privateAudio", messageData)
        }
        
    func sendVideo(videoData: Data) {
        guard let to = selectedUser else {
            print("Seçili kullanıcı yok")
            return
        }
        
        print("Video boyutu: \(videoData.count / 1024)KB")
        
        let base64Video = videoData.base64EncodedString()
        let messageId = UUID().uuidString
        
        let messageData: [String: Any] = [
            "to": to,
            "type": "video",
            "video": base64Video,
            "message": "🎥 Video",
        ]
        
        print("Video mesajı gönderiliyor...")
        socket.emit("privateVideo", messageData)
    }
    
    
    func reportMessageDelivery(messageId: String, username: String, from: String, completion: @escaping (Bool) -> Void) {
        if !socket.status.active {
            socket.connect()
        }
        
        let deliveryData: [String: Any] = [
            "messageId": messageId,
            "username": username,
            "senderName": from
        ]
        
        socket.emit("messageDelivered", deliveryData)
        
        DispatchQueue.main.async {
            if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                self.messages[index].status = .delivered
                CoreDataManager.shared.updateMessageStatus(messageId: messageId, status: .delivered)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if self.socket.status.active {
                self.socket.disconnect()
            }
            completion(true)
        }
    }
    
    func clearAllMessages() {
        CoreDataManager.shared.clearAllMessages()
        messages.removeAll()
    }
    
    func deleteMessage(id: String) {
        CoreDataManager.shared.deleteMessage(id: id)
        messages.removeAll { $0.id == id }
    }
    
    func sendNotificationReceivedConfirmation(messageId: String, username: String, senderName: String) {
        print("Bildirim alındı onayı gönderiliyor - MessageID: \(messageId)")
        
        socket.emit("notificationReceived", [
            "messageId": messageId,
            "username": username,
            "senderName": senderName
        ])
    }
}
