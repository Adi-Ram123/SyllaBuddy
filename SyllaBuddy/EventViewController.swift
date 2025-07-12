//
//  EventViewController.swift
//  SyllaBuddy
//
//  Created by Aditya Ramaswamy on 7/12/25.
//

import UIKit

class EventViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    
    @IBOutlet weak var tableView: UITableView!
    var delegate: PDFViewController!
    var eventList: [Event]!
    
    let cellId = "eventCell"
    
    override func viewDidLoad() {
        tableView.delegate = self
        tableView.dataSource = self
        super.viewDidLoad()

        // Do any additional setup after loading the view.
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
            guard let updatedTitle = alert.textFields?[0].text,
                  let updatedDate = alert.textFields?[1].text else { return }
            
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
        self.dismiss(animated: true)
    }
    

    

}
