//
//  NotificationScheduler.swift
//  SyllaBuddy
//
//  Created by Aditya Ramaswamy on 7/27/25.
//

import Foundation
import EventKit
import FirebaseFirestore
import FirebaseAuth
import UserNotifications

// Janky solution but helper class storing all notifications shown in userDefaults to avoid duplicate notifications and displays notifications
class NotificationScheduler {
    
    static let eventStore = EKEventStore()
    static let db = Firestore.firestore()
    static let notifiedEventsKey = "NotifiedEvents"
    
    // Check permissions
    static func checkPermissions() {
        let calendarStatus = EKEventStore.authorizationStatus(for: .event)
        guard calendarStatus == .fullAccess || calendarStatus == .writeOnly else {
            //print("No calendar access")
            return
        }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                //print("No notification access")
                return
            }

            checkToday()
        }
    }
    
    // Checks if there were events at the current day
    static func checkToday() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)

        fetchFirebaseEvents(for: events)
    }
    
    // Looking in firebase to see if the event exists and schedules notification if it does
    static func fetchFirebaseEvents(for calendarEvents: [EKEvent]) {
        let user = Auth.auth().currentUser
        let email = user!.email

        let userCollection = db.collection("User")

        userCollection.whereField("Email", isEqualTo: email!).getDocuments {
            snapshot, error in
            if let error = error {
                //print("Error fetching user document: \(error)")
                return
            }

            guard let documents = snapshot?.documents, let userDoc = documents.first else {
                //print("No user document found")
                return
            }

            guard let eventsArray = userDoc.data()["Events"] as? [[String: Any]] else {
                //print("No Events array found in user document")
                return
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd-yyyy"
            let todayString = formatter.string(from: Date())

            let todaysEvents = eventsArray.filter {
                eventDict in
                if let dateStr = eventDict["date"] as? String {
                    return dateStr == todayString
                }
                return false
            }

            let firestoreTitle = todaysEvents.compactMap { $0["event"] as? String }.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }

            for calendarEvent in calendarEvents {
                if let title = calendarEvent.title?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                    firestoreTitle.contains(title) {
                    let eventIdentifier = createIdentifier(for: calendarEvent)
                    createNotification(for: calendarEvent, identifier: eventIdentifier)
                }
            }
        }
    }
    
    // Creates the notification and updates user default to not show duplicate
    static func createNotification(for event: EKEvent, identifier: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let alreadyScheduled = requests.contains { request in
                request.identifier == identifier
            }

            if alreadyScheduled {
                return
            }

            if hasNotified(for: identifier) {
                return
            }

            scheduleNotification(for: event, identifier: identifier)
            markAsNotified(eventId: identifier)
        }
    }

    // Schedules the notification on phone
    static func scheduleNotification(for event: EKEvent, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = "Event Today"
        content.body = "\(event.title ?? "Untitled") is scheduled for today."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                //print("Failed to show notification: \(error.localizedDescription)")
            } else {
                //print("Notification scheduled for event: \(event.title ?? "Untitled")")
            }
        }
    }
    
    // Helper to create unique id
    static func createIdentifier(for event: EKEvent) -> String {
        let title = event.title?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let dateStr = formattedDate(from: event.startDate)
        return "\(title)_\(dateStr)"
    }
    
    // Helper to format date to month day year
    static func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy"
        return formatter.string(from: date)
    }

    // Helper to check if the user has already seen notification
    static func hasNotified(for identifier: String) -> Bool {
        let notified = UserDefaults.standard.array(forKey: notifiedEventsKey) as? [String] ?? []
        return notified.contains(identifier)
    }

    // Helper to update userDefault
    static func markAsNotified(eventId identifier: String) {
        var notified = UserDefaults.standard.array(forKey: notifiedEventsKey) as? [String] ?? []
        notified.append(identifier)
        UserDefaults.standard.set(notified, forKey: notifiedEventsKey)
    }
    
    // Helper to clear userDefault of events on relaunch
    static func clearNotifiedEvents() {
        UserDefaults.standard.removeObject(forKey: notifiedEventsKey)
    }
}

