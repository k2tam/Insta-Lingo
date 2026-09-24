import AppKit
import CoreGraphics
import LookupCore
import ScreenCaptureKit
import Vision

@MainActor
final class ScreenRegionOCR: RegionTextRecognizing {
    func recognizeSelectedRegion() async throws -> OCRRecognition? {
        // Do not request this permission at launch. It belongs to the user's
        // explicit "Select screen region" action.
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw ScreenRegionError.permissionDenied
        }

        let session = ScreenRegionSelectionSession()
        guard let region = await session.selectRegion() else { return nil }

        // Allow the compositor to remove the selection overlay before capture.
        try await Task.sleep(for: .milliseconds(120))

        // The CGImage is confined to this function. Neither the flow state nor
        // the lookup request has an image field, and nothing is written to disk.
        let image = try await SCScreenshotManager.captureImage(in: region)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        let candidates = request.results?.compactMap { $0.topCandidates(1).first } ?? []
        return OCRRecognition(
            text: candidates.map(\.string).joined(separator: "\n"),
            confidence: candidates.map(\.confidence).min() ?? 0
        )
    }
}

private enum ScreenRegionError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Screen Recording permission is needed to read the region you select. Enable TransAtGlance in System Settings → Privacy & Security → Screen & System Audio Recording, then try again."
        }
    }
}

/// A one-shot selection surface on every connected display. Each panel joins
/// full-screen spaces without activating our app or moving the reader's space.
@MainActor
private final class ScreenRegionSelectionSession {
    private var windows: [NSPanel] = []
    private var continuation: CheckedContinuation<CGRect?, Never>?

    func selectRegion() async -> CGRect? {
        // NSScreen.screens starts with the menu-bar (main) display, whose top
        // edge is the origin for ScreenCaptureKit's global display space.
        guard let mainScreen = NSScreen.screens.first else { return nil }
        let mainFrame = mainScreen.frame
        for screen in NSScreen.screens {
            let overlay = RegionSelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
            overlay.onFinish = { [weak self] localRect in
                guard let self else { return }
                let captureRect = localRect.map {
                    ScreenCaptureRegionMapping.captureRect(
                        localRect: $0,
                        screenFrame: screen.frame,
                        mainScreenFrame: mainFrame
                    )
                }
                self.finish(with: captureRect)
            }

            let window = RegionSelectionPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .screenSaver
            window.hidesOnDeactivate = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.contentView = overlay
            window.makeFirstResponder(overlay)
            windows.append(window)
            window.orderFrontRegardless()
        }
        // Escape works on the display where the pointer starts; clicking any
        // other overlay makes that panel key for the drag and subsequent Escape.
        if let pointerWindow = windows.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) {
            pointerWindow.makeKey()
        }
        NSCursor.crosshair.push()

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    private func finish(with rect: CGRect?) {
        guard let waiting = continuation else { return }
        continuation = nil
        for window in windows { window.orderOut(nil) }
        windows.removeAll()
        NSCursor.pop()
        waiting.resume(returning: rect)
    }
}

private final class RegionSelectionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
private final class RegionSelectionView: NSView {
    var onFinish: ((CGRect?) -> Void)?
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.28).setFill()
        bounds.fill()
        guard let selection = selectionRect else { return }
        NSColor.clear.setFill()
        selection.fill(using: .clear)
        NSColor.systemBlue.setStroke()
        let path = NSBezierPath(rect: selection)
        path.lineWidth = 2
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = boundedPoint(for: event)
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = boundedPoint(for: event)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = boundedPoint(for: event)
        guard let result = selectionRect, result.width >= 4, result.height >= 4 else {
            onFinish?(nil)
            return
        }
        onFinish?(result)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onFinish?(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    private var selectionRect: CGRect? {
        guard let startPoint, let currentPoint else { return nil }
        return CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(currentPoint.x - startPoint.x),
            height: abs(currentPoint.y - startPoint.y)
        )
    }

    private func boundedPoint(for event: NSEvent) -> CGPoint {
        let point = convert(event.locationInWindow, from: nil)
        return CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }
}
