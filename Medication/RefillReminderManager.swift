//
//  RefillReminderManager.swift
//  Medication
//
//  Created by Thomas Mustier on 13/03/2025.
//

import Foundation
import UserNotifications
import SwiftUI

// Class to manage medication refill reminders
public class RefillReminderManager {
    // Constants for time periods
    private let twoWeeksInSeconds: TimeInterval = 60 * 60 * 24 * 14
    private let threeDaysInSeconds: TimeInterval = 60 * 60 * 24 * 3
    private let oneDayInSeconds: TimeInterval = 60 * 60 * 24
    
    // Notification identifiers
    private let inventoryReminderIdentifier = "inventoryRefillReminder"
    private let timeReminderIdentifier = "timeBasedRefillReminder"
    private let followUpReminderIdentifier = "refillFollowUpReminder"
    
    // Access to inventory and settings
    private let inventory: InventoryModel
    private let settings: SettingsModel
    
    // For testing
    var notificationCenter: UNUserNotificationCenter
    
    // Initializer
    public init(inventory: InventoryModel, 
                settings: SettingsModel,
                notificationCenter: UNUserNotificationCenter = UNUserNotificationCenter.current()) {
        self.inventory = inventory
        self.settings = settings
        self.notificationCenter = notificationCenter
    }
    
    // MARK: - Public Methods
    
    // Check and schedule appropriate reminders based on current state
    public func checkAndScheduleReminders() {
        // Don't schedule reminders if they are disabled
        if !settings.refillRemindersEnabled {
            removeAllRefillNotifications()
            return
        }
        
        // Handle different reminder states
        if inventory.isWaitingForRefill {
            // If we're waiting for a refill, check if we need a follow-up reminder
            scheduleFollowUpReminder()
        } else {
            // Otherwise, check if we need inventory or time-based reminders
            checkAndScheduleInventoryReminder()
            checkAndScheduleTimeReminder()
        }
    }
    
    // Log a refill request and manage reminders
    public func handleRefillRequested() {
        // Log the refill request
        inventory.logRefillRequested()
        
        // Remove current reminders
        removeExistingReminders()
        
        // Schedule a follow-up reminder for 3 days from now
        scheduleFollowUpReminder()
    }
    
    // Log a refill received and reset reminders
    public func handleRefillReceived(pillCount: Int) {
        // Log the refill
        inventory.logRefillReceived(pillCount: pillCount, settings: settings)
        
        // Remove all pending refill notifications
        removeAllRefillNotifications()
        
        // Recalculate reminders based on new inventory
        checkAndScheduleReminders()
    }
    
    // MARK: - Private Methods
    
    // Schedule inventory-based reminder if needed
    private func checkAndScheduleInventoryReminder() {
        if inventory.shouldShowInventoryReminder(settings: settings) {
            // Calculate when to show the reminder (now or slightly in the future)
            let reminderDate = Date().addingTimeInterval(60) // 1 minute from now
            
            // Create the reminder
            createReminderNotification(
                title: "Medication Refill Reminder",
                body: "Your medication supply is running low. You have approximately \(inventory.estimatedDaysRemaining) days remaining.",
                identifier: inventoryReminderIdentifier,
                date: reminderDate
            )
        }
    }
    
    // Schedule time-based reminder if needed
    private func checkAndScheduleTimeReminder() {
        if inventory.shouldShowTimeReminder(settings: settings) {
            // Calculate when to show the reminder (now or slightly in the future)
            let reminderDate = Date().addingTimeInterval(60) // 1 minute from now
            
            // Create the reminder
            createReminderNotification(
                title: "Medication Refill Reminder",
                body: "It's been \(settings.timeReminderThreshold) days since your last refill.",
                identifier: timeReminderIdentifier,
                date: reminderDate
            )
        }
    }
    
    // Schedule follow-up reminder after a refill request
    private func scheduleFollowUpReminder() {
        // Don't schedule if we're not waiting for a refill
        guard inventory.isWaitingForRefill, let requestDate = inventory.refillRequestDate else {
            return
        }
        
        // Check if it's been 3 days since the request
        let daysSinceRequest = Calendar.current.dateComponents([.day], from: requestDate, to: Date()).day ?? 0
        
        // Determine when to show the follow-up reminder
        let reminderDate: Date
        if daysSinceRequest >= 3 {
            // If it's already been 3+ days, schedule for tomorrow
            reminderDate = Date().addingTimeInterval(oneDayInSeconds)
        } else {
            // Otherwise, schedule for 3 days after the request
            reminderDate = requestDate.addingTimeInterval(threeDaysInSeconds)
        }
        
        // Create the reminder
        createReminderNotification(
            title: "Medication Refill Follow-Up",
            body: "Have you received your medication refill yet?",
            identifier: followUpReminderIdentifier,
            date: reminderDate
        )
    }
    
    // Create and schedule a notification
    private func createReminderNotification(title: String, body: String, identifier: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "REFILL_REMINDER"
        
        // Create a date components trigger
        let triggerComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        
        // Create the request
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Add to notification center
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling refill notification: \(error)")
            }
        }
    }
    
    // Remove existing reminders when a new state is entered
    private func removeExistingReminders() {
        let identifiers = [inventoryReminderIdentifier, timeReminderIdentifier]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    // Remove all refill-related notifications
    private func removeAllRefillNotifications() {
        let identifiers = [inventoryReminderIdentifier, timeReminderIdentifier, followUpReminderIdentifier]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    // MARK: - Notification Category Setup
    
    // Setup notification categories and actions for interactive notifications
    public static func setupNotificationCategories() {
        // Define actions for refill reminders
        let requestAction = UNNotificationAction(
            identifier: "REQUEST_REFILL",
            title: "I've requested a refill",
            options: .foreground
        )
        
        let receivedAction = UNNotificationAction(
            identifier: "RECEIVED_REFILL",
            title: "I've received my refill",
            options: .foreground
        )
        
        let reminderCategory = UNNotificationCategory(
            identifier: "REFILL_REMINDER",
            actions: [requestAction, receivedAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Register the category
        UNUserNotificationCenter.current().setNotificationCategories([reminderCategory])
    }
}