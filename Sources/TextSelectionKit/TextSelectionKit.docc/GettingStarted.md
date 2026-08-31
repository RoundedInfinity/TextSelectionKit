# Getting Started with TextSelectionKit

Learn how to integrate continuous multi-element text selection into your SwiftUI views.

## Overview

Enabling multi-element selection requires two core building blocks:
1. Enclosing the selectable region in a ``SelectionContainer``.
2. Declaring text elements using ``SelectableText`` instead of SwiftUI's standard `Text`.

### Basic Setup

Wrap your view tree in a ``SelectionContainer``. Any child ``SelectableText`` views within the container coordinate together, enabling drag selection across view boundaries and dividers:

```swift
import SwiftUI
import TextSelectionKit

struct NoteDetailView: View {
    var body: some View {
        SelectionContainer {
            VStack(alignment: .leading, spacing: 16) {
                SelectableText("Meeting Notes")
                    .font(.title2.bold())
                
                Divider()
                
                SelectableText("Discussed project timeline, architecture milestones, and release schedules.")
                    .font(.body)
            }
            .padding()
        }
    }
}
```

### Hit-Testing Policies

By default, ``SelectionContainer`` uses ``SelectionHitTestPolicy/textOnly(padding:)``. This ensures surrounding controls (such as `Button`, `Toggle`, or `TextField`) receive click and tap events without gesture conflicts:

```swift
SelectionContainer(hitTestPolicy: .textOnly) {
    VStack {
        SelectableText("Selectable text block")
        Button("Interactive Action") {
            // Fires normally without gesture collision
        }
    }
}
```

For full-page document viewers, notes, or article readers where selection should begin smoothly from empty margins or padding, use ``SelectionHitTestPolicy/container``.

### Programmatic Control

Pass a custom ``SelectionManager`` to inspect or manipulate selection state, or drive external controls:

```swift
struct ControlledView: View {
    @State private var manager = SelectionManager()

    var body: some View {
        VStack {
            HStack {
                Button("Select All") { manager.selectAll() }
                Button("Copy") { manager.copySelection() }
                    .disabled(!manager.hasSelection)
                Button("Clear") { manager.deselectAll() }
                    .disabled(!manager.hasSelection)
            }

            SelectionContainer(manager: manager) {
                SelectableText("Custom managed text content.")
            }
        }
    }
}
```
