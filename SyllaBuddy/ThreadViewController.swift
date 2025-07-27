//
//  ThreadViewController.swift
//  SyllaBuddy
//
//  Created by Aditya Ramaswamy on 7/24/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class ThreadViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    var threadList = [Thread]()
    var userClasses: [String]!
    let cellId = "threadId"
    let threadId = "viewThread"
    let createId = "createThreadId"
    let db = Firestore.firestore()
    var threadListener: ListenerRegistration?
    var filteredClass: String!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ThemeManager.shared.applyAll(to: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.hidesBackButton = true
        tableView.delegate = self
        tableView.dataSource = self
        getUserClasses()
        setupThreadListener()
        filteredClass = "all"
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return threadList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath)
        cell.textLabel!.text = threadList[indexPath.row].title
        cell.detailTextLabel!.text = threadList[indexPath.row].className
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: threadId, sender: self)
    }
    
    func getUserClasses() {
        userClasses = [String]()
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
                
                self.userClasses = data["Classes"] as? [String]
                print("User Classes: \(self.userClasses!)")
            }
        }
        
    }
    
    func setupThreadListener() {
        // Remove any previous listener if exists
        threadListener?.remove()
            
        threadListener = db.collection("Thread").addSnapshotListener { snapshot, error in
            if let error = error {
                print("Error listening to threads: \(error)")
                return
            }
                
            guard let documents = snapshot?.documents else {
                print("No threads found")
                return
            }
                
            // Clear old threads before repopulating
            self.threadList = [Thread]()
                
            for document in documents {
                let data = document.data()
                    
                var posts: [Post] = []
                if let postArray = data["Posts"] as? [[String: Any]] {
                    posts = postArray.compactMap { postDict in
                        guard
                            let username = postDict["username"] as? String,
                            let message = postDict["message"] as? String
                        else {
                            print("Invalid post format: \(postDict)")
                            return nil
                        }
                        return Post(username: username, message: message)
                    }
                }
                    
                if let className = data["Class"] as? String,
                    let title = data["Title"] as? String,
                    let university = data["University"] as? String {
                    let thread = Thread(className: className, posts: posts, title: title, university: university)
                        
                    // Optional filtering by userClasses
                    if self.filteredClass == "all" || self.filteredClass == className {
                        self.threadList.append(thread)
                    }
                }
            }
                
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    @IBAction func filter(_ sender: Any) {
        let alert = UIAlertController(title: "Choose Class", message: nil, preferredStyle: .actionSheet)
            
        for className in userClasses {
            alert.addAction(UIAlertAction(title: className, style: .default) {
                _ in
                self.filteredClass = "\(className)"
                print(self.filteredClass!)
                self.setupThreadListener()
            })
        }
        
        alert.addAction(UIAlertAction(title: "show all", style: .default) {
            _ in
            self.filteredClass = "all"
            print(self.filteredClass!)
            self.setupThreadListener()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
        present(alert, animated: true, completion: nil)
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == threadId, let nextVC = segue.destination as? PostViewController, let indexPath = tableView.indexPathForSelectedRow {
            nextVC.threadInfo = threadList[indexPath.row]
            print(threadList[indexPath.row].posts.count)
            tableView.deselectRow(at: indexPath, animated: true)
        }
        
        if segue.identifier == createId, let nextVC = segue.destination as? CreateThreadController {
            nextVC.userClasses = userClasses
        }
    }

}
