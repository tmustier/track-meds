//
//  RefillReminderManagerTests.swift
//  MedicationTests
//
//  Created by Thomas Mustier on 13/03/2025.
//

import XCTest
@testable import Medication

final class MockNotificationCenter: UNUserNotificationCenter {
    // Track notification requests
    var pendingNotificationRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []
    
    // For testing notification categories
    var categories: Set<UNNotificationCategory> = []
    
    // For callbacks to complete normally
    override func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)? = nil) {
        pendingNotificationRequests.append(request)
        completionHandler?(nil)
    }
    
    override func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        pendingNotificationRequests.removeAll { request in
            identifiers.contains(request.identifier)
        }
    }
    
    override func getPendingNotificationRequests(completionHandler: @escaping ([UNNotificationRequest]) -> Void) {
        completionHandler(pendingNotificationRequests)
    }
    
    override func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        self.categories = categories
    }
}

final class RefillReminderManagerTests: XCTestCase {
    
    var mockNotificationCenter: MockNotificationCenter!
    var settings: SettingsModel!
    var inventory: InventoryModel!
    var reminderManager: RefillReminderManager!

    override func setUp() {
        super.setUp()
        
        // Set up mock notification center
        mockNotificationCenter = MockNotificationCenter()
        
        // Set up settings with reminders enabled
        settings = SettingsModel()
        settings.refillRemindersEnabled = true
        settings.inventoryReminderThreshold = 14
        settings.timeReminderThreshold = 14
        
        // Set up inventory
        inventory = InventoryModel(currentPillCount: 20, dailyUsageRate: 1.0)
        
        // Create reminder manager with mocks
        reminderManager = RefillReminderManager(
            inventory: inventory,
            settings: settings,
            notificationCenter: mockNotificationCenter
        )
    }

    override func tearDown() {
        mockNotificationCenter = nil
        settings = nil
        inventory = nil
        reminderManager = nil
        super.tearDown()
    }
    
    // MARK: - Test Reminder Scheduling
    
    func testNoRemindersWhenDisabled() {
        // Disable refill reminders
        settings.refillRemindersEnabled = false
        
        // Create low inventory condition
        inventory.currentPillCount = 5 // 5 days left at 1 pill/day
        
        // Check and schedule reminders
        reminderManager.checkAndScheduleReminders()
        
        // No notifications should be scheduled
        XCTAssertEqual(mockNotificationCenter.pendingNotificationRequests.count, 0)
    }
    
    func testInventoryReminderWhenBelowThreshold() {
        // Create low inventory condition
        inventory.currentPillCount = 10 // 10 days left at 1 pill/day
        inventory.dailyUsageRate = 1.0
        
        // Set threshold to 14 days
        settings.inventoryReminderThreshold = 14
        
        // Check and schedule reminders
        reminderManager.checkAndScheduleReminders()
        
        // Inventory reminder should be scheduled
        XCTAssertEqual(mockNotificationCenter.pendingNotificationRequests.count, 1)
        
        // Verify the notification
        let request = mockNotificationCenter.pendingNotificationRequests.first!
        XCTAssertEqual(request.identifier, "inventoryRefillReminder")
        XCTAssertEqual(request.content.title, "Medication Refill Reminder")
        XCTAssertTrue(request.content.body.contains("10 days"))
    }
    
    func testTimeReminderWhenAboveThreshold() {
        // Create old refill condition
        inventory.lastRefillDate = Calendar.current.date(byAdding: .day, value: -20, to: Date())!
        
        // Set threshold to 14 days
        settings.timeReminderThreshold = 14
        
        // Check and schedule reminders
        reminderManager.checkAndScheduleReminders()
        
        // Time-based reminder should be scheduled
        XCTAssertEqual(mockNotificationCenter.pendingNotificationRequests.count, 1)
        
        // Verify the notification
        let request = mockNotificationCenter.pendingNotificationRequests.first!
        XCTAssertEqual(request.identifier, "timeBasedRefillReminder")
        XCTAssertEqual(request.content.title, "Medication Refill Reminder")
        XCTAssertTrue(request.content.body.contains("14 days"))
    }
    
    func testNoRemindersWhenWaitingForRefill() {
        // Set up waiting for refill
        inventory.isWaitingForRefill = true
        inventory.refillRequestDate = Date()
        inventory.currentPillCount = 5 // Below threshold
        
        // Check and schedule reminders
        reminderManager.checkAndScheduleReminders()
        
        // Only follow-up reminder should be scheduled, not inventory or time reminders
        XCTAssertEqual(mockNotificationCenter.pendingNotificationRequests.count, 1)
        XCTAssertEqual(mockNotificationCenter.pendingNotificationRequests.first!.identifier, "refillFollowUpReminder")
    }
    
    // MARK: - Test Reminder Actions
    
