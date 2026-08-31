# Handling Multi-Column Grids and Reading Order

Customize traversal sequencing and text delimiters across columns, grids, and inline tokens.

## Overview

By default, a ``SelectionContainer`` traverses elements in natural 2D layout order (top-to-bottom, left-to-right). In multi-column layouts, this can cause selection to alternate between columns row-by-row rather than finishing column 1 before moving to column 2.

### Column-First Selection Order

Use ``SwiftUICore/View/selectionOrder(_:)`` to establish explicit priority indexes:

![Annotated layout diagram showing selection order arrows proceeding down the entire first column before moving to the top of the second column.](multicolumn-order)


```swift
SelectionContainer {
    HStack(alignment: .top, spacing: 20) {
        // Left column - should be fully selected first
        VStack(alignment: .leading) {
            SelectableText("Column 1: Header")
            SelectableText("Column 1: Paragraph 1")
            SelectableText("Column 1: Paragraph 2")
        }
        .selectionOrder(0)


        // Right column - should be selected after the entire left column
        VStack(alignment: .leading) {
            SelectableText("Column 2: Header")
            SelectableText("Column 2: Paragraph 1")
            SelectableText("Column 2: Paragraph 2")
        }
        .selectionOrder(1)
    }
}
```

### Inline Tokens and Delimiters

When synthesizing continuous text or copying to the clipboard, elements default to newline (`"\n"`) delimiters. Use ``SwiftUICore/View/selectionDelimiter(_:)`` on horizontal stacks or token lists:

```swift
HStack {
    SelectableText("First")
    SelectableText("Last")
}
.selectionDelimiter(" ") // Copies as "First Last"
```

### Disabling Selection for Sub-Hierarchies

To exclude non-selectable captions, badges, or controls from participating in multi-element selection, use ``SwiftUICore/View/selectableTextDisabled(_:)``:

```swift
VStack {
    SelectableText("Main selectable body text.")

    VStack {
        SelectableText("Metadata / unselectable note")
    }
    .selectableTextDisabled()
}
```
