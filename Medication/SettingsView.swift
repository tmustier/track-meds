//
//  SettingsView.swift
//  Medication
//
//  Created by Thomas Mustier on 13/03/2025.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showingTimePicker = false
    @Binding var notificationsEnabled: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Notifications")) {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { 
                            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
                        }
                    
                    if notificationsEnabled {
                        HStack {
                            Text("Morning Reminder Time")
                            Spacer()
                            Button(action: {
                                showingTimePicker = true
                            }) {
                                Text(timeString(from: settings.morningReminderTime))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Stepper(value: $settings.notificationDelay, in: 1...12, onEditingChanged: { editing in
                            if !editing {
                                settings.saveNotificationDelay()
                            }
                        }) {
                            Text("Time Between Reminders: \(settings.notificationDelay) hour\(settings.notificationDelay > 1 ? "s" : "")")
                        }
                    }
                }
                
                Section(header: Text("Medication")) {
                    Stepper(value: $settings.dailyPillTarget, in: 1...12, onEditingChanged: { editing in
                        if !editing {
                            settings.saveDailyPillTarget()
                        }
                    }) {
                        Text("Daily Target: \(settings.dailyPillTarget) pill\(settings.dailyPillTarget > 1 ? "s" : "")")
                    }
                }
                
                Section(header: Text("Support")) {
                    Button("Reset All Settings") {
                        // Reset to defaults
                        var components = DateComponents()
                        components.hour = 9
                        components.minute = 0
                        
                        settings.morningReminderTime = Calendar.current.date(from: components) ?? Date()
                        settings.notificationDelay = 2
                        settings.dailyPillTarget = 4
                        
                        // Save the reset values
                        settings.saveMorningTime()
                        settings.saveNotificationDelay()
                        settings.saveDailyPillTarget()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingTimePicker) {
                VStack {
                    DatePicker("", selection: $settings.morningReminderTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(WheelDatePickerStyle())
                        .labelsHidden()
                    
                    Button("Done") {
                        settings.saveMorningTime()
                        showingTimePicker = false
                    }
                    .padding()
                }
                .presentationDetents([.height(300)])
            }
        }
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    SettingsView(settings: SettingsModel(), notificationsEnabled: .constant(true))
}