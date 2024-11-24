//
//  MessageBubble.swift
//  denemeSockerIO
//
//  Created by Emre Aşcı on 21.11.2024.
//

import SwiftUI

struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.username)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack(alignment: .bottom, spacing: 4) {
                    Text(message.message)
                        .padding(10)
                        .background(isCurrentUser ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(16)
                    
                    if isCurrentUser {
                        MessageStatusIndicator(status: message.status)
                    }
                }
            }
            .padding(.horizontal, 4)
            
            if !isCurrentUser {
                Spacer()
            }
        }
    }
}

struct MessageStatusIndicator: View {
    let status: MessageStatus
    
    var body: some View {
        Group {
            switch status {
            case .sent:
                Image(systemName: "checkmark")
                    .foregroundColor(.gray)
            case .delivered:
                HStack(spacing: -4) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .foregroundColor(.gray)
            case .read:
                HStack(spacing: -4) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                }
                .foregroundColor(.blue)
            }
        }
        .font(.caption2)
    }
}
