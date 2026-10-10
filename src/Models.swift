import Foundation

public struct Message: Identifiable, Codable, Equatable {
    public let id: UUID
    public let chatId: UUID
    public var sender: String
    public var text: String
    public let timestamp: Date
    
    public init(id: UUID = UUID(), chatId: UUID, sender: String, text: String, timestamp: Date = Date()) {
        self.id = id
        self.chatId = chatId
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
    }
}

public struct Chat: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var person1: String
    public var person2: String
    public var person1Image: String?
    public var person2Image: String?
    public var nextSpeaker: String
    public let createdAt: Date
    public var updatedAt: Date
    public var messages: [Message]
    
    public init(
        id: UUID = UUID(),
        title: String,
        person1: String,
        person2: String,
        person1Image: String? = nil,
        person2Image: String? = nil,
        nextSpeaker: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [Message] = []
    ) {
        self.id = id
        let p1 = person1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Person 1" : person1
        let p2 = person2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Person 2" : person2
        self.person1 = p1
        self.person2 = p2
        self.person1Image = person1Image
        self.person2Image = person2Image
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Chat with \(p1) & \(p2)" : title
        
        let validNext = nextSpeaker?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let v = validNext, (v.caseInsensitiveCompare(p1) == .orderedSame || v.caseInsensitiveCompare(p2) == .orderedSame) {
            self.nextSpeaker = v
        } else {
            self.nextSpeaker = p1
        }
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
    
    public mutating func appendMessage(text: String, overrideSender: String? = nil) -> Message {
        let actualSender: String
        if let override = overrideSender?.trimmingCharacters(in: .whitespacesAndNewlines), !override.isEmpty {
            actualSender = override
        } else {
            actualSender = nextSpeaker
        }
        
        let msg = Message(chatId: id, sender: actualSender, text: text, timestamp: Date())
        messages.append(msg)
        updatedAt = Date()
        
        // Switch next speaker
        if actualSender.caseInsensitiveCompare(person1) == .orderedSame {
            nextSpeaker = person2
        } else if actualSender.caseInsensitiveCompare(person2) == .orderedSame {
            nextSpeaker = person1
        } else {
            nextSpeaker = (nextSpeaker == person1) ? person2 : person1
        }
        
        return msg
    }
    
    public mutating func switchSpeaker() -> String {
        if nextSpeaker.caseInsensitiveCompare(person1) == .orderedSame {
            nextSpeaker = person2
        } else {
            nextSpeaker = person1
        }
        updatedAt = Date()
        return nextSpeaker
    }
}

public struct UserPreferences: Codable, Equatable {
    public var defaultPerson1: String = "John"
    public var defaultPerson2: String = "Paul"
    public var fontSize: Double = 13.0
    public var showTimestamps: Bool = true
    public var soundEnabled: Bool = false
    
    public init() {}
}

public struct RevolutionData: Codable {
    public var version: String
    public var activeChatId: UUID?
    public var chats: [Chat]
    public var preferences: UserPreferences
    
    public init(
        version: String = "1.0.1",
        activeChatId: UUID? = nil,
        chats: [Chat] = [],
        preferences: UserPreferences = UserPreferences()
    ) {
        self.version = version
        self.activeChatId = activeChatId
        self.chats = chats
        self.preferences = preferences
    }
}
