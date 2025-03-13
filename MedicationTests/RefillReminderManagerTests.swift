//
//  RefillReminderManagerTests.swift
//  MedicationTests
//
//  Created by Thomas Mustier on 13/03/2025.
//

import XCTest
import UserNotifications
@testable import Medication

// Mock UNUserNotificationCenter for testing purposes
class MockNotificationCenter: UNUserNotificationCenter {
    // Store notification requests for testing
    var pendingRequests: [UNNotificationRequest] = []
    
    // Track which notifications were removed
    var removedIdentifiers: [String] = []
    
    // Track authorization status
    var authorizationStatus: UNAuthorizationStatus = .authorized
    
    // Mock implementation of adding requests
    override func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)? = nil) {
        pendingRequests.append(request)
        completionHandler?(nil)
    }
    
    // Mock implementation of removing requests
    override func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        // Remove matching requests from pendingRequests
        pendingRequests.removeAll { request in
            identifiers.contains(request.identifier)
        }
    }
    
    // Mock implementation for getting pending requests
    override func getPendingNotificationRequests(completionHandler: @escaping ([UNNotificationRequest]) -> Void) {
        completionHandler(pendingRequests)
    }
    
    // Mock implementation for getting notification settings
    override func getNotificationSettings(completionHandler: @escaping (UNNotificationSettings) -> Void) {
        let settings = MockNotificationSettings(authorizationStatus: authorizationStatus)
        completionHandler(settings)
    }
    
    // Helper method to check if a notification exists with a specific identifier
    func hasNotificationWith(identifier: String) -> Bool {
        return pendingRequests.contains { $0.identifier == identifier }
    }
    
    // Helper to reset the state between tests
    func reset() {
        pendingRequests = []
        removedIdentifiers = []
    }
}

// Mock UNNotificationSettings
class MockNotificationSettings: UNNotificationSettings {
    private let _authorizationStatus: UNAuthorizationStatus
    
    init(authorizationStatus: UNAuthorizationStatus) {
        self._authorizationStatus = authorizationStatus
        super.init()
    }
    
    override var authorizationStatus: UNAuthorizationStatus {
        return _authorizationStatus
    }
}

final class RefillReminderManagerTests: XCTestCase {
    
    var inventory: InventoryModel!
    var settings: SettingsModel!
    var mockNotificationCenter: MockNotificationCenter!
    var reminderManager: RefillReminderManager!
    
    override func setUp() {
        super.setUp()
        inventory = InventoryModel(currentPillCount: 30, refillEvents: [], dailyUsageRate: 1.0)
        settings = SettingsModel()
        mockNotificationCenter = MockNotificationCenter()
        reminderManager = RefillReminderManager(
            inventory: inventory,
            settings: settings,
            notificationCenter: mockNotificationCenter
        )
        
        // Configure settings for testing
        settings.refillRemindersEnabled = true
        settings.inventoryReminderThreshold = 7
        settings.timeReminderThreshold = 14
    }
    
    override func tearDown() {
        mockNotificationCenter.reset()
        inventory = nil
        settings = nil
        mockNotificationCenter = nil
        reminderManager = nil
        super.tearDown()
    }
    
    func testCheckAndScheduleRemindersDisabled() {
        // Given
        settings.refillRemindersEnabled = false
        
        // When
        reminderManager.checkAndScheduleReminders()
        
        // Then
        XCTAssertTrue(mockNotificationCenter.pendingRequests.isEmpty)
        XCTAssertTrue(mockNotificationCenter.removedIdentifiers.count > 0)
    }
    
    func testHandleRefillRequested() {
        // Given
        XCTAssertFalse(inventory.isWaitingForRefill)
        XCTAssertEqual(inventory.refillEvents.count, 0)
        
        // When
        reminderManager.handleRefillRequested()
        
        // Then
        XCTAssertTrue(inventory.isWaitingForRefill)
        XCTAssertEqual(inventory.refillEvents.count, 1)
        XCTAssertEqual(inventory.refillEvents[0].eventType, .requested)
        
        // Should have one follow-up reminder
        XCTAssertEqual(mockNotificationCenter.pendingRequests.count, 1)
        XCTAssertTrue(mockNotificationCenter.hasNotificationWith(identifier: "refillFollowUpReminder"))
    }
    
