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
    func deleteCalendarEvent(title: String, dateString: String)
}

class CalendarEventView: UIViewController, UIDocumentPickerDelegate, UITableViewDelegate, UITableViewDataSource, EventReloader, EventHandler, UICalendarSelectionSingleDateDelegate, UICalendarViewDelegate {
    
    
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var calendar: UIView!
    
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var tableView: UITableView!
    var calendarView: UICalendarView!
    let confirmSegue = "eventConfirmSegue"
    let eventId = "eventId"
    var eventList: [Event]!
    var displayedEvents: [Event]!
    var pdfList: [Event]!
    let db = Firestore.firestore()
    let eventStore = EKEventStore()
    let hamburgerButton = UIButton(type: .system)
    // Store the height constraint and natural height
    var calendarHeightConstraint: NSLayoutConstraint!
    var calendarNaturalHeight: CGFloat?
    
    var toggleOn = false
    
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
        
        hamburgerButton.setImage(UIImage(systemName: "line.horizontal.3"), for: .normal)
        hamburgerButton.tintColor = .systemBlue

        // Bigger button size for clear outline
        let size: CGFloat = 44
        hamburgerButton.frame = CGRect(x: 0, y: 0, width: size, height: size)
        
        toggleOn = false

        

        hamburgerButton.addTarget(self, action: #selector(hamburgerPressed), for: .touchUpInside)

        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: hamburgerButton)
        
        createCalendarLayout() //May need to move to viewDidLoad
        
        
        reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

