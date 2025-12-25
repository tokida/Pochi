# Pochi

<p align="center">
  <img src="AppIcon.png" alt="Pochi App Icon" width="128" height="128">
</p>

<p align="center">
  <strong>A simple, lightweight voice recorder for macOS that lives in your menu bar.</strong>
</p>

---

**Pochi** is designed for moments when you need to start recording instantly—meetings, quick ideas, or interviews—without cluttering your Dock.

## ✨ Key Features

*   **Menu Bar Resident:** Always accessible from the menu bar (next to the clock), keeping your Dock clean.
*   **Pop-over UI:** Click the icon to see your recent recordings, rename them, or manage settings instantly.
*   **One-Touch Recording:** Start/Stop recording instantly via Global Hotkey (`Cmd+Opt+R`) or the big record button in the menu.
*   **File Management:**
    *   **Rename List:** Rename your recorded files directly from the list (extensions are preserved automatically).
    *   **One-Click Finder Access:** Click the folder icon to instantly reveal your recordings in Finder.
*   **Minimalist & Configurable:**
    *   **Gear Menu:** A clean settings menu tucked away under a gear icon.
    *   **Launch at Login:** Option to automatically start Pochi when you log in to your Mac.
    *   **Menu Bar Timer:** Option to show the recording duration directly in the menu bar (e.g., `🔴 01:23`).
*   **Visual Indicators:**
    *   **Dynamic Icon:** The menu bar icon changes to a recording indicator and pulses based on your voice level.
*   **High Quality AAC:** Saves in standard AAC (.m4a) format, perfect for importing into tools like **Google NotebookLM**.

## 📥 Installation

1.  Download the latest release from [GitHub Releases](https://github.com/tokida/Pochi/releases/latest).
2.  Unzip the downloaded file.
3.  Move `Pochi.app` to your **Applications** folder.
4.  Double-click to launch.
    *   *Note:* You will be asked to grant **Microphone Access** on the first launch. Please click **"OK"**.

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

## ⚠️ Notes

*   **Sleep Prevention:** Pochi automatically prevents your Mac from sleeping while recording is in progress.

## Requirements

*   macOS 11.0 (Big Sur) or later
*   Apple Silicon (M1/M2/M3) or Intel Mac

## License

This project is licensed under the [MIT License](LICENSE).