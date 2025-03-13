//
//  InventoryModelTests.swift
//  MedicationTests
//
//  Created by Thomas Mustier on 13/03/2025.
//

import XCTest
@testable import Medication

final class InventoryModelTests: XCTestCase {
    
    var inventory: InventoryModel!
    var settings: SettingsModel!
    
    override func setUp() {
        super.setUp()
        inventory = InventoryModel(currentPillCount: 30, refillEvents: [], dailyUsageRate: 1.0)
        settings = SettingsModel()
        
        // Configure settings for testing
        settings.refillRemindersEnabled = true
        settings.inventoryReminderThreshold = 7
        settings.timeReminderThreshold = 14
    }
    
    override func tearDown() {
        inventory = nil
        settings = nil
        super.tearDown()
    }
    
    func testLogRefillRequested() {
        // Given
        XCTAssertEqual(inventory.refillEvents.count, 0)
        XCTAssertFalse(inventory.isWaitingForRefill)
        
        // When
        inventory.logRefillRequested()
        
        // Then
        XCTAssertEqual(inventory.refillEvents.count, 1)
        XCTAssertTrue(inventory.isWaitingForRefill)
        XCTAssertEqual(inventory.refillEvents[0].eventType, .requested)
        XCTAssertNil(inventory.refillEvents[0].pillCount)
    }
    
    func testLogRefillReceived() {
        // Given
        XCTAssertEqual(inventory.refillEvents.count, 0)
        XCTAssertEqual(inventory.currentPillCount, 30)
        
        // When
        inventory.logRefillReceived(pillCount: 60, settings: settings)
        
        // Then
        XCTAssertEqual(inventory.refillEvents.count, 1)
        XCTAssertEqual(inventory.currentPillCount, 60)
        XCTAssertEqual(inventory.refillEvents[0].eventType, .received)
        XCTAssertEqual(inventory.refillEvents[0].pillCount, 60)
        XCTAssertEqual(inventory.dailyUsageRate, Double(settings.dailyPillTarget))
    }
    
    func testLogMedicationTaken() {
        // Given
        XCTAssertEqual(inventory.currentPillCount, 30)
        
        // When
        inventory.logMedicationTaken()
        
        // Then
        XCTAssertEqual(inventory.currentPillCount, 29)
        
        // When - take more pills
        for _ in 0..<5 {
            inventory.logMedicationTaken()
        }
        
        // Then
        XCTAssertEqual(inventory.currentPillCount, 24)
    }
    
    func testEstimatedDaysRemaining() {
        // Given
        inventory.currentPillCount = 15
        inventory.dailyUsageRate = 1.0
        
        // Then
        XCTAssertEqual(inventory.estimatedDaysRemaining, 15)
        
        // When
        inventory.dailyUsageRate = 2.0
        
        // Then
        XCTAssertEqual(inventory.estimatedDaysRemaining, 8) // Rounded from 7.5
        
        // When - edge case of zero usage rate
        inventory.dailyUsageRate = 0.0
        
        // Then - should return a very large value to avoid division by zero
        XCTAssertEqual(inventory.estimatedDaysRemaining, 999)
    }
    
    func testShouldShowInventoryReminder() {
        // Given
        inventory.currentPillCount = 30
        inventory.dailyUsageRate = 2.0 // 15 days supply
        
        // Then - shouldn't show reminder with 15 days supply (> 7 day threshold)
        XCTAssertFalse(inventory.shouldShowInventoryReminder(settings: settings))
        
        // When - set to 10 pills (5 days supply at 2 pills/day)
        inventory.currentPillCount = 10
        
        // Then - should show reminder (5 days < 7 day threshold)
        XCTAssertTrue(inventory.shouldShowInventoryReminder(settings: settings))
        
        // When - disable reminders
        settings.refillRemindersEnabled = false
        
        // Then - shouldn't show reminder when disabled
        XCTAssertFalse(inventory.shouldShowInventoryReminder(settings: settings))
        
        // When - waiting for refill
        settings.refillRemindersEnabled = true
        inventory.logRefillRequested()
        
        // Then - shouldn't show reminder when already waiting
        XCTAssertFalse(inventory.shouldShowInventoryReminder(settings: settings))
    }
    
