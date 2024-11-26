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
    private var isConnecting = false
    private var pendingMessages: [(String, String, String)] = [] // (messageId, username, senderName)
    
    // Background task yönetimi için
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var backgroundTimer: Timer?
    private let backgroundTimeInterval: TimeInterval = 10 // 10 saniye
    
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        
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
        setupSocketConnection()
        
        return true
    }
    
    private func startBackgroundTask() {
        // Eğer hali hazırda bir background task varsa, timer'ı yeniden başlat
        if backgroundTask != .invalid {
            print("Mevcut background task'in süresi yenileniyor")
            restartBackgroundTimer()
            return
        }
        
        // Yeni background task başlat
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        print("Yeni background task başlatıldı")
        startBackgroundTimer()
    }
    
    private func startBackgroundTimer() {
        // Varolan timer'ı temizle
        backgroundTimer?.invalidate()
        
        // Yeni timer başlat
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: backgroundTimeInterval, repeats: false) { [weak self] _ in
            self?.endBackgroundTask()
        }
    }
    
    private func restartBackgroundTimer() {
        print("Background timer yeniden başlatılıyor")
        startBackgroundTimer()
    }
    
    private func endBackgroundTask() {
        print("Background task sonlandırılıyor")
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        
        // Socket bağlantısını kapat
        socketManager.disconnect()
    }
    
    private func setupSocketConnection() {
        socketManager.socket.on(clientEvent: .connect) { [weak self] _, _ in
            print("Socket bağlandı, bekleyen mesajları gönder")
            self?.isConnecting = false
            self?.processPendingMessages()
        }
        
        socketManager.socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            print("Socket bağlantısı koptu")
            self?.isConnecting = false
        }
        
        socketManager.socket.on(clientEvent: .error) { [weak self] _, _ in
            print("Socket bağlantı hatası")
            self?.isConnecting = false
        }
    }
    
    private func processPendingMessages() {
        guard !pendingMessages.isEmpty else { return }
        
        for (messageId, username, senderName) in pendingMessages {
            sendDeliveryReceipt(messageId: messageId, username: username, senderName: senderName)
        }
        pendingMessages.removeAll()
    }
    
    private func sendDeliveryReceipt(messageId: String, username: String, senderName: String) {
        // Socket bağlı değilse ve bağlanma işlemi devam etmiyorsa
        if !socketManager.socket.status.active && !isConnecting {
            isConnecting = true
            pendingMessages.append((messageId, username, senderName))
            socketManager.connect()
            return
        }
        
        // Socket bağlanıyor durumdaysa, mesajı kuyruğa ekle
        if isConnecting {
            pendingMessages.append((messageId, username, senderName))
            return
        }
        
        // Socket bağlıysa, mesajı hemen gönder
        socketManager.socket.emit("messageDelivered", [
            "messageId": messageId,
            "username": username,
            "senderName": senderName
        ])
        print("İletildi bilgisi gönderildi - MessageID: \(messageId)")
    }
    
    private func handleNotification(_ userInfo: [AnyHashable: Any], withCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)? = nil) {
        guard let messageId = userInfo["messageId"] as? String,
              let username = userInfo["username"] as? String,
              let senderName = userInfo["senderName"] as? String else {
            completionHandler?(.noData)
            return
        }
        
        // Background task'i başlat veya yenile
        startBackgroundTask()
        
        // Mesajı işle ve kaydet
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
        
        // İletildi bilgisini gönder
        sendDeliveryReceipt(messageId: messageId, username: username, senderName: senderName)
        
        completionHandler?(.newData)
    }
    
    func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication,
                    didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        handleNotification(userInfo, withCompletionHandler: completionHandler)
    }
}

extension AppDelegate: MessagingDelegate {
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

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handleNotification(notification.request.content.userInfo)
        completionHandler([[.banner, .badge, .sound]])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        handleNotification(response.notification.request.content.userInfo)
        completionHandler()
    }
}
