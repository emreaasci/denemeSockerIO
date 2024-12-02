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
import PushKit
import AVFoundation

class AppDelegate: NSObject, UIApplicationDelegate {
    let socketManager = SocketIOManager.shared
    private var voipRegistry: PKPushRegistry?
    
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        FirebaseApp.configure()
        
        // Push Notifications için
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        // Background fetch için
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        
        // Push izinleri
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions) { granted, error in
                print("Push notification izni:", granted)
                if let error = error {
                    print("Push notification izin hatası:", error)
                }
        }
        
        // Bildirim kategorilerini ayarla
        configurePushCategories()
        
        application.registerForRemoteNotifications()
        
        // VoIP push için
        voipRegistry = PKPushRegistry(queue: .main)
        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]
        
        
        configureAudioSession()
        
        return true
    }
    
    func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session yapılandırma hatası:", error)
        }
    }

    
    private func configurePushCategories() {
        let deliveryAction = UNNotificationAction(
            identifier: "DELIVERY_ACTION",
            title: "İletildi",
            options: [.foreground]
        )
        
        let chatCategory = UNNotificationCategory(
            identifier: "CHAT_MESSAGE",
            actions: [deliveryAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([chatCategory])
    }
    
    func handleChatNotification(_ userInfo: [AnyHashable: Any]) {
        guard let messageId = userInfo["messageId"] as? String,
              let username = userInfo["username"] as? String,
              let senderName = userInfo["senderName"] as? String else {
            return
        }
        
        let backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endAllTasks()
        }
        
        let type = userInfo["type"] as? String ?? "text"
        let image = userInfo["image"] as? String
        let audio = userInfo["audio"] as? String
        let video = userInfo["video"] as? String
        let duration = (userInfo["duration"] as? String).flatMap { Double($0) }
        
        // Mesajı kaydet
        switch type {
        case "image":
            let message = Message(
                id: messageId,
                username: senderName,
                toUsername: username,
                message: "Fotoğraf gönderdi",
                timestamp: Date().ISO8601Format(),
                status: .delivered,
                type: type,
                image: image,
                audio: nil,
                video: nil,
                duration: nil
            )
            
            DispatchQueue.main.async {
                CoreDataManager.shared.saveMessage(message, isCurrentUser: false)
                self.socketManager.messages.append(message)
            }
            
        case "audio":
            let message = Message(
                id: messageId,
                username: senderName,
                toUsername: username,
                message: "Ses mesajı gönderdi",
                timestamp: Date().ISO8601Format(),
                status: .delivered,
                type: type,
                image: nil,
                audio: audio,
                video: nil,
                duration: duration
            )
            
            DispatchQueue.main.async {
                CoreDataManager.shared.saveMessage(message, isCurrentUser: false)
                self.socketManager.messages.append(message)
            }
            
        case "video":
            let message = Message(
                id: messageId,
                username: senderName,
                toUsername: username,
                message: "Video gönderdi",
                timestamp: Date().ISO8601Format(),
                status: .delivered,
                type: type,
                image: nil,
                audio: nil,
                video: video,
                duration: duration
            )
            
            DispatchQueue.main.async {
                CoreDataManager.shared.saveMessage(message, isCurrentUser: false)
                self.socketManager.messages.append(message)
            }
            
        default: // text
            if let messageText = userInfo["message"] as? String {
                let message = Message(
                    id: messageId,
                    username: senderName,
                    toUsername: username,
                    message: messageText,
                    timestamp: Date().ISO8601Format(),
                    status: .delivered,
                    type: "text",
                    image: nil,
                    audio: nil,
                    video: nil,
                    duration: nil
                )
                
                DispatchQueue.main.async {
                    CoreDataManager.shared.saveMessage(message, isCurrentUser: false)
                    self.socketManager.messages.append(message)
                }
            }
        }
        
        // Socket.IO bağlantısını kur
        if !socketManager.socket.status.active {
            socketManager.connect()
        }
        
        // İletildi bilgisini gönder
        socketManager.socket.emit("messageDelivered", [
            "messageId": messageId,
            "username": username,
            "senderName": senderName
        ])
        
        // 5 saniye sonra background task'i sonlandır
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.endAllTasks()
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
        }
    }
    
    private func endAllTasks() {
        if socketManager.socket.status.active {
            socketManager.disconnect()
        }
    }
    
    func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication,
                    didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        handleChatNotification(userInfo)
        completionHandler(.newData)
    }
}

extension AppDelegate: PKPushRegistryDelegate {
    func pushRegistry(_ registry: PKPushRegistry,
                     didUpdate pushCredentials: PKPushCredentials,
                     for type: PKPushType) {
        print("VoIP token:", pushCredentials.token.map { String(format: "%02.2hhx", $0) }.joined())
    }
    
    func pushRegistry(_ registry: PKPushRegistry,
                     didReceiveIncomingPushWith payload: PKPushPayload,
                     for type: PKPushType,
                     completion: @escaping () -> Void) {
        
        handleChatNotification(payload.dictionaryPayload)
        completion()
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
        
        handleChatNotification(notification.request.content.userInfo)
        completionHandler([[.banner, .badge, .sound]])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        
        handleChatNotification(response.notification.request.content.userInfo)
        completionHandler()
    }
}
