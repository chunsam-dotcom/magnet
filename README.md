# 🧲 Magnet.swift
A lightweight Swift script to snap macOS windows to screen edges.

## ✨ Features
- Smart Snap: Aligns windows to screen edges when within 300px.
- One-Shot Fill: Expands window to full width/height if both sides are near edges.
- Force Apply: Overcomes macOS Window Manager resistance by multi-injecting coordinates.
- Vertical Monitor Support: Works perfectly with negative coordinate systems.

## 🚀 How to Run
Grant Permission: Add your Terminal (or IDE) to System Settings > Privacy & Security > Accessibility.

Execute:

```Bash
swift magnet.swift
```

## ⚠️ Notes
Grid Apps: Terminal or specialized IDEs might have 10-20px gaps due to character-grid constraints.
Re-grant Access: If you modify the code, you may need to remove and re-add the app in Accessibility settings.

## 📄 License
MIT
