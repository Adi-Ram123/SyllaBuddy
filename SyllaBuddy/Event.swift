//
//  Event.swift
//  SyllaBuddy
//
//  Created by Aditya Ramaswamy on 7/12/25.
//

import Foundation
class Event {
    
    var date: String
    var event: String
    var eventClass: String
    
    init(date: String, event: String, eventClass: String) {
        self.date = date
        self.event = event
        self.eventClass = eventClass
    }
    
    func toDictionary() -> [String: Any] {
        return ["class": eventClass,
                "date": date,
                "event": event
        ]
    }
    
}
