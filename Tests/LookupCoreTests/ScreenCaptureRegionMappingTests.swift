import CoreGraphics
import Testing
@testable import LookupCore

@Test(arguments: [
    (screen: CGRect(x: 0, y: 0, width: 1440, height: 900), local: CGRect(x: 100, y: 200, width: 300, height: 50), expected: CGRect(x: 100, y: 650, width: 300, height: 50)),
    (screen: CGRect(x: 1440, y: -100, width: 1200, height: 800), local: CGRect(x: 20, y: 100, width: 200, height: 40), expected: CGRect(x: 1460, y: 860, width: 200, height: 40)),
    (screen: CGRect(x: -1280, y: 50, width: 1280, height: 1024), local: CGRect(x: 100, y: 900, width: 250, height: 60), expected: CGRect(x: -1180, y: -110, width: 250, height: 60)),
    (screen: CGRect(x: 200, y: 900, width: 1000, height: 700), local: CGRect(x: 80, y: 50, width: 160, height: 35), expected: CGRect(x: 280, y: -85, width: 160, height: 35)),
])
func selectionMapsToGlobalCaptureSpace(_ geometry: (screen: CGRect, local: CGRect, expected: CGRect)) {
    let actual = ScreenCaptureRegionMapping.captureRect(
        localRect: geometry.local,
        screenFrame: geometry.screen,
        mainScreenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900)
    )
    #expect(actual == geometry.expected)
}
