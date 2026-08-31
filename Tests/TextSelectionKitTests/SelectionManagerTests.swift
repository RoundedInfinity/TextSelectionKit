import Testing
import Foundation
import CoreGraphics
@testable import TextSelectionKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@Suite("SelectionManager State & Coordinator Tests")
struct SelectionManagerTests {
    
    private func makeRegistration(id: AnyHashable = UUID(), text: String, attributedString: AttributedString? = nil) -> TextElementRegistration {
        #if os(macOS)
        let font = NSFont.systemFont(ofSize: 14)
        #else
        let font = UIFont.systemFont(ofSize: 14)
        #endif
        return TextElementRegistration(
            id: id,
            text: text,
            attributedString: attributedString,
            frame: CGRect(x: 0, y: 0, width: 200, height: 20),
            font: font,
            orderIndex: 0
        )
    }
    
    @Test("SelectionManager initial state is inactive and empty")
    @MainActor
    func testInitialState() {
        let manager = SelectionManager()
        #expect(!manager.hasSelection)
        #expect(!manager.isSelecting)
        #expect(manager.globalSelectedRange == 0..<0)
        #expect(manager.selections.isEmpty)
        #expect(manager.selectedText == "")
        #expect(String(manager.selectedAttributedString.characters) == "")
    }
    
    @Test("Selection lifecycle: set, selectAll, and clear")
    @MainActor
    func testSelectionLifecycle() {
        let manager = SelectionManager()
        let elem1 = makeRegistration(text: "Hello")
        let elem2 = makeRegistration(text: "World")
        
        manager.updateRegisteredElements([elem1, elem2])
        
        // 1. Partial Selection
        manager.select(0..<5)
        #expect(manager.hasSelection)
        #expect(manager.isSelecting)
        #expect(manager.globalSelectedRange == 0..<5)
        #expect(manager.selectedText == "Hello")
        #expect(String(manager.selectedAttributedString.characters) == "Hello")
        
        // 2. Select All
        manager.selectAll()
        #expect(manager.hasSelection)
        #expect(manager.globalSelectedRange == 0..<11)
        #expect(manager.selectedText == "Hello\nWorld")
        #expect(String(manager.selectedAttributedString.characters) == "Hello\nWorld")
        
        // 3. Deselect All
        manager.deselectAll()
        #expect(!manager.hasSelection)
        #expect(!manager.isSelecting)
        #expect(manager.globalSelectedRange == 0..<0)
        #expect(manager.selections.isEmpty)
        
        // 4. Repeated deselectAll is safe / idempotent
        manager.deselectAll()
        #expect(!manager.hasSelection)
        
        // 5. select(id:) labeled overload
        let selectedByID = manager.select(id: elem1.id)
        #expect(selectedByID)
        #expect(manager.hasSelection)
        #expect(manager.selectedText == "Hello")
    }
    
    @Test("Out of bounds selection clamping")
    @MainActor
    func testSelectionClamping() {
        let manager = SelectionManager()
        let elem = makeRegistration(text: "Swift")
        manager.updateRegisteredElements([elem]) // totalLength = 5
        
        manager.select(-10..<100)
        #expect(manager.globalSelectedRange == 0..<5)
        #expect(manager.selectedText == "Swift")
    }
    
    @Test("Selection change callback fires on state transitions")
    @MainActor
    func testSelectionChangeCallback() {
        let manager = SelectionManager()
        let elem = makeRegistration(text: "Callback Test")
        manager.updateRegisteredElements([elem])
        
        var callbackCount = 0
        manager.onSelectionChanged = {
            callbackCount += 1
        }
        
        manager.select(0..<8)
        #expect(callbackCount == 1)
        
        // Setting same range should NOT re-trigger callback
        manager.select(0..<8)
        #expect(callbackCount == 1)
        
        manager.deselectAll()
        #expect(callbackCount == 2)
    }
    
    @Test("SelectionFocusCoordinator clears inactive manager when another becomes active")
    @MainActor
    func testFocusCoordinatorIsolation() {
        let managerA = SelectionManager()
        let managerB = SelectionManager()
        
        let elemA = makeRegistration(text: "Container A")
        let elemB = makeRegistration(text: "Container B")
        
        managerA.updateRegisteredElements([elemA])
        managerB.updateRegisteredElements([elemB])
        
        // Select in Manager A
        managerA.select(0..<9)
        #expect(managerA.hasSelection)
        
        // Select in Manager B -> should clear Manager A's selection automatically!
        managerB.select(0..<9)
        #expect(managerB.hasSelection)
        #expect(!managerA.hasSelection)
        #expect(managerA.globalSelectedRange.isEmpty)
    }
    
    @Test("Updating registered elements re-clamps active selection")
    @MainActor
    func testElementUpdateReclamping() {
        let manager = SelectionManager()
        let elemLong = makeRegistration(text: "Very long initial text string")
        manager.updateRegisteredElements([elemLong])
        manager.selectAll()
        #expect(manager.selectedText == "Very long initial text string")
        
        // Now update with a shorter element while selection was active
        let elemShort = makeRegistration(text: "Short")
        manager.updateRegisteredElements([elemShort])
        
        #expect(manager.globalSelectedRange == 0..<5)
        #expect(manager.selectedText == "Short")
    }
    
