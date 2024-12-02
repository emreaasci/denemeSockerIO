//
//  CoreDataManager.swift
//  denemeSockerIO
//
//  Created by Emre Aşcı on 22.11.2024.
//


import CoreData


class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ChatModel")
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data container failed: \(error.localizedDescription)")
            }
        }
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func saveMessage(_ message: Message, isCurrentUser: Bool) {
            let context = viewContext
            let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", message.id)
            
            do {
                let existingMessages = try context.fetch(fetchRequest)
                
                if let existingMessage = existingMessages.first {
                    // Güncelle
                    existingMessage.status = message.status.rawValue
                    existingMessage.type = message.type
                    existingMessage.image = message.image
                    existingMessage.audio = message.audio
                    existingMessage.video = message.video
                    existingMessage.duration = message.duration ?? 0
                } else {
                    // Yeni oluştur
                    let messageEntity = MessageEntity(context: context)
                    messageEntity.id = message.id
                    messageEntity.username = message.username
                    messageEntity.toUsername = message.toUsername
                    messageEntity.message = message.message
                    messageEntity.timestamp = message.timestamp
                    messageEntity.status = message.status.rawValue
                    messageEntity.type = message.type
                    messageEntity.image = message.image
                    messageEntity.audio = message.audio
                    messageEntity.video = message.video
                    messageEntity.duration = message.duration ?? 0
                    messageEntity.isCurrentUser = isCurrentUser
                }
                
                try context.save()
            } catch {
                print("Failed to save message:", error)
                context.rollback()
            }
        }
    
    func fetchMessages() -> [Message] {
            let context = viewContext
            let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
            let sortDescriptor = NSSortDescriptor(key: "timestamp", ascending: true)
            fetchRequest.sortDescriptors = [sortDescriptor]
            
            do {
                let messageEntities = try context.fetch(fetchRequest)
                return messageEntities.map { entity in
                    Message(
                        id: entity.id ?? "",
                        username: entity.username ?? "",
                        toUsername: entity.toUsername ?? "",
                        message: entity.message ?? "",
                        timestamp: entity.timestamp ?? "",
                        status: MessageStatus(rawValue: entity.status ?? "sent") ?? .sent,
                        type: entity.type ?? "text",
                        image: entity.image,
                        audio: entity.audio,
                        video: entity.video,
                        duration: entity.duration
                    )
                }
            } catch {
                print("Failed to fetch messages:", error)
                return []
            }
        }
    
    func getMessage(id: String) -> Message? {
        let context = viewContext
        let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            let messages = try context.fetch(fetchRequest)
            if let messageEntity = messages.first {
                return Message(
                    id: messageEntity.id ?? "",
                    username: messageEntity.username ?? "",
                    toUsername: messageEntity.toUsername ?? "",
                    message: messageEntity.message ?? "",
                    timestamp: messageEntity.timestamp ?? "",
                    status: MessageStatus(rawValue: messageEntity.status ?? "sent") ?? .sent,
                    type: messageEntity.type,
                    image: messageEntity.image,
                    audio: messageEntity.audio,
                    video: messageEntity.video,
                    duration: messageEntity.duration
                )
            }
        } catch {
            print("Failed to fetch message: \(error)")
        }
        return nil
    }
    
    func updateMessageStatus(messageId: String, status: MessageStatus) {
        let context = viewContext
        let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", messageId)
        
        do {
            let messages = try context.fetch(fetchRequest)
            if let messageToUpdate = messages.first {
                messageToUpdate.status = status.rawValue
                try context.save()
            }
        } catch {
            print("Failed to update message status: \(error)")
        }
    }
    
    func clearAllMessages() {
        let context = viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = MessageEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print("Failed to clear messages: \(error)")
        }
    }
    
    func deleteMessage(id: String) {
        let context = viewContext
        let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            let messages = try context.fetch(fetchRequest)
            if let messageToDelete = messages.first {
                context.delete(messageToDelete)
                try context.save()
            }
        } catch {
            print("Failed to delete message: \(error)")
        }
    }
}
