//
//  PDFViewController.swift
//  SyllaBuddy
//
//  Created by Aditya Ramaswamy on 7/12/25.
//

import UIKit
import UniformTypeIdentifiers
import PDFKit
import FirebaseFirestore
import FirebaseAuth
import EventKit
import Vision

// Structs to organize json file for parsing
struct OpenAIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

struct GPTResponse: Decodable {
    let course: String
    let events: [Event]
}

// Protocols for updating events and event list
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
    
    // Storing Calendar constraints to safely collapse calendar
    var calendarHeightConstraint: NSLayoutConstraint!
    var calendarHeight: CGFloat?
    var toggleOn = false
    
    // Open API key
    var apiKey: String {
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let dict = NSDictionary(contentsOf: url),
           let key = dict["OpenAIAPIKey"] as? String {
            return key
        } else {
            print("Failed to load API key from Secrets.plist")
            return ""
        }
    }
    
    var prompt = ""
    let url = URL(string: "https://api.openai.com/v1/chat/completions")
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ThemeManager.shared.applyAll(to: self)
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // Check if user wants to add events to calendar
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
        
        // Collapse calendar button
        hamburgerButton.setImage(UIImage(systemName: "line.horizontal.3"), for: .normal)
        hamburgerButton.tintColor = .systemBlue
        let size: CGFloat = 44
        hamburgerButton.frame = CGRect(x: 0, y: 0, width: size, height: size)
        toggleOn = false
        hamburgerButton.addTarget(self, action: #selector(hamburgerPressed), for: .touchUpInside)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: hamburgerButton)
        
        //Programatically set up the view
        createCalendarLayout()
        reloadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if calendarHeightConstraint == nil {
            calendarHeight = calendar.frame.height
            calendarHeightConstraint = calendar.heightAnchor.constraint(equalToConstant: calendarHeight!)
            calendarHeightConstraint.isActive = true
        }
    }
    
    // Either collapse or expand the calendar
    @objc func hamburgerPressed() {
        toggleOn = !toggleOn
            if toggleOn {
                // Collapse calendar
                calendarHeightConstraint.constant = 0
                hamburgerButton.layer.borderColor = UIColor.systemBlue.cgColor
                hamburgerButton.layer.borderWidth = 2
                hamburgerButton.layer.cornerRadius = 4
                hamburgerButton.clipsToBounds = true
                displayedEvents = eventList
                reloadData()
            } else {
                // Expand Calendar
                calendarHeightConstraint.constant = calendarHeight!
                hamburgerButton.layer.borderColor = nil
                hamburgerButton.layer.borderWidth = 0
                hamburgerButton.layer.cornerRadius = 0
                hamburgerButton.clipsToBounds = false
                
                // Select the current date
                let todayString = selectToday(on: calendarView, animated: true)
                reloadDisplayData(dateString: todayString)
            }

            // Animation to expand or collapse view
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded() //update view
            }
        
    }
    
    // Helper method to select the current day on calendar
    func selectToday(on calendarView: UICalendarView, animated: Bool) -> String {
        let today = Date()
        
        // Format date as MM-dd-yyyy
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        let todayString = formatter.string(from: today)
        
        // Select today in the calendar
        let calendarDate = Calendar.current.dateComponents([.year, .month, .day], from: today)
        if let selection = calendarView.selectionBehavior as? UICalendarSelectionSingleDate {
            selection.setSelected(calendarDate, animated: animated)
        }
        
        return todayString
    }
    
    // Programatically setup layout
    func createCalendarLayout() {
        // Get rid of auto layout
        calendar.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
    
        // Setting elements to transparent
        calendar.backgroundColor = .clear
        stackView.backgroundColor = .clear
        tableView.backgroundColor = .clear
        
        // Giving space to show toolbar images
        toolbar.heightAnchor.constraint(equalToConstant: 100).isActive = true
            
        // Round calendar
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .white  // keep white for visible rounded corners
        container.layer.cornerRadius = 15
        container.layer.masksToBounds = true  // clip inside corners
            
        // Apply shadow on calendar
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
            
        // Set up the acutal calendar
        calendarView = UICalendarView()
        calendarView.translatesAutoresizingMaskIntoConstraints = false
        calendarView.calendar = .current
        calendarView.locale = .current
        calendarView.fontDesign = .rounded
        calendarView.backgroundColor = .clear
        calendarView.delegate = self
        calendarView.selectionBehavior = UICalendarSelectionSingleDate(delegate: self)
        container.addSubview(calendarView)
        NSLayoutConstraint.activate([
            calendarView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            calendarView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            calendarView.topAnchor.constraint(equalTo: container.topAnchor),
            calendarView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        // Select todays date
        _ = selectToday(on: calendarView, animated: true)
        
        // Doing some math to calculate table height
        let rowHeight: CGFloat = 50
        let numberOfRows: CGFloat = 4
        let tableHeight = rowHeight * numberOfRows
        tableView.heightAnchor.constraint(equalToConstant: tableHeight).isActive = true
            
        // Pinning stackview and setting up settings
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
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
    
    // Add button to make an event
    @IBAction func createEvent(_ sender: Any) {
        let sheet = UIAlertController(title: "Add Event", message: "Choose how to add an event", preferredStyle: .actionSheet)
        
        sheet.addAction(UIAlertAction(title: "Add Manually", style: .default) { _ in
            self.manualAddEventOption()
        })
        sheet.addAction(UIAlertAction(title: "Upload PDF", style: .default) { _ in
            self.pdfUpload()
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(sheet, animated: true)
    }
    
    // Helper to handle adding events manually (shows the alert)
    private func manualAddEventOption() {
        let alert = UIAlertController(title: "Add Event", message: nil, preferredStyle: .alert)
        
        alert.addTextField { $0.placeholder = "Class" }
        alert.addTextField { $0.placeholder = "Event" }
        alert.addTextField {
            $0.placeholder = "MM-DD-YYYY"
            $0.keyboardType = .numbersAndPunctuation
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Add", style: .default) { _ in
            self.manualAddEvent(from: alert)
        })
        
        present(alert, animated: true)
    }
    
    // Actually adds the event
    private func manualAddEvent(from alert: UIAlertController) {
        guard
            let newClass = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines),
            let newEvent = alert.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines),
            let dateString = alert.textFields?[2].text?.trimmingCharacters(in: .whitespacesAndNewlines),
            !newClass.isEmpty, !newEvent.isEmpty, !dateString.isEmpty
        else {
            presentAlert(title: "Missing Input", message: "Please fill out all fields before adding the event.")
            return
        }
        
        // Check for duplicates silently
        if eventList.contains(where: { $0.event == newEvent && $0.date == dateString && $0.eventClass == newClass }) {
            return
        }
        
        guard isValidDate(dateString) else {
            presentAlert(title: "Invalid Date", message: "Please enter the date in MM-dd-yyyy format (e.g. 06-18-2025).")
            return
        }
        
        addToFirestore(eventClass: newClass, event: newEvent, dateString: dateString)
    }
    
    // Helepr to ensure that the date is correct
    private func isValidDate(_ dateString: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString) != nil
    }
    
    // After validation add the event to firestore
    private func addToFirestore(eventClass: String, event: String, dateString: String) {
        let newEvent = Event(date: dateString, event: event, eventClass: eventClass)
        eventList.append(newEvent)
        
        guard let userEmail = Auth.auth().currentUser?.email else { return }
        
        let eventDictionaries = eventList.map { $0.toDictionary() }
        let collection = db.collection("User")
        
        collection.whereField("Email", isEqualTo: userEmail).getDocuments { snapshot, error in
            guard let document = snapshot?.documents.first else { return }
            
            document.reference.updateData([
                "Events": eventDictionaries,
                "Classes": FieldValue.arrayUnion([eventClass])
            ]) { error in
                if error != nil {
                    self.presentAlert(title: "Event Error", message: "Error in creating event")
                } else {
                    self.presentAlert(title: "Event Creation", message: "Successfully created event")
                    self.createCalendarEvent(title: event, date: dateString)
                    self.reloadData()
                }
            }
        }
    }
    
    // Helper to present alerts
    private func presentAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // Get the pdf selection from user
    func pdfUpload() {
        let supportedTypes: [UTType] = [UTType.pdf]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }
    
    // Select the PDF and call API to generate the events
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        
        pdfList = [Event]()
        guard let selectedURL = urls.first else { return }

        guard selectedURL.startAccessingSecurityScopedResource() else {
            makePopup(popupTitle: "PDF Error", popupMessage: "Error in reading PDF")
            return
        }
        defer { selectedURL.stopAccessingSecurityScopedResource() }

        let fileExtension = selectedURL.pathExtension.lowercased()

        if fileExtension == "pdf" {
            let extractedText = extractTextFromPDF(url: selectedURL)
            self.callChatGPT(with: extractedText) { result in
                switch result {
                    case .success(let gptResponse):
                        if gptResponse.events.isEmpty {
                            DispatchQueue.main.async {
                                self.makePopup(popupTitle: "PDF Error", popupMessage: "No Events were found")
                            }
                            return
                        }
                        
                        let course = gptResponse.course
                        for event in gptResponse.events {
                            let newEvent = Event(date: event.date, event: event.event, eventClass: course)
                            self.pdfList.append(newEvent)
                        }
                        
                        DispatchQueue.main.async {
                            self.performSegue(withIdentifier: self.confirmSegue, sender: self)
                        }

                    case .failure(let error):
                        DispatchQueue.main.async {
                            self.makePopup(popupTitle: "PDF Error", popupMessage: "Error in finding")
                        }
                        //print("Error calling GPT: \(error)")
                }
            }

        } else if ["png", "jpg", "jpeg"].contains(fileExtension) {
            if let image = UIImage(contentsOfFile: selectedURL.path) {
                extractTextFromImage(image) { extractedText in
                    self.callChatGPT(with: extractedText) { result in
                        switch result {
                            case .success(let gptResponse):
                                if gptResponse.events.isEmpty {
                                    return
                                }
                                
                                let course = gptResponse.course
                                for event in gptResponse.events {
                                    let newEvent = Event(date: event.date, event: event.event, eventClass: course)
                                    self.pdfList.append(newEvent)
                                }

                                DispatchQueue.main.async {
                                    self.performSegue(withIdentifier: self.confirmSegue, sender: self)
                                }

                            case .failure(let error):
                                print("Failed \(error.localizedDescription)")
                            }
                    }
                }
            } else {
                print("Couldn't load image.")
            }
        } else {
            print("Unsupported file type.")
        }
    }
    
    // API call (has a completion handler to ensure that everything waits until gpt has finished parsing)
    func callChatGPT(with text: String, completion: @escaping (Result<GPTResponse, Error>) -> Void) {
        
        // Validate url
        guard let url = url else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Prompt
        let prompt = """
        Extract the course number (like CS 371L) and all assignments, exams, and major deadlines from the following syllabus text.
        
        Return the result like a JSON object with two keys:
        - "course": a string with the course number (e.g., "CS 371L")
        - "events": an array of objects where each has a "event" and a "date" (formatted as MM-dd-YYYY)
        
        Date Handling Instructions:
        - If the exact month or year of an event is unclear, assume the current month and year based on today's date.
        - If only a day is mentioned (e.g., "Project due on 15th"), format it as MM-dd-YYYY using today's month and year.
        - The "eventClass" field in each event should be set to the same string as the top-level "course".

        
        Example:
        {
            "course": "CS 371L",
            "events": [
                { "event": "Project 1 Due", "date": "06-13-2025", "eventClass": "CS 371L" },
                { "event": "Midterm Exam", "date": "07-02-2025", "eventClass": "CS 371L" }
            ]
        }
        
        Syllabus Text:
        \(text.prefix(6000)) // Safety cap to avoid any API limitations
        """
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "You are an assistant that extracts structured academic deadlines."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.2
        ]
        
        // Convert response to JSON
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        //Parse the JSON
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
               if let error = error {
                   completion(.failure(error))
                   return
               }
               guard let data = data else {
                   completion(.failure(NSError(domain: "No data", code: 0)))
                   return
               }
               do {
                   let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                   let content = decoded.choices.first?.message.content ?? ""
                   
                   let cleanedContent = self.cleanJSON(from: content)
                   print("Cleaned content:\n\(cleanedContent)")
                   
                   if let jsonData = cleanedContent.data(using: .utf8) {
                       let parsed = try JSONDecoder().decode(GPTResponse.self, from: jsonData)
                       completion(.success(parsed))
                   } else {
                       completion(.failure(NSError(domain: "Content not decodable", code: 0)))
                   }
               } catch {
                   completion(.failure(error))
               }
           }
        task.resume()
    }
    
    // Helper to clean up Json file for parsing
    func cleanJSON(from text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("```json") {
            trimmed = String(trimmed.dropFirst("```json".count))
        } else if trimmed.hasPrefix("```") {
            trimmed = String(trimmed.dropFirst(3))
        }
            
        if trimmed.hasSuffix("```") {
            trimmed = String(trimmed.dropLast(3))
        }
            
        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Helper to get text from PDF
    func extractTextFromPDF(url: URL) -> String {
        guard let doc = PDFDocument(url: url) else { return ""}
        var result = ""
        for i in 0..<doc.pageCount {
            result += doc.page(at: i)?.string ?? ""
        }
        return result
    }
    
    // Helper to get text from image
    func extractTextFromImage(_ image: UIImage, completion: @escaping (String) -> Void) {
        guard let cgImage = image.cgImage else {
            completion("")
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            var result = ""
            for observation in request.results as? [VNRecognizedTextObservation] ?? [] {
                if let text = observation.topCandidates(1).first {
                    result += text.string + "\n"
                }
            }
            completion(result)
        }
        
        request.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
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
    
    // Handles deleting events from table
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
                        self.makePopup(popupTitle: "Event Error", popupMessage: "Error in deleting event")
                    } else {
                        self.makePopup(popupTitle: "Event Deleted", popupMessage: "Succesfully deleted event")
                        self.deleteCalendarEvent(title: delete.event, dateString: delete.date)
                        self.reloadData()
                    }
                }
                
            }
        }
    }
    
    // Reload database
    func reloadFirestoreData() {
        eventList = [Event]()
        let user = Auth.auth().currentUser
        let userEmail = Auth.auth().currentUser!.email

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

                    }
                }
                if(self.toggleOn) {
                    self.displayedEvents = self.eventList
                }
                self.tableView.reloadData()
            }
        }
    }
    
    // Reload local array
    func reloadDisplayData(dateString: String) {
        displayedEvents = []
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
                self.tableView.reloadData()
            }
        }
    }
    
    func reloadData() {
        reloadFirestoreData()
        NotificationScheduler.checkPermissions()
        if let selection = calendarView.selectionBehavior as? UICalendarSelectionSingleDate,
               let selectedDateComponents = selection.selectedDate,
               let selectedDate = Calendar.current.date(from: selectedDateComponents), !toggleOn {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM-dd-yyyy"
                let dateString = formatter.string(from: selectedDate)
                reloadDisplayData(dateString: dateString)
        } else {
            //displayedEvents = eventList
            //tableView.reloadData()
        }
    }
    
    // Creates events on local calendar
    func createCalendarEvent(title: String, date: String) {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess else {
            return
        }
        let event = EKEvent(eventStore: eventStore)
        let cal = Calendar.current
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        
        event.title = title
        event.startDate = formatter.date(from: date) ?? Date()
        event.endDate = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: event.startDate)!)
        event.isAllDay = true
        
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            
        }
    }
    
    func deleteCalendarEvent(title: String, dateString: String) {
        // Check calendar authorization
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess else {
            return
        }
        
        // Parse date string to Date
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        
        guard let startDate = formatter.date(from: dateString) else {
            return
        }
        
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: startDate)!)
        
        // Essentially just fetch the event that is at the given date
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        
        // Filter the event to specifically the one I want to delete
        if let eventToDelete = events.first(where: { $0.title == title }) {
            do {
                try eventStore.remove(eventToDelete, span: .thisEvent)
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
    
    // Helper to make simple popup alerts
    func makePopup(popupTitle:String, popupMessage:String) {
        let controller = UIAlertController(
            title: popupTitle,
            message: popupMessage,
            preferredStyle: .alert)
        
        controller.addAction(UIAlertAction(title: "OK", style: .default))
        
        present(controller,animated:true)
    }
    
}
