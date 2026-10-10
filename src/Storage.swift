import Foundation
import Combine

public class ChatStore: ObservableObject {
    @Published public var chats: [Chat] = []
    @Published public var activeChatId: UUID? = nil
    @Published public var searchText: String = ""
    @Published public var preferences: UserPreferences = UserPreferences()
    
    public let dataDirectory: URL
    public let avatarsDirectory: URL
    public let fileURL: URL
    public let mirrorFileURL: URL
    public let statusURL: URL
    
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder
    
    private var lastFileModDate: Date?
    private var lastMirrorModDate: Date?
    private var watchTimer: Timer?
    
    public init() {
        let tmpDir = URL(fileURLWithPath: "/tmp/revolution")
        _ = try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        self.mirrorFileURL = tmpDir.appendingPathComponent("chats.json")
        
        let dir: URL
        if let envPath = ProcessInfo.processInfo.environment["REVOLUTION_DATA_DIR"], !envPath.isEmpty {
            dir = URL(fileURLWithPath: envPath)
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let standardDir = home.appendingPathComponent(".revolution")
            let appSupportDir = home.appendingPathComponent("Library/Application Support/Revolution 2")
            
            if (try? FileManager.default.createDirectory(at: standardDir, withIntermediateDirectories: true)) != nil {
                dir = standardDir
            } else if (try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)) != nil {
                dir = appSupportDir
            } else {
                dir = tmpDir
            }
        }
        
        self.dataDirectory = dir
        self.avatarsDirectory = dir.appendingPathComponent("avatars")
        _ = try? FileManager.default.createDirectory(at: avatarsDirectory, withIntermediateDirectories: true)
        
        self.fileURL = dir.appendingPathComponent("chats.json")
        self.statusURL = dir.appendingPathComponent("app_status.json")
        
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.jsonEncoder.dateEncodingStrategy = .iso8601
        
