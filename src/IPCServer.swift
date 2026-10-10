import Foundation

public class IPCServer {
    public static let shared = IPCServer()
    
    public let socketPath: String
    private var serverFd: Int32 = -1
    private var isRunning: Bool = false
    private let queue = DispatchQueue(label: "com.stellarstye.revolution.ipc", qos: .userInitiated)
    
    private weak var store: ChatStore?
    
    public init() {
        if let envSock = ProcessInfo.processInfo.environment["REVOLUTION_SOCK_PATH"], !envSock.isEmpty {
            self.socketPath = envSock
        } else {
            self.socketPath = "/tmp/revolution.sock"
        }
    }
    
    public func start(with store: ChatStore) {
        self.store = store
        guard !isRunning else { return }
        isRunning = true
        
        queue.async { [weak self] in
            self?.runServer()
        }
    }
    
    public func stop() {
        isRunning = false
        if serverFd >= 0 {
            close(serverFd)
            serverFd = -1
        }
        unlink(socketPath)
    }
    
    private func runServer() {
        unlink(socketPath)
        
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            print("[IPCServer] Failed to create socket")
            return
        }
        serverFd = fd
        
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        
        _ = withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: 104) { cptr in
                socketPath.withCString { str in
                    strncpy(cptr, str, 104)
                }
            }
        }
        
        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindRes = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sptr in
                bind(fd, sptr, addrLen)
            }
        }
        
        guard bindRes == 0 else {
            print("[IPCServer] Failed to bind socket at \(socketPath): \(String(cString: strerror(errno)))")
            close(fd)
            serverFd = -1
            return
        }
        
        guard listen(fd, 16) == 0 else {
            print("[IPCServer] Failed to listen on socket")
            close(fd)
            serverFd = -1
            return
        }
        
        print("[IPCServer] Listening on \(socketPath)")
        
        while isRunning {
            var clientAddr = sockaddr_un()
            var clientLen = socklen_t(MemoryLayout<sockaddr_un>.size)
            
            let clientFd = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sptr in
                    accept(fd, sptr, &clientLen)
                }
            }
            
            if clientFd < 0 {
                if !isRunning { break }
                continue
            }
            
            handleClient(fd: clientFd)
        }
    }
    
    private func handleClient(fd: Int32) {
        var buffer = [UInt8](repeating: 0, count: 8192)
        var receivedData = Data()
        
        while true {
            let bytesRead = read(fd, &buffer, buffer.count)
            if bytesRead <= 0 { break }
            receivedData.append(buffer, count: bytesRead)
            if receivedData.contains(10) { // newline
                break
            }
        }
        
        guard !receivedData.isEmpty,
              let json = try? JSONSerialization.jsonObject(with: receivedData, options: []) as? [String: Any],
              let action = json["action"] as? String else {
            sendError(fd: fd, message: "Invalid JSON or missing action")
            close(fd)
            return
        }
        
        let responseDict = processAction(action, payload: json)
        if let responseData = try? JSONSerialization.data(withJSONObject: responseDict, options: []),
           var responseString = String(data: responseData, encoding: .utf8) {
            responseString.append("\n")
            _ = responseString.withCString { cstr in
                write(fd, cstr, strlen(cstr))
            }
        }
        
        close(fd)
    }
    
    private func processAction(_ action: String, payload: [String: Any]) -> [String: Any] {
        guard let store = self.store else {
            return ["status": "error", "message": "Store not available"]
        }
        
        var result: [String: Any] = ["status": "ok"]
        
        DispatchQueue.main.sync {
            switch action {
            case "ping":
                result["message"] = "pong"
                result["appName"] = "Revolution 2"
                result["version"] = "1.0.1"
                
            case "status":
                result["appName"] = "Revolution 2"
                result["version"] = "1.0.1"
                result["chatsCount"] = store.chats.count
                result["activeChatId"] = store.activeChatId?.uuidString
                result["activeChatTitle"] = store.activeChat?.title
                result["dataDir"] = store.dataDirectory.path
                
            case "list_chats":
                let chatSummaries: [[String: Any]] = store.chats.map { chat in
                    var d: [String: Any] = [
                        "id": chat.id.uuidString,
                        "title": chat.title,
                        "person1": chat.person1,
                        "person2": chat.person2,
                        "nextSpeaker": chat.nextSpeaker,
                        "messageCount": chat.messages.count,
                        "lastMessage": chat.messages.last?.text ?? "",
                        "updatedAt": ISO8601DateFormatter().string(from: chat.updatedAt)
                    ]
                    if let p1Img = chat.person1Image { d["person1Image"] = p1Img }
                    if let p2Img = chat.person2Image { d["person2Image"] = p2Img }
                    return d
                }
                result["chats"] = chatSummaries
                result["activeChatId"] = store.activeChatId?.uuidString
                
            case "get_chat", "get_active_chat":
                let targetId: UUID?
                if let idStr = payload["chatId"] as? String, let uuid = UUID(uuidString: idStr) {
                    targetId = uuid
                } else {
                    targetId = store.activeChatId ?? store.chats.first?.id
                }
                
                guard let id = targetId, let chat = store.chats.first(where: { $0.id == id }) else {
                    result = ["status": "error", "message": "Chat not found"]
                    return
                }
                
                let messagesArray: [[String: Any]] = chat.messages.map { msg in
                    return [
                        "id": msg.id.uuidString,
                        "sender": msg.sender,
                        "text": msg.text,
                        "timestamp": ISO8601DateFormatter().string(from: msg.timestamp)
                    ]
                }
                
                var chatDict: [String: Any] = [
                    "id": chat.id.uuidString,
                    "title": chat.title,
                    "person1": chat.person1,
                    "person2": chat.person2,
                    "nextSpeaker": chat.nextSpeaker,
                    "createdAt": ISO8601DateFormatter().string(from: chat.createdAt),
                    "updatedAt": ISO8601DateFormatter().string(from: chat.updatedAt),
                    "messages": messagesArray
                ]
                if let p1Img = chat.person1Image { chatDict["person1Image"] = p1Img }
                if let p2Img = chat.person2Image { chatDict["person2Image"] = p2Img }
                result["chat"] = chatDict
                
            case "create_chat":
                let title = payload["title"] as? String ?? "New Conversation"
                let p1 = payload["person1"] as? String ?? store.preferences.defaultPerson1
                let p2 = payload["person2"] as? String ?? store.preferences.defaultPerson2
                let p1Img = payload["person1Image"] as? String
                let p2Img = payload["person2Image"] as? String
                let firstSpeaker = payload["firstSpeaker"] as? String ?? p1
                
                let newChat = store.createChat(
                    title: title,
                    person1: p1,
                    person2: p2,
                    person1Image: p1Img,
                    person2Image: p2Img,
                    firstSpeaker: firstSpeaker
                )
                result["chatId"] = newChat.id.uuidString
                result["title"] = newChat.title
                result["person1"] = newChat.person1
                result["person2"] = newChat.person2
                result["nextSpeaker"] = newChat.nextSpeaker
                
            case "send_message":
                guard let text = payload["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    result = ["status": "error", "message": "Message text cannot be empty"]
                    return
                }
                
                let targetId: UUID?
                if let idStr = payload["chatId"] as? String, let uuid = UUID(uuidString: idStr) {
                    targetId = uuid
                } else {
                    targetId = store.activeChatId ?? store.chats.first?.id
                }
                
                guard let id = targetId else {
                    result = ["status": "error", "message": "No chat available to send message to"]
                    return
                }
                
                let sender = payload["sender"] as? String
                if let message = store.sendMessage(chatId: id, text: text, sender: sender) {
                    let updatedChat = store.chats.first(where: { $0.id == id })
                    result["messageId"] = message.id.uuidString
                    result["sender"] = message.sender
                    result["text"] = message.text
                    result["nextSpeaker"] = updatedChat?.nextSpeaker ?? ""
                    result["chatId"] = id.uuidString
                } else {
                    result = ["status": "error", "message": "Failed to send message"]
                }
                
            case "switch_speaker":
                let targetId: UUID?
                if let idStr = payload["chatId"] as? String, let uuid = UUID(uuidString: idStr) {
                    targetId = uuid
                } else {
                    targetId = store.activeChatId ?? store.chats.first?.id
                }
                
                guard let id = targetId, let next = store.switchSpeaker(chatId: id) else {
                    result = ["status": "error", "message": "Chat not found"]
                    return
                }
                result["chatId"] = id.uuidString
                result["nextSpeaker"] = next
                
            case "select_chat":
                guard let idStr = payload["chatId"] as? String, let uuid = UUID(uuidString: idStr) else {
                    result = ["status": "error", "message": "Invalid chat ID"]
                    return
                }
                store.selectChat(id: uuid)
                result["activeChatId"] = uuid.uuidString
                
            case "clear_chat":
                let targetId: UUID?
                if let idStr = payload["chatId"] as? String, let uuid = UUID(uuidString: idStr) {
                    targetId = uuid
                } else {
                    targetId = store.activeChatId
                }
                guard let id = targetId else {
                    result = ["status": "error", "message": "No active chat to clear"]
                    return
                }
                store.clearChat(chatId: id)
                result["chatId"] = id.uuidString
                
            case "delete_chat":
                guard let idStr = payload["chatId"] as? String, let uuid = UUID(uuidString: idStr) else {
                    result = ["status": "error", "message": "Invalid chat ID"]
                    return
                }
                store.deleteChat(chatId: uuid)
                result["deletedChatId"] = uuid.uuidString
                
            case "get_preferences":
                result["preferences"] = [
                    "defaultPerson1": store.preferences.defaultPerson1,
                    "defaultPerson2": store.preferences.defaultPerson2,
                    "fontSize": store.preferences.fontSize,
                    "showTimestamps": store.preferences.showTimestamps,
                    "soundEnabled": store.preferences.soundEnabled
                ]
                
            default:
                result = ["status": "error", "message": "Unknown action '\(action)'"]
            }
        }
        
        return result
    }
    
    private func sendError(fd: Int32, message: String) {
        let err = ["status": "error", "message": message]
        if let data = try? JSONSerialization.data(withJSONObject: err, options: []),
           var str = String(data: data, encoding: .utf8) {
            str.append("\n")
            _ = str.withCString { cstr in
                write(fd, cstr, strlen(cstr))
            }
        }
    }
}
