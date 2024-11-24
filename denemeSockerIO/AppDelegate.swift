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
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        print("=== Firebase Configuration Debug ===")
        print("Bundle ID:", Bundle.main.bundleIdentifier ?? "Not found")
        
        FirebaseApp.configure()
        
        // Messaging delegate'i ayarla
        Messaging.messaging().delegate = self
        
        // Push notification için izin iste
        UNUserNotificationCenter.current().delegate = self
        
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
        
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("APNS token:", token)
    }
    
    func application(_ application: UIApplication,
                    didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications:", error)
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("=== FCM Token Debug ===")
        if let token = fcmToken {
            print("Valid FCM token received:", token)
            
            // Token'ı server'a gönder
            NotificationCenter.default.post(
                name: Notification.Name("FCMToken"),
                object: nil,
                userInfo: ["token": token]
            )
        } else {
            print("FCM token is nil!")
        }
        
        // APNS token'ı da kontrol et
        if let apnsToken = Messaging.messaging().apnsToken {
            print("APNS token is set:", apnsToken)
        } else {
            print("APNS token is not set!")
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("Received notification while app is in foreground:", userInfo)
        
        completionHandler([[.banner, .badge, .sound]])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("Tapped notification:", userInfo)
        
        completionHandler()
    }
}
