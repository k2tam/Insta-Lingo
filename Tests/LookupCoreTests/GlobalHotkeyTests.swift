import Foundation
import Testing
@testable import LookupCore

@Test
func defaultHotkeysAreDistinctAndValid() {
    let shortcuts = HotkeyAction.allCases.map(\.defaultShortcut)
    #expect(Set(shortcuts).count == shortcuts.count)
    #expect(shortcuts.allSatisfy(\.isValid))
}

@Test
func bareAndShiftOnlyKeysAreRejected() {
    #expect(!HotkeyShortcut(keyCode: 37, modifiers: []).isValid)
    #expect(!HotkeyShortcut(keyCode: 37, modifiers: [.shift]).isValid)
}

@Test
func duplicateHotkeyAssignmentsAreDetected() {
    var assignments = HotkeyAssignments.defaults
    assignments[.selectedText] = assignments[.openPanel]
    #expect(assignments.conflictingAction(for: .selectedText) == .openPanel)
}

@Test
func hotkeyAssignmentsRoundTrip() throws {
    var assignments = HotkeyAssignments.defaults
    assignments[.screenRegion] = HotkeyShortcut(keyCode: 15, modifiers: [.command, .shift])
    let data = try JSONEncoder().encode(assignments)
    #expect(try JSONDecoder().decode(HotkeyAssignments.self, from: data) == assignments)
}
