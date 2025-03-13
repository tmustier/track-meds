# Medication Tracker

A comprehensive iOS application for tracking daily medication intake with smart reminders, inventory management, and refill tracking. Optimized for managing one medication taken multiple times daily, with a focus on adherence and ensuring you never run out of medication.

## Key Features

### Medication Tracking
- **One-Touch Logging**: Record medication with a single tap
- **Daily Counter**: Track pills taken today against your daily target
- **Adherence Monitoring**: Visual indicators show if you're meeting your targets
- **Retroactive Logging**: Record medications taken earlier with date/time selection
- **Medication Undo**: Remove accidentally logged doses within 5 minutes
- **History Timeline**: View complete medication history by day

### Smart Reminder System
- **Morning Reminders**: Daily notification at your preferred time
- **Interval Reminders**: Get notified after a customizable interval since your last dose
- **Next Dose Indicator**: See exactly when your next pill is due
- **Persistent Notifications**: Reminders continue throughout the day until all doses are taken
- **Daily Goal Tracking**: Visual indicators show your progress toward daily target

### Inventory Management
- **Pill Counter**: Track remaining medication quantity
- **Usage Calculation**: Automatically calculate daily usage rate based on your target
- **Supply Estimation**: View days of medication remaining based on:
  - Current inventory level
  - Initial pill count at last refill
- **Depletion Forecasting**: See the exact date when you'll run out
- **Visual Indicators**: Color-coded warnings when inventory runs low

### Refill Tracking System
- **Refill Request Logging**: Record when you request a medication refill
- **Refill Receipt Logging**: Record when you receive your medication
- **Dual Reminder System**:
  - **Inventory-based**: Get reminders when your supply runs below a certain threshold 
  - **Time-based**: Get reminders when you have fewer than X days of pills remaining from your last refill
- **Intelligent Follow-ups**: Automatic follow-up reminders if refill not received within 3 days
- **Refill History**: Complete searchable history of all refill events

### Comprehensive Statistics
- **Adherence Rate**: Percentage of days meeting your target
- **Star Rating**: Simple visual representation of your adherence
- **Daily Trends**: View your medication patterns over time
- **Average Consumption**: Track actual versus target consumption
- **Supply Management**: Monitor how effectively you're managing refills

### User-Friendly UI/UX
- **Clean Interface**: Intuitive design focused on essential information
- **Dark/Light Mode**: Automatic support for system appearance
- **Accessibility**: Support for VoiceOver and Dynamic Type
- **Quick Actions**: Common tasks accessible with minimal taps
- **Interactive Notifications**: Take action directly from notification alerts

## Technical Details

### App Architecture
- Built with Swift and SwiftUI
- MVVM architecture for clean separation of concerns
- Optimized for iOS 15.0 and later
- Persistent storage with UserDefaults
- Intelligent notification scheduling with UNUserNotificationCenter

### Requirements
- iOS 15.0+
- Xcode 13.0+
- Swift 5.0+

## Installation

1. Clone the repository
2. Open the `Medication.xcodeproj` file in Xcode
3. Build and run the application on your iOS device or simulator

## Usage Guide

### Main Screen
- **Take Medication**: Tap the large "Take Medication" button whenever you take a dose
- **Log Past Dose**: Use this option to record medication taken at an earlier time
- **Undo**: Remove the most recent logged dose (available within 5 minutes)
- **Daily Status**: View your progress toward daily target at the top of the screen
- **Today's Log**: See all medications taken today
- **Previous Logs**: Review your medication history by scrolling down

### History Screen
- Access by tapping the calendar icon
- **Summary Statistics**: View adherence percentage, total days tracked, and average consumption
- **Refill Events**: See your recent medication refill events
- **Daily Breakdown**: Review each day's medication logs with detailed timestamps
- **Progress Indicators**: Visual representation of daily adherence
- **Expandable Details**: Tap to see exact times for each dose

### Inventory Screen
- Access by tapping the pills icon
- **Inventory Dashboard**: See current pill count, usage rate, and days remaining
- **Refill Actions**: Request a refill or log a received refill
- **Supply Forecasting**: View when you'll run out based on current usage
- **Refill History**: Review your complete history of refill events
- **Visual Indicators**: Color-coded warnings when supply is running low

### Settings Screen
- Access by tapping the gear icon
- **Notification Settings**: Enable/disable and customize medication reminders
- **Daily Target**: Set how many pills you need to take each day
- **Refill Reminders**: Configure when you receive refill reminders:
  - Set the threshold for inventory-based reminders (days of supply)
  - Set the threshold for time-based reminders (days remaining)
- **Reset Options**: Reset all settings to default values if needed

## Customization

The app offers extensive customization options:

1. **Notification Settings**:
   - Enable/disable all medication reminders
   - Set your preferred morning reminder time
   - Adjust interval between follow-up reminders (1-12 hours)

2. **Medication Schedule**:
   - Set your daily pill target (1-12 pills)
   - The app will track your progress toward this goal

3. **Refill Reminder Thresholds**:
   - Inventory-based: Get reminded when 1-30 days of pills remain
   - Time-based: Get reminded when days remaining from last refill falls below 7-30 days
   - The app uses whichever threshold is reached first

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Icons provided by SF Symbols
- Built with SwiftUI