import SwiftUI
import AppKit

public struct ContentView: View {
    @ObservedObject public var store: ChatStore
    @ObservedObject public var uiState: UIState
    
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
    
    public init(store: ChatStore, uiState: UIState) {
        self.store = store
        self.uiState = uiState
    }
    
    public var body: some View {
        HSplitView {
            SidebarView(store: store, uiState: uiState)
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
            
            DetailView(store: store, uiState: uiState, timeFormatter: timeFormatter)
                .frame(minWidth: 460, idealWidth: 620)
        }
        .transaction { $0.animation = nil }
        .sheet(isPresented: $uiState.showNewChatSheet) {
            NewChatSheet(store: store, uiState: uiState)
        }
        .sheet(isPresented: $uiState.showEditChatSheet) {
            EditChatSheet(store: store, uiState: uiState)
        }
        .sheet(isPresented: $uiState.showPreferencesSheet) {
            PreferencesSheetView(store: store, uiState: uiState)
        }
        .sheet(isPresented: $uiState.showAboutSheet) {
            AboutSheetView(uiState: uiState)
        }
        .sheet(isPresented: $uiState.showHelpSheet) {
            HelpSheetView(uiState: uiState)
        }
        .alert("Clear Conversation?", isPresented: $uiState.showClearConfirmAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                if let target = uiState.targetChatForAction {
                    store.clearChat(chatId: target.id)
                }
            }
        } message: {
            if let target = uiState.targetChatForAction {
                Text("Are you sure you want to clear all messages in \"\(target.title)\"? This cannot be undone.")
            } else {
                Text("Are you sure you want to clear this conversation? This cannot be undone.")
            }
        }
        .alert("Delete Conversation?", isPresented: $uiState.showDeleteConfirmAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let target = uiState.targetChatForAction {
                    store.deleteChat(chatId: target.id)
                }
            }
        } message: {
            if let target = uiState.targetChatForAction {
                Text("Are you sure you want to delete \"\(target.title)\"? All messages will be permanently removed.")
            } else {
                Text("Are you sure you want to delete this conversation? This cannot be undone.")
            }
        }
    }
}

// MARK: - Liquid Glass App Icon (Two Lenses, One Above the Other)

public struct LiquidGlassAppIcon: View {
    let size: CGFloat
    
    public var body: some View {
        Group {
            if let image = loadIconImage() {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                fallbackIcon
            }
        }
    }
    
    private func loadIconImage() -> NSImage? {
        let bundleResources = Bundle.main.resourcePath ?? ""
        let directPng = (bundleResources as NSString).appendingPathComponent("AppIcon.png")
        if FileManager.default.fileExists(atPath: directPng), let img = NSImage(contentsOfFile: directPng) {
            return img
        }
        if let img = NSImage(contentsOfFile: "./clean_icon.png") {
            return img
        }
        if let img = NSImage(named: "AppIcon") {
            return img
        }
        return NSApp.applicationIconImage
    }
    
    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.224)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(white: 0.94)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.224)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.95), Color.gray.opacity(0.35)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: max(1.0, size * 0.02)
                        )
                )
                .shadow(color: Color.black.opacity(0.12), radius: size * 0.08, x: 0, y: size * 0.04)
            
            VStack(spacing: size * 0.08) {
                OpticalLensView(
                    size: size * 0.35,
                    coreDark: Color(white: 0.04),
                    coreMid: Color(white: 0.22),
                    bezelTone: Color(white: 0.20)
                )
                
                OpticalLensView(
                    size: size * 0.35,
                    coreDark: Color(white: 0.16),
                    coreMid: Color(white: 0.36),
                    bezelTone: Color(white: 0.32)
                )
            }
        }
        .frame(width: size, height: size)
    }
}

// Single Optical Lens Component
struct OpticalLensView: View {
    let size: CGFloat
    let coreDark: Color
    let coreMid: Color
    let bezelTone: Color
    
    var body: some View {
        ZStack {
            // Metallic bezel ring
            Circle()
                .fill(bezelTone)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: max(0.5, size * 0.08))
                )
                .shadow(color: Color.black.opacity(0.35), radius: size * 0.12, x: 0, y: size * 0.08)
            
            // Inner groove
            Circle()
                .fill(Color(white: 0.08))
                .frame(width: size * 0.88, height: size * 0.88)
            
