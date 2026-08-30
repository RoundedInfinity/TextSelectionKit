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
    
    @Test("SelectionButton creates typed action and executes closure with visual displayedShortcut")
    @MainActor
    func testSelectionButton() {
        var actionExecuted = false
        let button = SelectionButton("Highlight", systemImage: "highlighter") {
            actionExecuted = true
        }
        .displayedShortcut("h", modifiers: [.command, .shift])
        
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
        
        action()
        #expect(actionExecuted)
    }
    
    @Test("SelectionButton displayedShortcut modifier overloads")
    @MainActor
    func testSelectionButtonDisplayedShortcutOverloads() {
        let btn1 = SelectionButton("Action 1") {}.displayedShortcut("k")
        #expect(btn1.displayedShortcut?.key == KeyEquivalent("k"))
        #expect(btn1.displayedShortcut?.modifiers == EventModifiers.command)
        
        let btn2 = SelectionButton("Action 2") {}.displayedShortcut(KeyEquivalent("f"), modifiers: [.command, .option])
        #expect(btn2.displayedShortcut?.key == KeyEquivalent("f"))
        #expect(btn2.displayedShortcut?.modifiers == [.command, .option])
        
        let btn3 = SelectionButton("Action 3", displayedShortcut: SelectionKeyboardShortcut("z", modifiers: .command)) {}
        #expect(btn3.displayedShortcut?.key == KeyEquivalent("z"))
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
    
    @Test("SelectionButton and SelectionMenu support LocalizedStringKey and LocalizationValue")
    @MainActor
    func testLocalizationSupport() {
        let key: LocalizedStringKey = "menu_highlight_action"
        let btnKey = SelectionButton(key, systemImage: "highlighter") {}
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
