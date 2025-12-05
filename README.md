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
*   **One-Touch Recording:** Start/Stop recording instantly via Global Hotkey or Menu click.
*   **Visual Indicators:**
    *   **Menu Bar Icon:** The red dot icon pulses and changes size in real-time based on your voice level.
    *   **Floating Panel:** A small panel appears at the top-right of your screen during recording to show duration and audio levels.
*   **Auto-Save:** Recordings are automatically named with the timestamp (`Recording_YYYY-MM-DD_HH-mm-ss.m4a`) and saved locally.
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

2.  **Menu Bar Icon:**
    *   Click the icon (Mic or Red Dot) in the menu bar.
    *   Select **Start Recording** / **Stop Recording**.

### Accessing Recordings

1.  Click the Pochi icon in the menu bar.
2.  Select **Open Recordings Folder**.
    *   This opens `~/Music/Pochi` in Finder.

## ⚠️ Notes

*   **Quitting:** Click the menu bar icon and select **Quit** to exit the application completely.
*   **Sleep Prevention:** Pochi automatically prevents your Mac from sleeping while recording is in progress.

## Requirements

*   macOS 11.0 (Big Sur) or later
*   Apple Silicon (M1/M2/M3) or Intel Mac

## License

This project is licensed under the [MIT License](LICENSE).