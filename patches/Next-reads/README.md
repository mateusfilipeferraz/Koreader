 crie em inglês
Next Reads (TBR Queue) for Bookshelf (KOReader)

A lightweight and non-intrusive User Patch for KOReader that integrates a dedicated Next Reads / TBR (To Be Read) queue into the Bookshelf plugin.
🎯 Overview

Managing a large digital library often leads to choice paralysis when deciding what to read next. This patch provides a dedicated shelf view where you can pin the books you plan to read next without cluttering your main library views.
✨ Features

    Native Bookshelf Tab: Injects a dedicated "Next Reads" tab into the top shelf navigation bar to display only the books in your queue.

    Direct Book Action: Adds a toggle button ("Add to Next Reads" / "Remove from Next Reads") inside the Edit tab of the book details dialog (under the Plugin Actions section, accessed via long-pressing any book cover).

    Non-Destructive: Does not modify upstream Bookshelf or KOReader core files. Upstream updates will not overwrite your configuration.

    Lightweight Persistence: The queue list is stored in a clean JSON format at settings/bookshelf_next_queue.json.

    Customizable Label: The display name of the tab and action buttons can be customized via a single variable at the top of the script.

📥 Installation

    Download or copy the 2-bookshelf-tbr-next.lua file.

    Connect your device (Kindle, Kobo, Android, etc.) to your computer via USB or access its filesystem via SSH/SFTP.

    Place the file inside the KOReader patches directory:
    Plaintext

    koreader/patches/2-bookshelf-tbr-next.lua

    (If the patches/ folder does not exist inside koreader/, create it).

    Restart KOReader (Top Menu > Settings / Tools > Exit > Restart KOReader).

📖 Usage

    Adding/Removing a book:

        On the Bookshelf grid, long-press the cover of any book.

        Switch to the Edit tab in the book details dialog.

        Scroll down to PLUGIN ACTIONS and tap "Add to Next Reads".(To remove it later, repeat the steps and tap "Remove from Next Reads").

    Accessing the queue:

        Tap the Next Reads tab on the top navigation bar of Bookshelf to view your queued books.

⚙️ Customization

If you prefer a different label on the tab and action buttons (e.g., "TBR", "Reading Queue", or "Up Next"), open 2-bookshelf-tbr-next.lua and edit the DISPLAY_NAME variable near the top:
Lua

-- VISIBLE NAME FOR TAB AND BUTTONS
local DISPLAY_NAME = "Reading Queue"

    Note: Only change the text inside the quotes for DISPLAY_NAME. Do not rename internal identifiers ("next") throughout the rest of the script to prevent runtime errors.


📄 License

This patch is distributed under the MIT License.
