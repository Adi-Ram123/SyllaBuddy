//
//  EventViewController.swift
//  SyllaBuddy
//
//  Created by Aditya Ramaswamy on 7/12/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class EventViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    
    @IBOutlet weak var eventFound: UILabel!
    @IBOutlet weak var tableView: UITableView!
    var delegate: CalendarEventView!
    var eventList: [Event]!
    let db = Firestore.firestore()
    
    let cellId = "eventCell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        eventFound.text = "\(eventList.count) events found in \(eventList[0].eventClass)"

        // Do any additional setup after loading the view.
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let tableVC = self.delegate as! EventReloader
        tableVC.reloadData()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        eventList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath)
        cell.textLabel!.text = eventList[indexPath.row].event
        cell.detailTextLabel!.text = eventList[indexPath.row].date
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true) // Deselect immediately
                
        let alert = UIAlertController(title: "Edit Event", message: nil, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Event"
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Date"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        alert.addAction(UIAlertAction(title: "Edit", style: .default, handler: { _ in
            guard let updatedTitle = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let updatedDate = alert.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !updatedTitle.isEmpty, !updatedDate.isEmpty else { return }
            
            self.eventList[indexPath.row].event = updatedTitle
            self.eventList[indexPath.row].date = updatedDate
            
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }))
        
        present(alert, animated: true, completion: nil)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            eventList.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
    
    
    @IBAction func confirmPressed(_ sender: Any) {
        //Determine which document to update
        let userEmail = Auth.auth().currentUser!.email
        print(userEmail!)
        
        let eventDictionaries = eventList.map { $0.toDictionary() }
        
        //I will have direct access to class with label but for now do this also update the label when I integrate
        guard let className = eventDictionaries.first?["class"] else {
            print("No class found in first event.")
            return
        }
        
        let collection = db.collection("User")
        
        collection.whereField("Email", isEqualTo: userEmail!).getDocuments
        {
            (querySnapshot, error) in
                if let error = error {
                    print("Error querying user: \(error.localizedDescription)")
                } else if let documents = querySnapshot?.documents, !documents.isEmpty {
                    let userDoc = documents[0]
                    let docRef = collection.document(userDoc.documentID)
                    
                    //Update the document
                    docRef.updateData(["Events": FieldValue.arrayUnion(eventDictionaries),
                                       "Classes": FieldValue.arrayUnion([className])])
                    {
                        error in
                        if let error = error {
                            print("Error updating events: \(error.localizedDescription)")
                        } else {
                            print("Events successfully added.")
                            let tableVC = self.delegate as! EventReloader
                            tableVC.reloadData()
                            
                            //create calendar events
                            let calendarVC = self.delegate as! EventHandler
                            self.eventList.forEach {
                                event in
                                calendarVC.createCalendarEvent(title: event.event, date: event.date)
                                print("Event added to calendar")
                            }
                            
                            
                        }
                    }
                }
        }
        
        self.dismiss(animated: true)
        
    }
    

    

}
