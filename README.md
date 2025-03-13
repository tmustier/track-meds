# Medication Tracker

A simple iOS application to track daily medication intake with reminders and logs. Optimized for one medication, taken multiple times every day.

## Features

- **Simple Medication Tracking**: Log medications with a single tap
- **Daily Counter**: Track how many pills you've taken today
- **Next Dose Reminder**: See when your next pill is due
- **Medication History**: View a log of all medications taken
- **Retroactive Logging**: Record medications taken earlier
- **Smart Notifications**: Get reminded at 9 AM daily and 2 hours after your last dose
- **Inventory Management**:
  - Track remaining pill count
  - Monitor estimated days of supply left
  - Log refill requests and receipts
- **Refill Reminders**:
  - Get reminders based on low inventory
  - Get reminders based on time since last refill
  - Follow up on pending refill requests
- **Refill History**: View complete history of refill events
- **Customizable Settings**:
  - Set your preferred morning reminder time
  - Adjust time between doses
  - Set your daily medication target
  - Configure refill reminder thresholds

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.0+

## Installation

1. Clone the repository
2. Open the `Medication.xcodeproj` file in Xcode
3. Build and run the application on your iOS device or simulator

## Usage

- **Tracking Medication**: Tap the "Take Medication" button whenever you take a dose
- **Past Medication**: Use "Log Past Dose" to record medication taken earlier
- **Undo**: Use the undo button below "Log Past Dose" to remove the last recorded medication
- **View History**: Scroll through the list to see all medications taken today and previously
- **Inventory Management**: Tap the pills icon to:
  - View your current pill count and estimated supply
  - Request a medication refill
  - Log when you receive a refill
- **Refill History**: View complete history of all refill events with dates and pill counts
- **Settings**: Access app settings through the gear icon to customize reminders and targets

## Customization

In the Settings screen, you can customize:

1. **Notifications**: Enable or disable medication reminders
2. **Morning Reminder Time**: Set when your first daily reminder appears
3. **Time Between Reminders**: Set how long after taking a pill before you get reminded again
4. **Daily Target**: Set how many pills you need to take each day
5. **Refill Reminders**: Configure when you receive refill reminders:
   - **Inventory-based**: Set how many days of supply triggers a reminder
   - **Time-based**: Set how many days since last refill triggers a reminder

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Icons provided by SF Symbols
- Built with SwiftUI
