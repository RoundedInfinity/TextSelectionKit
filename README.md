# TextSelectionKit

**Native, continuous multi-element text selection for SwiftUI.**

<a href="https://github.com/roundedinfinity/TextSelectionKit"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/github/roundedinfinity/TextSelectionKit/stars.svg?variant=secondary" /><img alt="badge" src="https://shieldcn.dev/github/roundedinfinity/TextSelectionKit/stars.svg?variant=secondary&amp;mode=light" /></picture></a>
<a href="https://swift.org"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/badge/Swift-6.0.svg?variant=secondary&amp;logo=ri%3ATbBrandSwift" /><img alt="badge" src="https://shieldcn.dev/badge/Swift-6.0.svg?variant=secondary&amp;mode=light&amp;logo=ri%3ATbBrandSwift" /></picture></a>
<a href="https://github.com/roundedinfinity/TextSelectionKit"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/github/roundedinfinity/TextSelectionKit/license.svg?variant=secondary" /><img alt="license" src="https://shieldcn.dev/github/roundedinfinity/TextSelectionKit/license.svg?variant=secondary&amp;mode=light" /></picture></a>

<p align="center">
  <img alt="Screen recording demonstrating smooth drag selection across multiple SwiftUI text elements." src="https://github.com/RoundedInfinity/TextSelectionKit/blob/main/Sources/TextSelectionKit/TextSelectionKit.docc/Resources/demo.gif?raw=true" width="100%" />
</p>

---

## The Problem

In standard SwiftUI, applying `.textSelection(.enabled)` treats each `Text` view as an isolated selection region. Users cannot drag their mouse or finger to highlight text across multiple headings, paragraphs, dividers, or columns.

## The Solution

**TextSelectionKit** unifies discrete SwiftUI views into a continuous virtual document coordinate space. Dragging seamlessly spans headings, body paragraphs, and dividers with authentic platform-native text selection physics, selection handles, magnifying loupes, and contextual menus.

```swift
import SwiftUI
import TextSelectionKit

struct ArticleView: View {
    var body: some View {
        SelectionContainer {
            VStack(alignment: .leading, spacing: 12) {
                SelectableText("Introduction to TextSelectionKit")
                    .font(.title2.bold())

                Divider()

                SelectableText("Dragging the mouse or finger across this divider smoothly selects both the headline and this paragraph together.")
                    .font(.body)
            }
            .padding()
        }
    }
}
```

## Features

- **Multi-Element Selection**: Continuous selection spanning distinct SwiftUI views, headings, paragraphs, and dividers.
- **Native Platform Experience**: Full integration with AppKit (macOS) and UIKit `UITextInput` (iOS/visionOS) with loupe magnifiers, selection handles, and edit menus.
- **Typography & Rich Text**: Supports system text styles, custom weights, font designs (`.serif`, `.rounded`, `.monospaced`), tracking, kerning, and markdown formatting.
- **Custom Reading Orders**: Explicit sequencing with `.selectionOrder(_:)` for multi-column grids.
- **Context Menu**: Declarative `.selectionContextMenu` with placement options and shortcut displays.
- **Programmatic Control**: Inspect and control active selection ranges via `SelectionManager`.

## Requirements

- **iOS 17.0+** / **iPadOS 17.0+**
- **macOS 14.0+**
- **visionOS 1.0+**
- **Swift 6.0+** / **Xcode 16.0+**

## Installation

### Swift Package Manager

Add `TextSelectionKit` to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/RoundedInfinity/TextSelectionKit.git", from: "1.0.0")
]
```

Or in Xcode:
1. Select **File > Add Package Dependencies...**
2. Enter the repository URL: `https://github.com/RoundedInfinity/TextSelectionKit.git`
3. Select your version rules and click **Add Package**.

---

## Quick Start

### 1. Basic Multi-Element Selection

Wrap your view hierarchy in a `SelectionContainer` and use `SelectableText`. Dragging smoothly spans across headings, dividers, tags, quotes, and body paragraphs:

