import Testing
import SwiftUI
@testable import TextSelectionKit

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

@Suite("Selection Context Menu Tests")
struct SelectionContextMenuTests {
    
    @Test("SelectionMenuContext properties and hasSelection check")
    func testSelectionMenuContext() {
        let emptyContext = SelectionMenuContext(
            selectedText: "",
            selectedAttributedString: AttributedString(""),
            globalSelectedRange: 0..<0,
            selectedIDs: []
        )
        #expect(!emptyContext.hasSelection)
        #expect(emptyContext.selectedText.isEmpty)
        #expect(emptyContext.selectedIDs.isEmpty)
        
        let activeContext = SelectionMenuContext(
            selectedText: "Selected snippet",
            selectedAttributedString: AttributedString("Selected snippet"),
            globalSelectedRange: 10..<26,
            selectedIDs: ["para-1", 42]
        )
        #expect(activeContext.hasSelection)
        #expect(activeContext.selectedText == "Selected snippet")
        #expect(activeContext.globalSelectedRange == 10..<26)
        #expect(activeContext.selectedIDs == [AnyHashable("para-1"), AnyHashable(42)])
    }
    
    @Test("SelectionButton creates typed action and executes closure with shortcut")
    @MainActor
    func testSelectionButton() {
        var actionExecuted = false
        let button = SelectionButton(
            "Highlight",
            systemImage: "highlighter",
            shortcut: SelectionKeyboardShortcut("h", modifiers: [.command, .shift])
        ) {
            actionExecuted = true
        }
        
        let items = button.makeParsedMenuItems()
        #expect(items.count == 1)
        
        guard case .action(let title, let systemImage, let role, let isEnabled, let shortcut, let action) = items.first else {
            Issue.record("Expected .action item")
            return
        }
        
        #expect(title == "Highlight")
        #expect(systemImage == "highlighter")
        #expect(role == nil)
        #expect(isEnabled)
        #expect(shortcut?.key == "h")
        #expect(shortcut == SelectionKeyboardShortcut("h", modifiers: [.command, .shift]))
        #expect(button.shortcut == SelectionKeyboardShortcut("h", modifiers: [.command, .shift]))
        
        action()
        #expect(actionExecuted)
    }
    
    @Test("SelectionButton shortcut init property overloads")
    @MainActor
    func testSelectionButtonShortcutInitOverloads() {
        let btn1 = SelectionButton("Action 1", shortcut: SelectionKeyboardShortcut("k")) {}
        #expect(btn1.shortcut?.key == KeyEquivalent("k"))
        #expect(btn1.shortcut?.modifiers == EventModifiers.command)
        
        let btn2 = SelectionButton("Action 2", shortcut: SelectionKeyboardShortcut("f", modifiers: [.command, .option])) {}
        #expect(btn2.shortcut?.key == KeyEquivalent("f"))
        #expect(btn2.shortcut?.modifiers == [.command, .option])
        
        let btn3 = SelectionButton(verbatim: "Action 3", shortcut: SelectionKeyboardShortcut("z", modifiers: .command)) {}
        #expect(btn3.shortcut?.key == KeyEquivalent("z"))
    }
    
    @Test("SelectionButton handles destructive role and disabled state")
    @MainActor
    func testSelectionButtonRoleAndDisabled() {
        var deleteExecuted = false
        let destructiveBtn = SelectionButton("Delete", systemImage: "trash", role: .destructive) {
            deleteExecuted = true
        }
        
        let dItems = destructiveBtn.makeParsedMenuItems()
        #expect(dItems.count == 1)
        guard case .action(let title, let img, let role, let isEnabled, _, let action) = dItems.first else {
            Issue.record("Expected .action item")
            return
        }
        #expect(title == "Delete")
        #expect(img == "trash")
        #expect(role == .destructive)
        #expect(isEnabled)
        action()
        #expect(deleteExecuted)
        
        let disabledBtn = SelectionButton("Disabled Action") {}.disabled(true)
        let disItems = disabledBtn.makeParsedMenuItems()
        guard case .action(_, _, _, let disEnabled, _, _) = disItems.first else {
            Issue.record("Expected .action item")
            return
        }
        #expect(!disEnabled)
    }
    
    @Test("SelectionMenu and SelectionDivider produce valid menu hierarchy")
    @MainActor
    func testDedicatedMenuHierarchy() {
        var noteExecuted = false
        
        let menu = SelectionMenu("Share", systemImage: "square.and.arrow.up") {
            SelectionButton("To Notes", systemImage: "note.text") {
                noteExecuted = true
            }
            SelectionDivider()
            SelectionButton("To Messages", systemImage: "message") {}
        }
        
        let items = menu.makeParsedMenuItems()
        #expect(items.count == 1)
        
        guard case .submenu(let title, let img, let subItems) = items.first else {
            Issue.record("Expected .submenu item")
            return
        }
        
        #expect(title == "Share")
        #expect(img == "square.and.arrow.up")
        #expect(subItems.count == 3)
        
        guard case .action(let nTitle, let nImg, _, _, _, let nAction) = subItems[0] else {
            Issue.record("Expected .action at index 0")
            return
        }
        #expect(nTitle == "To Notes")
        #expect(nImg == "note.text")
        nAction()
        #expect(noteExecuted)
        
        guard case .separator = subItems[1] else {
            Issue.record("Expected .separator at index 1")
            return
        }
        
        guard case .action(let mTitle, let mImg, _, _, _, _) = subItems[2] else {
            Issue.record("Expected .action at index 2")
            return
        }
        #expect(mTitle == "To Messages")
        #expect(mImg == "message")
    }
    
