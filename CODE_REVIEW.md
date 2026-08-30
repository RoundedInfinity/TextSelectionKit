# TextSelectionKit — Code Review

### What it does

Standard SwiftUI .textSelection(.enabled) makes each Text an isolated selection island: you can't drag from a heading through a divider into a paragraph. This package fixes that. You wrap a hierarchy in SelectionContainer and use SelectableText in place of Text:

A single drag now selects across both, with native affordances: word/paragraph snapping and shift-click on macOS, UIKit grab handles and the system edit menu on iOS, ⌘C/⌘A, a context menu with Look Up and Share, arrow-key extension, and RTL/BiDi-aware highlight rects. SelectionManager exposes the selection programmatically (selectAll(), copySelection(), getSelectedAttributedString(), per-element queries).

Current state: builds clean on macOS apart from two warnings; 47 of 49 tests pass (the other 2 are iOS-only and didn't run on this destination).

### How it works internally

The design is a four-stage pipeline, and it's a sound choice for the problem.

1. Registration upward (SelectableText.swift:314-347). Each SelectableText renders a Text, and in a .background(GeometryReader) publishes a TextElementRegistration through ElementRegistrationKey — its frame in the named SelectionContainerCoordinateSpace, plus resolved PlatformFont, alignment, line spacing, line limit, truncation mode, layout direction, and delimiter. SelectionContainer collects them via onPreferenceChange (SelectionContainer.swift:75).

2. Virtual document (VirtualTextDocument.swift:294-356). Elements are sorted by explicit orderIndex, then by Y (2pt tolerance), then X. Each is assigned a global UTF-16 range, with delimiter characters occupying the gaps between them. The result is a 1-D index space over a 2-D layout, plus a concatenated fullText. Slice lookup is a binary search (:381); range→per-element mapping is a linear-with-early-break scan (:364).

3. CoreText shadow layout (CachedElementLayout, :120-290). For each element the kit rebuilds the layout itself: converts the AttributedString to NSAttributedString, synthesizes a CTParagraphStyle from the SwiftUI environment values, framesets it, applies lineLimit truncation manually, and caches the CTLines. Geometry queries (caretRect, characterRect, lineSelectionRects, closestGlobalOffset) run against this cache, walking CTRuns so BiDi highlights are per-run rather than one bounding box. Cache invalidation (isValid(for:), :277) deliberately ignores frame origin and tolerates sub-0.5pt width drift, so scrolling doesn't re-layout. That's the right call and it's the smartest part of the file.

4. Platform responder overlays. macOS (NativeSelectionOverlay_macOS.swift) is an NSView handling mouse/key events, cursor rects, and NSMenu directly. iOS (NativeSelectionOverlay_iOS.swift) implements the full UITextInput protocol over the virtual document and attaches a UITextInteraction(for: .nonEditable), letting UIKit supply loupe, handles, and edit menu for free. Both use hitTest overrides driven by SelectionHitTestPolicy so non-text controls underneath stay tappable.

The highlight itself is drawn differently per platform: iOS gets it from selectionRects(for:) via UIKit, while macOS re-renders each Text with backgroundColor/foregroundColor applied to the selected sub-range (SelectableText.swift:369-386).

The load-bearing assumption throughout is that CoreText's line breaking matches SwiftUI's. Where it doesn't, carets and highlights drift. That's inherent to the approach and worth stating in the README, not a defect.

⸻

### Correctness findings

1. text(in:) and attributedString(in:) disagree on partial delimiters — high

copySelection() (SelectionManager.swift:134) writes plain text from text(in:) (which slices fullText) and RTF from attributedString(in:) (which re-inserts element.delimiter between overlapping slices, VirtualTextDocument.swift:434-436). For any range that partially covers a multi-character delimiter, the two flavours differ. Measured with delimiter ", ":

| Range | `text(in:)` | `attributedString(in:)` |
|---|---|---|
| `4..<8` | `"e, B"` | `"e, B"` |
| `5..<8` | `", B"` | `"B"` |
| `6..<8` | `" B"` | `"B"` |

So pasting into TextEdit vs. a plain-text field gives different results. Fix by deriving both from the same slicing logic — have attributedString(in:) compute the delimiter's own global range and clip it against the requested range, the way forEachOverlappingSlice already does for element text.

2. The public onSelectionChanged callback is silently overwritten — high

SelectionManager.onSelectionChanged is documented public API (SelectionManager.swift:62), but both overlays claim it for their own redraw hook in the manager didSet (NativeSelectionOverlay_macOS.swift:22-26, _iOS.swift:47-52), and updateNSView/updateUIView reassign manager on every SwiftUI update. Any consumer closure is wiped on the next view update; conversely, a consumer setting it breaks macOS redraw and iOS selectionDidChange notification. Make the internal hook a separate stored property and fan out to both.

3. selections ranges are UTF-16 offsets, documented as "character" offsets — high (docs)

Range<Int> values from selection(for:), selections, and globalSelectedRange are UTF-16 code-unit offsets (VirtualTextDocument.swift:331). Every doc comment calls them "character" ranges/offsets. A consumer who indexes a Swift String with them gets wrong results the moment emoji or combining marks appear. Either say "UTF-16 code-unit offsets" everywhere, or expose Range<String.Index>/Range<AttributedString.Index> and keep the integers internal.

4. SelectableText("literal") does not localize — high (API)

Two overloads accept a string literal: init(_ text: String) (:242) and init(_ key: LocalizedStringKey) (:218). Swift's literal-type preference picks String, so SelectableText("Hello") skips localization entirely — silently diverging from Text("Hello"), which does localize. Users hitting this will not find it easily.

The LocalizedStringKey init itself is also unusable in practice: it recovers the key by String(describing: key) and regex-scraping key: "…" (:219-225), then looks up in Bundle.main — so it can't handle interpolation, format arguments, or a package's own .bundle. I'd delete that init and keep LocalizedStringResource/init(localized:), which are correct.

5. Runtime Strings get markdown-parsed — medium

init(_ text: String) parses markdown whenever the string contains any of *   _ ~ [ (:243-244). So SelectableText(userName) mangles snake_case_id, [1] Reference, or 2 * 3. Text(String) is verbatim; this is a surprising divergence in the direction that loses data. Either restrict markdown to the explicit init(markdown:) (already present) or document it loudly.

6. hasSelection and getSelectedText() disagree on delimiter-only selections — low

Selecting only a delimiter yields an empty selections dictionary, so hasSelection is false (:165) while getSelectedText() returns "\n". copySelection() guards on the text, not hasSelection, so it copies a bare newline. Harmless but inconsistent.

7. totalLength / fullText are not observable — medium

document is @ObservationIgnored (:57), so the public computed totalLength and fullText (:68-75) never invalidate a SwiftUI view that reads them. A view showing "1,204 characters" will be stale. Either mirror the count into an observed property or document these as non-reactive.

⸻

### Performance findings

The design is genuinely performance-conscious — cached CT layout, origin-insensitive invalidation, binary search, a bounded font cache behind OSAllocatedUnfairLock. Three specific things undercut it.

8. VirtualTextDocument.update early-return usually misses when tree order ≠ visual order — medium

The guard compares the stored sorted array against the incoming unsorted one (:307). When they differ, every layout pass re-sorts, rebuilds fullText (a full O(total chars) concat), and re-validates every layout cache entry. Measured over 200 updates of an 80-element document:

| Incoming order | Per update |
|---|---|
| Matches sorted order (early-return hits) | 0.03 ms |
| Reverse of sorted order (guard misses) | 0.25 ms |

An 8× difference, hit on every layout pass. This is exactly the multi-column / selectionOrder case the package advertises. Fix: keep the raw incoming array for the comparison and sort into a separate stored property.

Note that even the fast path isn't free — the 0.03 ms is the Equatable comparison of 80 registrations, which deep-compares every AttributedString. Consider comparing a cheap content hash or a per-element revision counter instead.

9. updateRegisteredElements writes observable state unconditionally — medium

When a selection is active, updateRegisteredElements reassigns globalSelectedRange, selections, and isSelecting on every call even when the clamped values are identical (SelectionManager.swift:80-88). Each write fires @Observable notifications, invalidating every SelectableText body in the container. Guard the writes with an equality check.

10. iOS hitTest recomputes the full selection geometry on every touch — medium

hitTest calls lineSelectionRects(for: manager.globalSelectedRange) for the whole selection (_iOS.swift:130), and hitTest runs multiple times per touch event. Measured on a 300-element / 51k-character document with select-all: 600 rects, ~1 ms per warm call. That's frame-budget-relevant during a drag on a long document. Cache the rects (invalidate on selection or layout change) or test against element frames first and only fall back to rect proximity.

For comparison, closestGlobalOffset — the one actually in the drag loop — measured 0.088 ms per call at 300 elements. Fine today, but it's two linear passes over all slices; a coarse Y-sorted index would make it scale.

11. macOS redraws every SelectableText on every selection change — low/medium

Because macOS highlighting works by re-rendering Text with a background color, SelectableText.body reads selectionManager?.selections (:364), so all elements in the container invalidate on every drag update, and each rebuilds effectiveAttributedText (a run-by-run copy) from scratch. Worth measuring under Instruments on the long-document example; a draw(_:) override on the tracking view that fills lineSelectionRects with NSColor.selectedTextBackgroundColor would decouple highlight from view invalidation entirely — and needsDisplay = true in the callback (_macOS.swift:24) suggests that was the original plan, since with no draw override it currently does nothing.

### API ergonomics

What works well. SelectionContainer { } + SelectableText is exactly the API from the design note, and the environment-driven modifiers (selectionOrder, selectableTextDisabled, selectionDelimiter) compose the SwiftUI way — applying them to a subtree rather than per-element is the right ergonomics. SelectionHitTestPolicy is a well-judged escape hatch with a safe default. Optional external SelectionManager for programmatic control, with an internal one by default, is the right shape. The standalone fallback to .textSelection(.enabled) with a debug log (:348-357) is a thoughtful touch. Doc comments are thorough and include runnable examples.

#### Rough edges:

• disabledSelection(_:) and selectableTextDisabled(_:) are byte-identical with identical doc comments (:97, :120). Ship one; deprecate the other. selectableTextDisabled fits SwiftUI's selectionDisabled(_:) precedent.
• SelectableText.foregroundStyle(_ color: Color) (:502) shadows SwiftUI's ShapeStyle version with a Color-only signature, so .foregroundStyle(.tint) or a gradient silently won't compile in the shadowed position. Either widen it or rename.
• selections: [AnyHashable: Range<Int>] is public (:49) — it leaks the internal keying scheme, and AnyHashable is unpleasant at the call site. The typed accessors (selection(for:), selectedIDs(_:)) are the good API; consider making the raw dictionary internal.
• There's no way to enumerate registered element IDs or ask for an element's text — only selected ones. A registeredIDs accessor would help anyone building selection-driven UI.
• + silently drops the right operand's id (:521), undocumented.
• Elements without an explicit id get a per-view @State UUID (:160), so selection(for:) is unusable unless you pass ids everywhere, and duplicate explicit ids collide silently in both selections and layoutCache. A debug assertion on duplicate ids would catch a whole class of confusing bugs.

⸻

### Code quality

Generally high: consistent 4-space indentation and MARK: organization, no force unwraps in the source, no Combine, clean #if os() platform separation, thorough doc comments on all public API. Specific notes:

• Two build warnings. PlatformTypes.swift:96 — "Conformance of 'NSFont' to 'Sendable' is unavailable" (reading run.appKit.font). NativeSelectionOverlay_macOS.swift:177 — NSSharingService.sharingServices(forItems:) deprecated since macOS 13; use NSSharingServicePicker.standardShareMenuItem.
• PlatformFontResolver.resolveInternal reflects over Font internals (PlatformTypes.swift:267-323) — walking Mirror children, matching on type-name substrings like "BoldModifier", and parsing "\(child.value)" string descriptions. This is the single biggest maintenance liability in the package: it will break silently on an SDK update, degrading to a wrong font size with no diagnostic. Hard-coded macOS text-style point sizes (:340-350) are a second copy of the same fragility. It's understandable — SwiftUI exposes no Font → NSFont bridge — but it deserves a prominent comment, a #if DEBUG sanity check, and a public escape hatch (SelectableText(…, resolvedFont: NSFont)) for consumers who need determinism. It's also why Dynamic Type support is best-effort.
• The font cache is FIFO, not LRU despite the MARK: - Thread-Safe LRU Font Cache header (:160) — get never reorders (:184). Either implement recency or rename.
• @unchecked Sendable in three places (TextElementRegistration, PlatformFontBox, BoundedFontCache). The latter two are justified by the lock and by font immutability; TextElementRegistration: @unchecked Sendable (VirtualTextDocument.swift:12) is broader than needed and hides the NSFont issue rather than isolating it.
• TextSelectionKit.swift is a 3-line file containing one comment. Fold it into a DocC catalog or delete it.
• File/type naming: NativeSelectionOverlay_iOS.swift uses a non-Swift underscore suffix, and IOSSelectionOverlay reads awkwardly while actually covering iOS + visionOS + tvOS. UIKitSelectionOverlay / AppKitSelectionOverlay in SelectionOverlay+UIKit.swift would be more accurate and idiomatic.
• Logger subsystem is "SelectionTesting" (SelectableText.swift:5) — a leftover from the prototype. Should be "TextSelectionKit" or the bundle id.
• mouseUp is an empty override with a comment (_macOS.swift:121); drop it.
• Package.swift exports TextSelectionKitExample as a library product (:18-21), so every consumer sees demo views in their module list. Move it to an Examples/ sub-package or a demo app target.
• CachedElementLayout's 4-level nested withUnsafePointer (:172-186) is correct but hard to read; a small helper taking [(CTParagraphStyleSpecifier, Any)] would flatten it.
• linePitch = frame.height / lineCount (:242) derives per-line Y from an average rather than from CTFrameGetLineOrigins (whose values are used for X only). This works for uniform-size text and breaks for mixed font sizes within one element. Worth an explanatory comment since it looks like an oversight rather than a deliberate trade.
• Example bug: ComplexLayoutRTLExampleView.swift:48,52 reads columnOrderMode ? 1 : 1 (and similar), so the "Column-First Selection Order" toggle is a no-op — the example doesn't demonstrate what it claims. Its doc text also describes the font cache as "NSLock protected" (LongDocumentExampleView.swift:127) when it uses OSAllocatedUnfairLock.

### Testing

47 passing tests with good coverage of the pure-logic core: document assembly, delimiter arithmetic, binary search boundaries (including the tricky delimiter-gap and past-end cases), spatial vs. explicit ordering, clamping, focus-coordinator isolation, and RTL/BiDi geometry invariants. The RTL test asserting startCaret.minX > endCaret.minX is a nice property check.

Gaps:

• SelectableTextTests asserts nothing. All nine tests are let x = …; _ = x smoke tests (SelectableTextTests.swift). They'd pass if every initializer produced empty text. Assert on the resulting text/attributes — for instance that SelectableText("**Bold**") yields "Bold" with .stronglyEmphasized, and that verbatim: doesn't strip the asterisks.
• No test covers the finding in §1 — add a round-trip assertion that text(in: r) and String(attributedString(in: r).characters) agree for all r, including partial delimiter overlap. That single property test would have caught it.
• Untested: SelectionHitTestPolicy hit-test logic (extractable from the views into a testable free function), .textCase transformation, markdown auto-detection heuristics, lineLimit truncation, and the + operator's semantics.
• Font resolver tests only assert pointSize > 0 and relative ordering (PlatformBridgeTests.swift), which won't catch the Mirror parsing silently breaking for weights, designs, or italic.
• The two iOS-only tests never run on a macOS destination; consider a test plan covering both.

⸻

### Prioritized recommendations

1. Make text(in:) and attributedString(in:) share delimiter slicing (§1), and add the round-trip property test.
2. Stop the overlays from hijacking onSelectionChanged (§2).
3. Fix the update(elements:) early-return to compare against the unsorted input (§8), and guard the unconditional observable writes (§9).
4. Resolve the localization story: drop the LocalizedStringKey init, and decide whether SelectableText("literal") should localize (§4).
5. Correct the "character offset" documentation to "UTF-16 code-unit offset" throughout (§3).
6. Cache iOS selection rects instead of recomputing them per hitTest (§10).
7. Clear the two build warnings, and add a #if DEBUG sanity check plus an explicit-font escape hatch around the Mirror-based font resolver (§Code quality).
8. Give SelectableTextTests real assertions.
9. Write a README covering the CoreText-vs-SwiftUI layout assumption, the hit-test policy trade-off, and the localization/markdown behaviour; AGENTS.md currently carries the only prose and reads as prototype notes.

Overall: the architecture is the right one for this problem and the CoreText caching layer is carefully built. The defects cluster in the seams — plain/rich text divergence, the public callback collision, the early-return guard, and the Text-parity surprises in the initializers — all of which are contained fixes rather than redesigns.

