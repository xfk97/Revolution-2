# Revolution 2 for macOS

*The Beatles already made Revolution 1, so this is Revolution 2.*

**Revolution 2** is a native macOS two-person chat application. It does not connect to anything external. It is 100% local, which means you are either talking to yourself or sharing a keyboard like it is 1998.

Every time a message is sent, the conversation automatically passes the turn to the other participant. When creating a chat, you can configure the title, names of both people, custom photos for each person, and specify who speaks first.

---

## Info for the sake of it

- **Native macOS Design**: Frameless window without the redundant top title bar, SF Pro everywhere, and standard inline traffic light controls.
- **No Animations**: Things just happen when you click them. You do not need a 400ms spring curve to open a text box.
- **Turn-Based Dialogues**: Sending a message hands the turn to the other person automatically.
- **Tab Key Turn Switching**: Press `Tab` at any moment to switch who speaks next without losing focus from the message field.
- **Custom Participant Photos**: Choose custom photos (PNG, JPEG, WebP) for both participants so it feels slightly less lonely.
- **App Icon**: Made in Icon Composer. Two lenses, one above the other.
- **Strictly Offline & Private**: Zero cloud servers, zero analytics, zero external network connections. Conversations sit in a plain JSON file on your Mac (`~/.revolution/`).
- **Terminal CLI (`revolution`)**: Command-line tool to manage chats, send messages, switch turns, and read transcripts if you prefer the terminal.
- **Model Context Protocol (MCP)**: Native stdio MCP server (`revolution-mcp`) so AI assistants (Claude Desktop, Antigravity, Cursor) can talk to each other in your app while you watch.
- **Real-Time IPC & Live Sync**: The macOS app, the CLI, and AI agents stay synced in real time via `/tmp/revolution.sock` and `/tmp/revolution/chats.json`.

---

## Installation & Download

### Option 1: Download DMG Installer (Recommended)
Download **[`Revolution-2.dmg`](https://github.com/xfk97/Revolution-2/raw/main/Revolution-2.dmg)**, double-click to open, and drag **Revolution 2** into your **Applications** folder.

The app is immediately available in **Launchpad** and **Spotlight** (`Cmd + Space` -> `Revolution 2`).

> **Note:** Apple charges \$99 a year just to stop macOS from complaining when you open an app from the internet. This app is ad-hoc signed for free instead. If Gatekeeper blocks first launch, run:
> ```bash
> xattr -cr "/Applications/Revolution 2.app"
> ```

### Option 2: Homebrew Cask
```bash
brew tap xfk97/revolution-2 https://github.com/xfk97/Revolution-2
brew install --cask revolution-2
```

### Option 3: Build From Source
Requirements: macOS 13+, Xcode Command Line Tools (`swiftc`).

```bash
git clone https://github.com/xfk97/Revolution-2.git
cd Revolution-2
make install
```

---

## For AI Agents & Terminal Users

To type directly into the live **Revolution 2** window and wait for the other person (or another AI) to reply:

```bash
# Send a message to the live window and block until a reply comes back
./bin/revolution send "Hello there" --wait

# Or wait for the other person to speak first
./bin/revolution wait
```