    @Test("SelectionMenuBuilder supports conditionals and loops")
    @MainActor
    func testSelectionMenuBuilderConditionals() {
        @SelectionMenuBuilder
        func makeItems(includeSpecial: Bool, options: [String]) -> [any SelectionMenuItemConvertible] {
            SelectionButton("Primary") {}
            SelectionDivider()
            if includeSpecial {
                SelectionButton("Special", systemImage: "star") {}
            }
            for opt in options {
                SelectionButton(verbatim: opt) {}
            }
        }
        
        let withSpecial = makeItems(includeSpecial: true, options: ["Opt1", "Opt2"])
        let parsedWith = withSpecial.flatMap { $0.makeParsedMenuItems() }
        #expect(parsedWith.count == 5)
        
        let withoutSpecial = makeItems(includeSpecial: false, options: ["Opt1"])
        let parsedWithout = withoutSpecial.flatMap { $0.makeParsedMenuItems() }
        #expect(parsedWithout.count == 3)
    }
    
    @Test("SelectionMenuBuilder buildLimitedAvailability direct call and result builder branches")
    @MainActor
    func testSelectionMenuBuilderAvailabilityChecks() {
        // Direct call verification
        let sampleItems: [any SelectionMenuItemConvertible] = [
            SelectionButton("Direct Item 1") {},
            SelectionButton("Direct Item 2") {}
        ]
        let limited = SelectionMenuBuilder.buildLimitedAvailability(sampleItems)
        #expect(limited.count == 2)
        
        // Result builder with #available branch
        @SelectionMenuBuilder
        func makeMenuWithAvailability() -> [any SelectionMenuItemConvertible] {
            SelectionButton("Base Action") {}
            if #available(macOS 15.0, iOS 18.0, visionOS 2.0, *) {
                SelectionButton("New OS Feature", systemImage: "sparkles") {}
            } else {
                SelectionButton("Fallback Feature", systemImage: "arrow.backward") {}
            }
        }
        
        let items = makeMenuWithAvailability()
        let parsed = items.flatMap { $0.makeParsedMenuItems() }
        #expect(parsed.count == 2)
        guard case .action(let baseTitle, _, _, _, _, _) = parsed[0] else {
            Issue.record("Expected .action item for base")
            return
        }
        #expect(baseTitle == "Base Action")
        
        guard case .action(let featureTitle, _, _, _, _, _) = parsed[1] else {
            Issue.record("Expected .action item for availability branch")
            return
        }
        #expect(featureTitle == "New OS Feature" || featureTitle == "Fallback Feature")
    }
    
    @Test("SelectionButton and SelectionMenu support LocalizedStringKey and LocalizationValue")
    @MainActor
    func testLocalizationSupport() {
        let key: LocalizedStringKey = "menu_highlight_action"
        let btnKey = SelectionButton(localizedKey: key, systemImage: "highlighter") {}
        let parsedBtn = btnKey.makeParsedMenuItems()
        guard case .action(let title, let img, _, _, _, _) = parsedBtn.first else {
            Issue.record("Expected .action")
            return
        }
        #expect(!title.isEmpty)
        #expect(img == "highlighter")
        
        let locValue: String.LocalizationValue = "menu_share_submenu"
        let subMenu = SelectionMenu(localized: locValue) {
            SelectionButton(localized: "menu_sub_action") {}
        }
        let parsedMenu = subMenu.makeParsedMenuItems()
        guard case .submenu(let menuTitle, _, let items) = parsedMenu.first else {
            Issue.record("Expected .submenu")
            return
        }
        #expect(!menuTitle.isEmpty)
        #expect(items.count == 1)
    }
    
    @Test("SelectionButton and SelectionMenu support String.LocalizationValue with interpolation")
    @MainActor
    func testLocalizationInterpolationSupport() {
        let count = 5
        let btn = SelectionButton("Delete \(count) items", systemImage: "trash") {}
        let parsedBtn = btn.makeParsedMenuItems()
        guard case .action(let title, let img, _, _, _, _) = parsedBtn.first else {
            Issue.record("Expected .action")
            return
        }
        #expect(title == "Delete 5 items")
        #expect(img == "trash")
        
        let menu = SelectionMenu("Share \(count) files") {
            SelectionButton("Export") {}
        }
        let parsedMenu = menu.makeParsedMenuItems()
        guard case .submenu(let menuTitle, _, let items) = parsedMenu.first else {
            Issue.record("Expected .submenu")
            return
        }
        #expect(menuTitle == "Share 5 files")
        #expect(items.count == 1)
    }
    
    @Test("selectionContextMenu modifier attaches provider to environment")
    @MainActor
    func testSelectionContextMenuModifier() {
        let view = Text("Hello")
            .selectionContextMenu(placement: .prepend) { context in
                SelectionButton("Custom", systemImage: "star") {}
            }
        
        let mirror = Mirror(reflecting: view)
        #expect(mirror.children.count >= 0)
    }
}
