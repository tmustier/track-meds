//
//  ModelTests.swift
//  MedicationTests
//
//  Created by Thomas Mustier on 13/03/2025.
//

import XCTest
@testable import Medication

final class ModelTests: XCTestCase {
    
    // MARK: - RefillEvent Tests
    
    func testRefillEventInitialization() {
        // Test requested event
        let requestedEvent = RefillEvent(timestamp: Date(), eventType: .requested)
        XCTAssertEqual(requestedEvent.eventType, .requested)
        XCTAssertNil(requestedEvent.pillCount)
        
        // Test received event with pill count
        let pillCount = 30
        let receivedEvent = RefillEvent(timestamp: Date(), eventType: .received, pillCount: pillCount)
        XCTAssertEqual(receivedEvent.eventType, .received)
        XCTAssertEqual(receivedEvent.pillCount, pillCount)
    }
    
    func testRefillEventEquality() {
        let id = UUID()
        let timestamp = Date()
        
        let event1 = RefillEvent(id: id, timestamp: timestamp, eventType: .requested)
        let event2 = RefillEvent(id: id, timestamp: timestamp, eventType: .requested)
        let event3 = RefillEvent(timestamp: timestamp, eventType: .requested) // Different ID
        
        XCTAssertEqual(event1, event2)
        XCTAssertNotEqual(event1, event3)
    }
    
    // MARK: - InventoryModel Tests
    
    func testInventoryModelInitialization() {
        let model = InventoryModel()
        
        // Check default values
        XCTAssertEqual(model.currentPillCount, 0)
        XCTAssertEqual(model.dailyUsageRate, 0.0)
        XCTAssertFalse(model.isWaitingForRefill)
        XCTAssertNil(model.refillRequestDate)
        XCTAssertTrue(model.refillEvents.isEmpty)
    }
    
    func testEstimatedDaysRemaining() {
        let model = InventoryModel(currentPillCount: 20, dailyUsageRate: 2.0)
        
        // 20 pills ÷ 2 pills per day = 10 days
        XCTAssertEqual(model.estimatedDaysRemaining, 10)
        
        // Test with zero usage rate (should return current count)
        let zeroUsageModel = InventoryModel(currentPillCount: 15, dailyUsageRate: 0.0)
        XCTAssertEqual(zeroUsageModel.estimatedDaysRemaining, 15)
        
        // Test with zero pills (should return 0 days)
        let zeroPillsModel = InventoryModel(currentPillCount: 0, dailyUsageRate: 1.0)
        XCTAssertEqual(zeroPillsModel.estimatedDaysRemaining, 0)
    }
    
    func testLogMedicationTaken() {
        let model = InventoryModel(currentPillCount: 10)
        
        model.logMedicationTaken()
        XCTAssertEqual(model.currentPillCount, 9)
        
        // Test behavior at zero pills
        model.currentPillCount = 1
        model.logMedicationTaken()
        XCTAssertEqual(model.currentPillCount, 0)
        
        model.logMedicationTaken() // Should not go below zero
        XCTAssertEqual(model.currentPillCount, 0)
    }
    
    func testLogRefillRequested() {
        let model = InventoryModel()
        
        model.logRefillRequested()
        
        XCTAssertTrue(model.isWaitingForRefill)
        XCTAssertNotNil(model.refillRequestDate)
        XCTAssertEqual(model.refillEvents.count, 1)
        XCTAssertEqual(model.refillEvents[0].eventType, .requested)
    }
    
    func testLogRefillReceived() {
        let model = InventoryModel(isWaitingForRefill: true, refillRequestDate: Date())
        let newPillCount = 60
        
        model.logRefillReceived(pillCount: newPillCount)
        
        XCTAssertEqual(model.currentPillCount, newPillCount)
        XCTAssertFalse(model.isWaitingForRefill)
        XCTAssertNil(model.refillRequestDate)
        XCTAssertEqual(model.refillEvents.count, 1)
        XCTAssertEqual(model.refillEvents[0].eventType, .received)
        XCTAssertEqual(model.refillEvents[0].pillCount, newPillCount)
    }
    
