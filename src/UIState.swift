import Foundation
import Combine

public class UIState: ObservableObject {
    @Published public var draftMessage: String = ""
    @Published public var showNewChatSheet: Bool = false
    @Published public var showEditChatSheet: Bool = false
    @Published public var showPreferencesSheet: Bool = false
    @Published public var showAboutSheet: Bool = false
    @Published public var showHelpSheet: Bool = false
    
    // Confirmation alerts
    @Published public var showClearConfirmAlert: Bool = false
    @Published public var showDeleteConfirmAlert: Bool = false
    @Published public var targetChatForAction: Chat? = nil
    
    // Form fields for New Chat
    @Published public var newTitle: String = ""
    @Published public var newPerson1: String = "John"
    @Published public var newPerson2: String = "Paul"
    @Published public var newFirstSpeaker: String = "John"
    @Published public var newPerson1Photo: String? = nil
    @Published public var newPerson2Photo: String? = nil
    
    // Form fields for Edit Chat
    @Published public var editTitle: String = ""
    @Published public var editPerson1: String = ""
    @Published public var editPerson2: String = ""
    @Published public var editPerson1Photo: String? = nil
    @Published public var editPerson2Photo: String? = nil
    @Published public var editNextSpeaker: String = ""
    
    // Form fields for Preferences
    @Published public var prefDefaultPerson1: String = "John"
    @Published public var prefDefaultPerson2: String = "Paul"
    @Published public var prefFontSize: Double = 13.0
    @Published public var prefShowTimestamps: Bool = true
    
    public init() {}
    
    public func resetNewChatForm(with prefs: UserPreferences) {
        newTitle = ""
        newPerson1 = prefs.defaultPerson1
        newPerson2 = prefs.defaultPerson2
        newFirstSpeaker = prefs.defaultPerson1
        newPerson1Photo = nil
        newPerson2Photo = nil
    }
    
    public func prepareEdit(for chat: Chat) {
        editTitle = chat.title
        editPerson1 = chat.person1
        editPerson2 = chat.person2
        editPerson1Photo = chat.person1Image
        editPerson2Photo = chat.person2Image
        editNextSpeaker = chat.nextSpeaker
    }
    
    public func loadPreferences(_ prefs: UserPreferences) {
        prefDefaultPerson1 = prefs.defaultPerson1
        prefDefaultPerson2 = prefs.defaultPerson2
        prefFontSize = prefs.fontSize
        prefShowTimestamps = prefs.showTimestamps
    }
    
    public func promptClear(for chat: Chat) {
        targetChatForAction = chat
        showClearConfirmAlert = true
    }
    
    public func promptDelete(for chat: Chat) {
        targetChatForAction = chat
        showDeleteConfirmAlert = true
    }
}