```swift
import SwiftUI
import TextSelectionKit

struct ArticleView: View {
    var body: some View {
        SelectionContainer {
            VStack(alignment: .leading, spacing: 14) {
                SelectableText("Deep Dive into SwiftUI Architecture")
                    .font(.title.bold())

                Divider()

                SelectableText("""
                Standard SwiftUI isolates each `Text` element. With **TextSelectionKit**,
                 dragging your cursor or finger highlights text seamlessly across this entire view tree.
                """)
                    .font(.body)

                SelectableText("\"A unified selection experience across disjoint views.\"")
                    .font(.callout.italic())
                    .padding(.leading, 12)

                SelectableText("Works out-of-the-box with standard SwiftUI fonts, layout stacks, and custom containers.")
                    .font(.body)
            }
            .padding()
        }
    }
}
```

### 2. Programmatic Selection

Pass a `SelectionManager` into `SelectionContainer` to inspect, select, copy, or clear selection programmatically:

```swift
struct ProgrammaticSelectionView: View {
    @State private var manager = SelectionManager()

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Button("Select All") { manager.selectAll() }
                Button("Copy") { manager.copySelection() }
                    .disabled(!manager.hasSelection)
                Button("Clear") { manager.deselectAll() }
                    .disabled(!manager.hasSelection)
            }

            SelectionContainer(manager: manager) {
                VStack(alignment: .leading, spacing: 12) {
                    SelectableText("First Section Heading")
                        .font(.headline)
                    SelectableText("This content is observed and controlled programmatically by the SelectionManager.")
                }
                .padding()
            }
        }
    }
}
```

### 3. Multi-Column Reading Order

In side-by-side columns or grids, use `.selectionOrder(_:)` to prioritize column-first reading order over default visual row scanning:

<p align="center">
  <img alt="image" src="https://github.com/RoundedInfinity/TextSelectionKit/blob/main/Sources/TextSelectionKit/TextSelectionKit.docc/Resources/multicolumn-order.png?raw=true" />
</p>

```swift
SelectionContainer {
    HStack(alignment: .top, spacing: 20) {
        // Left Column (Selected 1st)
        VStack(alignment: .leading, spacing: 8) {
            SelectableText("Column 1: Header").font(.headline)
            SelectableText("Column 1: First paragraph.")
            SelectableText("Column 1: Second paragraph.")
        }
        .selectionOrder(0)

        // Right Column (Selected 2nd)
        VStack(alignment: .leading, spacing: 8) {
            SelectableText("Column 2: Header").font(.headline)
            SelectableText("Column 2: First paragraph.")
            SelectableText("Column 2: Second paragraph.")
        }
        .selectionOrder(1)
    }
}
```

> **Note on Custom Delimiters**: By default, elements are joined by newline characters (`"\n"`). Use `.selectionDelimiter(" ")` on inline views (such as first and last name tokens) to customize how text is concatenated when copied.

### 4. Custom Context Menus

Attach custom actions to the native edit menu on iOS and context menu on macOS:

```swift
SelectionContainer {
    ArticleContentView()
}
.selectionContextMenu(placement: .append) { context in
    SelectionButton(
        "Highlight",
        systemImage: "highlighter",
        // Note: The shortcut parameter is purely visual; actual keyboard shortcut triggers
        // must be handled elsewhere in your view hierarchy or macOS commands menu.
        shortcut: SelectionKeyboardShortcut("h", modifiers: [.command, .shift])
    ) {
        print("Highlighted: \(context.selectedText)")
    }

    SelectionButton("Quote in Reply", systemImage: "quote.opening") {
        print("Quoting: \(context.selectedText)")
    }

    SelectionDivider()

    SelectionMenu("Share", systemImage: "square.and.arrow.up") {
        SelectionButton("To Notes", systemImage: "note.text") { }
        SelectionButton("To Messages", systemImage: "message") { }
    }
}
```

---

## Example App

Explore the complete showcase project in [`Examples/TextSelectionKitExample`](Examples/TextSelectionKitExample) for interactive demonstrations of multi-column layouts, typography modifiers, RTL scripts, and document reader implementations.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

