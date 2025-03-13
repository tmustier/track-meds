//
//  MedicationTests.swift
//  MedicationTests
//
//  Created by Thomas Mustier on 13/03/2025.
//

import XCTest
@testable import Medication

final class MedicationTests: XCTestCase {
    
    func testRefillEventCreation() {
        // Test RefillEvent creation
        let requestEvent = RefillEvent(timestamp: Date(), eventType: .requested)
        let receiveEvent = RefillEvent(timestamp: Date(), eventType: .received, pillCount: 30)
        
        XCTAssertEqual(requestEvent.eventType, .requested)
        XCTAssertNil(requestEvent.pillCount)
        
        XCTAssertEqual(receiveEvent.eventType, .received)
        XCTAssertEqual(receiveEvent.pillCount, 30)
    }
    
    func testSettingsModelRefillSettings() {
        // Check defaults
        let settings = SettingsModel()
        
        // Default values should be initialized
        XCTAssertTrue(settings.refillRemindersEnabled)
        XCTAssertEqual(settings.inventoryReminderThreshold, 7)
        XCTAssertEqual(settings.timeReminderThreshold, 30)
        
        // Test saving settings
        settings.refillRemindersEnabled = false
        settings.inventoryReminderThreshold = 10
        settings.timeReminderThreshold = 21
        
        settings.saveRefillReminderSettings()
        
        // Read settings from UserDefaults directly to verify
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "refillRemindersEnabled"))
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "inventoryReminderThreshold"), 10)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "timeReminderThreshold"), 21)
        
        // Clean up UserDefaults after test
        UserDefaults.standard.removeObject(forKey: "refillRemindersEnabled")
        UserDefaults.standard.removeObject(forKey: "inventoryReminderThreshold")
        UserDefaults.standard.removeObject(forKey: "timeReminderThreshold")
    }
    
    func testMedicationLogCompatibility() {
        // Create a medication log
        let log = MedicationLog(timestamp: Date())
        
        // Basic assertions - make sure the model wasn't broken
        XCTAssertNotNil(log.id)
        XCTAssertNotNil(log.timestamp)
    }
}
