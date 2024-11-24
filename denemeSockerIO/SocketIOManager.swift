// SocketIO Manager
class SocketIOManager: ObservableObject {
    @Published var messages: [Message] = []
    @Published var onlineUsers: [String] = []
    
    private let manager: SocketManager
    private var socket: SocketIOClient
    
    init() {
        // Sunucu adresinizi buraya yazın
        manager = SocketManager(socketURL: URL(string: "http://localhost:3000")!, config: [
            .log(true),
            .compress,
            .forceWebsockets(true)
        ])
        
        socket = manager.defaultSocket
        setupSocketEvents()
    }
    
    private func setupSocketEvents() {
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            print("Socket bağlandı!")
        }
        
        socket.on("newMessage") { [weak self] data, _ in
            guard let messageData = data[0] as? [String: Any],
                  let id = messageData["id"] as? String,
                  let username = messageData["username"] as? String,
                  let message = messageData["message"] as? String,
                  let timestamp = messageData["timestamp"] as? String else { return }
            
            DispatchQueue.main.async {
                self?.messages.append(Message(id: id, username: username, message: message, timestamp: timestamp))
            }
        }
        
        socket.on("userList") { [weak self] data, _ in
            guard let users = data[0] as? [String] else { return }
            DispatchQueue.main.async {
                self?.onlineUsers = users
            }
        }
    }
    
    func connect() {
        socket.connect()
    }
    
    func disconnect() {
        socket.disconnect()
    }
    
    func joinChat(username: String) {
        socket.emit("userJoined", ["username": username])
    }
    
    func sendMessage(message: String) {
        socket.emit("sendMessage", ["message": message])
    }
}