            // Lens optical glass
            Circle()
                .fill(
                    RadialGradient(
                        colors: [coreMid, coreDark],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.40
                    )
                )
                .frame(width: size * 0.78, height: size * 0.78)
                .overlay(
                    // Optical crescent glint
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.70), Color.white.opacity(0.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size * 0.50, height: size * 0.25)
                        .offset(x: -size * 0.08, y: -size * 0.14)
                )
                .overlay(
                    // Subtle blue anti-reflective coating ring
                    Circle()
                        .stroke(Color.blue.opacity(0.20), lineWidth: max(0.5, size * 0.05))
                        .frame(width: size * 0.45, height: size * 0.45)
                )
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Avatar View

public struct AvatarView: View {
    public let name: String
    public let imagePath: String?
    public let size: CGFloat
    public let isPerson1: Bool
    
    public var body: some View {
        Group {
            if let path = imagePath, let nsImage = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
            } else {
                Circle()
                    .fill(isPerson1 ? Color.accentColor : Color(NSColor.systemGray))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(String(name.prefix(1)).uppercased())
                            .font(.system(size: size * 0.44, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @ObservedObject var store: ChatStore
    @ObservedObject var uiState: UIState
    
    var body: some View {
        VStack(spacing: 0) {
            // Sidebar Header
            HStack(alignment: .center, spacing: 10) {
                Text("Revolution 2")
                    .font(.system(size: 24, weight: .bold))
                
                Spacer()
                
                Button(action: {
                    uiState.resetNewChatForm(with: store.preferences)
                    uiState.showNewChatSheet = true
                }) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(.plain)
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .help("New Conversation")
            }
            .padding(.horizontal, 16)
            .padding(.top, 36)
            .padding(.bottom, 12)
            
            // Search Field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField("Search conversations...", text: $store.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !store.searchText.isEmpty {
                    Button(action: { store.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            
            Divider()
            
            // Chat List
            if store.filteredChats.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 26))
                        .foregroundColor(.secondary)
                    Text(store.searchText.isEmpty ? "No conversations yet" : "No results found")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(store.filteredChats) { chat in
                    ChatRowView(
                        chat: chat,
                        isSelected: store.activeChatId == chat.id,
                        onSelect: {
                            store.selectChat(id: chat.id)
                        },
                        onEdit: {
                            uiState.prepareEdit(for: chat)
                            uiState.showEditChatSheet = true
                        },
                        onClear: {
                            uiState.promptClear(for: chat)
                        },
                        onDelete: {
                            uiState.promptDelete(for: chat)
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                    .listRowSeparator(.hidden)
                }
                .listStyle(.sidebar)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .transaction { $0.animation = nil }
    }
}

// MARK: - Chat Row View

struct ChatRowView: View {
    let chat: Chat
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onClear: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // Dual Avatars
                ZStack {
                    AvatarView(name: chat.person1, imagePath: chat.person1Image, size: 24, isPerson1: true)
                        .offset(x: -5, y: -4)
                    
                    AvatarView(name: chat.person2, imagePath: chat.person2Image, size: 22, isPerson1: false)
                        .offset(x: 5, y: 5)
                }
                .frame(width: 36, height: 36)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(chat.title)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Turn badge
                        Text("Next: \(chat.nextSpeaker)")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(isSelected ? 0.25 : 0.12))
                            .foregroundColor(isSelected ? .primary : Color.accentColor)
                            .cornerRadius(4)
                    }
                    
                    HStack {
                        Text("\(chat.person1) & \(chat.person2)")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if let last = chat.messages.last {
                            Text(last.text)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        } else {
                            Text("No messages")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color(NSColor.selectedContentBackgroundColor) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit Conversation...") {
                onEdit()
            }
            Divider()
            Button("Clear Conversation...") {
                onClear()
            }
            Button("Delete Conversation...", role: .destructive) {
                onDelete()
            }
        }
    }
}

// MARK: - Detail View

struct DetailView: View {
    @ObservedObject var store: ChatStore
    @ObservedObject var uiState: UIState
    let timeFormatter: DateFormatter
    
    var body: some View {
        Group {
            if let chat = store.activeChat {
                VStack(spacing: 0) {
                    // Top Conversation Toolbar (Clean: no contact adding button, no delete button)
                    ConversationHeaderView(chat: chat, store: store)
                    
                    Divider()
                    
                    // Messages Transcript
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if chat.messages.isEmpty {
                                    EmptyChatPrompt(chat: chat)
                                        .padding(.top, 40)
                                } else {
                                    ForEach(chat.messages) { msg in
                                        MessageBubbleView(
                                            message: msg,
                                            chat: chat,
                                            isPerson1: msg.sender.caseInsensitiveCompare(chat.person1) == .orderedSame,
                                            fontSize: store.preferences.fontSize,
                                            showTimestamp: store.preferences.showTimestamps,
                                            timeFormatter: timeFormatter
                                        )
                                        .id(msg.id)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                        .background(Color(NSColor.textBackgroundColor))
                        .onChange(of: chat.messages.count) { _, _ in
                            if let lastId = chat.messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                        .onAppear {
                            if let lastId = chat.messages.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Bottom Composer
                    ComposerBarView(chat: chat, store: store, uiState: uiState)
                }
            } else {
                VStack(spacing: 8) {
                    Text("No Conversation Selected")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Select a conversation from the sidebar.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))
            }
        }
        .transaction { $0.animation = nil }
    }
}

// MARK: - Conversation Header (Clean, only avatars, title, and turn pill)

struct ConversationHeaderView: View {
    let chat: Chat
    @ObservedObject var store: ChatStore
    
    var body: some View {
        HStack(spacing: 12) {
            // Dual Avatars in Header
            HStack(spacing: -6) {
                AvatarView(name: chat.person1, imagePath: chat.person1Image, size: 26, isPerson1: true)
                AvatarView(name: chat.person2, imagePath: chat.person2Image, size: 26, isPerson1: false)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(chat.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("\(chat.person1) & \(chat.person2)")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Clean Turn Indicator Pill
            Button(action: {
                _ = store.switchSpeaker(chatId: chat.id)
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Next: \(chat.nextSpeaker)")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.12))
                .foregroundColor(Color.accentColor)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Click or press Tab to switch speaker")
        }
        .padding(.horizontal, 16)
        .padding(.top, 28)
        .padding(.bottom, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Empty Chat Prompt

struct EmptyChatPrompt: View {
    let chat: Chat
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Conversation Started")
                .font(.system(size: 13, weight: .bold))
            
            Text("Messages switch speakers automatically each turn. Press Tab at any time to switch who speaks next.")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            
            Text("First to speak: \(chat.nextSpeaker)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.accentColor)
                .padding(.top, 4)
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    let message: Message
    let chat: Chat
    let isPerson1: Bool
    let fontSize: Double
    let showTimestamp: Bool
    let timeFormatter: DateFormatter
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isPerson1 {
                AvatarView(
                    name: message.sender,
                    imagePath: chat.person1Image,
                    size: 28,
                    isPerson1: true
                )
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(message.sender)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        if showTimestamp {
                            Text(timeFormatter.string(from: message.timestamp))
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                    }
                    
                    Text(message.text)
                        .font(.system(size: CGFloat(fontSize), weight: .regular))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.secondarySystemFill))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )
                }
                .frame(maxWidth: 440, alignment: .leading)
                Spacer()
            } else {
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 6) {
                        if showTimestamp {
                            Text(timeFormatter.string(from: message.timestamp))
                                .font(.system(size: 10, weight: .regular))
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        Text(message.sender)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.accentColor)
                    }
                    
                    Text(message.text)
                        .font(.system(size: CGFloat(fontSize), weight: .regular))
                        .foregroundColor(.white)
                        .textSelection(.enabled)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }
                .frame(maxWidth: 440, alignment: .trailing)
                
                AvatarView(
                    name: message.sender,
                    imagePath: chat.person2Image,
                    size: 28,
                    isPerson1: false
                )
            }
        }
    }
}

// MARK: - Composer Bar

struct ComposerBarView: View {
    let chat: Chat
    @ObservedObject var store: ChatStore
    @ObservedObject var uiState: UIState
    
    var isCurrentPerson1: Bool {
        chat.nextSpeaker.caseInsensitiveCompare(chat.person1) == .orderedSame
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // Speaker Badge Button (Clean)
            Button(action: {
                _ = store.switchSpeaker(chatId: chat.id)
            }) {
                HStack(spacing: 6) {
                    AvatarView(
                        name: chat.nextSpeaker,
                        imagePath: isCurrentPerson1 ? chat.person1Image : chat.person2Image,
                        size: 18,
                        isPerson1: isCurrentPerson1
                    )
                    Text(chat.nextSpeaker)
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .help("Click or press Tab to switch speaker")
            
            // Text Input Field
            TextField("Type a message as \(chat.nextSpeaker)...", text: $uiState.draftMessage)
                .textFieldStyle(.plain)
                .font(.system(size: CGFloat(store.preferences.fontSize), weight: .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
                .onSubmit {
                    sendMessage()
                }
            
            // Send Button
            Button(action: sendMessage) {
                HStack(spacing: 4) {
                    Text("Send")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "arrow.up")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(uiState.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.4) : Color.accentColor)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(uiState.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func sendMessage() {
        let text = uiState.draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        _ = store.sendMessage(chatId: chat.id, text: text)
        uiState.draftMessage = ""
    }
}

// MARK: - Participant Card Component (Spacious, Zero Text Truncation)

struct ParticipantCard: View {
    let roleLabel: String
    @Binding var name: String
    let defaultPlaceholder: String
    @Binding var photoPath: String?
    let isPerson1: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(roleLabel)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 14) {
                AvatarView(
                    name: name.isEmpty ? defaultPlaceholder : name,
                    imagePath: photoPath,
                    size: 44,
                    isPerson1: isPerson1
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    TextField(defaultPlaceholder, text: $name)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                    
                    HStack(spacing: 8) {
                        Button("Choose Photo...") {
                            selectPhotoFile()
                        }
                        .font(.system(size: 11))
                        .controlSize(.small)
                        
                        if photoPath != nil {
                            Button("Remove Photo") {
                                photoPath = nil
                            }
                            .font(.system(size: 11))
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }
    
    private func selectPhotoFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .webP]
        panel.prompt = "Choose Photo"
        if panel.runModal() == .OK, let url = panel.url {
            photoPath = url.path
        }
    }
}

// MARK: - New Chat Sheet ("New Conversation")

struct NewChatSheet: View {
    @ObservedObject var store: ChatStore
    @ObservedObject var uiState: UIState
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("New Conversation")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Conversation Title")
                        .font(.system(size: 12, weight: .medium))
                    TextField("e.g. Brainstorming, Interview, Debate", text: $uiState.newTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }
                
                ParticipantCard(
                    roleLabel: "PERSON 1",
                    name: $uiState.newPerson1,
                    defaultPlaceholder: "Person 1",
                    photoPath: $uiState.newPerson1Photo,
                    isPerson1: true
                )
                
                ParticipantCard(
                    roleLabel: "PERSON 2",
                    name: $uiState.newPerson2,
                    defaultPlaceholder: "Person 2",
                    photoPath: $uiState.newPerson2Photo,
                    isPerson1: false
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("First to Speak")
                        .font(.system(size: 12, weight: .medium))
                    
                    Picker("", selection: $uiState.newFirstSpeaker) {
                        Text(uiState.newPerson1.isEmpty ? "Person 1" : uiState.newPerson1)
                            .tag(uiState.newPerson1)
                        Text(uiState.newPerson2.isEmpty ? "Person 2" : uiState.newPerson2)
                            .tag(uiState.newPerson2)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(.vertical, 2)
            
            HStack {
                Button("Cancel") {
                    uiState.showNewChatSheet = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Create Conversation") {
                    let title = uiState.newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    let p1 = uiState.newPerson1.trimmingCharacters(in: .whitespacesAndNewlines)
                    let p2 = uiState.newPerson2.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    let finalP1 = p1.isEmpty ? "Person 1" : p1
                    let finalP2 = p2.isEmpty ? "Person 2" : p2
                    let finalTitle = title.isEmpty ? "Chat with \(finalP1) & \(finalP2)" : title
                    let first = (uiState.newFirstSpeaker == uiState.newPerson2) ? finalP2 : finalP1
                    
                    store.createChat(
                        title: finalTitle,
                        person1: finalP1,
                        person2: finalP2,
                        person1Image: uiState.newPerson1Photo,
                        person2Image: uiState.newPerson2Photo,
                        firstSpeaker: first
                    )
                    uiState.showNewChatSheet = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 500)
    }
}

// MARK: - Edit Chat Sheet ("Edit Conversation")

struct EditChatSheet: View {
    @ObservedObject var store: ChatStore
    @ObservedObject var uiState: UIState
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Edit Conversation")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Conversation Title")
                        .font(.system(size: 12, weight: .medium))
                    TextField("Title", text: $uiState.editTitle)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }
                
                ParticipantCard(
                    roleLabel: "PERSON 1",
                    name: $uiState.editPerson1,
                    defaultPlaceholder: "Person 1",
                    photoPath: $uiState.editPerson1Photo,
                    isPerson1: true
                )
                
                ParticipantCard(
                    roleLabel: "PERSON 2",
                    name: $uiState.editPerson2,
                    defaultPlaceholder: "Person 2",
                    photoPath: $uiState.editPerson2Photo,
                    isPerson1: false
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Speaker")
                        .font(.system(size: 12, weight: .medium))
                    
                    Picker("", selection: $uiState.editNextSpeaker) {
                        Text(uiState.editPerson1.isEmpty ? "Person 1" : uiState.editPerson1)
                            .tag(uiState.editPerson1)
                        Text(uiState.editPerson2.isEmpty ? "Person 2" : uiState.editPerson2)
                            .tag(uiState.editPerson2)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(.vertical, 2)
            
            HStack {
                Button("Cancel") {
                    uiState.showEditChatSheet = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save Changes") {
                    if let activeId = store.activeChatId {
                        store.updateChat(
                            chatId: activeId,
                            title: uiState.editTitle,
                            person1: uiState.editPerson1,
                            person2: uiState.editPerson2,
                            person1Image: uiState.editPerson1Photo,
                            person2Image: uiState.editPerson2Photo,
                            nextSpeaker: uiState.editNextSpeaker
                        )
                    }
                    uiState.showEditChatSheet = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 500)
    }
}

// MARK: - Preferences Sheet

struct PreferencesSheetView: View {
    @ObservedObject var store: ChatStore
    @ObservedObject var uiState: UIState
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Preferences")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 14) {
                // Default Names
                VStack(alignment: .leading, spacing: 6) {
                    Text("Default Names for New Chats")
                        .font(.system(size: 12, weight: .bold))
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Person 1")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            TextField("John", text: $uiState.prefDefaultPerson1)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Person 2")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            TextField("Paul", text: $uiState.prefDefaultPerson2)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                        }
                    }
                }
                
                Divider()
                
                // Typography & Display
                VStack(alignment: .leading, spacing: 8) {
                    Text("Appearance")
                        .font(.system(size: 12, weight: .bold))
                    
                    HStack {
                        Text("Message Font Size: \(Int(uiState.prefFontSize)) pt")
                            .font(.system(size: 12))
                        Spacer()
                        Slider(value: $uiState.prefFontSize, in: 11...18, step: 1)
                            .frame(width: 140)
                    }
                    
                    Toggle("Show Timestamps on Messages", isOn: $uiState.prefShowTimestamps)
                        .font(.system(size: 12))
                }
                
                Divider()
                
                // Data Storage
                VStack(alignment: .leading, spacing: 6) {
                    Text("Local Storage")
                        .font(.system(size: 12, weight: .bold))
                    
                    Text("All conversations are saved offline on this Mac.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: store.dataDirectory.path)
                    }
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 4)
            
            HStack {
                Spacer()
                
                Button("Done") {
                    var p = store.preferences
                    p.defaultPerson1 = uiState.prefDefaultPerson1
                    p.defaultPerson2 = uiState.prefDefaultPerson2
                    p.fontSize = uiState.prefFontSize
                    p.showTimestamps = uiState.prefShowTimestamps
                    store.updatePreferences(p)
                    uiState.showPreferencesSheet = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

// MARK: - Help Sheet (Explaining the App)

struct HelpSheetView: View {
    @ObservedObject var uiState: UIState
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Guide to Revolution 2")
                        .font(.system(size: 15, weight: .bold))
                    Text("Two-Person Offline Conversations")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Turn-Based Dialogue")
                        .font(.system(size: 12, weight: .bold))
                    Text("Every time a message is sent, the conversation automatically passes the turn to the other person. The input placeholder updates dynamically to show who speaks next.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Tab Key Shortcut")
                        .font(.system(size: 12, weight: .bold))
                    Text("Press the Tab key at any time while typing to immediately switch who speaks next without losing focus from the message field.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Custom Photos")
                        .font(.system(size: 12, weight: .bold))
                    Text("You can assign custom photos for both participants by choosing 'Edit Conversation...' from the Edit menu (or Cmd+E).")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Offline & Private")
                        .font(.system(size: 12, weight: .bold))
                    Text("Revolution 2 does not connect to anything external. All conversations stay completely on your Mac.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
            
            HStack {
                Spacer()
                Button("Done") {
                    uiState.showHelpSheet = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}

// MARK: - About Sheet

struct AboutSheetView: View {
    @ObservedObject var uiState: UIState
    
    var body: some View {
        VStack(spacing: 14) {
            LiquidGlassAppIcon(size: 72)
            
            VStack(spacing: 2) {
                Text("Revolution 2")
                    .font(.system(size: 18, weight: .bold))
                
                Text("Version 1.0.1")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 6) {
                Text("Made by stellarstye with the assistance of Gemini.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("The Beatles already made Revolution 1, so this is Revolution 2.")
                    .font(.system(size: 11, weight: .regular))
                    .italic()
                    .foregroundColor(.secondary)
            }
            .multilineTextAlignment(.center)
            
            Text("Strictly offline, local conversations for macOS.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Button("Close") {
                uiState.showAboutSheet = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .padding(.top, 4)
        }
        .padding(22)
        .frame(width: 360)
    }
}
