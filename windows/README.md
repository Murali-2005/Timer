# StudyFlow Windows Floating Overlay Card

A standalone always-on-top floating study timer card for Windows 10 and Windows 11 — no extra installations required.

## Features
- **Always-on-Top Overlay Card**: Floats above all open Windows applications (browsers, PDFs, IDEs, documents). Drag anywhere on the card header/background to move it around your screen.
- **Black, Grey & White Dark Theme**: Matches the monochrome dark theme (`#000000` black, `#121214` / `#222226` greys, `#FFFFFF` white).
- **Minimal First View (Timer & Buttons Only)**: Counts up from `00:00:00` with **START / RESUME**, **PAUSE**, **STOP**, and **RESET** buttons.
- **Study Log View (`Log` button in card header)**:
  - Shows **Total Studied Today** and **Times Started Today**.
  - Lists every completed session with **Start time**, **Stop time**, and **Duration**.
  - Automatically saved locally per day to `%LOCALAPPDATA%\StudyFlow\sessions.json`.

## How to Run on Windows
1. Export or download the `windows/` folder (`StudyFlowOverlay.ps1` and `Start_StudyFlow.bat`) to your Windows PC.
2. Double-click **`Start_StudyFlow.bat`** to launch the floating card overlay.
