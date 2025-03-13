//
//  ContentView.swift
//  Medication
//
//  Created by Thomas Mustier on 13/03/2025.
//

import SwiftUI
import UserNotifications
import Foundation
import Combine

struct ContentView: View {
    @StateObject private var settings = SettingsModel()
    @StateObject private var inventory = InventoryModel.load()
    
    @State private var medicationLogs: [MedicationLog] = []
    @State private var todayCount: Int = 0
    @State private var showingDatePicker = false
    @State private var showingSettings = false
    @State private var showingHistory = false
    @State private var selectedDate = Date()
    @State private var notificationsEnabled = false
    @State private var nextPillTime: Date? = nil
    @State private var showUndoAlert = false
    @State private var lastMidnightCheck: Date = UserDefaults.standard.object(forKey: "lastMidnightCheck") as? Date ?? Date()
    
    private var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    private var fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    private func isSameDay(date1: Date, date2: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date1, inSameDayAs: date2)
    }
    
    private func updateTodayCount() {
        let today = Date()
        todayCount = medicationLogs.filter { isSameDay(date1: $0.timestamp, date2: today) }.count
    }
    
    private func checkForDateChange() {
        let now = Date()
        let calendar = Calendar.current
        
        // Check if we've crossed midnight since the last check
        if !calendar.isDate(lastMidnightCheck, inSameDayAs: now) {
            // Day has changed, update the count
            updateTodayCount()
            updateNextPillTime()
            
            if notificationsEnabled {
                scheduleNotifications()
            }
            
            // Reset the morning notification
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["morningReminder"])
            scheduleDailyMorningNotification()
        }
        
        // Update the last check time
        lastMidnightCheck = now
        UserDefaults.standard.set(now, forKey: "lastMidnightCheck")
    }
    
    private func loadMedicationLogs() {
        if let data = UserDefaults.standard.data(forKey: "medicationLogs") {
            if let decoded = try? JSONDecoder().decode([MedicationLog].self, from: data) {
                medicationLogs = decoded
                updateTodayCount()
                updateNextPillTime()
            }
        }
        
        // Load notification permission status
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
    }
    
    private func saveMedicationLogs() {
        if let encoded = try? JSONEncoder().encode(medicationLogs) {
            UserDefaults.standard.set(encoded, forKey: "medicationLogs")
        }
    }
    
    private func addMedication() {
        let newLog = MedicationLog(timestamp: Date())
        medicationLogs.append(newLog)
        medicationLogs.sort { $0.timestamp > $1.timestamp }
        updateTodayCount()
        saveMedicationLogs()
        updateNextPillTime()
        
        // Update inventory pill count
        inventory.logMedicationTaken()
        
        if notificationsEnabled {
            scheduleNotifications()
        }
    }
    
    private func addMedicationAt(date: Date) {
        medicationLogs.append(MedicationLog(timestamp: date))
        medicationLogs.sort { $0.timestamp > $1.timestamp }
        updateTodayCount()
        saveMedicationLogs()
        updateNextPillTime()
        showingDatePicker = false
        
        // Only update inventory for today's medications
        if Calendar.current.isDateInToday(date) {
            inventory.logMedicationTaken()
        }
        
        if notificationsEnabled {
            scheduleNotifications()
        }
    }
    
    private func deleteMedication(at indexSet: IndexSet, from logs: [MedicationLog]) {
        // Find the corresponding indices in the main array
        let itemsToDelete = indexSet.map { logs[$0] }
        for item in itemsToDelete {
            if let index = medicationLogs.firstIndex(where: { $0.id == item.id }) {
                medicationLogs.remove(at: index)
            }
        }
        updateTodayCount()
        saveMedicationLogs()
        updateNextPillTime()
        
        if notificationsEnabled {
            scheduleNotifications()
        }
    }
    
    private func undoLastMedication() {
        guard !medicationLogs.isEmpty else { return }
        
        // Check if the most recent log was created within the last 5 minutes
        let now = Date()
        let timeInterval = now.timeIntervalSince(medicationLogs[0].timestamp)
        let fiveMinutesInSeconds: TimeInterval = 5 * 60
        
        guard timeInterval <= fiveMinutesInSeconds else {
            showUndoAlert = true
            return
        }
        
        // Check if log is from today (only adjust inventory for today's logs)
        let isFromToday = Calendar.current.isDateInToday(medicationLogs[0].timestamp)
        
        // Remove the most recent medication log
        medicationLogs.removeFirst() // removeFirst because they're sorted newest first
        
        // If we're undoing a log from today, adjust the inventory
        if isFromToday && inventory.currentPillCount < 999 {
            // Increment pill count (with a reasonable max)
            inventory.currentPillCount += 1
            inventory.save()
        }
        
        updateTodayCount()
        saveMedicationLogs()
        updateNextPillTime()
        
        if notificationsEnabled {
            scheduleNotifications()
        }
    }
    
    // MARK: - Notification Handling
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                notificationsEnabled = granted
                UserDefaults.standard.set(granted, forKey: "notificationsEnabled")
                
                if granted {
                    scheduleNotifications()
                }
            }
        }
    }
    
    private func scheduleNotifications() {
        // First check if we need to adjust notifications or create new ones
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                // Only reschedule follow-up notification (keep morning notification)
                self.removeFollowUpNotification(existingRequests: requests)
                
                // Always ensure daily morning notification exists
                let hasMorningNotification = requests.contains { $0.identifier == "morningReminder" }
                if !hasMorningNotification {
                    self.scheduleDailyMorningNotification()
                }
                
                // Schedule follow-up notification if fewer than target number of pills taken today
                if self.todayCount < self.settings.dailyPillTarget {
                    self.scheduleFollowUpNotification()
                }
            }
        }
    }
    
    private func removeFollowUpNotification(existingRequests: [UNNotificationRequest]) {
        // Only remove the follow-up notification, not all notifications
        if existingRequests.contains(where: { $0.identifier == "followUpReminder" }) {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["followUpReminder"])
        }
    }
    
    private func scheduleDailyMorningNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Medication Reminder"
        content.body = "Remember to take your medication"
        content.sound = UNNotificationSound.default
        
        // Use time from settings
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: settings.morningReminderTime)
        
        var dateComponents = DateComponents()
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "morningReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling morning notification: \(error)")
            }
        }
    }
    
    private func scheduleFollowUpNotification() {
        // Find the most recent log chronologically (by actual timestamp, not insertion order)
        let sortedByTimestamp = medicationLogs.sorted(by: { $0.timestamp > $1.timestamp })
        guard let mostRecentLog = sortedByTimestamp.first else { return }
        
        // Get the logs from today
        let today = Date()
        let todayLogs = sortedByTimestamp.filter { isSameDay(date1: $0.timestamp, date2: today) }
        
        // Use the most recent log for today's date
        let logToUse = todayLogs.first ?? mostRecentLog
        
        let content = UNMutableNotificationContent()
        content.title = "Time for Your Next Dose"
        content.body = "It's been \(settings.notificationDelay) hour\(settings.notificationDelay > 1 ? "s" : "") since your last medication"
        content.sound = UNNotificationSound.default
        
        // Use delay from settings
        let triggerDate = Calendar.current.date(byAdding: .hour, value: settings.notificationDelay, to: logToUse.timestamp)!
        
        // Update the next pill time
        updateNextPillTime()
        
        // Only schedule if the date is in the future
        if triggerDate > Date() {
            let triggerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
            let request = UNNotificationRequest(identifier: "followUpReminder", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling follow-up notification: \(error)")
                }
            }
        }
    }
    
    private func updateNextPillTime() {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if we've taken all pills for today
        if todayCount >= settings.dailyPillTarget {
            // Calculate tomorrow's morning reminder time
            let timeComponents = calendar.dateComponents([.hour, .minute], from: settings.morningReminderTime)
            var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: now)
            tomorrowComponents.day = (tomorrowComponents.day ?? 0) + 1
            tomorrowComponents.hour = timeComponents.hour
            tomorrowComponents.minute = timeComponents.minute
            
            nextPillTime = calendar.date(from: tomorrowComponents)
            return
        }
        
        // Haven't taken all pills for today
        
        // If there are medication logs today
        if !medicationLogs.isEmpty {
            // Get logs from today
            let todayLogs = medicationLogs.filter { isSameDay(date1: $0.timestamp, date2: now) }
                                         .sorted(by: { $0.timestamp > $1.timestamp })
            
            if let mostRecentLog = todayLogs.first {
                // Calculate the next time based on the delay setting
                let nextTime = calendar.date(byAdding: .hour, value: settings.notificationDelay, to: mostRecentLog.timestamp)!
                
                // If the calculated time is in the future, use it
                if nextTime > now {
                    nextPillTime = nextTime
                    return
                } else {
                    // Overdue pill - set the time to now to show "Take your next pill now"
                    nextPillTime = now
                    return
                }
            }
        }
        
        // No logs today, check if morning reminder time has passed
        let timeComponents = calendar.dateComponents([.hour, .minute], from: settings.morningReminderTime)
        var todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
        todayComponents.hour = timeComponents.hour
        todayComponents.minute = timeComponents.minute
        
        let morningTime = calendar.date(from: todayComponents)
        
        if let time = morningTime {
            if time > now {
                // Morning time is still in the future
                nextPillTime = time
            } else {
                // Morning time has passed but no pills taken yet - pill is overdue
                nextPillTime = now // Use current time to indicate "Take pill now"
            }
        } else {
            // Fallback in case date creation fails
            nextPillTime = now
        }
    }
    
    // Timer for periodically checking date changes (every minute)
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    // Notification center for app state changes
    private let notificationCenter = NotificationCenter.default
    
    var body: some View {
        NavigationView {
            ZStack {
            VStack(spacing: 20) {
                Text("Medication Tracker")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 30)
                
                VStack(spacing: 8) {
                    Text("Pills taken today: \(todayCount)/\(settings.dailyPillTarget)")
                        .font(.title)
                    
                    if todayCount >= settings.dailyPillTarget {
                        // All pills taken for today
                        if let nextTime = nextPillTime {
                            Text("Next pill tomorrow at \(dateFormatter.string(from: nextTime))")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        
                        if todayCount > settings.dailyPillTarget {
                            Text("You've taken \(todayCount)/\(settings.dailyPillTarget) pills today (extra: \(todayCount - settings.dailyPillTarget))")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        } else {
                            Text("You've taken all your pills for today!")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                    } else {
                        // Pills still due today
                        if let nextTime = nextPillTime {
                            let now = Date()
                            let isOverdue = nextTime < now && Calendar.current.isDateInToday(nextTime)
                            let isTomorrow = !Calendar.current.isDateInToday(nextTime)
                            
                            if isOverdue {
                                Text("Take your next pill now")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                    .fontWeight(.bold)
                            } else if isTomorrow {
                                Text("Next pill tomorrow at \(dateFormatter.string(from: nextTime))")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            } else {
                                Text("Take your next pill at \(dateFormatter.string(from: nextTime))")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .padding()
                
                HStack(spacing: 20) {
                    Button(action: addMedication) {
                        VStack {
                            Image(systemName: "pills")
                                .font(.system(size: 60))
                            Text("Take Medication")
                                .font(.title2)
                        }
                        .padding(40)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(20)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    VStack(spacing: 8) {
                        Button(action: { showingDatePicker = true }) {
                            VStack {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 40))
                                Text("Log Past Dose")
                                    .font(.callout)
                            }
                            .padding()
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(10)
                            .frame(height: 120)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if !medicationLogs.isEmpty {
                            Button(action: undoLastMedication) {
                                HStack {
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.system(size: 12))
                                    Text("Undo")
                                        .font(.footnote)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .foregroundColor(.gray)
                        }
                    }
                }
                
                List {
                    let todayLogs = medicationLogs.filter { isSameDay(date1: $0.timestamp, date2: Date()) }
                    Section(header: Text("Today's Log")) {
                        ForEach(todayLogs) { log in
                            HStack {
                                Text("Pill taken at")
                                Spacer()
                                Text(dateFormatter.string(from: log.timestamp))
                                    .foregroundColor(.gray)
                            }
                        }
                        .onDelete { indexSet in
                            deleteMedication(at: indexSet, from: todayLogs)
                        }
                    }
                    
                    let previousLogs = medicationLogs.filter { !isSameDay(date1: $0.timestamp, date2: Date()) }
                    if !previousLogs.isEmpty {
                        Section(header: Text("Previous Logs")) {
                            ForEach(previousLogs) { log in
                                HStack {
                                    Text("Pill taken on")
                                    Spacer()
                                    Text(fullDateFormatter.string(from: log.timestamp))
                                        .foregroundColor(.gray)
                                }
                            }
                            .onDelete { indexSet in
                                deleteMedication(at: indexSet, from: previousLogs)
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            showingHistory = true
                        }) {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gear")
                        }
                        .padding(.horizontal, 5)
                        
                        EditButton()
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView(settings: settings, notificationsEnabled: $notificationsEnabled)
                        .onDisappear {
                            if notificationsEnabled {
                                // Check if notifications are authorized and request if needed
                                UNUserNotificationCenter.current().getNotificationSettings { settings in
                                    DispatchQueue.main.async {
                                        if settings.authorizationStatus != .authorized {
                                            requestNotificationPermission()
                                        } else {
                                            // Reschedule notifications when settings change
                                            scheduleNotifications()
                                        }
                                    }
                                }
                            }
                        }
                }
                .sheet(isPresented: $showingHistory) {
                    NavigationView {
                        HistoryView(
                            medicationLogs: medicationLogs, 
                            dailyTarget: settings.dailyPillTarget,
                            refillEvents: inventory.refillEvents
                        )
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingHistory = false
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .onAppear {
                loadMedicationLogs()
                
                // Check for date change on app appear
                checkForDateChange()
                
                // Check notification status when app appears
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    DispatchQueue.main.async {
                        if settings.authorizationStatus == .authorized {
                            self.notificationsEnabled = true
                            if UserDefaults.standard.bool(forKey: "notificationsEnabled") {
                                self.scheduleNotifications()
                                self.updateNextPillTime()
                            }
                        }
                    }
                }
                
                // Register for foreground notifications
                notificationCenter.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
                    self.checkForDateChange()
                }
            }
            // Check for date change every minute
            .onReceive(timer) { _ in
                checkForDateChange()
            }
            // Handle system date/time changes
            .onReceive(notificationCenter.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                // This will trigger when system time changes significantly (like timezone changes, daylight saving, etc.)
                checkForDateChange()
            }
            .alert("Cannot Undo", isPresented: $showUndoAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You can only undo medication logs that were created within the last 5 minutes.")
            }
            
            // Date picker for adding past medication
            if showingDatePicker {
                // Create a new environment with light mode only for this component
                ZStack {
                    // Semi-transparent background overlay
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            showingDatePicker = false
                        }
                    
                    // Important: Force the entire container to light mode
                    // This ensures both background and text have proper contrast
                    VStack {
                        Text("Select Date and Time")
                            .font(.headline)
                            .padding()
                        
                        // Date picker
                        DatePicker("", selection: $selectedDate)
                            .datePickerStyle(GraphicalDatePickerStyle())
                            .accentColor(.blue)
                            .frame(maxHeight: 400)
                            .padding()
                        
                        // Buttons
                        HStack {
                            Button("Cancel") {
                                showingDatePicker = false
                            }
                            .foregroundColor(.red)
                            .padding()
                            
                            Spacer()
                            
                            Button("Log Medication") {
                                addMedicationAt(date: selectedDate)
                            }
                            .foregroundColor(.blue)
                            .padding()
                        }
                    }
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(20)
                    .padding()
                    .shadow(radius: 10)
                    // This is the key modification - force light mode for the entire component
                    .environment(\.colorScheme, .light)
                }
                .zIndex(1)
            }
        }
        }
    }
}

#Preview {
    ContentView()
}
