//
//  Message.swift
//  denemeSockerIO
//
//  Created by Emre Aşcı on 21.11.2024.
//



struct Message: Identifiable, Equatable {
    let id: String
    let username: String
    let toUsername: String
    let message: String
    let timestamp: String
    var status: MessageStatus
}

enum MessageStatus: String {
    case sent = "sent"
    case delivered = "delivered"
    case read = "read"
}
