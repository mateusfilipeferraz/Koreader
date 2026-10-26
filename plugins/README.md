Markdown

# All Highlights (KOReader Plugin)

A centralized highlights and notes viewer for [KOReader](https://github.com/koreader/koreader).

Browse, review, and read all annotations across your entire library directly from the main menu, without needing to open each book individually.

---

## 💡 The Problem

In KOReader, viewing highlights and bookmarks is straightforward while inside an active book. However, when browsing the File Manager or organizing your library, there is no quick, unified way to consult your saved notes across multiple titles. Reviewing quotes from finished books or checking recent annotations typically required opening each document one by one.

**All Highlights** solves this by directly reading your book metadata files (`.sdr` directories) and providing a centralized, native-styled interface to browse all your highlights, notes, and quotes from anywhere.

---

## ✨ Features

- **Centralized Library View:** Automatically detects and lists all books that contain saved highlights, along with total annotation counts.
- **Interactive Highlight Browser:** Select any title to inspect quotes with page numbers, chapter context, creation timestamps, and user notes.
- **Continuous Reading View:** View all highlights from a chosen book on a single scrollable text screen (ideal for study review or copying text).
- **Native UI Integration:** Built with standard KOReader widgets (`Menu`, `TextViewer`, `InfoMessage`) to match the stock system aesthetic.
- **Dynamic Localization:** Automatically adapts to KOReader’s active interface language (supports Portuguese and English out of the box).
- **Dispatcher Ready:** Registered as a global action (`show_all_highlights`), allowing you to bind it to gestures, corner taps, or hardware buttons.
- **Context Independent:** Works seamlessly from both the File Manager and inside an open book.

---

## 📦 Installation

1. Download or clone this repository.
https://github.com/mateusfilipeferraz/Koreader/releases#release-Highlights-Notes-Viewer-v1.0.0
2. Copy the plugin folder to your KOReader plugins directory:
   ```text
   koreader/plugins/all_highlights.koplugin/

    Make sure the structure looks like this:
    Plaintext

    koreader/
    └── plugins/
        └── all_highlights.koplugin/
            ├── _meta.lua
            ├── main.lua
            └── README.md

    Restart KOReader (Exit > Restart).

🚀 Usage

    Open KOReader's top menu (in either the File Manager or inside a book).

    Look for Library Highlights (or Destaques da Biblioteca if using Portuguese).

    The plugin will scan your document folders for .sdr metadata.

    Select a book from the list to inspect its highlights individually or open the full continuous text review.

    Note: KOReader flushes highlights to .sdr files on disk when a document is closed or saved. If you just highlighted a passage, close the book before launching the plugin to ensure the newest annotations are indexed.

⚙️ Gesture / Key Mapping (Optional)

Because the plugin registers an action with KOReader’s Dispatcher, you can map it to a gesture:

    Go to Device > Gestures (or Key mappings on button-based devices).

    Create a new shortcut and select View all highlights and notes (show_all_highlights).

📄 License

This project is open-source and released under the MIT License.