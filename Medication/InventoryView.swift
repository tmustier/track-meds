//
//  InventoryView.swift
//  Medication
//
//  Created by Thomas Mustier on 13/03/2025.
//

import SwiftUI

public struct InventoryView: View {
    // Model state
    @ObservedObject public var inventory: InventoryModel
    @ObservedObject public var settings: SettingsModel
    
    public init(inventory: InventoryModel, settings: SettingsModel) {
        self.inventory = inventory
        self.settings = settings
    }
    
    // Local view state
    @State private var showingRefillConfirmation = false
    @State private var showingReceiveRefillSheet = false
    @State private var newPillCount = ""
    @State private var pillCountError = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    // Date formatters
    private var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    // Pills remaining progress calculation
    private var pillsRemainingProgress: Double {
        // Calculate percentage of pills remaining for progress view
        // Assuming 100% is the max pill count from the last refill
        
        // Get received refill events
        let receivedEvents = inventory.refillEvents.filter { $0.eventType == .received }
        
        // Sort by timestamp (newest first)
        let sortedEvents = receivedEvents.sorted { $0.timestamp > $1.timestamp }
        
        // Get the most recent refill
        guard let lastRefill = sortedEvents.first,
              let lastCount = lastRefill.pillCount,
              lastCount > 0 else {
            // Default to 50% if no refill history
            return 0.5
        }
        
        let progress = Double(inventory.currentPillCount) / Double(lastCount)
        return min(max(progress, 0.0), 1.0) // Clamp between 0 and 1
    }
    
    // Color based on remaining pills
    private var pillsRemainingColor: Color {
        if inventory.estimatedDaysRemaining <= 7 {
            return .red
        } else if inventory.estimatedDaysRemaining <= 14 {
            return .orange
        } else {
            return .green
        }
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Current Inventory Section
                    GroupBox(label: Label("Current Inventory", systemImage: "pills.fill")
                        .font(.headline)) {
                        VStack(alignment: .leading, spacing: 15) {
                            HStack {
                                Text("Pills remaining:")
                                    .font(.headline)
                                Spacer()
                                Text("\(inventory.currentPillCount)")
                                    .font(.title2)
                                    .foregroundColor(pillsRemainingColor)
                                    .fontWeight(.bold)
                            }
                            
                            // Progress bar
                            ProgressView(value: pillsRemainingProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: pillsRemainingColor))
                                .padding(.vertical, 5)
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Daily Target:")
                                    Spacer()
                                    Text("\(settings.dailyPillTarget)")
                                        .fontWeight(.medium)
                                    Text("pills/day")
                                        .fontWeight(.medium)
                                }
                                
                                HStack {
                                    Text("Estimated days remaining:")
                                    Spacer()
                                    Text("\(inventory.estimatedDaysRemaining)")
                                        .fontWeight(.medium)
                                        .foregroundColor(pillsRemainingColor)
                                }
                                
                                HStack {
                                    Text("Estimated to run out by:")
                                    Spacer()
                                    Text(dateFormatter.string(from: inventory.estimatedDepletionDate))
                                        .fontWeight(.medium)
                                        .foregroundColor(pillsRemainingColor)
                                }
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Last refill:")
                                Spacer()
                                Text(dateFormatter.string(from: inventory.lastRefillDate))
                                    .fontWeight(.medium)
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    // Refill Actions
                    GroupBox(label: Label("Refill Actions", systemImage: "arrow.clockwise.circle.fill")
                        .font(.headline)) {
                        VStack(spacing: 15) {
                            // Request refill button
                            Button {
                                showingRefillConfirmation = true
                            } label: {
                                HStack {
                                    Image(systemName: "doc.badge.plus")
                                        .font(.title3)
                                    Text("Request Medication Refill")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(10)
                            }
                            .disabled(inventory.isWaitingForRefill)
                            .opacity(inventory.isWaitingForRefill ? 0.5 : 1.0)
                            
                            // Receive refill button
                            Button {
                                showingReceiveRefillSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle")
                                        .font(.title3)
                                    Text("Log Received Refill")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .foregroundColor(.green)
                                .cornerRadius(10)
                            }
                            
                            if inventory.isWaitingForRefill {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    Text("Refill requested on \(dateFormatter.string(from: inventory.refillRequestDate ?? Date()))")
                                        .font(.footnote)
                                        .foregroundColor(.orange)
                                }
                                .padding(.top, 5)
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    // Recent Refill History
                    GroupBox(label: Label("Recent Refill History", systemImage: "clock.fill")
                        .font(.headline)) {
                        if inventory.refillEvents.isEmpty {
                            Text("No refill history available")
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundColor(.secondary)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(inventory.refillEvents.prefix(5)) { event in
                                    HStack(alignment: .top) {
                                        // Event type icon
                                        Image(systemName: event.eventType == .requested ? "doc.badge.plus" : "checkmark.circle")
                                            .foregroundColor(event.eventType == .requested ? .blue : .green)
                                            .font(.subheadline)
                                            .frame(width: 20)
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(event.eventType.rawValue)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            
                                            Text(dateFormatter.string(from: event.timestamp))
                                                .font(.footnote)
                                                .foregroundColor(.secondary)
                                            
                                            if event.eventType == .received, let count = event.pillCount {
                                                Text("Received \(count) pills")
                                                    .font(.footnote)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, 5)
                                    
                                    if event != inventory.refillEvents.prefix(5).last {
                                        Divider()
                                    }
                                }
                            }
                            .padding()
                        }
                        
                        // Show more history button
                        NavigationLink(destination: RefillHistoryView(refillEvents: inventory.refillEvents)) {
                            Text("See Full History")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .font(.footnote)
                                .fontWeight(.medium)
                        }
                        .padding(.bottom, 10)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Medication Inventory")
            .alert("Request Refill", isPresented: $showingRefillConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Confirm") {
                    // Create reminder manager and handle refill request
                    let reminderManager = RefillReminderManager(inventory: inventory, settings: settings)
                    reminderManager.handleRefillRequested()
                }
            } message: {
                Text("Would you like to log that you've requested a medication refill?")
            }
            .sheet(isPresented: $showingReceiveRefillSheet) {
                // Reset form data when sheet dismissed
                newPillCount = ""
                pillCountError = false
            } content: {
                RefillReceivedView(inventory: inventory, settings: settings, isPresented: $showingReceiveRefillSheet)
            }
            .alert("Invalid Pill Count", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
}

// View for logging a received refill
public struct RefillReceivedView: View {
    @ObservedObject public var inventory: InventoryModel
    @ObservedObject public var settings: SettingsModel
    @Binding public var isPresented: Bool
    
    public init(inventory: InventoryModel, settings: SettingsModel, isPresented: Binding<Bool>) {
        self.inventory = inventory
        self.settings = settings
        self._isPresented = isPresented
    }
    
    @State private var newPillCount = ""
    @State private var pillCountError = false
    @State private var errorMessage = ""
    
    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Refill Information")) {
                    Text("Enter the number of pills you received in your refill")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 5)
                    
                    HStack {
                        Text("Pill Count:")
                        TextField("Enter count", text: $newPillCount)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    if pillCountError {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.top, 5)
                    }
                }
            }
            .navigationTitle("Log Received Refill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        processPillCount()
                    }
                }
            }
        }
    }
    
    private func processPillCount() {
        // Validate pill count
        guard !newPillCount.isEmpty else {
            pillCountError = true
            errorMessage = "Please enter a pill count"
            return
        }
        
        guard let count = Int(newPillCount), count > 0 else {
            pillCountError = true
            errorMessage = "Please enter a valid number greater than 0"
            return
        }
        
        // Create reminder manager and handle refill received
        let reminderManager = RefillReminderManager(inventory: inventory, settings: settings)
        reminderManager.handleRefillReceived(pillCount: count)
        
        // Dismiss sheet
        isPresented = false
    }
}

