//
//  MedicationApp.swift
//  Medication
//
//  Created by Thomas Mustier on 13/03/2025.
//

import SwiftUI
import UserNotifications

@main
struct MedicationApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        
        // Setup notification categories for refill reminders
        RefillReminderManager.setupNotificationCategories()
        
        return true
    }
    
    // This ensures notifications work even when the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    // Handle notification response when app is not active
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Get the notification identifier
        let identifier = response.notification.request.identifier
        let actionIdentifier = response.actionIdentifier
        
        // Handle refill reminder actions
        if identifier.contains("RefillReminder") && actionIdentifier != UNNotificationDefaultActionIdentifier {
            let inventory = InventoryModel.load()
            let settings = SettingsModel()
            let reminderManager = RefillReminderManager(inventory: inventory, settings: settings)
            
            if actionIdentifier == "REQUEST_REFILL" {
                reminderManager.handleRefillRequested()
            }
            
            // Note: For "RECEIVED_REFILL" we need user input so this will be handled in the app UI
            // The user will be directed to the inventory view when they open the app
        }
        
        completionHandler()
    }
}
