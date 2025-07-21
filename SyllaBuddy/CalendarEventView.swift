//
//  PDFViewController.swift
//  SyllaBuddy
//
//  Created by Aditya Ramaswamy on 7/12/25.
//

// Add UICalendar
// If date selected show only events at the date
// Implement grid view
// Integrate API


import UIKit
import UniformTypeIdentifiers
import PDFKit
import FirebaseFirestore
import FirebaseAuth
import EventKit

protocol EventReloader {
    func reloadData()
}

protocol EventHandler {
    func createCalendarEvent(title: String, date: String)
}

class CalendarEventView: UIViewController, UIDocumentPickerDelegate, UITableViewDelegate, UITableViewDataSource, EventReloader, EventHandler, UICalendarSelectionSingleDateDelegate, UICalendarViewDelegate {
    
    
    
    @IBOutlet weak var tableView: UITableView!
    let confirmSegue = "eventConfirmSegue"
    let eventId = "eventId"
    var eventList: [Event]!
    var pdfList: [Event]!
    let db = Firestore.firestore()
    let eventStore = EKEventStore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        eventStore.requestFullAccessToEvents { _, _ in }
        tableView.delegate = self
        tableView.dataSource = self
        self.navigationItem.hidesBackButton = true
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.514, green: 0.384, blue: 0.259, alpha: 1.0),
            .font: UIFont(name: "Arial", size: 26.0)!
        ]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        
        createCalendar()
        
        
        reloadData()
    }
    
    func createCalendar() {
        let calendarView = UICalendarView()
        calendarView.translatesAutoresizingMaskIntoConstraints = false
        
        calendarView.calendar = .current
        calendarView.locale = .current
        calendarView.fontDesign = .rounded
        calendarView.delegate = self
        
        view.addSubview(calendarView)
        
        NSLayoutConstraint.activate([
            calendarView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            calendarView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            calendarView.heightAnchor.constraint(equalToConstant: 300),
            calendarView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        ])
    }
    
    func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
        return
    }

    
    
    //FUNCTION IS HUGE MAKE SOME HELPER METHODS AND CLEAN IT UP
    @IBAction func createEvent(_ sender: Any) {
        let sheet = UIAlertController(title: "Add Event", message: "Choose how to add an event", preferredStyle: .actionSheet)
        
        let manual = UIAlertAction(title: "Add Manually", style: .default) { _ in
            print("Manual selected")
            let alert = UIAlertController(title: "Add Event", message: nil, preferredStyle: .alert)
            
            alert.addTextField { textField in
                textField.placeholder = "Class"
            }
            
            alert.addTextField { textField in
                textField.placeholder = "Event"
            }
            
            alert.addTextField { textField in
                textField.placeholder = "MM-DD-YYYY"
                textField.keyboardType = .numbersAndPunctuation
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            alert.addAction(UIAlertAction(title: "Add", style: .default, handler: { _ in
                guard let newClass = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines),
                      let newEvent = alert.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines),
                      let dateString = alert.textFields?[2].text?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !newClass.isEmpty, !newEvent.isEmpty, !dateString.isEmpty else {
                    
                    let missingInputAlert = UIAlertController(title: "Missing Input", message: "Please fill out all fields before adding the event.", preferredStyle: .alert)
                    missingInputAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(missingInputAlert, animated: true)
                    return
                }
                
                // Check if event already exists locally (silent skip)
                let exists = self.eventList.contains {
                    $0.event == newEvent && $0.date == dateString && $0.eventClass == newClass
                }
                if exists {
                    // Duplicate found, do not add or alert, just return silently
                    return
                }
                
                let formatter = DateFormatter()
                formatter.dateFormat = "MM-dd-yyyy"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone.current

                guard let _ = formatter.date(from: dateString) else {
                    let errorAlert = UIAlertController(title: "Invalid Date", message: "Please enter the date in MM-dd-yyyy format (e.g. 06-18-2025).", preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(errorAlert, animated: true)
                    return
                }

                // Date is valid, proceed
                let addEvent = Event(date: dateString, event: newEvent, eventClass: newClass)
                self.eventList.append(addEvent)
                
                let userEmail = Auth.auth().currentUser!.email
                print("Saving for user: \(userEmail!)")
                
                let eventDictionaries = self.eventList.map { $0.toDictionary() }
                let collection = self.db.collection("User")
                
                collection.whereField("Email", isEqualTo: userEmail!).getDocuments { (querySnapshot, error) in
                    guard let document = querySnapshot?.documents.first else { return }
                    document.reference.updateData([
                        "Events": eventDictionaries,
                        "Classes": FieldValue.arrayUnion([newClass])
                    ]) { error in
                        if let error = error {
                            print("Error updating: \(error.localizedDescription)")
                        } else {
                            print("Event successfully added")
                            self.createCalendarEvent(title: newEvent, date: dateString)
                            self.reloadData()
                        }
                    }
                }
            }))
            
            self.present(alert, animated: true)
        }
        
        let upload = UIAlertAction(title: "Upload PDF", style: .default) { _ in
            print("Upload selected")
            self.pdfUpload()
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
        
        sheet.addAction(manual)
        sheet.addAction(upload)
        sheet.addAction(cancel)
        
        present(sheet, animated: true)
    }
    
    func pdfUpload() {
        let supportedTypes: [UTType] = [UTType.pdf]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let selectedURL = urls.first else { return }
        // Load PDF document
        pdfList = [Event]()
        if let pdfDocument = PDFDocument(url: selectedURL) {
            var fullText = ""
            // Extract text from each page
            for pageIndex in 0..<pdfDocument.pageCount {
                if let page = pdfDocument.page(at: pageIndex), let pageText = page.string {
                    fullText += pageText + "\n"
                }
            }
            print("Extracted PDF text:\n\(fullText)")
            let pairs = extractEventDatePairs(from: fullText)
            if pairs.isEmpty {
                // No events found - show alert and do not segue
                let alert = UIAlertController(title: "No Events Found", message: "No events were found in the syllabus", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
                return
            }
            for (date, event) in pairs {
                print("Date: \(date)\tEvent: \(event)")
                //Change this
                let event = Event(date: date, event: event, eventClass: "CS371")
                pdfList.append(event)
                print("pdfList append")
            }
            performSegue(withIdentifier: confirmSegue, sender: self)
        } else {
            print("Failed to load PDF document.")
        }
    }
    
    func extractEventDatePairs(from text: String) -> [(date: String, event: String)] {
        let months = "(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:t)?(?:ember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)"
            let datePattern = #"\b\#(months) \d{1,2}\b"#

            guard let dateRegex = try? NSRegularExpression(pattern: datePattern, options: .caseInsensitive) else {
                return []
            }

            var results: [(String, String)] = []
            let lines = text.components(separatedBy: .newlines)

            for line in lines {
                let nsrange = NSRange(line.startIndex..., in: line)
                let matches = dateRegex.matches(in: line, options: [], range: nsrange)
                if matches.isEmpty {
                    continue
                }

                let dates = matches.compactMap { match -> String? in
                    guard let range = Range(match.range, in: line) else { return nil }
                    return String(line[range])
                }

                let eventDate = dates.first!
                let eventDescription = line.trimmingCharacters(in: .whitespacesAndNewlines)

                results.append((eventDate, eventDescription))
            }
            return results
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("User canceled document picker.")
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return eventList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: eventId, for: indexPath)
        cell.textLabel!.text = eventList[indexPath.row].event
        cell.detailTextLabel!.text = "\(eventList[indexPath.row].eventClass)\n\(eventList[indexPath.row].date)"
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let delete = eventList[indexPath.row]
            eventList.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            let userEmail = Auth.auth().currentUser!.email
            let collection = db.collection("User")
            collection.whereField("Email", isEqualTo: userEmail!).getDocuments {
                (querySnapshot, error) in
                if let error = error {
                    print("Error finding user document: \(error.localizedDescription)")
                    return
                }
                
                guard let document = querySnapshot?.documents.first else {
                    print("No user document found")
                    return
                }
                
                let docRef = document.reference
                let eventDictArray = self.eventList.map { event in
                    return [
                        "event": event.event,
                        "date": event.date,
                        "class": event.eventClass
                    ]
                }
                docRef.updateData(["Events": eventDictArray]) {
                    error in
                    if let error = error {
                        print("Error updating Events in Firestore: \(error.localizedDescription)")
                    } else {
                        print("Successfully updated Events array in Firestore.")
                        self.deleteCalendarEvent(title: delete.event, dateString: delete.date)
                        
                        self.reloadData()
                    }
                }
                
            }
        }
    }
    
    //Add something where you check to see if the user still has events in the classes field. If not remove the class
    func reloadData() {
        eventList = [Event]()
        if let user = Auth.auth().currentUser {
            // User is signed in
            print("User is signed in with email: \(user.email ?? "No Email")")
        } else {
            // No user is signed in
            print("No user is currently signed in.")
        }
        let userEmail = Auth.auth().currentUser!.email
        print(userEmail!)
        
        let collection = db.collection("User")
        
        collection.whereField("Email", isEqualTo: userEmail!).getDocuments
        {
            (querySnapshot, error) in
            if let error = error {
                print("Error querying user: \(error.localizedDescription)")
            } else if let documents = querySnapshot?.documents, !documents.isEmpty {
                let userDoc = documents[0]
                let data = userDoc.data()
                
                if let eventsArray = data["Events"] as? [[String: Any]] {
                    for dict in eventsArray {
                        guard let event = dict["event"] as? String, let date = dict["date"] as? String, let className = dict["class"] as? String else {
                            print("Invalid event format in Firestore")
                            return
                        }
                        let myEvent = Event(date: date, event: event, eventClass: className)
                        self.eventList.append(myEvent)
                        print(myEvent.event)
                    }
                }
                
                self.tableView.reloadData()
                print("Final event list: \(self.eventList!)")
            }
        }
        
    }
    
    //ADJUST THIS AFTER INTEGRATING API FOR EVENTS
    func dateFormatter(dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy"  // Correct format for month-day-year
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current

        return formatter.date(from: dateString) ?? Date()
    }
    
    func createCalendarEvent(title: String, date: String) {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess else {
            print("User has not given calendar access")
            return
        }
        let event = EKEvent(eventStore: eventStore)
        let cal = Calendar.current
        
        event.title = title
        event.startDate = dateFormatter(dateString: date)
        event.endDate = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: event.startDate)!)
        event.isAllDay = true
        
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            print("Success in creating event")
        } catch {
            print("Error in creating event")
        }
    }
    
    func deleteCalendarEvent(title: String, dateString: String) {
        // Check calendar authorization
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess else {
            print("User has not given calendar access")
            return
        }
        
        // Parse date string to Date
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        
        guard let startDate = formatter.date(from: dateString) else {
            print("Invalid date format")
            return
        }
        
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: startDate)!)
        
        // Create predicate to search events on the date range
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        
        let events = eventStore.events(matching: predicate)
        
        // Find events with matching title
        let eventsToDelete = events.filter { $0.title == title }
        
        for event in eventsToDelete {
            do {
                try eventStore.remove(event, span: .thisEvent)
                print("Deleted event: \(event.title ?? "") on \(dateString)")
            } catch {
                print("Failed to delete event: \(error.localizedDescription)")
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == confirmSegue, let nextVC = segue.destination as? EventViewController {
            nextVC.delegate = self
            nextVC.eventList = pdfList
        }
    }
    
}