    func testDaysRemainingFromLastRefill() {
        // Create a refill event 15 days ago with 30 pills
        let calendar = Calendar.current
        let oldDate = calendar.date(byAdding: .day, value: -15, to: Date())!
        
        // Given (30 pills at 1.0 daily usage, 15 days ago)
        let refillEvents = [
            RefillEvent(timestamp: oldDate, eventType: .received, pillCount: 30)
        ]
        inventory = InventoryModel(currentPillCount: 15, refillEvents: refillEvents, dailyUsageRate: 1.0)
        
        // Then - should have 15 days remaining (30 total - 15 elapsed)
        XCTAssertEqual(inventory.daysRemainingFromLastRefill, 15)
        
        // When - daily usage rate is higher (2.0)
        inventory.dailyUsageRate = 2.0
        
        // Then - should have 0 days remaining (30/2 = 15 total - 15 elapsed)
        XCTAssertEqual(inventory.daysRemainingFromLastRefill, 0)
        
        // When - no refill events
        inventory = InventoryModel(currentPillCount: 10, refillEvents: [], dailyUsageRate: 1.0)
        
        // Then - should fall back to estimatedDaysRemaining
        XCTAssertEqual(inventory.daysRemainingFromLastRefill, inventory.estimatedDaysRemaining)
    }
    
    func testShouldShowTimeReminder() {
        // Create a refill event 15 days ago with 30 pills
        let calendar = Calendar.current
        let oldDate = calendar.date(byAdding: .day, value: -15, to: Date())!
        
        // Given (30 pills at 1.0 daily usage, 15 days ago)
        let refillEvents = [
            RefillEvent(timestamp: oldDate, eventType: .received, pillCount: 30)
        ]
        inventory = InventoryModel(currentPillCount: 15, refillEvents: refillEvents, dailyUsageRate: 1.0)
        settings.timeReminderThreshold = 14
        
        // Then - should NOT show reminder (15 days remaining > 14 day threshold)
        XCTAssertFalse(inventory.shouldShowTimeReminder(settings: settings))
        
        // When - set the threshold higher
        settings.timeReminderThreshold = 16
        
        // Then - SHOULD show reminder (15 days remaining < 16 day threshold)
        XCTAssertTrue(inventory.shouldShowTimeReminder(settings: settings))
        
        // When - disable reminders
        settings.refillRemindersEnabled = false
        
        // Then - shouldn't show reminder when disabled
        XCTAssertFalse(inventory.shouldShowTimeReminder(settings: settings))
        
        // When - waiting for refill
        settings.refillRemindersEnabled = true
        inventory.logRefillRequested()
        
        // Then - shouldn't show reminder when already waiting
        XCTAssertFalse(inventory.shouldShowTimeReminder(settings: settings))
    }
    
    func testLastRefillDate() {
        // Given - no refill events
        XCTAssertNotNil(inventory.lastRefillDate)
        
        // When - add refill events
        let calendar = Calendar.current
        let oldDate = calendar.date(byAdding: .day, value: -30, to: Date())!
        let newerDate = calendar.date(byAdding: .day, value: -15, to: Date())!
        
        inventory.refillEvents = [
            RefillEvent(timestamp: oldDate, eventType: .received, pillCount: 30),
            RefillEvent(timestamp: newerDate, eventType: .received, pillCount: 30)
        ]
        
        // Then - should return the most recent received event
        XCTAssertEqual(inventory.lastRefillDate, newerDate)
        
        // When - add a requested event that's newer
        let requestDate = calendar.date(byAdding: .day, value: -7, to: Date())!
        inventory.refillEvents.append(RefillEvent(timestamp: requestDate, eventType: .requested))
        
        // Then - should still return the most recent received event (not the requested one)
        XCTAssertEqual(inventory.lastRefillDate, newerDate)
    }
    
    func testRefillRequestDate() {
        // Given - no refill events
        XCTAssertNil(inventory.refillRequestDate)
        
        // When - add non-request events
        let calendar = Calendar.current
        let oldDate = calendar.date(byAdding: .day, value: -30, to: Date())!
        
        inventory.refillEvents = [
            RefillEvent(timestamp: oldDate, eventType: .received, pillCount: 30)
        ]
        
        // Then - should still be nil
        XCTAssertNil(inventory.refillRequestDate)
        
        // When - add a requested event
        let requestDate = calendar.date(byAdding: .day, value: -7, to: Date())!
        inventory.refillEvents.append(RefillEvent(timestamp: requestDate, eventType: .requested))
        
        // Then - should return the date of the requested event
        XCTAssertEqual(inventory.refillRequestDate, requestDate)
        
        // When - add a newer received event
        let receivedDate = calendar.date(byAdding: .day, value: -3, to: Date())!
        inventory.refillEvents.append(RefillEvent(timestamp: receivedDate, eventType: .received, pillCount: 30))
        
        // Then - should return nil as the latest event is a received event
        XCTAssertNil(inventory.refillRequestDate)
    }
    
    func testReset() {
        // Given
        inventory.currentPillCount = 30
        inventory.refillEvents = [
            RefillEvent(timestamp: Date(), eventType: .received, pillCount: 30)
        ]
        inventory.dailyUsageRate = 2.0
        
        // When
        inventory.reset()
        
        // Then
        XCTAssertEqual(inventory.currentPillCount, 0)
        XCTAssertTrue(inventory.refillEvents.isEmpty)
        XCTAssertEqual(inventory.dailyUsageRate, 1.0)
    }
}