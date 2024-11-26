//
//  NotificationHandler.swift
//  denemeSockerIO
//
//  Created by Emre Aşcı on 26.11.2024.
//


// NotificationHandler.swift
import UserNotifications
import Firebase
import FirebaseMessaging

class NotificationHandler: NSObject {
    static let shared = NotificationHandler()
    private let socketManager = SocketIOManager.shared
    
    private override init() {
        super.init()
    }
    
    func configure() {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if let error = error {
                print("Push notification izin hatası:", error)
            }
        }
    }
    
    private func handleNotification(_ userInfo: [AnyHashable: Any], completionHandler: ((UIBackgroundFetchResult) -> Void)? = nil) {
        // Notification tipini kontrol et
        let type = userInfo["type"] as? String
        let messageId = userInfo["messageId"] as? String ?? ""
        let username = userInfo["username"] as? String ?? ""
        let senderName = userInfo["senderName"] as? String ?? ""
        let message = userInfo["message"] as? String
        
        // Mesajı CoreData'ya kaydet ve UI'ı güncelle
        if let messageText = message {
            let newMessage = Message(
                id: messageId,
                username: senderName,
                toUsername: username,
                message: messageText,
                timestamp: Date().ISO8601Format(),
                status: .delivered
            )
            
            DispatchQueue.main.async {
                CoreDataManager.shared.saveMessage(newMessage, isCurrentUser: false)
                self.socketManager.messages.append(newMessage)
            }
        }
        
        // Socket.IO üzerinden iletildi bilgisini gönder
        self.socketManager.connect()
        self.socketManager.socket.once(clientEvent: .connect) { [weak self] _, _ in
            let deliveryEvent = type == "silent_receipt" ? "notificationReceived" : "messageDelivered"
            
            self?.socketManager.socket.emit(deliveryEvent, [
                "messageId": messageId,
                "username": username,
                "senderName": senderName
            ])
            
            // Bağlantıyı kapat
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self?.socketManager.disconnect()
                completionHandler?(.newData)
            }
        }
        
        // Timeout kontrolü
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if self.socketManager.socket.status.active {
                self.socketManager.disconnect()
                completionHandler?(.failed)
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationHandler: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        handleNotification(userInfo)
        completionHandler([[.banner, .badge, .sound]])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        handleNotification(userInfo)
        completionHandler()
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        handleNotification(userInfo, completionHandler: completionHandler)
    }
}

// MARK: - MessagingDelegate
extension NotificationHandler: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let token = fcmToken {
            NotificationCenter.default.post(
                name: Notification.Name("FCMToken"),
                object: nil,
                userInfo: ["token": token]
            )
        }
    }
}