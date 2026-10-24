# KOReader Modifications, Patches & Plugins

A curated collection of personal modifications, plugins, and **user patches** for the open-source e-reader application **[KOReader](https://github.com/koreader/koreader)**.

The purpose of this repository is to centralize custom UI adjustments, workflow automations, and feature enhancements designed to improve the daily reading experience on e-ink devices and emulators.

---

## 📂 Repository Structure

Projects are organized into dedicated modular directories by category:

```text
KOReader/
├── patches/                  # User patches (.lua) for runtime injection
│   └── next-reads/           # 'Next Reads' (TBR) shelf for Bookshelf
├── plugins/                  # Full standalone plugins (.koplugin)
│   └── (work in progress)
└── README.md                 # Repository overview and documentation

```

---

## 🛠️ Projects & Patches

### 1. [Next Reads (TBR Queue) for Bookshelf](https://www.google.com/search?q=./patches/next-reads/)

* **Type:** User Patch (`2-bookshelf-tbr-next.lua`)
* **Target:** [Bookshelf Plugin](https://www.google.com/search?q=https://github.com/bookshelf-koreader/bookshelf)
* **Description:** Injects a dedicated **"Next Reads"** tab into Bookshelf's top navigation bar and provides an inline toggle button under *Plugin Actions* (inside the book details menu) to easily add or remove titles from your immediate reading queue.
* **Compatibility:** Tested on jailbroken Kindle devices and the KOReader emulator.

*(Additional patches, scripts, and utilities will be added here as they are developed).*

---

## 📥 Installation Guide

Installation steps vary depending on whether you are using a user patch or a standalone plugin:

### User Patches (`.lua`)

1. Connect your e-reader to your computer (via USB, SSH, or SFTP).
2. Copy the desired `.lua` patch file into KOReader's patches directory:
```text
koreader/patches/

```


*(If the `patches/` folder does not exist in your KOReader root directory, create it).*
3. Restart KOReader (**Top Menu > Tools/Settings > Exit > Restart KOReader**).

### Standalone Plugins (`.koplugin`)

1. Copy the entire plugin folder (e.g., `plugin_name.koplugin/`) into:
```text
koreader/plugins/

```


2. Restart KOReader to allow the internal module loader to register the new plugin.

---

## 💡 Best Practices & Development Notes

* **Non-destructive injection:** Patches utilize KOReader's native `userpatch` subsystem, ensuring that official updates to KOReader or third-party plugins (such as Bookshelf) will not overwrite your personal configurations.
* **Diagnostics:** If any patch or script behaves unexpectedly, check the active execution log on your device:
```text
koreader/crash.log

```



---

## 📄 License

This repository is distributed under the [MIT](https://www.google.com/search?q=LICENSE) License. You are free to use, adapt, and build upon these scripts.
