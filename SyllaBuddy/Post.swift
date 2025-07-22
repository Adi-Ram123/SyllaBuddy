//
//  Post.swift
//  SyllaBuddy
//
//  Created by Aditya Ramaswamy on 7/22/25.
//

import Foundation

class Post {
    
    var username: String
    var message: String
    
    init(username: String, message: String) {
        self.username = username
        self.message = message
    }
    
    func toDictionary() -> [String: Any] {
        return ["username": username,
                "message": message,
        ]
    }
    
}
