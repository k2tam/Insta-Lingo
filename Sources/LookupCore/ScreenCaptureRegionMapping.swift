import CoreGraphics

/// Converts a selection in one AppKit screen's local, bottom-left coordinates
/// to the global, top-left display space used by ScreenCaptureKit screenshots.
public enum ScreenCaptureRegionMapping {
    public static func captureRect(
        localRect: CGRect,
        screenFrame: CGRect,
        mainScreenFrame: CGRect
    ) -> CGRect {
        let appKitRect = localRect.offsetBy(dx: screenFrame.minX, dy: screenFrame.minY)
        return CGRect(
            x: appKitRect.minX - mainScreenFrame.minX,
            y: mainScreenFrame.maxY - appKitRect.maxY,
            width: appKitRect.width,
            height: appKitRect.height
        )
    }
}