// Full history view
public struct RefillHistoryView: View {
    public let refillEvents: [RefillEvent]
    
    public init(refillEvents: [RefillEvent]) {
        self.refillEvents = refillEvents
    }
    
    // Date formatters
    private var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    public var body: some View {
        List {
            ForEach(refillEvents.sorted(by: { $0.timestamp > $1.timestamp })) { event in
                HStack(alignment: .top) {
                    // Event type icon
                    Image(systemName: event.eventType == .requested ? "doc.badge.plus" : "checkmark.circle")
                        .foregroundColor(event.eventType == .requested ? .blue : .green)
                        .font(.headline)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text(event.eventType.rawValue)
                            .font(.headline)
                        
                        Text(dateFormatter.string(from: event.timestamp))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if event.eventType == .received, let count = event.pillCount {
                            Text("Received \(count) pills")
                                .font(.subheadline)
                                .padding(.top, 2)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 5)
            }
        }
        .navigationTitle("Refill History")
        .listStyle(InsetGroupedListStyle())
    }
}

#Preview {
    let inventory = InventoryModel(
        currentPillCount: 25,
        lastRefillDate: Date().addingTimeInterval(-60*60*24*10), // 10 days ago
        refillEvents: [
            RefillEvent(timestamp: Date().addingTimeInterval(-60*60*24*10), eventType: .received, pillCount: 30),
            RefillEvent(timestamp: Date().addingTimeInterval(-60*60*24*11), eventType: .requested),
            RefillEvent(timestamp: Date().addingTimeInterval(-60*60*24*40), eventType: .received, pillCount: 30),
            RefillEvent(timestamp: Date().addingTimeInterval(-60*60*24*41), eventType: .requested)
        ],
        dailyUsageRate: 0.5
    )
    
    InventoryView(inventory: inventory, settings: SettingsModel())
}