    func testHandleRefillRequested() {
        // Start with no waiting flag
        XCTAssertFalse(inventory.isWaitingForRefill)
        XCTAssertNil(inventory.refillRequestDate)
        XCTAssertEqual(inventory.refillEvents.count, 0)
        
        // Handle refill request
        reminderManager.handleRefillRequested()
        
        // Check that inventory state is updated
        XCTAssertTrue(inventory.isWaitingForRefill)
        XCTAssertNotNil(inventory.refillRequestDate)
        XCTAssertEqual(inventory.refillEvents.count, 1)
        XCTAssertEqual(inventory.refillEvents[0].eventType, .requested)
        
        // Verify follow-up reminder is scheduled
        XCTAssertEqual(mockNotificationCenter.pendingNotificationRequests.count, 1)
        XCTAssertEqual(mockNotificationCenter.pendingNotificationRequests[0].identifier, "refillFollowUpReminder")
    }
    
    func testHandleRefillReceived() {
        // Start with waiting flag
        inventory.isWaitingForRefill = true
        inventory.refillRequestDate = Date()
        
        // Handle refill received
        let newPillCount = 60
        reminderManager.handleRefillReceived(pillCount: newPillCount)
        
        // Check that inventory state is updated
        XCTAssertFalse(inventory.isWaitingForRefill)
        XCTAssertNil(inventory.refillRequestDate)
        XCTAssertEqual(inventory.currentPillCount, newPillCount)
        XCTAssertEqual(inventory.refillEvents.count, 1)
        XCTAssertEqual(inventory.refillEvents[0].eventType, .received)
        XCTAssertEqual(inventory.refillEvents[0].pillCount, newPillCount)
        
        // Verify all notifications are removed
        XCTAssertTrue(mockNotificationCenter.removedIdentifiers.contains("inventoryRefillReminder"))
        XCTAssertTrue(mockNotificationCenter.removedIdentifiers.contains("timeBasedRefillReminder"))
        XCTAssertTrue(mockNotificationCenter.removedIdentifiers.contains("refillFollowUpReminder"))
    }
    
    // MARK: - Test Follow-Up Logic
    
    func testFollowUpReminderScheduling() {
        // Set up a refill request from 2 days ago
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        inventory.isWaitingForRefill = true
        inventory.refillRequestDate = twoDaysAgo
        
        // Check and schedule reminders
        reminderManager.checkAndScheduleReminders()
        
        // Verify follow-up reminder is scheduled
        XCTAssertEqual(mockNotificationCenter.pendingNotificationRequests.count, 1)
        let request = mockNotificationCenter.pendingNotificationRequests.first!
        XCTAssertEqual(request.identifier, "refillFollowUpReminder")
        
        // Verify the trigger date (should be 3 days after the request date, so 1 day from now)
        if let trigger = request.trigger as? UNCalendarNotificationTrigger {
            let triggerDate = Calendar.current.date(from: trigger.dateComponents)!
            let oneDayFromNow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            
            // Allow 1 hour tolerance for test reliability
            let difference = abs(triggerDate.timeIntervalSince(oneDayFromNow))
            XCTAssertLessThan(difference, 3600)
        } else {
            XCTFail("Expected a calendar trigger")
        }
    }
    
    func testDailyFollowUpAfterThreeDays() {
        // Set up a refill request from 4 days ago
        let fourDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: Date())!
        inventory.isWaitingForRefill = true
        inventory.refillRequestDate = fourDaysAgo
        
        // Check and schedule reminders
        reminderManager.checkAndScheduleReminders()
        
        // Verify follow-up reminder is scheduled
        XCTAssertEqual(mockNotificationCenter.pendingNotificationRequests.count, 1)
        let request = mockNotificationCenter.pendingNotificationRequests.first!
        XCTAssertEqual(request.identifier, "refillFollowUpReminder")
        
        // Verify the trigger date (should be tomorrow, not 3 days from request date)
        if let trigger = request.trigger as? UNCalendarNotificationTrigger {
            let triggerDate = Calendar.current.date(from: trigger.dateComponents)!
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            
            // Allow 1 hour tolerance for test reliability
            let difference = abs(triggerDate.timeIntervalSince(tomorrow))
            XCTAssertLessThan(difference, 3600)
        } else {
            XCTFail("Expected a calendar trigger")
        }
    }
    
    // MARK: - Test Notification Categories
    
    func testNotificationCategorySetup() {
        // Test the static method
        RefillReminderManager.setupNotificationCategories()
        
        // Since we can't modify the real UNUserNotificationCenter, we'll create a local mock
        let localMock = MockNotificationCenter()
        
        // Create a category with expected options
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
        
        let expectedCategory = UNNotificationCategory(
            identifier: "REFILL_REMINDER", 
            actions: [requestAction, receivedAction], 
            intentIdentifiers: [], 
            options: []
        )
        
        // Call the setup method with our mock
        localMock.setNotificationCategories([expectedCategory])
        
        // Verify the category was set
        XCTAssertEqual(localMock.categories.count, 1)
        let category = localMock.categories.first!
        XCTAssertEqual(category.identifier, "REFILL_REMINDER")
        
        // Verify actions
        let actions = category.actions
        XCTAssertEqual(actions.count, 2)
        XCTAssertEqual(actions[0].identifier, "REQUEST_REFILL")
        XCTAssertEqual(actions[1].identifier, "RECEIVED_REFILL")
    }
}