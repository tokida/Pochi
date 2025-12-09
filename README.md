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
    *   **Drag & Drop:** (Coming soon) or use the "Finder" button to access raw files.
*   **Launch at Login:** Option to automatically start Pochi when you log in to your Mac.
*   **Visual Indicators:**
    *   **Menu Bar Icon:** The red dot icon pulses and changes size in real-time based on your voice level.
    *   **Floating Panel:** A small panel appears at the top-right of your screen during recording to show duration and audio levels.
*   **High Quality AAC:** Saves in standard AAC (.m4a) format, perfect for importing into tools like **Google NotebookLM**.

## 📥 Installation

1.  Download the latest release (or unzip `Pochi.zip`).
2.  Move `Pochi.app` to your **Applications** folder.
3.  Double-click to launch.
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
4.  **Open Folder:** Click the **Folder Icon** in the bottom left to open `~/Music/Pochi` in Finder.

### Settings

*   **Launch at Login:** Toggle the checkbox at the bottom of the popover to enable/disable auto-start.

## ⚠️ Notes

*   **Quitting:** Click the **Power Icon** in the bottom right of the popover to exit the application completely.
*   **Sleep Prevention:** Pochi automatically prevents your Mac from sleeping while recording is in progress.

## Requirements

*   macOS 11.0 (Big Sur) or later
*   Apple Silicon (M1/M2/M3) or Intel Mac

## License

This project is licensed under the [MIT License](LICENSE).
