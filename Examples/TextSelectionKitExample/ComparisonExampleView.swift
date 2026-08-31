import SwiftUI
import TextSelectionKit

/// A clean side-by-side comparison view demonstrating standard SwiftUI text selection vs. TextSelectionKit multi-element selection.
///
/// Designed for screen recordings, video demonstrations, and visual verification.
public struct ComparisonExampleView: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 64) {

            VStack(alignment: .leading, spacing: 14) {
                Text("Standard SwiftUI Selection")
                    .font(.title3.bold())

                Divider()

                Text("In standard SwiftUI, each Text view functions as an isolated island. Dragging across this divider is blocked.")
                    .font(.body)
                    .lineSpacing(3)

                Divider()

                HStack(spacing: 12) {
                    Button {} label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    Button {} label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button {} label: {
                        Label("Bookmark", systemImage: "bookmark")
                    }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .font(.footnote)
                .foregroundStyle(.secondary)



                Text("You can only select within a single Text block at any given time.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .textSelection(.enabled)


            Divider()


            SelectionContainer {
                VStack(alignment: .leading, spacing: 14) {
                    SelectableText("Multi-Element Selection")
                        .font(.title3.bold())

                    Divider()

                    (SelectableText("With ")
                        + SelectableText("TextSelectionKit").bold().foregroundColor(.blue)
                        + SelectableText(", all text views form a continuous virtual document. Dragging spans across this divider seamlessly."))
                        .font(.body)
                        .lineSpacing(3)

                    Divider()

                    HStack(spacing: 12) {
                        Button {} label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        Button {} label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Button {} label: {
                            Label("Bookmark", systemImage: "bookmark")
                        }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .font(.footnote)
                    .foregroundStyle(.blue.opacity(0.8))

                    (SelectableText("Multiple distinct views, ")
                        + SelectableText("rich attributed styles").bold().foregroundColor(.blue)
                        + SelectableText(", and paragraphs are selected together naturally."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

        }
        .padding(64)

    }


}

#Preview("Standard SwiftUI vs. TextSelectionKit") {
    ComparisonExampleView()
        .frame(minWidth: 700, minHeight: 480)
}
