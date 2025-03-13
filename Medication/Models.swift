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

// Settings model for app preferences - moved from ContentView for better organization
public class SettingsModel: ObservableObject {
    @Published public var morningReminderTime: Date
    @Published public var notificationDelay: Int
    @Published public var dailyPillTarget: Int
    
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
        
        // Set default values if needed
        if delay == 0 {
            UserDefaults.standard.set(2, forKey: "notificationDelay")
        }
        
        if target == 0 {
            UserDefaults.standard.set(4, forKey: "dailyPillTarget")
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
}