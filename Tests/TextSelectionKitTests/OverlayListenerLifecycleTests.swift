import Testing
import Foundation
@testable import TextSelectionKit

#if os(macOS)
import AppKit
#elseif os(iOS) || os(visionOS) || os(tvOS)
import UIKit
#endif

@Suite("Overlay Observer Lifecycle & Memory Management Tests")
struct OverlayListenerLifecycleTests {
    
    #if os(macOS)
    @Test("MacOSSelectionHighlightView unregisters observer on deinit")
    @MainActor
    func testMacOSSelectionHighlightViewUnregistersOnDeinit() {
        let manager = SelectionManager()
        #expect(manager.observerCount == 0)
        
        autoreleasepool {
            let highlightView = MacOSSelectionHighlightView()
            highlightView.manager = manager
            #expect(manager.observerCount == 1, "Registering manager on highlight view must add 1 observer")
        }
        
        #expect(manager.observerCount == 0, "Highlight view deinit must remove its observer from SelectionManager")
    }
    
    @Test("MacOSSelectionTrackingView unregisters observer on deinit")
    @MainActor
    func testMacOSSelectionTrackingViewUnregistersOnDeinit() {
        let manager = SelectionManager()
        #expect(manager.observerCount == 0)
        
        autoreleasepool {
            let trackingView = MacOSSelectionTrackingView()
            trackingView.manager = manager
            #expect(manager.observerCount == 1, "Registering manager on tracking view must add 1 observer")
        }
        
        #expect(manager.observerCount == 0, "Tracking view deinit must remove its observer from SelectionManager")
    }
    
    @Test("Reassigning manager on tracking view unregisters from old manager")
    @MainActor
    func testReassigningManagerCleansUpOldObserver() {
        let managerA = SelectionManager()
        let managerB = SelectionManager()
        
        let trackingView = MacOSSelectionTrackingView()
        trackingView.manager = managerA
        #expect(managerA.observerCount == 1)
        #expect(managerB.observerCount == 0)
        
        trackingView.manager = managerB
        #expect(managerA.observerCount == 0, "Old manager must have observer removed")
        #expect(managerB.observerCount == 1, "New manager must have observer added")
        
        trackingView.manager = nil
        #expect(managerA.observerCount == 0)
        #expect(managerB.observerCount == 0)
    }
    
    @Test("Repeated SwiftUI view mounting and unmounting cycles do not accumulate observers")
    @MainActor
    func testRepeatedViewMountCyclesDoNotLeak() {
        let manager = SelectionManager()
        #expect(manager.observerCount == 0)
        
        for _ in 0..<50 {
            autoreleasepool {
                let trackingView = MacOSSelectionTrackingView()
                let highlightView = MacOSSelectionHighlightView()
                trackingView.manager = manager
                highlightView.manager = manager
                #expect(manager.observerCount == 2)
            }
        }
        
        #expect(manager.observerCount == 0, "No orphaned observers should remain after all views deallocate")
    }
    #endif
    
    #if os(iOS) || os(visionOS) || os(tvOS)
    @Test("NativeSelectionTrackingUIView registers and unregisters observer on lifecycle changes")
    @MainActor
    func testIOSSelectionTrackingViewObserverLifecycle() {
        let manager = SelectionManager()
        #expect(manager.observerCount == 0)
        
        autoreleasepool {
            let trackingView = NativeSelectionTrackingUIView()
            trackingView.manager = manager
            #expect(manager.observerCount == 1)
        }
        
        #expect(manager.observerCount == 0)
    }
    
    @Test("iOS reassigning manager cleans up old observer")
    @MainActor
    func testIOSReassigningManagerCleansUpOldObserver() {
        let managerA = SelectionManager()
        let managerB = SelectionManager()
        
        let trackingView = NativeSelectionTrackingUIView()
        trackingView.manager = managerA
        #expect(managerA.observerCount == 1)
        #expect(managerB.observerCount == 0)
        
        trackingView.manager = managerB
        #expect(managerA.observerCount == 0)
        #expect(managerB.observerCount == 1)
        
        trackingView.manager = nil
        #expect(managerA.observerCount == 0)
        #expect(managerB.observerCount == 0)
    }
    #endif
    
    @Test("Custom SelectionObserver receives change notifications independently from onSelectionChanged")
    @MainActor
    func testCustomSelectionObserverReceivesNotifications() {
        final class TestObserver: SelectionObserver {
            var changesCount = 0
            func selectionDidChange(in manager: SelectionManager) {
                changesCount += 1
            }
        }
        
        let manager = SelectionManager()
        let observer = TestObserver()
        manager.addObserver(observer)
        #expect(manager.observerCount == 1)
        
        var publicCallbackCount = 0
        manager.onSelectionChanged = {
            publicCallbackCount += 1
        }
        
        let elem = TextElementRegistration(
            id: "elem1",
            text: "Hello World",
            frame: CGRect(x: 0, y: 0, width: 100, height: 20),
            font: .systemFont(ofSize: 14)
        )
        manager.updateRegisteredElements([elem])
        
        manager.select(0..<5)
        #expect(observer.changesCount == 1)
        #expect(publicCallbackCount == 1)
        
        manager.deselectAll()
        #expect(observer.changesCount == 2)
        #expect(publicCallbackCount == 2)
        
        manager.removeObserver(observer)
        #expect(manager.observerCount == 0)
        
        manager.select(0..<5)
        #expect(observer.changesCount == 2) // Did not increment after removal
        #expect(publicCallbackCount == 3)
    }
    
    @Test("Weak SelectionObserver automatically prunes without explicit removeObserver call")
    @MainActor
    func testWeakObserverAutoPrunesOnDeallocation() {
        final class EphemeralObserver: SelectionObserver {
            func selectionDidChange(in manager: SelectionManager) {}
        }
        
        let manager = SelectionManager()
        
        autoreleasepool {
            let observer = EphemeralObserver()
            manager.addObserver(observer)
            #expect(manager.observerCount == 1)
        }
        
        #expect(manager.observerCount == 0, "Weak reference should auto-prune when observer deallocates")
    }
}
