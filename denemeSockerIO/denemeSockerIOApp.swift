//
//  denemeSockerIOApp.swift
//  denemeSockerIO
//
//  Created by Emre Aşcı on 21.11.2024.
//

import SwiftUI
import Firebase
import FirebaseCore

@main
struct ChatApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    let persistenceController = CoreDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            ChatView(defaultUsername: "Simulator-iPhone")
                .environment(\.managedObjectContext, persistenceController.viewContext)
        }
    }
}