    func testHandleRefillReceived() {
        // Given
        inventory.logRefillRequested() // First request a refill
        mockNotificationCenter.reset() // Clear mock state
        
        // When
        reminderManager.handleRefillReceived(pillCount: 60)
        
        // Then
        XCTAssertFalse(inventory.isWaitingForRefill)
        XCTAssertEqual(inventory.refillEvents.count, 2)
        XCTAssertEqual(inventory.refillEvents[1].eventType, .received)
        XCTAssertEqual(inventory.refillEvents[1].pillCount, 60)
        XCTAssertEqual(inventory.currentPillCount, 60)
        XCTAssertEqual(inventory.dailyUsageRate, Double(settings.dailyPillTarget))
        
        // All refill notifications should be removed
        XCTAssertTrue(mockNotificationCenter.removedIdentifiers.contains("inventoryRefillReminder"))
        XCTAssertTrue(mockNotificationCenter.removedIdentifiers.contains("timeBasedRefillReminder"))
        XCTAssertTrue(mockNotificationCenter.removedIdentifiers.contains("refillFollowUpReminder"))
    }
    
    func testInventoryReminderScheduling() {
        // Given - set inventory low enough to trigger reminder
        inventory.currentPillCount = 5 // 5 days supply with 1.0 daily usage
        
        // When
        reminderManager.checkAndScheduleReminders()
        
        // Then - should have an inventory-based reminder
        XCTAssertEqual(mockNotificationCenter.pendingRequests.count, 1)
        XCTAssertTrue(mockNotificationCenter.hasNotificationWith(identifier: "inventoryRefillReminder"))
        
        // Check content
        let request = mockNotificationCenter.pendingRequests.first!
        XCTAssertEqual(request.content.title, "Medication Refill Reminder")
        XCTAssertTrue(request.content.body.contains("running low"))
    }
    
    func testTimeReminderScheduling() {
        // Given - add a refill event from 15 days ago
        let calendar = Calendar.current
        let oldDate = calendar.date(byAdding: .day, value: -15, to: Date())!
        inventory.refillEvents = [
            RefillEvent(timestamp: oldDate, eventType: .received, pillCount: 30)
        ]
        
        // When
        reminderManager.checkAndScheduleReminders()
        
        // Then - should have a time-based reminder
        XCTAssertEqual(mockNotificationCenter.pendingRequests.count, 1)
        XCTAssertTrue(mockNotificationCenter.hasNotificationWith(identifier: "timeBasedRefillReminder"))
        
        // Check content
        let request = mockNotificationCenter.pendingRequests.first!
        XCTAssertEqual(request.content.title, "Medication Refill Reminder")
        XCTAssertTrue(request.content.body.contains("14 days"))
    }
    
    func testFollowUpReminderScheduling() {
        // Given - request a refill 2 days ago
        let calendar = Calendar.current
        let requestDate = calendar.date(byAdding: .day, value: -2, to: Date())!
        inventory.refillEvents = [
            RefillEvent(timestamp: requestDate, eventType: .requested)
        ]
        
        // When
        reminderManager.checkAndScheduleReminders()
        
        // Then - should have a follow-up reminder in 1 day (3 days after request)
        XCTAssertEqual(mockNotificationCenter.pendingRequests.count, 1)
        XCTAssertTrue(mockNotificationCenter.hasNotificationWith(identifier: "refillFollowUpReminder"))
        
        // Check content
        let request = mockNotificationCenter.pendingRequests.first!
        XCTAssertEqual(request.content.title, "Medication Refill Follow-Up")
    }
}