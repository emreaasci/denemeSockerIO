//
//  SocketIOManager.swift
//  denemeSockerIO
//
//  Created by Emre Aşcı on 21.11.2024.
//

import Foundation
import SocketIO

class SocketIOManager: ObservableObject {
    static let shared = SocketIOManager()
    @Published var messages: [Message] = []
    @Published var onlineUsers: [String] = []
    @Published var selectedUser: String?
    private var currentUsername: String = ""
    
    private var manager: SocketManager
    var socket: SocketIOClient
    
    init() {
        let serverURL = "http://172.10.40.76:3000"
        
        manager = SocketManager(socketURL: URL(string: serverURL)!, config: [
            .log(true),
            .compress,
            .forceWebsockets(true),
            .reconnects(true)
        ])
        
        socket = manager.defaultSocket
        setupSocketEvents()
        setupFCMTokenObserver()
        
        // Kaydedilmiş mesajları yükle
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
            
            DispatchQueue.main.async {
                let newMessage = Message(
                    id: id,
                    username: from,
                    toUsername: to,
                    message: message,
                    timestamp: timestamp,
                    status: status
                )
                self.messages.append(newMessage)
                
                // Mesajı CoreData'ya kaydet
                CoreDataManager.shared.saveMessage(newMessage, isCurrentUser: from == self.currentUsername)
                
                // Mesaj alındığında okundu bildirimi gönder
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
            guard let users = data[0] as? [String] else { return }
            DispatchQueue.main.async {
                self?.onlineUsers = users.filter { $0 != self?.currentUsername }
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
            // CoreData'da mesaj durumunu güncelle
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
        socket.connect()
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
            "message": message
        ]
        socket.emit("privateMessage", messageData)
    }
    
    func reportMessageDelivery(messageId: String, username: String, from: String, completion: @escaping (Bool) -> Void) {
        // Socket bağlı değilse bağlan
        if !socket.status.active {
            connect()
        }
        
        // Mesajın iletildiğini bildir
        socket.emit("messageDelivered", [
            "messageId": messageId,
            "username": username,
            "from": from
        ])
        
        // Gönderenin mesajını güncelle
        DispatchQueue.main.async {
            if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                self.messages[index].status = .delivered
                // CoreData'da güncelle
                CoreDataManager.shared.updateMessageStatus(messageId: messageId, status: .delivered)
            }
        }
        
        completion(true)
    }
    
    // CoreData ile ilgili yardımcı fonksiyonlar
    func clearAllMessages() {
        CoreDataManager.shared.clearAllMessages()
        messages.removeAll()
    }
    
    func deleteMessage(id: String) {
        CoreDataManager.shared.deleteMessage(id: id)
        messages.removeAll { $0.id == id }
    }
}

extension SocketIOManager {
    func sendNotificationReceivedConfirmation(messageId: String, username: String, senderName: String) {
        print("Bildirim alındı onayı gönderiliyor - MessageID: \(messageId)")
        
        socket.emit("notificationReceived", [
            "messageId": messageId,
            "username": username,
            "senderName": senderName
        ])
    }
}