            if calendarHeightConstraint == nil {
                calendarNaturalHeight = calendar.frame.height
                print("Detected calendar height: \(calendarNaturalHeight!)")
                calendarHeightConstraint = calendar.heightAnchor.constraint(equalToConstant: calendarNaturalHeight!)
                calendarHeightConstraint.isActive = true
            }
    }
    
    @objc func hamburgerPressed() {
        toggleOn = !toggleOn
        print("Toggle Pressed")

                if toggleOn {
                    // Collapse calendar: set height to zero
                    calendarHeightConstraint.constant = 0
                    hamburgerButton.layer.borderColor = UIColor.systemBlue.cgColor
                    hamburgerButton.layer.borderWidth = 2
                    hamburgerButton.layer.cornerRadius = 4
                    hamburgerButton.clipsToBounds = true
                } else {
                    // Expand calendar: restore natural height
                    calendarHeightConstraint.constant = calendarNaturalHeight!
                    hamburgerButton.layer.borderColor = nil
                    hamburgerButton.layer.borderWidth = 0
                    hamburgerButton.layer.cornerRadius = 0
                    hamburgerButton.clipsToBounds = false
                }

                // Animate the height change
                UIView.animate(withDuration: 0.3) {
                    self.view.layoutIfNeeded()
                }
        
    }
    
    //Mess around with margins later (Doing the layout programatically)
    func createCalendarLayout() {
        // Disable autoresizing mask for views to use Auto Layout
        calendar.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
            
        // Set backgrounds transparent except toolbar and container
        calendar.backgroundColor = .clear
        stackView.backgroundColor = .clear
        tableView.backgroundColor = .clear
        
        // Toolbar fixed height (enough space for image buttons)
        toolbar.heightAnchor.constraint(equalToConstant: 100).isActive = true
            
        // Container to hold calendar view with rounded corners and white background
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .white  // keep white for visible rounded corners
        container.layer.cornerRadius = 15
        container.layer.masksToBounds = true  // clip inside corners
            
        // Shadow container to hold container and apply shadow
        let shadowContainer = UIView()
        shadowContainer.translatesAutoresizingMaskIntoConstraints = false
        shadowContainer.backgroundColor = .clear
        shadowContainer.layer.shadowColor = UIColor.black.cgColor
        shadowContainer.layer.shadowOpacity = 0.15
        shadowContainer.layer.shadowOffset = CGSize(width: 0, height: 3)
        shadowContainer.layer.shadowRadius = 6
        shadowContainer.layer.masksToBounds = false
            
        calendar.addSubview(shadowContainer)
        shadowContainer.addSubview(container)
            
        NSLayoutConstraint.activate([
            shadowContainer.leadingAnchor.constraint(equalTo: calendar.leadingAnchor, constant: 20),
            shadowContainer.trailingAnchor.constraint(equalTo: calendar.trailingAnchor, constant: -20),
            shadowContainer.topAnchor.constraint(equalTo: calendar.topAnchor, constant: 10),
            shadowContainer.bottomAnchor.constraint(equalTo: calendar.bottomAnchor, constant: -10),
                
            container.leadingAnchor.constraint(equalTo: shadowContainer.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: shadowContainer.trailingAnchor),
            container.topAnchor.constraint(equalTo: shadowContainer.topAnchor),
            container.bottomAnchor.constraint(equalTo: shadowContainer.bottomAnchor)
        ])
            
        // Create and add UICalendarView inside container
        calendarView = UICalendarView()
        calendarView.translatesAutoresizingMaskIntoConstraints = false
        calendarView.calendar = .current
        calendarView.locale = .current
        calendarView.fontDesign = .rounded
        calendarView.backgroundColor = .clear
        calendarView.delegate = self
        calendarView.selectionBehavior = UICalendarSelectionSingleDate(delegate: self)
        
        //Look back at date formatter method potentially
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        let todayString = formatter.string(from: today)
        reloadDisplayData(dateString: todayString)
        
            
        container.addSubview(calendarView)
            
        NSLayoutConstraint.activate([
            calendarView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            calendarView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            calendarView.topAnchor.constraint(equalTo: container.topAnchor),
            calendarView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
            
        // TableView fixed height for 5 rows (~50 height each)
        let rowHeight: CGFloat = 50
        let numberOfRows: CGFloat = 4
        let tableHeight = rowHeight * numberOfRows
        tableView.heightAnchor.constraint(equalToConstant: tableHeight).isActive = true
            
        // Stack view pinned to safe area with vertical padding and edges
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
            
        // Stack view properties with layout margins enabled
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = 8
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
    }
    
    func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
        reloadData()
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
        return displayedEvents.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: eventId, for: indexPath)
        cell.textLabel!.text = displayedEvents[indexPath.row].event
        cell.detailTextLabel!.text = "\(displayedEvents[indexPath.row].eventClass)\n\(displayedEvents[indexPath.row].date)"
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let delete = displayedEvents[indexPath.row]
            displayedEvents.remove(at: indexPath.row)
            if let index = eventList.firstIndex(of: delete) {
                eventList.remove(at: index)
            }
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
    
    func reloadFirestoreData() {
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
    
    func reloadDisplayData(dateString: String) {
        displayedEvents = [] // Clear previous data
            
            let userEmail = Auth.auth().currentUser!.email
            let collection = db.collection("User")
            
            collection.whereField("Email", isEqualTo: userEmail!).getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error fetching user: \(error.localizedDescription)")
                    return
                }
                
                guard let document = querySnapshot?.documents.first else {
                    print("No user document found")
                    return
                }
                
                if let eventsArray = document.data()["Events"] as? [[String: Any]] {
                    for dict in eventsArray {
                        if let event = dict["event"] as? String,
                           let date = dict["date"] as? String,
                           let className = dict["class"] as? String {
                            
                            if date == dateString {
                                let matchedEvent = Event(date: date, event: event, eventClass: className)
                                self.displayedEvents.append(matchedEvent)
                            }
                        }
                    }
                    print("Filtered events for \(dateString): \(self.displayedEvents)")
                    self.tableView.reloadData()
                }
            }
        
        
    }
    
    //Add something where you check to see if the user still has events in the classes field. If not remove the class
    func reloadData() {
        reloadFirestoreData()
        
        if let selection = calendarView.selectionBehavior as? UICalendarSelectionSingleDate,
               let selectedDateComponents = selection.selectedDate,
               let selectedDate = Calendar.current.date(from: selectedDateComponents) {
                
                let formatter = DateFormatter()
                formatter.dateFormat = "MM-dd-yyyy"
                let dateString = formatter.string(from: selectedDate)
                reloadDisplayData(dateString: dateString)
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
