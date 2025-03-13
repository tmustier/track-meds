//
//  HistoryView.swift
//  Medication
//
//  Created by Thomas Mustier on 13/03/2025.
//

import SwiftUI
import Foundation

public struct HistoryView: View {
    public let medicationLogs: [MedicationLog]
    public let dailyTarget: Int
    public let refillEvents: [RefillEvent]
    
    public init(medicationLogs: [MedicationLog], dailyTarget: Int, refillEvents: [RefillEvent] = []) {
        self.medicationLogs = medicationLogs
        self.dailyTarget = dailyTarget
        self.refillEvents = refillEvents
    }
    
    // Date formatters
    private var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    private var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    // Group logs by date
    private var groupedLogs: [Date: [MedicationLog]] {
        let calendar = Calendar.current
        
        var grouped: [Date: [MedicationLog]] = [:]
        
        for log in medicationLogs {
            // Get just the date component (no time)
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: log.timestamp)
            guard let dateKey = calendar.date(from: dateComponents) else { continue }
            
            if grouped[dateKey] == nil {
                grouped[dateKey] = []
            }
            
            grouped[dateKey]?.append(log)
        }
        
        return grouped
    }
    
    // Sort dates in descending order (newest first)
    private var sortedDates: [Date] {
        return groupedLogs.keys.sorted(by: >)
    }
    
    // Check if two dates are the same day
    private func isSameDay(date1: Date, date2: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(date1, inSameDayAs: date2)
    }
    
    // Calculate summary statistics
    private var totalDays: Int {
        return groupedLogs.keys.count
    }
    
    private var daysOnTarget: Int {
        return groupedLogs.values.filter { $0.count >= dailyTarget }.count
    }
    
    private var adherencePercentage: Int {
        guard totalDays > 0 else { return 0 }
        return Int(Double(daysOnTarget) / Double(totalDays) * 100)
    }
    
    private var averagePillsPerDay: Double {
        guard totalDays > 0 else { return 0 }
        let totalPills = groupedLogs.values.flatMap { $0 }.count
        return Double(totalPills) / Double(totalDays)
    }
    
    public var body: some View {
        List {
            // Refill Events Section
            if !refillEvents.isEmpty {
                Section(header: Text("Refill Events")) {
                    ForEach(refillEvents.prefix(5).sorted(by: { $0.timestamp > $1.timestamp })) { event in
                        HStack {
                            if event.eventType == .requested {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.blue)
                                Text("Requested Refill")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(dateFormatter.string(from: event.timestamp))
                                    .foregroundColor(.gray)
                            } else {
                                Image(systemName: "pills")
                                    .foregroundColor(.green)
                                if let count = event.pillCount {
                                    Text("Received \(count) pills")
                                        .fontWeight(.medium)
                                } else {
                                    Text("Received Refill")
                                        .fontWeight(.medium)
                                }
                                Spacer()
                                Text(dateFormatter.string(from: event.timestamp))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    if refillEvents.count > 5 {
                        NavigationLink(destination: RefillHistoryDetailView(refillEvents: refillEvents)) {
                            Text("View all \(refillEvents.count) refill events")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            // Summary section
            Section(header: Text("Summary")) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Total days tracked")
                        Text("\(totalDays)")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Days on target")
                        Text("\(daysOnTarget) (\(adherencePercentage)%)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(adherencePercentage >= 80 ? .green : (adherencePercentage >= 50 ? .orange : .red))
                    }
                }
                .padding(.vertical, 4)
                
                Divider()
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Average pills per day")
                        Text(String(format: "%.1f", averagePillsPerDay))
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Spacer()
                    
                    // Visual indicator of adherence trend
                    VStack(alignment: .trailing) {
                        Text("Adherence")
                        HStack(spacing: 2) {
                            ForEach(0..<5) { i in
                                if i < adherencePercentage / 20 {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                } else {
                                    Image(systemName: "star")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Daily data
            ForEach(sortedDates, id: \.self) { date in
                if let logs = groupedLogs[date] {
                    Section {
                        // Daily summary row
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Pills taken:")
                                Spacer()
                                Text("\(logs.count) of \(dailyTarget)")
                                    .foregroundColor(logs.count >= dailyTarget ? .green : .orange)
                                    .fontWeight(.semibold)
                            }
                            
                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    // Background bar
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 8)
                                    
                                    // Progress - capped at 100%
                                    let progress = min(Double(logs.count) / Double(dailyTarget), 1.0)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(progressColor(for: logs.count, target: dailyTarget))
                                        .frame(width: geo.size.width * progress, height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding(.vertical, 8)
                        
                        // Expandable list of times
                        DisclosureGroup("Show times") {
                            // Sort logs by time
                            let sortedLogs = logs.sorted { $0.timestamp < $1.timestamp }
                            
                            ForEach(sortedLogs) { log in
                                HStack {
                                    Text("Pill taken at")
                                    Spacer()
                                    Text(timeFormatter.string(from: log.timestamp))
                                        .foregroundColor(.gray)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        let isToday = isSameDay(date1: date, date2: Date())
                        Text(isToday ? "Today" : dateFormatter.string(from: date))
                            .font(.headline)
                    }
                }
            }
        }
        .navigationTitle("Medication History")
        .listStyle(InsetGroupedListStyle())
    }
    
    // Color the progress bar based on adherence
    private func progressColor(for count: Int, target: Int) -> Color {
        if count >= target {
            return .green
        } else if Double(count) / Double(target) >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
}

#Preview {
    // Sample data for preview
    let sampleLogs = [
        MedicationLog(timestamp: Date()),
        MedicationLog(timestamp: Calendar.current.date(byAdding: .hour, value: -2, to: Date())!),
        MedicationLog(timestamp: Calendar.current.date(byAdding: .day, value: -1, to: Date())!),
        MedicationLog(timestamp: Calendar.current.date(byAdding: .day, value: -1, to: Date().addingTimeInterval(3600))!)
    ]
    
    // Sample refill events
    let sampleRefillEvents = [
        RefillEvent(
            timestamp: Calendar.current.date(byAdding: .day, value: -10, to: Date())!,
            eventType: .requested
        ),
        RefillEvent(
            timestamp: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
            eventType: .received,
            pillCount: 30
        )
    ]
    
    NavigationView {
        HistoryView(
            medicationLogs: sampleLogs,
            dailyTarget: 4,
            refillEvents: sampleRefillEvents
        )
    }
}
