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
    var threadList: [Thread]!
    var userClasses: [String]!
    let cellId = "threadId"
    let threadId = "viewThread"
    let db = Firestore.firestore()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.hidesBackButton = true
        tableView.delegate = self
        tableView.dataSource = self
        reloadThreads()
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
    
    func reloadThreads() {
        getUserClasses()
        threadList = [Thread]()
        let collection = db.collection("Thread")
        
        collection.getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching documents: \(error)")
                return
            }

            guard let documents = snapshot?.documents else {
                print("No documents found")
                return
            }
            
            for document in documents {
                let data = document.data()
                // Convert the "Posts" map to [Post]
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
                } else {
                    print("Posts is not in expected array format")
                }
                
                
                
                let myThread = Thread(className: data["Class"] as! String, posts: posts, title: data["Title"] as! String, university: data["University"] as! String)
                self.threadList.append(myThread)
                self.tableView.reloadData()
            }
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "viewThread", let nextVC = segue.destination as? PostViewController, let indexPath = tableView.indexPathForSelectedRow {
            nextVC.threadInfo = threadList[indexPath.row]
            print(threadList[indexPath.row].posts.count)
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

}
