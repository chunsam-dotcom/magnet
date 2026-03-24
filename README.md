# 🧲 Magnet.swift
A lightweight Swift script to snap macOS windows to screen edges.

## ✨ Features
- Smart Snap: Aligns windows to screen edges when within 300px.
- One-Shot Fill: Expands window to full width/height if both sides are near edges.
- Force Apply: Overcomes macOS Window Manager resistance by multi-injecting coordinates.
- Vertical Monitor Support: Works perfectly with negative coordinate systems.

## 🚀 How to Run
Grant Permission: Add your Terminal (or IDE, executable) to System Settings > Privacy & Security > Accessibility.

Execute:

- If you download excutable
  
```Bash
./magnet
```

- If you want to run with source code
  
```Bash
swift magnet.swift
```

> [!TIP]
> **If you see "Move to Trash" error on macOS:**
> This happens because the app is not code-signed. To fix this, run the following command in your terminal:
> ```bash
> xattr -rd com.apple.quarantine ./magnet
> ```

## ⚠️ Notes
Grid Apps: Terminal or specialized IDEs might have 10-20px gaps due to character-grid constraints.
Re-grant Access: If you modify the code, you may need to remove and re-add the app in Accessibility settings.

## 📄 License
MIT
