//
//  Models.swift
//  Medication
//
//  Created by Thomas Mustier on 13/03/2025.
//

import Foundation
import SwiftUI

// Shared model for medication logs
public struct MedicationLog: Identifiable, Codable, Hashable {
    public let id: UUID
    public let timestamp: Date
    
    public init(id: UUID = UUID(), timestamp: Date) {
        self.id = id
        self.timestamp = timestamp
    }
    
    // Add Hashable conformance for use in ForEach
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: MedicationLog, rhs: MedicationLog) -> Bool {
        return lhs.id == rhs.id
    }
}

// Enum for refill event types
public enum RefillEventType: String, Codable {
    case requested = "Requested"
    case received = "Received"
}

// Model for storing refill events
public struct RefillEvent: Identifiable, Codable, Hashable {
    public let id: UUID
    public let timestamp: Date
    public let eventType: RefillEventType
    public let pillCount: Int?
    
    public init(id: UUID = UUID(), timestamp: Date, eventType: RefillEventType, pillCount: Int? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.pillCount = pillCount
    }
    
    // Add Hashable conformance for use in ForEach
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: RefillEvent, rhs: RefillEvent) -> Bool {
        return lhs.id == rhs.id
    }
}

// Model for inventory management
public class InventoryModel: ObservableObject {
    // Published properties that trigger UI updates
    @Published public var currentPillCount: Int
    @Published public var refillEvents: [RefillEvent]
    @Published public var dailyUsageRate: Double
    
    // Computed properties for refill status
    public var isWaitingForRefill: Bool {
        guard let lastEvent = refillEvents.sorted(by: { $0.timestamp > $1.timestamp }).first else {
            return false
        }
        return lastEvent.eventType == .requested
    }
    
    public var refillRequestDate: Date? {
        let sortedEvents = refillEvents.sorted(by: { $0.timestamp > $1.timestamp })
        guard let lastEvent = sortedEvents.first, lastEvent.eventType == .requested else {
            return nil
        }
        return lastEvent.timestamp
    }
    
    public var lastRefillDate: Date {
        let receivedEvents = refillEvents.filter { $0.eventType == .received }
            .sorted(by: { $0.timestamp > $1.timestamp })
        
        return receivedEvents.first?.timestamp ?? Date()
    }
    
    public var estimatedDaysRemaining: Int {
        guard dailyUsageRate > 0 else { return 999 } // Avoid division by zero
        let daysRemaining = Double(currentPillCount) / dailyUsageRate
        return Int(daysRemaining.rounded())
    }
    
    public var estimatedDepletionDate: Date {
        let daysRemaining = Double(estimatedDaysRemaining)
        return Calendar.current.date(byAdding: .day, value: Int(daysRemaining), to: Date()) ?? Date()
    }
    
    // Initializer
    public init(currentPillCount: Int = 0, lastRefillDate: Date? = nil, refillEvents: [RefillEvent] = [], dailyUsageRate: Double = 0.0) {
        self.currentPillCount = currentPillCount
        self.refillEvents = refillEvents
        self.dailyUsageRate = dailyUsageRate
        
        // If a specific lastRefillDate is provided, add a refill event for it
        if let lastRefillDate = lastRefillDate, refillEvents.isEmpty {
            self.refillEvents.append(
                RefillEvent(timestamp: lastRefillDate, eventType: .received, pillCount: currentPillCount)
            )
        }
    }
    
    // MARK: - Persistence Methods
    
    // Save inventory data to UserDefaults
    public func save() {
        UserDefaults.standard.set(currentPillCount, forKey: "inventoryPillCount")
        
        if let encoded = try? JSONEncoder().encode(refillEvents) {
            UserDefaults.standard.set(encoded, forKey: "inventoryRefillEvents")
        }
        
        UserDefaults.standard.set(dailyUsageRate, forKey: "inventoryDailyUsageRate")
    }
    
    // Static method to load inventory data from UserDefaults
    public static func load() -> InventoryModel {
        let inventory = InventoryModel()
        
        // Load pill count
        inventory.currentPillCount = UserDefaults.standard.integer(forKey: "inventoryPillCount")
        
        // Load refill events
        if let data = UserDefaults.standard.data(forKey: "inventoryRefillEvents") {
            if let decoded = try? JSONDecoder().decode([RefillEvent].self, from: data) {
                inventory.refillEvents = decoded
            }
        }
        
        // Load usage rate
        inventory.dailyUsageRate = UserDefaults.standard.double(forKey: "inventoryDailyUsageRate")
        
        // If no usage rate is set, default to the daily target
        let settings = SettingsModel()
        if inventory.dailyUsageRate == 0 {
            inventory.dailyUsageRate = Double(settings.dailyPillTarget)
            inventory.save()
        }
        
        return inventory
    }
    
    // MARK: - Refill Management Methods
    
    // Log a refill request
    public func logRefillRequested() {
        let newEvent = RefillEvent(
            timestamp: Date(),
            eventType: .requested
        )
        
        refillEvents.append(newEvent)
        save()
    }
    
    // Log a refill received
    public func logRefillReceived(pillCount: Int, settings: SettingsModel) {
        let newEvent = RefillEvent(
            timestamp: Date(),
            eventType: .received,
            pillCount: pillCount
        )
        
        refillEvents.append(newEvent)
        
        // Update the pill count
        self.currentPillCount = pillCount
        
        // Update the daily usage rate based on settings
        updateDailyUsageRate(settings: settings)
        
        save()
    }
    
