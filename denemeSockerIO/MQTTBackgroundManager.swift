import Foundation
import CocoaMQTT
import BackgroundTasks
import UIKit

class MQTTBackgroundManager: NSObject {
    static let shared = MQTTBackgroundManager()
    
    private var mqttClient: CocoaMQTT?
    private let clientID = UIDevice.current.identifierForVendor?.uuidString ?? "iOS_Device"
    private let broker = "your.mqtt.broker.url"
    private let port: UInt16 = 1883
    private let backgroundTaskIdentifier = "com.yourdomain.mqtt.refresh"
    
    private override init() {
        super.init()
        setupMQTTClient()
        registerBackgroundTask()
    }
    
    private func setupMQTTClient() {
        mqttClient = CocoaMQTT(clientID: clientID, host: broker, port: port)
        mqttClient?.keepAlive = 60
        mqttClient?.delegate = self
        mqttClient?.allowUntrustCACertificate = true // Geliştirme için, production'da false yapın
        
        // QoS 1 kullanarak mesaj iletimini garanti altına alıyoruz
        mqttClient?.autoReconnect = true
        mqttClient?.autoReconnectTimeInterval = 1
    }
    
    func connect() {
        _ = mqttClient?.connect()
    }
    
    func disconnect() {
        mqttClient?.disconnect()
    }
    
    private func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: backgroundTaskIdentifier,
            using: nil
        ) { task in
            self.handleBackgroundTask(task: task as! BGAppRefreshTask)
        }
    }
    
    func scheduleBackgroundTask() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 dakika
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Background task scheduling failed: \(error)")
        }
    }
    
    private func handleBackgroundTask(task: BGAppRefreshTask) {
        // Background task'in zamanında tamamlanmasını sağlamak için
        task.expirationHandler = {
            self.disconnect()
            task.setTaskCompleted(success: false)
        }
        
        // MQTT bağlantısını kontrol et ve gerekirse yeniden bağlan
        if mqttClient?.connState != .connected {
            connect()
        }
        
        // Yeni background task planla
        scheduleBackgroundTask()
        
        // Task'i başarıyla tamamlandı olarak işaretle
        task.setTaskCompleted(success: true)
    }
    
    // Mesaj durumunu sunucuya bildir
    func reportMessageDelivery(messageId: String, username: String) {
        let topic = "chat/message/delivery/\(messageId)"
        let message = [
            "messageId": messageId,
            "delivered": true,
            "userId": username
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: message),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            mqttClient?.publish(topic, withString: jsonString, qos: .qos1)
        }
    }
}

// MQTT Delegate metodları
extension MQTTBackgroundManager: CocoaMQTTDelegate {
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        if ack == .accept {
            // Gerekli topic'lere subscribe ol
            mqtt.subscribe("chat/message/status/#", qos: .qos1)
            mqtt.subscribe("chat/message/delivery/#", qos: .qos1)
        }
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        print("Message published successfully")
    }
    
    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16) {
        // Gelen mesajları işle
        if let messageString = message.string,
           let messageData = messageString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any] {
            
            // Eğer bu bir push notification ile ilgili bir mesajsa
            if message.topic.contains("delivery") {
                handleDeliveryStatus(json)
            }
        }
    }
    
    private func handleDeliveryStatus(_ data: [String: Any]) {
        if let messageId = data["messageId"] as? String,
           let delivered = data["delivered"] as? Bool,
           delivered {
            // SocketIOManager'a mesajın iletildiğini bildir
            NotificationCenter.default.post(
                name: Notification.Name("MessageDelivered"),
                object: nil,
                userInfo: ["messageId": messageId]
            )
        }
    }
    
    // Diğer gerekli delegate metodları
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {}
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {}
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {}
    func mqttDidPing(_ mqtt: CocoaMQTT) {}
    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {}
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?) {
        // Bağlantı koptuğunda yeniden bağlanmayı dene
        connect()
    }
}