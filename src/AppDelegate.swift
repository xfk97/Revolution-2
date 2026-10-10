import AppKit
import SwiftUI

public class AppDelegate: NSObject, NSApplicationDelegate {
    public var window: NSWindow?
    public let store = ChatStore()
    public let uiState = UIState()
    private var keyMonitor: Any?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        
        setupMenu()
        setupWindow()
        setupTabKeyMonitor()
        
        // Start local IPC Server for CLI and MCP control
        IPCServer.shared.start(with: store)
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        IPCServer.shared.stop()
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            window?.makeKeyAndOrderFront(nil)
        }
        return true
    }
    
    private func setupWindow() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1020, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.minSize = NSSize(width: 720, height: 460)
        win.title = ""
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.center()
        
        let hostingView = NSHostingView(rootView: ContentView(store: store, uiState: uiState))
        win.contentView = hostingView
        win.makeKeyAndOrderFront(nil)
        self.window = win
    }
    
    private func setupTabKeyMonitor() {
        // Tab key (keyCode 48) changes user turn without losing focus
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 48 { // Tab key
                guard let self = self, let activeId = self.store.activeChatId else {
                    return event
                }
                
                // Do not intercept if a modal sheet is presented
                if self.uiState.showNewChatSheet || self.uiState.showEditChatSheet || self.uiState.showPreferencesSheet || self.uiState.showAboutSheet || self.uiState.showHelpSheet || self.uiState.showClearConfirmAlert || self.uiState.showDeleteConfirmAlert {
                    return event
                }
                
                _ = self.store.switchSpeaker(chatId: activeId)
                return nil // Event consumed! Turn changed cleanly
            }
            return event
        }
    }
    
    private func setupMenu() {
        let mainMenu = NSMenu()
        
        // App Menu ("Revolution 2")
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        let aboutItem = NSMenuItem(title: "About Revolution 2", action: #selector(aboutAction), keyEquivalent: "")
        aboutItem.target = self
        appMenu.addItem(aboutItem)
        
        appMenu.addItem(NSMenuItem.separator())
        
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(preferencesAction), keyEquivalent: ",")
        prefsItem.target = self
        appMenu.addItem(prefsItem)
        
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide Revolution 2", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthersItem = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit Revolution 2", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        // File Menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu
        
        let newChatItem = NSMenuItem(title: "New Conversation", action: #selector(newChatAction), keyEquivalent: "n")
        newChatItem.target = self
        fileMenu.addItem(newChatItem)
        
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        
        // Edit Menu
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        
        editMenu.addItem(NSMenuItem.separator())
        
        let editConversationItem = NSMenuItem(title: "Edit Conversation...", action: #selector(editConversationAction), keyEquivalent: "e")
        editConversationItem.target = self
        editMenu.addItem(editConversationItem)
        
        let clearConversationItem = NSMenuItem(title: "Clear Conversation...", action: #selector(clearConversationAction), keyEquivalent: "")
        clearConversationItem.target = self
        editMenu.addItem(clearConversationItem)
        
        let deleteConversationItem = NSMenuItem(title: "Delete Conversation...", action: #selector(deleteConversationAction), keyEquivalent: "")
        deleteConversationItem.target = self
        editMenu.addItem(deleteConversationItem)
        
        // Window Menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        
        // Help Menu
        let helpMenuItem = NSMenuItem()
        mainMenu.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: "Help")
        helpMenuItem.submenu = helpMenu
        
        let helpItem = NSMenuItem(title: "Guide to Revolution 2", action: #selector(helpAction), keyEquivalent: "?")
        helpItem.target = self
        helpMenu.addItem(helpItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    @objc private func newChatAction() {
        uiState.resetNewChatForm(with: store.preferences)
        uiState.showNewChatSheet = true
    }
    
    @objc private func editConversationAction() {
        if let chat = store.activeChat {
            uiState.prepareEdit(for: chat)
            uiState.showEditChatSheet = true
        }
    }
    
    @objc private func clearConversationAction() {
        if let chat = store.activeChat {
            uiState.promptClear(for: chat)
        }
    }
    
    @objc private func deleteConversationAction() {
        if let chat = store.activeChat {
            uiState.promptDelete(for: chat)
        }
    }
    
    @objc private func preferencesAction() {
        uiState.loadPreferences(store.preferences)
        uiState.showPreferencesSheet = true
    }
    
    @objc private func helpAction() {
        uiState.showHelpSheet = true
    }
    
    @objc private func aboutAction() {
        uiState.showAboutSheet = true
    }
}
