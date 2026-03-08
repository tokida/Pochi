# Pochi

<p align="center">
  <img src="AppIcon.png" alt="Pochi App Icon" width="128" height="128">
</p>

<p align="center">
  <strong>A simple, lightweight voice recorder for macOS that lives in your menu bar.<br>Built-in MCP server for AI-powered recording management.</strong>
</p>

---

**Pochi** is designed for moments when you need to start recording instantly—meetings, quick ideas, or interviews—without cluttering your Dock.

## ✨ Key Features

*   **Menu Bar Resident:** Always accessible from the menu bar (next to the clock), keeping your Dock clean.
*   **Pop-over UI:** Click the icon to see your recent recordings, rename them, or manage settings instantly.
*   **One-Touch Recording:** Start/Stop recording instantly via Global Hotkey (`Cmd+Opt+R`) or the big record button in the menu.
*   **Speech-to-Text:** Automatic transcription after recording using Apple's on-device speech recognition (Japanese). Results are cached as JSON in `~/Music/Pochi/transcripts/`. Long audio files are automatically split into chunks for reliable processing.
*   **File Management:**
    *   **Rename List:** Rename your recorded files directly from the list (extensions are preserved automatically).
    *   **One-Click Finder Access:** Click the folder icon to instantly reveal your recordings in Finder.
    *   **Duration Display:** Each recording shows its duration (`mm:ss`) in the list.
    *   **Transcription Badge:** A `txt` badge indicates transcription status — click to trigger or open the transcript.
*   **Minimalist & Configurable:**
    *   **Gear Menu:** A clean settings menu tucked away under a gear icon.
    *   **Launch at Login:** Option to automatically start Pochi when you log in to your Mac.
    *   **Menu Bar Timer:** Option to show the recording duration directly in the menu bar (e.g., `🔴 01:23`).
*   **Visual Indicators:**
    *   **Dynamic Icon:** The menu bar icon changes to a recording indicator and pulses based on your voice level.
*   **High Quality AAC:** Saves in standard AAC (.m4a) format, perfect for importing into tools like **Google NotebookLM**.
*   **Single Instance:** Automatic duplicate prevention — only one GUI instance can run at a time.
*   **MCP Server Built-in:** The app itself acts as an [MCP (Model Context Protocol)](https://modelcontextprotocol.io/) server. Control recording and manage files from Claude Desktop or Claude Code — no extra installation needed.

## 📥 Installation

1.  Download the latest release from [GitHub Releases](https://github.com/tokida/Pochi/releases/latest).
2.  Unzip the downloaded file.
3.  Move `Pochi.app` to your **Applications** folder.
4.  Double-click to launch.
    *   *Note:* You will be asked to grant **Microphone Access** and **Speech Recognition** permission on the first launch. Please click **"OK"**.

## 🚀 Usage

### Start / Stop Recording

You can control Pochi in two ways:

1.  **Global Hotkey (Recommended):**
    *   Press `Command` + `Option` + `R` anywhere to toggle recording.
    *   Works even when Pochi is in the background.

2.  **Menu Bar Interface:**
    *   Click the icon (Mic or Red Dot) in the menu bar to open the popover.
    *   Click the large **Record Button** at the top.

### Managing Recordings

1.  **View Recent:** The popover shows your last 10 recordings.
2.  **Rename:** Click on any filename in the list to rename it. The extension (.m4a) is handled automatically.
3.  **Delete:** Swipe left or use right-click logic (depending on OS config) to delete recordings from the list.
4.  **Open Folder:** Click the **Folder Icon (📂)** in the bottom left to open `~/Music/Pochi` in Finder.

### Settings ⚙️

Click the **Gear Icon** in the bottom right corner to access:

*   **Launch at Login:** Enable/disable auto-start.
*   **Show Timer in Menu Bar:** Toggle the real-time duration display in the menu bar.
*   **Quit Pochi:** Completely exit the application.

## 🤖 MCP Integration

Pochi includes a built-in MCP server. The same binary runs as a GUI app normally, or as an MCP server when launched with `--mcp`.

### Setup

**Claude Code:**

```bash
eval $(/Applications/Pochi.app/Contents/MacOS/Pochi --mcp-install)
```

**Claude Desktop (One-Click Install):**

1. Download `pochi.mcpb` from [GitHub Releases](https://github.com/tokida/Pochi/releases/latest).
2. Open Claude Desktop → Settings → Install Extension...
3. Select the downloaded `pochi.mcpb` file.

**Claude Desktop (Manual):**

Run the following command and add the output to your Claude Desktop configuration:

```bash
/Applications/Pochi.app/Contents/MacOS/Pochi --mcp-config
```

### Available Tools

| Tool | Description | GUI Required |
|------|-------------|:---:|
| `start_recording` | Start audio recording (auto-launches GUI if needed) | Auto |
| `stop_recording` | Stop audio recording (auto-launches GUI if needed) | Auto |
| `get_recording_status` | Check current recording state | No |
| `list_recordings` | List recordings (with date filter / limit) | No |
| `get_recording_info` | Get file details (size, duration, date) | No |
| `rename_recording` | Rename a recording file | No |
| `delete_recording` | Move recording to Trash | No |
| `search_recordings` | Search recordings by filename | No |
| `get_transcription` | Get speech-to-text transcription of a recording | No |

### Architecture

```
┌──────────────────────────────────────────────────┐
│                 Pochi Binary                      │
│                                                   │
│   No flag   → GUI app (menu bar)                 │
│   --mcp     → MCP server (stdio transport)       │
│   --mcp-install → Claude Code setup helper       │
│   --mcp-config  → Claude Desktop config output   │
└──────────────────────────────────────────────────┘

Process 1: Pochi (GUI)        Process 2: Pochi --mcp
    ↕ NSDistributedNotification     ↕ stdio (MCP protocol)
    └──── ~/Music/Pochi/ ──────────┘
           Shared data layer
```

- **Recording control** (`start`/`stop`) auto-launches the GUI app if not running. The MCP server sends a notification to the GUI process.
- **File management** (`list`/`rename`/`delete`/`search`/`info`) works independently — the MCP server reads `~/Music/Pochi/` directly.
- **Transcription** (`get_transcription`) runs on-device speech recognition and caches results in `~/Music/Pochi/transcripts/`.
- Deleted files are moved to **Finder Trash** (recoverable).

## ⚠️ Notes

*   **Sleep Prevention:** Pochi automatically prevents your Mac from sleeping while recording is in progress.

## Requirements

*   macOS 13.0 (Ventura) or later
*   Apple Silicon (M1/M2/M3) or Intel Mac

### Build Requirements

*   Swift 6.0+ (Xcode 16+)

## License

This project is licensed under the [MIT License](LICENSE).