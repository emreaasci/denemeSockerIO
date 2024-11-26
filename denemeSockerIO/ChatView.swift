//
//  ChatView.swift
//  denemeSockerIO
//
//  Created by Emre Aşcı on 21.11.2024.
//


import SwiftUI

struct ChatView: View {
    @StateObject private var socketManager = SocketIOManager.shared
    @State private var messageText = ""
    @State private var username: String
    @State private var showUserList = false
    @State private var showLogs = false
    
    init(defaultUsername: String) {
        _username = State(initialValue: defaultUsername)
    }
    
    var body: some View {
        NavigationView {
            if let selectedUser = socketManager.selectedUser {
                // Chat ekranı
                VStack {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading) {
                                ForEach(chatMessages) { message in
                                    MessageBubble(
                                        message: message,
                                        isCurrentUser: message.username == username
                                    )
                                    .id(message.id)
                                }
                            }
                            .padding()
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
                .sheet(isPresented: $showLogs) {
                    LogViewer()
                }
            } else {
                // Kullanıcı seçme ekranı
                VStack {
                    List(socketManager.onlineUsers, id: \.self) { user in
                        Button(action: { socketManager.selectUser(user) }) {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.green)
                                Text(user)
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
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        socketManager.sendMessage(message: messageText)
        messageText = ""
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