    // Log a medication taken - reduce inventory
    public func logMedicationTaken() {
        if currentPillCount > 0 {
            currentPillCount -= 1
            save()
        }
    }
    
    // Calculate daily usage rate based on settings
    public func updateDailyUsageRate(settings: SettingsModel) {
        // Use the daily target from settings
        dailyUsageRate = Double(settings.dailyPillTarget)
        
        save()
    }
    
    // MARK: - Reminder Helper Methods
    
    // Check if an inventory-based reminder should be shown
    public func shouldShowInventoryReminder(settings: SettingsModel) -> Bool {
        // Don't remind if reminders are disabled
        if !settings.refillRemindersEnabled { return false }
        
        // Don't remind if we're already waiting for a refill
        if isWaitingForRefill { return false }
        
        // Check if we're below the threshold
        return estimatedDaysRemaining <= settings.inventoryReminderThreshold
    }
    
    // Check if a time-based reminder should be shown
    public func shouldShowTimeReminder(settings: SettingsModel) -> Bool {
        // Don't remind if reminders are disabled
        if !settings.refillRemindersEnabled { return false }
        
        // Don't remind if we're already waiting for a refill
        if isWaitingForRefill { return false }
        
        // Get days since last refill
        let daysSinceLastRefill = Calendar.current.dateComponents(
            [.day],
            from: lastRefillDate,
            to: Date()
        ).day ?? 0
        
        // Check if we're at or past the threshold
        return daysSinceLastRefill >= settings.timeReminderThreshold
    }
    
    // Reset all inventory data (for testing)
    public func reset() {
        currentPillCount = 0
        refillEvents = []
        dailyUsageRate = 1.0
        save()
    }
}

// Settings model for app preferences - moved from ContentView for better organization
public class SettingsModel: ObservableObject {
    @Published public var morningReminderTime: Date
    @Published public var notificationDelay: Int
    @Published public var dailyPillTarget: Int
    
    // Refill reminder settings
    @Published public var refillRemindersEnabled: Bool
    @Published public var inventoryReminderThreshold: Int // Days remaining
    @Published public var timeReminderThreshold: Int // Days since last refill
    
    public init() {
        // Load saved values or use defaults for morning reminder time
        let hour = UserDefaults.standard.integer(forKey: "morningReminderHour")
        let minute = UserDefaults.standard.integer(forKey: "morningReminderMinute")
        
        // If no saved values, use 9:00 AM as default
        let defaultHour = hour == 0 ? 9 : hour
        let defaultMinute = (hour == 0 && minute == 0) ? 0 : minute
        
        // Create date with hour and minute
        var components = DateComponents()
        components.hour = defaultHour
        components.minute = defaultMinute
        self.morningReminderTime = Calendar.current.date(from: components) ?? Date()
        
        // Load notification delay (default 2 hours)
        let delay = UserDefaults.standard.integer(forKey: "notificationDelay")
        self.notificationDelay = delay == 0 ? 2 : delay
        
        // Load daily pill target (default 4)
        let target = UserDefaults.standard.integer(forKey: "dailyPillTarget")
        self.dailyPillTarget = target == 0 ? 4 : target
        
        // Load refill reminder settings
        self.refillRemindersEnabled = UserDefaults.standard.bool(forKey: "refillRemindersEnabled")
        
        // Load inventory threshold (default 7 days)
        let inventoryThreshold = UserDefaults.standard.integer(forKey: "inventoryReminderThreshold")
        self.inventoryReminderThreshold = inventoryThreshold == 0 ? 7 : inventoryThreshold
        
        // Load time threshold (default 30 days)
        let timeThreshold = UserDefaults.standard.integer(forKey: "timeReminderThreshold")
        self.timeReminderThreshold = timeThreshold == 0 ? 30 : timeThreshold
        
        // Set default values if needed
        if delay == 0 {
            UserDefaults.standard.set(2, forKey: "notificationDelay")
        }
        
        if target == 0 {
            UserDefaults.standard.set(4, forKey: "dailyPillTarget")
        }
        
        // Set default refill reminder settings if not already set
        if UserDefaults.standard.object(forKey: "refillRemindersEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "refillRemindersEnabled")
        }
        
        if inventoryThreshold == 0 {
            UserDefaults.standard.set(7, forKey: "inventoryReminderThreshold")
        }
        
        if timeThreshold == 0 {
            UserDefaults.standard.set(30, forKey: "timeReminderThreshold")
        }
    }
    
    // Save settings when values change
    public func saveMorningTime() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: morningReminderTime)
        if let hour = components.hour, let minute = components.minute {
            UserDefaults.standard.set(hour, forKey: "morningReminderHour")
            UserDefaults.standard.set(minute, forKey: "morningReminderMinute")
        }
    }
    
    public func saveNotificationDelay() {
        UserDefaults.standard.set(notificationDelay, forKey: "notificationDelay")
    }
    
    public func saveDailyPillTarget() {
        UserDefaults.standard.set(dailyPillTarget, forKey: "dailyPillTarget")
    }
    
    // Save refill reminder settings
    public func saveRefillReminderSettings() {
        UserDefaults.standard.set(refillRemindersEnabled, forKey: "refillRemindersEnabled")
        UserDefaults.standard.set(inventoryReminderThreshold, forKey: "inventoryReminderThreshold")
        UserDefaults.standard.set(timeReminderThreshold, forKey: "timeReminderThreshold")
    }
}