    @Test("External SelectionManager exposes totalLength and fullText")
    @MainActor
    func testExternalManagerDocumentProperties() {
        let manager = SelectionManager()
        let elem1 = makeRegistration(text: "First Header")
        let elem2 = makeRegistration(text: "Second Paragraph")
        manager.updateRegisteredElements([elem1, elem2])
        
        #expect(manager.totalLength == 29) // 12 + 1 + 16
        #expect(manager.fullText == "First Header\nSecond Paragraph")
    }
    
    @Test("SelectionContainer accepts externally injected SelectionManager")
    @MainActor
    func testExternalSelectionManagerInjection() {
        let externalManager = SelectionManager()
        let container = SelectionContainer(manager: externalManager) {
            SelectableText("Injectable Content")
        }
        _ = container.body
        
        let elem = makeRegistration(text: "Injectable Content")
        externalManager.updateRegisteredElements([elem])
        
        externalManager.selectAll()
        #expect(externalManager.hasSelection)
        #expect(externalManager.selectedText == "Injectable Content")
        
        externalManager.deselectAll()
        #expect(!externalManager.hasSelection)
    }
    
    @Test("View.selectionContainer modifier accepts externally injected SelectionManager")
    @MainActor
    func testViewSelectionContainerWithManagerModifier() {
        let externalManager = SelectionManager()
        let view = SelectableText("Modifier Content").selectionContainer(manager: externalManager)
        _ = view.body
        
        let elem = makeRegistration(text: "Modifier Content")
        externalManager.updateRegisteredElements([elem])
        
        externalManager.select(0..<8)
        #expect(externalManager.selectedText == "Modifier")
    }
    
    @Test("SelectionHitTestPolicy configurations on SelectionContainer")
    @MainActor
    func testSelectionHitTestPolicyConfigurations() {
        let containerDefault = SelectionContainer {
            SelectableText("Default TextOnly Content")
        }
        _ = containerDefault.body
        
        let containerFull = SelectionContainer(hitTestPolicy: .container) {
            SelectableText("Full Container Content")
        }
        _ = containerFull.body
        
        let containerCustomPadding = SelectionContainer(hitTestPolicy: .textOnly(padding: 12)) {
            SelectableText("Custom Padding Content")
        }
        _ = containerCustomPadding.body
        
        let viewModifier = SelectableText("Modifier Policy Content")
            .selectionContainer(hitTestPolicy: .container)
        _ = viewModifier.body
        
        #expect(SelectionHitTestPolicy.textOnly == .textOnly(padding: 4))
        #expect(SelectionHitTestPolicy.container != .textOnly(padding: 4))
    }
    
    @Test("Element identification queries by custom String, Int, and UUID IDs")
    @MainActor
    func testElementIdentificationAndQueries() {
        let manager = SelectionManager()
        
        var attrHeader = AttributedString("Header Title")
        attrHeader.foregroundColor = .red
        
        let elem1 = makeRegistration(id: "header", text: "Header Title", attributedString: attrHeader)
        let elem2 = makeRegistration(id: 101, text: "Middle Paragraph")
        let elem3 = makeRegistration(id: "footer", text: "Footer Note")
        
        manager.updateRegisteredElements([elem1, elem2, elem3])
        
        // Initially nothing is selected
        #expect(manager.selection(for: "header") == nil)
        #expect(!manager.isSelected("header"))
        #expect(manager.selectedText(for: "header") == nil)
        #expect(manager.selectedAttributedString(for: "header") == nil)
        #expect(manager.selectedIDs(String.self).isEmpty)
        #expect(manager.selectedIDs.isEmpty)
        
        // Select full first element ("Header Title" -> length 12) + delimiter (1) + partial second ("Middle" -> 6 chars)
        // Global range: 0..<19
        manager.select(0..<19)
        
        #expect(manager.isSelected("header"))
        #expect(manager.isSelected(101))
        #expect(!manager.isSelected("footer"))
        
        #expect(manager.selection(for: "header") == 0..<12)
        #expect(manager.selection(for: 101) == 0..<6)
        #expect(manager.selection(for: "footer") == nil)
        
        #expect(manager.selectedText(for: "header") == "Header Title")
        #expect(manager.selectedText(for: 101) == "Middle")
        #expect(manager.selectedText(for: "footer") == nil)
        
        let selectedAttr = manager.selectedAttributedString(for: "header")
        #expect(selectedAttr != nil)
        #expect(String(selectedAttr!.characters) == "Header Title")
        
        // Query selected IDs in reading order
        let stringIDs: [String] = manager.selectedIDs(String.self)
        #expect(stringIDs == ["header"])
        
        let intIDs: [Int] = manager.selectedIDs(Int.self)
        #expect(intIDs == [101])
        
        let allIDs = manager.selectedIDs
        #expect(allIDs == [AnyHashable("header"), AnyHashable(101)])
    }
    