        self.jsonDecoder = JSONDecoder()
        self.jsonDecoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let isoStandard = ISO8601DateFormatter()
            if let d = isoStandard.date(from: str) { return d }
            let isoFrac = ISO8601DateFormatter()
            isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = isoFrac.date(from: str) { return d }
            let localFmt = DateFormatter()
            localFmt.locale = Locale(identifier: "en_US_POSIX")
            for fmt in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ssZ"] {
                localFmt.dateFormat = fmt
                if let d = localFmt.date(from: str) { return d }
            }
            return Date()
        }
        
        load()
        updateAppStatus(running: true)
        startWatchingFile()
    }
    
    deinit {
        watchTimer?.invalidate()
        updateAppStatus(running: false)
    }
    
    public var activeChat: Chat? {
        guard let id = activeChatId else { return chats.first }
        return chats.first(where: { $0.id == id }) ?? chats.first
    }
    
    public var filteredChats: [Chat] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return chats
        }
        return chats.filter { chat in
            chat.title.lowercased().contains(query) ||
            chat.person1.lowercased().contains(query) ||
            chat.person2.lowercased().contains(query) ||
            chat.messages.contains(where: { $0.text.lowercased().contains(query) })
        }
    }
    
    public func load(from sourceURL: URL? = nil) {
        let targetURL = sourceURL ?? fileURL
        guard FileManager.default.fileExists(atPath: targetURL.path) else {
            if targetURL == fileURL && FileManager.default.fileExists(atPath: mirrorFileURL.path) {
                load(from: mirrorFileURL)
                return
            }
            seedDefaultData()
            return
        }
        
        do {
            let data = try Data(contentsOf: targetURL)
            let decoded = try jsonDecoder.decode(RevolutionData.self, from: data)
            self.chats = decoded.chats
            self.activeChatId = decoded.activeChatId ?? decoded.chats.first?.id
            self.preferences = decoded.preferences
            if targetURL != fileURL || !FileManager.default.fileExists(atPath: mirrorFileURL.path) {
                save()
            } else {
                self.lastFileModDate = getFileModificationDate(for: fileURL)
                self.lastMirrorModDate = getFileModificationDate(for: mirrorFileURL)
            }
        } catch {
            print("[Revolution 2] Error loading data from \(targetURL.path): \(error). Seeding defaults.")
            seedDefaultData()
        }
    }
    
    public func save() {
        let payload = RevolutionData(
            version: "1.0.1",
            activeChatId: activeChatId,
            chats: chats,
            preferences: preferences
        )
        do {
            let data = try jsonEncoder.encode(payload)
            let tempURL = fileURL.deletingLastPathComponent().appendingPathComponent("chats.json.tmp.\(UUID().uuidString)")
            try data.write(to: tempURL, options: .atomic)
            _ = try? FileManager.default.removeItem(at: fileURL)
            try FileManager.default.moveItem(at: tempURL, to: fileURL)
            
            if fileURL.path != mirrorFileURL.path {
                let mirrorTemp = mirrorFileURL.deletingLastPathComponent().appendingPathComponent("chats.json.tmp.\(UUID().uuidString)")
                try? data.write(to: mirrorTemp, options: .atomic)
                _ = try? FileManager.default.removeItem(at: mirrorFileURL)
                try? FileManager.default.moveItem(at: mirrorTemp, to: mirrorFileURL)
            }
            
            self.lastFileModDate = getFileModificationDate(for: fileURL)
            self.lastMirrorModDate = getFileModificationDate(for: mirrorFileURL)
        } catch {
            print("[Revolution 2] Error saving to \(fileURL.path): \(error)")
        }
    }
    
    private func getFileModificationDate(for url: URL) -> Date? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        return attrs[.modificationDate] as? Date
    }
    
    private func startWatchingFile() {
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.fileURL.path != self.mirrorFileURL.path,
               let mirrorMod = self.getFileModificationDate(for: self.mirrorFileURL) {
                if let lastMirror = self.lastMirrorModDate {
                    if mirrorMod > lastMirror {
                        DispatchQueue.main.async {
                            self.load(from: self.mirrorFileURL)
                        }
                        return
                    }
                } else {
                    self.lastMirrorModDate = mirrorMod
                }
            }
            
            if let currentModDate = self.getFileModificationDate(for: self.fileURL) {
                if let last = self.lastFileModDate {
                    if currentModDate > last {
                        DispatchQueue.main.async {
                            self.load(from: self.fileURL)
                        }
                    }
                } else {
                    self.lastFileModDate = currentModDate
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.watchTimer = timer
    }
    
    public func updateAppStatus(running: Bool) {
        let status: [String: Any] = [
            "pid": ProcessInfo.processInfo.processIdentifier,
            "appName": "Revolution 2",
            "version": "1.0.1",
            "running": running,
            "dataDir": dataDirectory.path,
            "activeChatId": activeChatId?.uuidString ?? "",
            "chatsCount": chats.count,
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]
        if let data = try? JSONSerialization.data(withJSONObject: status, options: [.prettyPrinted]) {
            try? data.write(to: statusURL, options: .atomic)
            try? data.write(to: URL(fileURLWithPath: "/tmp/revolution/app_status.json"), options: .atomic)
        }
    }
    
    private func seedDefaultData() {
        var welcomeChat = Chat(
            title: "Revolution 2",
            person1: "John",
            person2: "Paul",
            nextSpeaker: "John"
        )
        
        _ = welcomeChat.appendMessage(text: "You say you want a revolution? Well, you know...")
        _ = welcomeChat.appendMessage(text: "We all want to change the world. Every sent message passes the turn to the other person!")
        
        self.chats = [welcomeChat]
        self.activeChatId = welcomeChat.id
        self.preferences = UserPreferences()
        save()
    }
    
    @discardableResult
    public func createChat(
        title: String,
        person1: String,
        person2: String,
        person1Image: String? = nil,
        person2Image: String? = nil,
        firstSpeaker: String? = nil
    ) -> Chat {
        let newChat = Chat(
            title: title,
            person1: person1,
            person2: person2,
            person1Image: person1Image,
            person2Image: person2Image,
            nextSpeaker: firstSpeaker
        )
        chats.insert(newChat, at: 0)
        activeChatId = newChat.id
        save()
        return newChat
    }
    
    @discardableResult
    public func sendMessage(chatId: UUID, text: String, sender: String? = nil) -> Message? {
        guard let index = chats.firstIndex(where: { $0.id == chatId }) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let msg = chats[index].appendMessage(text: trimmed, overrideSender: sender)
        save()
        return msg
    }
    
    @discardableResult
    public func switchSpeaker(chatId: UUID) -> String? {
        guard let index = chats.firstIndex(where: { $0.id == chatId }) else { return nil }
        let next = chats[index].switchSpeaker()
        save()
        return next
    }
    
    public func selectChat(id: UUID) {
        if chats.contains(where: { $0.id == id }) {
            activeChatId = id
            save()
        }
    }
    
    public func clearChat(chatId: UUID) {
        guard let index = chats.firstIndex(where: { $0.id == chatId }) else { return }
        chats[index].messages.removeAll()
        chats[index].updatedAt = Date()
        save()
    }
    
    public func deleteChat(chatId: UUID) {
        chats.removeAll(where: { $0.id == chatId })
        if activeChatId == chatId {
            activeChatId = chats.first?.id
        }
        save()
    }
    
    public func updateChat(
        chatId: UUID,
        title: String?,
        person1: String?,
        person2: String?,
        person1Image: String?,
        person2Image: String?,
        nextSpeaker: String?
    ) {
        guard let index = chats.firstIndex(where: { $0.id == chatId }) else { return }
        if let t = title, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chats[index].title = t
        }
        if let p1 = person1, !p1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let oldP1 = chats[index].person1
            chats[index].person1 = p1
            if chats[index].nextSpeaker == oldP1 {
                chats[index].nextSpeaker = p1
            }
        }
        if let p2 = person2, !p2.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let oldP2 = chats[index].person2
            chats[index].person2 = p2
            if chats[index].nextSpeaker == oldP2 {
                chats[index].nextSpeaker = p2
            }
        }
        chats[index].person1Image = person1Image
        chats[index].person2Image = person2Image
        
        if let ns = nextSpeaker, !ns.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            chats[index].nextSpeaker = ns
        }
        chats[index].updatedAt = Date()
        save()
    }
    
    public func saveAvatar(imageData: Data, forChatId chatId: UUID, personSlot: Int) -> String? {
        let filename = "\(chatId.uuidString)_p\(personSlot).png"
        let destURL = avatarsDirectory.appendingPathComponent(filename)
        do {
            try imageData.write(to: destURL, options: .atomic)
            return destURL.path
        } catch {
            print("[Revolution 2] Failed to save avatar: \(error)")
            return nil
        }
    }
    
    public func updatePreferences(_ newPrefs: UserPreferences) {
        self.preferences = newPrefs
        save()
    }
}
