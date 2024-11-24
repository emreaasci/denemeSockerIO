// Ana View
struct ChatView: View {
    @StateObject private var socketManager = SocketIOManager()
    @State private var messageText = ""
    @State private var username = ""
    @State private var isJoined = false
    
    var body: some View {
        if isJoined {
            VStack {
                // Mesaj listesi
                ScrollView {
                    LazyVStack(alignment: .leading) {
                        ForEach(socketManager.messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding()
                }
                
                // Mesaj gönderme alanı
                HStack {
                    TextField("Mesajınız...", text: $messageText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    Button("Gönder") {
                        if !messageText.isEmpty {
                            socketManager.sendMessage(message: messageText)
                            messageText = ""
                        }
                    }
                    .padding(.trailing)
                }
                .padding(.bottom)
            }
            .navigationTitle("Sohbet")
        } else {
            // Giriş ekranı
            VStack {
                TextField("Kullanıcı adı", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button("Sohbete Katıl") {
                    if !username.isEmpty {
                        socketManager.connect()
                        socketManager.joinChat(username: username)
                        isJoined = true
                    }
                }
            }
            .padding()
        }
    }
}
