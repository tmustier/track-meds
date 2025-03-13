//
//  RefillHistoryDetailView.swift
//  Medication
//
//  Created by Thomas Mustier on 13/03/2025.
//

import SwiftUI

public struct RefillHistoryDetailView: View {
    public let refillEvents: [RefillEvent]
    
    public init(refillEvents: [RefillEvent]) {
        self.refillEvents = refillEvents
    }
    
    // Date formatters
    private var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    private var fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    public var body: some View {
        List {
            ForEach(groupedEvents.keys.sorted(by: >), id: \.self) { month in
                Section(header: Text(monthFormatter.string(from: month))) {
                    ForEach(groupedEvents[month]!.sorted(by: { $0.timestamp > $1.timestamp })) { event in
                        HStack {
                            // Left side - icon and main text
                            HStack {
                                if event.eventType == .requested {
                                    Image(systemName: "doc.text")
                                        .foregroundColor(.blue)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Refill Requested")
                                            .font(.headline)
                                        Text("Waiting for delivery")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Image(systemName: "pills")
                                        .foregroundColor(.green)
                                        .frame(width: 30)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Refill Received")
                                            .font(.headline)
                                        if let count = event.pillCount {
                                            Text("\(count) pills added to inventory")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Right side - date
                            VStack(alignment: .trailing) {
                                Text(dateFormatter.string(from: event.timestamp))
                                    .font(.subheadline)
                                Text(timeFormatter.string(from: event.timestamp))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Refill History")
        .listStyle(InsetGroupedListStyle())
    }
    
    // Group events by month for better organization
    private var groupedEvents: [Date: [RefillEvent]] {
        let calendar = Calendar.current
        var grouped = [Date: [RefillEvent]]()
        
        for event in refillEvents {
            let components = calendar.dateComponents([.year, .month], from: event.timestamp)
            guard let monthStart = calendar.date(from: components) else { continue }
            
            if grouped[monthStart] == nil {
                grouped[monthStart] = []
            }
            
            grouped[monthStart]?.append(event)
        }
        
        return grouped
    }
    
    // Format just time
    private var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
    
    // Format just month and year for section headers
    private var monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
}

#Preview {
    NavigationView {
        RefillHistoryDetailView(refillEvents: [
            RefillEvent(
                timestamp: Date().addingTimeInterval(-60*60*24*1),
                eventType: .received,
                pillCount: 30
            ),
            RefillEvent(
                timestamp: Date().addingTimeInterval(-60*60*24*3),
                eventType: .requested
            ),
            RefillEvent(
                timestamp: Date().addingTimeInterval(-60*60*24*35),
                eventType: .received,
                pillCount: 28
            ),
            RefillEvent(
                timestamp: Date().addingTimeInterval(-60*60*24*37),
                eventType: .requested
            )
        ])
    }
}