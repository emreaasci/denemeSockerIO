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
        let messageEntity = MessageEntity(context: context)
        
        messageEntity.id = message.id
        messageEntity.username = message.username
        messageEntity.toUsername = message.toUsername
        messageEntity.message = message.message
        messageEntity.timestamp = message.timestamp
        messageEntity.status = message.status.rawValue
        messageEntity.isCurrentUser = isCurrentUser
        
        do {
            try context.save()
        } catch {
            print("Failed to save message: \(error)")
        }
    }
    
    func fetchMessages() -> [Message] {
        let context = viewContext
        let fetchRequest: NSFetchRequest<MessageEntity> = MessageEntity.fetchRequest()
        
        do {
            let messageEntities = try context.fetch(fetchRequest)
            return messageEntities.map { entity in
                Message(
                    id: entity.id ?? "",
                    username: entity.username ?? "",
                    toUsername: entity.toUsername ?? "",
                    message: entity.message ?? "",
                    timestamp: entity.timestamp ?? "",
                    status: MessageStatus(rawValue: entity.status ?? "sent") ?? .sent
                )
            }
        } catch {
            print("Failed to fetch messages: \(error)")
            return []
        }
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
}