//
//  AppDelegate.swift
//  denemeSockerIO
//
//  Created by Emre Aşcı on 22.11.2024.
//


import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    let socketManager = SocketIOManager.shared
    
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        
        // Background fetch'i etkinleştir
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions) { granted, error in
                print("Push notification izni:", granted)
                if let error = error {
                    print("Push notification izin hatası:", error)
                }
        }
        
        application.registerForRemoteNotifications()
        
        return true
    }
    
    func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication,
                    didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications:", error)
    }
    
    func application(_ application: UIApplication,
                    didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        print("Bildirim alındı:", userInfo)
        
        // Background task oluştur
        var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        backgroundTask = application.beginBackgroundTask {
            application.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        
        if let messageId = userInfo["messageId"] as? String,
           let username = userInfo["username"] as? String,
           let senderName = userInfo["senderName"] as? String {
            
            // Socket.IO bağlantısını kur
            socketManager.connect()
            
            // Mesajı CoreData'ya kaydet ve UI'ı güncelle
            if let messageText = userInfo["message"] as? String {
                let message = Message(
                    id: messageId,
                    username: senderName,
                    toUsername: username,
                    message: messageText,
                    timestamp: Date().ISO8601Format(),
                    status: .delivered
                )
                
                DispatchQueue.main.async {
                    CoreDataManager.shared.saveMessage(message, isCurrentUser: false)
                    self.socketManager.messages.append(message)
                }
            }
            
            // Socket bağlantısı için timeout başlat
            let timeoutTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                if self.socketManager.socket.status.active {
                    self.socketManager.disconnect()
                    application.endBackgroundTask(backgroundTask)
                    completionHandler(.failed)
                }
            }
            
            socketManager.socket.once(clientEvent: .connect) { [weak self] data, ack in
                // Delivery receipt'i gönder
                self?.socketManager.socket.emit("messageDelivered", [
                    "messageId": messageId,
                    "username": username,
                    "senderName": senderName
                ])
                
                print("MessageDelivered eventi gönderildi")
                
                // Timer'ı iptal et
                timeoutTimer.invalidate()
                
                // Bağlantıyı kapat ve background task'i sonlandır
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self?.socketManager.disconnect()
                    application.endBackgroundTask(backgroundTask)
                    completionHandler(.newData)
                }
            }
            
            // Bağlantı hatası durumu için
            socketManager.socket.on(clientEvent: .error) { [weak self] data, ack in
                print("Socket bağlantı hatası")
                self?.socketManager.disconnect()
                application.endBackgroundTask(backgroundTask)
                completionHandler(.failed)
            }
            
        } else {
            application.endBackgroundTask(backgroundTask)
            completionHandler(.noData)
        }
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("=== FCM Token Debug ===")
        if let token = fcmToken {
            print("Valid FCM token received:", token)
            
            NotificationCenter.default.post(
                name: Notification.Name("FCMToken"),
                object: nil,
                userInfo: ["token": token]
            )
        } else {
            print("FCM token is nil!")
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("Foreground'da bildirim alındı:", userInfo)
        
        // Background task oluştur
        var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        backgroundTask = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        
        if let messageId = userInfo["messageId"] as? String,
           let username = userInfo["username"] as? String,
           let senderName = userInfo["senderName"] as? String {
            
            // Socket.IO bağlantısını kur ve iletildi bilgisini gönder
            socketManager.connect()
            
            socketManager.socket.once(clientEvent: .connect) { [weak self] data, ack in
                self?.socketManager.socket.emit("messageDelivered", [
                    "messageId": messageId,
                    "username": username,
                    "senderName": senderName
                ])
                
                print("Message delivery receipt gönderildi")
                
                // Bağlantıyı kapat ve background task'i sonlandır
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self?.socketManager.disconnect()
                    UIApplication.shared.endBackgroundTask(backgroundTask)
                }
            }
        }
        
        completionHandler([[.banner, .badge, .sound]])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("Bildirime tıklandı:", userInfo)
        
        // Background task oluştur
        var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        backgroundTask = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        
        if let messageId = userInfo["messageId"] as? String,
           let username = userInfo["username"] as? String,
           let senderName = userInfo["senderName"] as? String {
            
            print("Bildirime tıklandı ve işleniyor - MessageID: \(messageId)")
            
            // Socket.IO bağlantısını kur
            socketManager.connect()
            
            socketManager.socket.once(clientEvent: .connect) { [weak self] data, ack in
                self?.socketManager.socket.emit("messageDelivered", [
                    "messageId": messageId,
                    "username": username,
                    "senderName": senderName
                ])
                
                print("MessageDelivered eventi gönderildi")
                
                // Bağlantıyı kapat ve background task'i sonlandır
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self?.socketManager.disconnect()
                    UIApplication.shared.endBackgroundTask(backgroundTask)
                }
            }
        }
        
        completionHandler()
    }
}
