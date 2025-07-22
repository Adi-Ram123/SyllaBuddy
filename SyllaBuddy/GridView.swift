//
//  GridView.swift
//  SyllaBuddy
//
//  Created by Aditya Ramaswamy on 7/22/25.
//

import UIKit

class GridView: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    
    
    @IBOutlet weak var tableView: UITableView!
    let segueId = "calendarView"
    let eventId = "eventId"
    var delegate: CalendarEventView!
    var eventList: [Event]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.hidesBackButton = true
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.514, green: 0.384, blue: 0.259, alpha: 1.0),
            .font: UIFont(name: "Arial", size: 26.0)!
        ]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        
        let hamburgerButton = UIButton(type: .system)
        hamburgerButton.setImage(UIImage(systemName: "line.horizontal.3"), for: .normal)
        hamburgerButton.tintColor = .systemBlue

        // Bigger button size for clear outline
        let size: CGFloat = 44
        hamburgerButton.frame = CGRect(x: 0, y: 0, width: size, height: size)

        // Blue square outline with slight rounding
        hamburgerButton.layer.borderColor = UIColor.systemBlue.cgColor
        hamburgerButton.layer.borderWidth = 2
        hamburgerButton.layer.cornerRadius = 4
        hamburgerButton.clipsToBounds = true

        hamburgerButton.addTarget(self, action: #selector(hamburgerPressed), for: .touchUpInside)

        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: hamburgerButton)
        
        tableView.delegate = self
        tableView.dataSource = self
        
        
        // Do any additional setup after loading the view.
    }
    
    @objc func hamburgerPressed() {
        performSegue(withIdentifier: segueId, sender: self)
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
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
