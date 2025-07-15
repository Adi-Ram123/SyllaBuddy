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

protocol EventReloader {
    func reloadData()
}

class CalendarEventView: UIViewController, UIDocumentPickerDelegate, UITableViewDelegate, UITableViewDataSource, EventReloader {
    
    @IBOutlet weak var tableView: UITableView!
    let confirmSegue = "eventConfirmSegue"
    let eventId = "eventId"
    var eventList: [Event]!
    let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
        reloadData()
    }
    
    
    @IBAction func pdfUpload(_ sender: Any) {
        let supportedTypes: [UTType] = [UTType.pdf]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let selectedURL = urls.first else { return }
        // Load PDF document
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
            for (date, event) in pairs {
                print("Date: \(date)\tEvent: \(event)")
                let event = Event(date: date, event: event, eventClass: "CS371")
                eventList.append(event)
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
                        self.reloadData()
                    }
                }
                
            }
        }
    }
    
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == confirmSegue, let nextVC = segue.destination as? EventViewController {
            nextVC.delegate = self
            nextVC.eventList = eventList
        }
    }
    
}