    func testUpdateUsageRate() {
        // Test with initial refill
        let initialRefill = RefillEvent(timestamp: Date(), eventType: .received, pillCount: 30)
        let model = InventoryModel(
            currentPillCount: 20,
            lastRefillDate: Calendar.current.date(byAdding: .day, value: -10, to: Date())!,
            refillEvents: [initialRefill]
        )
        
        model.updateUsageRate()
        
        // Should calculate: (30 - 20) ÷ 10 = 1.0 pill per day
        XCTAssertEqual(model.dailyUsageRate, 1.0)
        
        // Test with no refill events
        let emptyModel = InventoryModel()
        emptyModel.updateUsageRate()
        
        // Should default to 1.0 pill per day
        XCTAssertEqual(emptyModel.dailyUsageRate, 1.0)
    }
    
    func testShouldShowInventoryReminder() {
        let settings = SettingsModel()
        settings.refillRemindersEnabled = true
        settings.inventoryReminderThreshold = 7
        
        // Test case: Not waiting for refill, below threshold
        let lowInventory = InventoryModel(currentPillCount: 3, dailyUsageRate: 1.0)
        XCTAssertTrue(lowInventory.shouldShowInventoryReminder(settings: settings))
        
        // Test case: Not waiting for refill, above threshold
        let highInventory = InventoryModel(currentPillCount: 30, dailyUsageRate: 1.0)
        XCTAssertFalse(highInventory.shouldShowInventoryReminder(settings: settings))
        
        // Test case: Waiting for refill
        let waitingModel = InventoryModel(currentPillCount: 3, dailyUsageRate: 1.0, isWaitingForRefill: true)
        XCTAssertFalse(waitingModel.shouldShowInventoryReminder(settings: settings))
        
        // Test case: Reminders disabled
        settings.refillRemindersEnabled = false
        XCTAssertFalse(lowInventory.shouldShowInventoryReminder(settings: settings))
    }
    
    func testShouldShowTimeReminder() {
        let settings = SettingsModel()
        settings.refillRemindersEnabled = true
        settings.timeReminderThreshold = 14
        
        // Test case: Not waiting for refill, below threshold (recent refill)
        let recentRefill = InventoryModel(
            lastRefillDate: Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        )
        XCTAssertFalse(recentRefill.shouldShowTimeReminder(settings: settings))
        
        // Test case: Not waiting for refill, above threshold (old refill)
        let oldRefill = InventoryModel(
            lastRefillDate: Calendar.current.date(byAdding: .day, value: -20, to: Date())!
        )
        XCTAssertTrue(oldRefill.shouldShowTimeReminder(settings: settings))
        
        // Test case: Waiting for refill
        let waitingModel = InventoryModel(
            lastRefillDate: Calendar.current.date(byAdding: .day, value: -20, to: Date())!,
            isWaitingForRefill: true
        )
        XCTAssertFalse(waitingModel.shouldShowTimeReminder(settings: settings))
        
        // Test case: Reminders disabled
        settings.refillRemindersEnabled = false
        XCTAssertFalse(oldRefill.shouldShowTimeReminder(settings: settings))
    }
    
    // MARK: - Codable Tests
    
    func testInventoryModelCodable() {
        // Create a model with some test data
        let refillEvent = RefillEvent(timestamp: Date(), eventType: .received, pillCount: 30)
        let originalModel = InventoryModel(
            currentPillCount: 25,
            lastRefillDate: Date(),
            refillEvents: [refillEvent],
            dailyUsageRate: 1.5
        )
        
        // Encode and decode
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        do {
            let data = try encoder.encode(originalModel)
            let decodedModel = try decoder.decode(InventoryModel.self, from: data)
            
            // Verify properties
            XCTAssertEqual(decodedModel.currentPillCount, originalModel.currentPillCount)
            XCTAssertEqual(decodedModel.dailyUsageRate, originalModel.dailyUsageRate)
            XCTAssertEqual(decodedModel.refillEvents.count, originalModel.refillEvents.count)
            XCTAssertEqual(decodedModel.refillEvents[0].pillCount, originalModel.refillEvents[0].pillCount)
        } catch {
            XCTFail("Encoding/decoding failed: \(error)")
        }
    }
}