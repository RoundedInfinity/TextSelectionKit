# ``TextSelectionKit``

Coordinate native, multi-element text selection across complex SwiftUI view hierarchies.

@Video(poster: poster, source: intro-video.mp4, alt: "Screen recording demonstrating smooth drag selection across multiple SwiftUI text elements.")


Standard SwiftUI text selection treats each `Text` view as an isolated selection island. **TextSelectionKit** unifies discrete text elements into a continuous virtual document, allowing users to drag-select across headings, body paragraphs, dividers, and columns on macOS, iOS, and visionOS.

Wrap your layout in a ``SelectionContainer`` and use ``SelectableText`` views to enable continuous selection:

```swift
import SwiftUI
import TextSelectionKit

struct ArticleView: View {
    var body: some View {
        SelectionContainer {
            VStack(alignment: .leading, spacing: 12) {
                SelectableText("Headline").font(.headline)
                Divider()
                SelectableText("Body paragraph selectable together with the headline above.")
            }
        }
    }
}
```

## Topics

### Essentials

- <doc:GettingStarted>
- ``SelectionContainer``
- ``SelectableText``
- ``SwiftUICore/View/selectionContainer(manager:hitTestPolicy:)``

### Layout and Flow Control

- <doc:MultiColumnLayouts>
- ``SwiftUICore/View/selectionOrder(_:)``
- ``SwiftUICore/View/selectionDelimiter(_:)``
- ``SwiftUICore/View/selectableTextDisabled(_:)``
- ``SelectionHitTestPolicy``

### Programmatic Selection

- ``SelectionManager``
- ``SelectionFocusCoordinator``

### Context Menus and Actions

- ``SwiftUICore/View/selectionContextMenu(placement:content:)``
- ``SelectionButton``
- ``SelectionMenu``
- ``SelectionDivider``
- ``SelectionMenuItem``
- ``SelectionKeyboardShortcut``
- ``SelectionMenuContext``
- ``SelectionMenuPlacement``
