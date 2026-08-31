import Testing
import SwiftUI
import CoreGraphics
@testable import TextSelectionKit

#if os(macOS)
import AppKit

@Suite("macOS Selection Focus & Responder Chain Tests")
struct MacOSSelectionFocusTests {
    
    private func makeRegistration(id: AnyHashable = UUID(), text: String) -> TextElementRegistration {
        let font = NSFont.systemFont(ofSize: 14)
        return TextElementRegistration(
            id: id,
            text: text,
            frame: CGRect(x: 0, y: 0, width: 200, height: 20),
            font: font,
            orderIndex: 0
        )
    }
    
    @Test("Selection is preserved when MacOSSelectionTrackingView resigns first responder")
    @MainActor
    func testSelectionPreservedOnResignFirstResponder() {
        let manager = SelectionManager()
        let elem = makeRegistration(text: "Selected text in container")
        manager.updateRegisteredElements([elem])
        
        let trackingView = MacOSSelectionTrackingView()
        trackingView.manager = manager
        
        // 1. Establish selection
        manager.select(0..<8) // "Selected"
        #expect(manager.hasSelection)
        #expect(manager.globalSelectedRange == 0..<8)
        #expect(manager.selectedText == "Selected")
        
        // 2. Tracking view becomes first responder
        _ = trackingView.becomeFirstResponder()
        #expect(SelectionFocusCoordinator.shared.activeManager === manager)
        
        // 3. User clicks an external toolbar button / inspector -> view resigns first responder
        let didResign = trackingView.resignFirstResponder()
        #expect(didResign)
        
        // 4. VERIFY: Selection is NOT cleared and remains accessible to toolbar actions (Copy, Highlight, etc.)
        #expect(manager.hasSelection, "Active selection must be preserved when tracking view resigns first responder")
        #expect(manager.globalSelectedRange == 0..<8)
        #expect(manager.selectedText == "Selected")
    }
    
    @Test("Copy action succeeds even after tracking view resigns first responder")
    @MainActor
    func testCopyActionWorksAfterResignFirstResponder() {
        let manager = SelectionManager()
        let elem = makeRegistration(text: "Copyable content")
        manager.updateRegisteredElements([elem])
        
        let trackingView = MacOSSelectionTrackingView()
        trackingView.manager = manager
        
        manager.select(0..<8) // "Copyable"
        _ = trackingView.becomeFirstResponder()
        _ = trackingView.resignFirstResponder()
        
        // Simulate external toolbar Copy button calling manager.copySelection()
        manager.copySelection()
        
        let pasteboardString = NSPasteboard.general.string(forType: .string)
        #expect(pasteboardString == "Copyable")
    }
    
    @Test("Focus coordinator clears previous manager only when a new manager becomes active")
    @MainActor
    func testFocusCoordinatorSwitchesBetweenManagers() {
        let manager1 = SelectionManager()
        let manager2 = SelectionManager()
        
        let elem1 = makeRegistration(text: "Container 1")
        let elem2 = makeRegistration(text: "Container 2")
        manager1.updateRegisteredElements([elem1])
        manager2.updateRegisteredElements([elem2])
        
        let trackingView1 = MacOSSelectionTrackingView()
        trackingView1.manager = manager1
        
        let trackingView2 = MacOSSelectionTrackingView()
        trackingView2.manager = manager2
        
        // Focus Container 1
        _ = trackingView1.becomeFirstResponder()
        manager1.select(0..<9)
        #expect(manager1.hasSelection)
        #expect(SelectionFocusCoordinator.shared.activeManager === manager1)
        
        // Resign Container 1 without focusing Container 2 (e.g. focus toolbar)
        _ = trackingView1.resignFirstResponder()
        #expect(manager1.hasSelection) // Still preserved!
        
        // Now focus Container 2
        _ = trackingView2.becomeFirstResponder()
        manager2.select(0..<9)
        #expect(manager2.hasSelection)
        #expect(!manager1.hasSelection, "Manager 1 selection should only be cleared when Manager 2 becomes active")
    }
}
#endif
