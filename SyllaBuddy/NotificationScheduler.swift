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

class NotificationScheduler {
    
    static let eventStore = EKEventStore()
    static let db = Firestore.firestore()
    static let notifiedEventsKey = "NotifiedEvents"  // UserDefaults key to track notified events
    
    // Call this to check permissions and notify immediately if event today
    static func notifyIfEventTodayExistsIfAuthorized() {
        let calendarStatus = EKEventStore.authorizationStatus(for: .event)
        guard calendarStatus == .fullAccess || calendarStatus == .writeOnly else {
            print("No calendar access")
            return
        }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                print("No notification access")
                return
            }

            scheduleImmediateNotificationIfEventToday()
        }
    }
    
    static func scheduleImmediateNotificationIfEventToday() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)

        checkUserEventsAndNotify(for: events)
    }
    
    static func checkUserEventsAndNotify(for calendarEvents: [EKEvent]) {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            print("No user signed in or email unavailable")
            return
        }

        let userCollection = db.collection("User")

        userCollection
            .whereField("Email", isEqualTo: email)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching user document: \(error)")
                    return
                }

                guard let documents = snapshot?.documents, let userDoc = documents.first else {
                    print("No user document found")
                    return
                }

                guard let eventsArray = userDoc.data()["Events"] as? [[String: Any]] else {
                    print("No Events array found in user document")
                    return
                }

                let formatter = DateFormatter()
                formatter.dateFormat = "MM-dd-yyyy"
                let todayString = formatter.string(from: Date())

                let todaysEvents = eventsArray.filter { eventDict in
                    if let dateStr = eventDict["date"] as? String {
                        return dateStr == todayString
                    }
                    return false
                }

                let firestoreEventTitles = todaysEvents.compactMap { $0["event"] as? String }.map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                }

                for calendarEvent in calendarEvents {
                    if let title = calendarEvent.title?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                       firestoreEventTitles.contains(title) {
                        
                        let eventIdentifier = createIdentifier(for: calendarEvent)
                        checkAndScheduleNotification(for: calendarEvent, identifier: eventIdentifier)
                    }
                }
            }
    }
    
    static func checkAndScheduleNotification(for event: EKEvent, identifier: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let alreadyScheduled = requests.contains { request in
                request.identifier == identifier
            }

            if alreadyScheduled {
                print("Notification for '\(event.title ?? "")' already scheduled, skipping.")
                return
            }

            if hasNotified(for: identifier) {
                print("Notification for '\(event.title ?? "")' already notified, skipping.")
                return
            }

            scheduleImmediateNotification(for: event, identifier: identifier)
            markAsNotified(eventId: identifier)
        }
    }

    static func scheduleImmediateNotification(for event: EKEvent, identifier: String) {
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
                print("Failed to show notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled for event: \(event.title ?? "Untitled")")
            }
        }
    }
    
    static func createIdentifier(for event: EKEvent) -> String {
        let title = event.title?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "untitled"
        let dateStr = formattedDate(from: event.startDate)
        return "\(title)_\(dateStr)"
    }
    
    static func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy"
        return formatter.string(from: date)
    }

    static func hasNotified(for identifier: String) -> Bool {
        let notified = UserDefaults.standard.array(forKey: notifiedEventsKey) as? [String] ?? []
        return notified.contains(identifier)
    }

    static func markAsNotified(eventId identifier: String) {
        var notified = UserDefaults.standard.array(forKey: notifiedEventsKey) as? [String] ?? []
        notified.append(identifier)
        UserDefaults.standard.set(notified, forKey: notifiedEventsKey)
    }
    
    static func clearNotifiedEvents() {
        UserDefaults.standard.removeObject(forKey: notifiedEventsKey)
    }
}