    @Test("Programmatically selecting element by ID and local range in ID")
    @MainActor
    func testSelectByElementID() {
        let manager = SelectionManager()
        let elem1 = makeRegistration(id: "title", text: "Introduction")
        let elem2 = makeRegistration(id: "body", text: "SwiftUI native selection")
        let elem3 = makeRegistration(id: 42, text: "Chapter 42")
        
        manager.updateRegisteredElements([elem1, elem2, elem3])
        
        // 1. Select element "body" by ID
        let didSelectBody = manager.select(id: "body")
        #expect(didSelectBody)
        #expect(manager.isSelected("body"))
        #expect(!manager.isSelected("title"))
        #expect(!manager.isSelected(42))
        #expect(manager.selectedText == "SwiftUI native selection")
        #expect(manager.selectedText(for: "body") == "SwiftUI native selection")
        
        // 2. Select by Int ID 42
        let didSelectInt = manager.select(id: 42)
        #expect(didSelectInt)
        #expect(manager.isSelected(42))
        #expect(manager.selectedText == "Chapter 42")
        
        // 3. Select subrange inside element "body": select "SwiftUI" (0..<7)
        let didSelectSubrange = manager.select(0..<7, in: "body")
        #expect(didSelectSubrange)
        #expect(manager.selectedText == "SwiftUI")
        #expect(manager.selectedText(for: "body") == "SwiftUI")
        
        // 4. Non-existent ID returns false without modifying active selection
        let didSelectNonExistent = manager.select(id: "missing-id")
        #expect(!didSelectNonExistent)
        #expect(manager.selectedText == "SwiftUI")
    }
    
    @Test("Public onSelectionChanged callback is not overwritten by platform overlay mounting")
    @MainActor
    func testOverlayDoesNotOverwritePublicCallback() {
        let manager = SelectionManager()
        let elem = makeRegistration(text: "Overlay Isolation Test")
        manager.updateRegisteredElements([elem])
        
        var userCallbackFired = 0
        manager.onSelectionChanged = {
            userCallbackFired += 1
        }
        
        #if os(macOS)
        let trackingView = MacOSSelectionTrackingView()
        trackingView.manager = manager
        #else
        let trackingView = NativeSelectionTrackingUIView()
        trackingView.manager = manager
        #endif
        
        // Changing selection should fire user's callback
        manager.select(0..<7)
        #expect(userCallbackFired == 1)
        
        // Clearing selection should fire user's callback again
        manager.deselectAll()
        #expect(userCallbackFired == 2)
    }
    
    @Test("Setting public onSelectionChanged after observer registration preserves observer notifications")
    @MainActor
    func testSettingPublicCallbackPreservesInternalHandler() {
        final class ObserverStub: SelectionObserver {
            var count = 0
            func selectionDidChange(in manager: SelectionManager) {
                count += 1
            }
        }
        
        let manager = SelectionManager()
        let elem = makeRegistration(text: "Handler Preservation Test")
        manager.updateRegisteredElements([elem])
        
        let observer = ObserverStub()
        manager.addObserver(observer)
        
        var userCallbackFired = 0
        manager.onSelectionChanged = {
            userCallbackFired += 1
        }
        
        manager.select(0..<5)
        #expect(userCallbackFired == 1)
        #expect(observer.count == 1)
        
        // Reassign public callback to a new closure
        var secondUserCallbackFired = 0
        manager.onSelectionChanged = {
            secondUserCallbackFired += 1
        }
        
        manager.deselectAll()
        #expect(userCallbackFired == 1) // first closure was replaced
        #expect(secondUserCallbackFired == 1) // second closure fired
        #expect(observer.count == 2) // observer still fired
    }
    
    @Test("Observable totalLength and fullText update reactively and delimiter-only selection reports hasSelection true")
    @MainActor
    func testObservableDocumentPropertiesAndDelimiterOnlySelection() {
        let manager = SelectionManager()
        #expect(manager.totalLength == 0)
        #expect(manager.fullText == "")
        
        let elem1 = makeRegistration(text: "Hello")
        let elem2 = makeRegistration(text: "World")
        manager.updateRegisteredElements([elem1, elem2])
        
        #expect(manager.totalLength == 11)
        #expect(manager.fullText == "Hello\nWorld")
        
        // Select delimiter-only range: offset 5..<6 is "\n"
        manager.select(5..<6)
        #expect(manager.selectedText == "\n")
        #expect(manager.hasSelection)
        #expect(manager.isSelecting)
    }
    
    @Test("Redundant element updates with unchanged selection state do not fire callbacks or redundant state changes")
    @MainActor
    func testRedundantElementUpdatesAvoidSpuriousMutations() {
        let manager = SelectionManager()
        let elem1 = makeRegistration(text: "Alpha")
        let elem2 = makeRegistration(text: "Beta")
        let elements = [elem1, elem2]
        
        manager.updateRegisteredElements(elements)
        manager.select(0..<5)
        
        var callbackCount = 0
        manager.onSelectionChanged = {
            callbackCount += 1
        }
        
        // Updating with identical elements and identical selection
        manager.updateRegisteredElements(elements)
        #expect(callbackCount == 0)
        
        manager.updateRegisteredElements(elements)
        #expect(callbackCount == 0)
    }
}


