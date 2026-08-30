
# TextSelectionKit
A SwiftUI package for better native text selection.
### Goals
Have a working text selection for multiple text elements
Native behaviour on macOS and iOS!
**Problem**: normal swiftui text selection only allows selecting one Text view at a time.
Be performant! Keep it as simple as possible.
### Supposed Behavior 
Here is a propsel on how text selection should work.
```swift
  // Multiple selections are possible in this container. Dragging the mouse down will select both texts.
  SelectionContainer {
            VStack {
                // First selectable text
                SelectableText("Hello")

                Divider()
                // Second selectable text. Both text can be selected simultaniously.
                SelectableText("World")
            }
            .padding()
        }
```

## Xcode MCP
If the Xcode MCP is configured, prefer its tools over generic alternatives when working on this project:
- DocumentationSearch — verify API availability and correct usage before writing code
- BuildProject — build the project after making changes to confirm compilation succeeds
- GetBuildLog — inspect build errors and warnings
- RenderPreview — visually verify SwiftUI views using Xcode Previews
- XcodeListNavigatorIssues — check for issues visible in the Xcode Issue Navigator
- ExecuteSnippet — test a code snippet in the context of a source file
- XcodeRead, XcodeWrite, XcodeUpdate — prefer these over generic file tools when working with Xcode project files
