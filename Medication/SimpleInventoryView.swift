//
//  SimpleInventoryView.swift
//  Medication
//
//  Created by Thomas Mustier on 13/03/2025.
//

import SwiftUI

/// A simplified inventory view for testing the refill functionality
struct SimpleInventoryView: View {
    @ObservedObject var inventory: InventoryModel
    @ObservedObject var settings: SettingsModel
    
    // State for the refill sheet
    @State private var showingNewRefillSheet = false
    @State private var newPillCount = ""
    @State private var errorMessage = ""
    
    var body: some View {
        Form {
            // Current inventory section
            Section(header: Text("Current Inventory")) {
                HStack {
                    Text("Pills remaining:")
                    Spacer()
                    Text("\(inventory.currentPillCount)")
                        .bold()
                }
                
                HStack {
                    Text("Daily usage rate:")
                    Spacer()
                    Text(String(format: "%.1f", inventory.dailyUsageRate))
                }
                
                HStack {
                    Text("Estimated days remaining:")
                    Spacer()
                    Text("\(inventory.estimatedDaysRemaining)")
                }
                
                HStack {
                    Text("Last refill:")
                    Spacer()
                    Text("\(inventory.lastRefillDate, style: .date)")
                }
            }
            
            // Refill actions section
            Section(header: Text("Refill Actions")) {
                Button(action: {
                    let reminderManager = RefillReminderManager(inventory: inventory, settings: settings)
                    reminderManager.handleRefillRequested()
                }) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Log Refill Request")
                    }
                }
                .disabled(inventory.isWaitingForRefill)
                
                Button(action: {
                    showingNewRefillSheet = true
                }) {
                    HStack {
                        Image(systemName: "pills")
                        Text("Log Refill Received")
                    }
                }
                
                if inventory.isWaitingForRefill, let date = inventory.refillRequestDate {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Refill requested on \(date, style: .date)")
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Refill history section
            Section(header: Text("Recent Refill Events")) {
                if inventory.refillEvents.isEmpty {
                    Text("No refill history")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(inventory.refillEvents.sorted(by: { $0.timestamp > $1.timestamp })) { event in
                        HStack {
                            if event.eventType == .requested {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.blue)
                                Text("Requested: \(event.timestamp, style: .date)")
                            } else {
                                Image(systemName: "pills")
                                    .foregroundColor(.green)
                                if let count = event.pillCount {
                                    Text("Received: \(count) pills on \(event.timestamp, style: .date)")
                                } else {
                                    Text("Received: \(event.timestamp, style: .date)")
                                }
                            }
                        }
                    }
                }
            }
            
            // Reset action for testing
            Section(header: Text("Testing")) {
                Button(action: {
                    inventory.reset()
                }) {
                    Text("Reset Inventory Data")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Medication Inventory")
        .sheet(isPresented: $showingNewRefillSheet) {
            // Reset form values
            newPillCount = ""
            errorMessage = ""
        } content: {
            NavigationView {
                Form {
                    Section(header: Text("New Refill")) {
                        TextField("Pill Count", text: $newPillCount)
                            .keyboardType(.numberPad)
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .foregroundColor(.red)
                        }
                    }
                }
                .navigationTitle("Log Refill")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        showingNewRefillSheet = false
                    },
                    trailing: Button("Save") {
                        processNewRefill()
                    }
                )
            }
        }
    }
    
    private func processNewRefill() {
        // Validate input
        guard !newPillCount.isEmpty else {
            errorMessage = "Please enter a pill count"
            return
        }
        
        guard let count = Int(newPillCount), count > 0 else {
            errorMessage = "Please enter a valid number"
            return
        }
        
        // Log the refill
        let reminderManager = RefillReminderManager(inventory: inventory, settings: settings)
        reminderManager.handleRefillReceived(pillCount: count)
        
        // Close the sheet
        showingNewRefillSheet = false
    }
}

#Preview {
    SimpleInventoryView(
        inventory: InventoryModel(
            currentPillCount: 25,
            refillEvents: [
                RefillEvent(timestamp: Date().addingTimeInterval(-60*60*24*7), eventType: .received, pillCount: 30)
            ],
            dailyUsageRate: 1.0
        ),
        settings: SettingsModel()
    )
}