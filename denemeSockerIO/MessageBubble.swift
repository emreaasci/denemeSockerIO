// Mesaj balonu view'ı
struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(message.username)
                .font(.caption)
                .foregroundColor(.gray)
            
            Text(message.message)
                .padding(10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
            
            Text(message.timestamp)
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}