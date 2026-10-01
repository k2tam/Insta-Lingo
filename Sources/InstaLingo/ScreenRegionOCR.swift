import AppKit
import CoreGraphics
import LookupCore
import ScreenCaptureKit
import Vision
import os

private let ocrDebugLogger = Logger(subsystem: "com.k2tam.InstaLingo", category: "DEBUG-ocr-9c2e")

@MainActor
final class ScreenRegionOCR: RegionTextRecognizing {
    init() {
        Self.warmUpVision()
    }

    /// The first Vision text request loads its models, which can take seconds.
    /// Run a throwaway recognition at launch so the first real capture is fast.
    private static func warmUpVision() {
        Task.detached(priority: .utility) {
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(
                    data: nil, width: 128, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { return }
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 128, height: 64))
            guard let image = context.makeImage() else { return }
            ocrDebugLogger.notice("[DEBUG-ocr-9c2e] vision warm-up start t=\(Date().timeIntervalSince1970, privacy: .public)")
            for level in [VNRequestTextRecognitionLevel.accurate, .fast] {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = level
                request.recognitionLanguages = ["en-US"]
                try? VNImageRequestHandler(cgImage: image).perform([request])
            }
            ocrDebugLogger.notice("[DEBUG-ocr-9c2e] vision warm-up done t=\(Date().timeIntervalSince1970, privacy: .public)")
        }
    }

    func recognizeSelectedRegion(onSelection: @MainActor () async -> Void) async throws -> OCRRecognition? {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw ScreenRegionError.permissionDenied
        }
        // Enumerating shareable content is slow on first use; overlap it with the drag.
        ocrDebugLogger.notice("[DEBUG-ocr-9c2e] shareable content start t=\(Date().timeIntervalSince1970, privacy: .public)")
        let contentTask = Task {
            let snapshot = ShareableContentSnapshot(content: try await SCShareableContent.current)
            ocrDebugLogger.notice("[DEBUG-ocr-9c2e] shareable content done t=\(Date().timeIntervalSince1970, privacy: .public)")
            return snapshot
        }
        let session = ScreenRegionSelectionSession()
        guard let region = await session.selectRegion() else {
            contentTask.cancel()
            return nil
        }
        ocrDebugLogger.notice("[DEBUG-ocr-9c2e] region selected t=\(Date().timeIntervalSince1970, privacy: .public)")
        await onSelection()
        ocrDebugLogger.notice("[DEBUG-ocr-9c2e] panel shown t=\(Date().timeIntervalSince1970, privacy: .public)")

        // The CGImage is confined to this function. Neither the flow state nor
        // the lookup request has an image field, and nothing is written to disk.
        let image: CGImage
        do {
            let content = try await contentTask.value.content
            ocrDebugLogger.notice("[DEBUG-ocr-9c2e] content awaited t=\(Date().timeIntervalSince1970, privacy: .public)")
            guard let display = content.displays.first(where: { $0.displayID == region.displayID }) else {
                throw ScreenRegionError.displayUnavailable
            }
            let ownApplications = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
            guard !ownApplications.isEmpty else { throw ScreenRegionError.displayUnavailable }
            let filter = SCContentFilter(display: display, excludingApplications: ownApplications, exceptingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.sourceRect = region.rect.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY)
            configuration.width = Int(ceil(region.rect.width * CGFloat(filter.pointPixelScale)))
            configuration.height = Int(ceil(region.rect.height * CGFloat(filter.pointPixelScale)))
            configuration.showsCursor = false
            ocrDebugLogger.notice("[DEBUG-ocr-9c2e] capture start t=\(Date().timeIntervalSince1970, privacy: .public)")
            image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            ocrDebugLogger.notice("[DEBUG-ocr-9c2e] capture done t=\(Date().timeIntervalSince1970, privacy: .public)")
        } catch {
            ocrDebugLogger.notice("[DEBUG-ocr-9c2e] capture failed \(error.localizedDescription, privacy: .public) t=\(Date().timeIntervalSince1970, privacy: .public)")
            let captureError = error as NSError
            if captureError.domain == SCStreamErrorDomain,
               captureError.code == SCStreamError.userDeclined.rawValue {
                throw ScreenRegionError.permissionDenied
            }
            throw error
        }
        return try await Task.detached(priority: .userInitiated) {
            // ScreenCaptureKit buffers can carry display-specific color spaces or
            // be very small; Vision's reader (CRImageReaderError) rejects both.
            // Re-render into a plain sRGB bitmap with a minimum edge first.
            ocrDebugLogger.notice("[DEBUG-ocr-9c2e] vision start t=\(Date().timeIntervalSince1970, privacy: .public)")
            let prepared = Self.normalized(image) ?? image
            var lastError: Error?
            for level in [VNRequestTextRecognitionLevel.accurate, .fast] {
                do {
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = level
                    request.recognitionLanguages = ["en-US"]
                    request.usesLanguageCorrection = level == .accurate
                    try VNImageRequestHandler(cgImage: prepared).perform([request])
                    ocrDebugLogger.notice("[DEBUG-ocr-9c2e] vision done level=\(level.rawValue, privacy: .public) t=\(Date().timeIntervalSince1970, privacy: .public)")
                    let candidates = request.results?.compactMap { $0.topCandidates(1).first } ?? []
                    return OCRRecognition(
                        text: candidates.map(\.string).joined(separator: "\n"),
                        confidence: candidates.map(\.confidence).min() ?? 0
                    )
                } catch {
                    lastError = error
                }
            }
            throw lastError ?? ScreenRegionError.displayUnavailable
        }.value
    }

    nonisolated private static func normalized(_ image: CGImage) -> CGImage? {
        let minEdge = 64
        let width = max(image.width, minEdge)
        let height = max(image.height, minEdge)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // Keep the capture top-left aligned inside any white padding.
        context.draw(image, in: CGRect(x: 0, y: height - image.height, width: image.width, height: image.height))
        return context.makeImage()
    }
}

/// `SCShareableContent` is an immutable snapshot but isn't marked `Sendable`,
/// so box it to hand it back from the task that prefetches it.
private struct ShareableContentSnapshot: @unchecked Sendable {
    let content: SCShareableContent
}

private enum ScreenRegionError: LocalizedError {
    case permissionDenied
    case displayUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "macOS did not authorize this screen capture. Enable Insta Lingo in System Settings → Privacy & Security → Screen & System Audio Recording, then quit and reopen the app."
        case .displayUnavailable:
            "Could not capture the selected screen. Try again."
        }
    }
}

/// A one-shot selection surface on every connected display. Each panel joins
/// full-screen spaces without activating our app or moving the reader's space.
private struct SelectedRegion {
    let rect: CGRect
    let displayID: CGDirectDisplayID
}

@MainActor
private final class ScreenRegionSelectionSession {
    private var windows: [NSPanel] = []
    private var continuation: CheckedContinuation<SelectedRegion?, Never>?

    func selectRegion() async -> SelectedRegion? {
        // NSScreen.screens starts with the menu-bar (main) display, whose top
        // edge is the origin for ScreenCaptureKit's global display space.
        let screens = NSScreen.screens
        guard let mainScreen = screens.first else { return nil }
        let mainFrame = mainScreen.frame
        return await withCheckedContinuation { continuation in
            // Install the continuation before exposing any overlay. Otherwise
            // a quick click or Escape can arrive first and be dropped forever.
            self.continuation = continuation

            for screen in screens {
                let overlay = RegionSelectionView(frame: CGRect(origin: .zero, size: screen.frame.size))
                overlay.onFinish = { [weak self] localRect in
                    guard let self else { return }
                    let selectedRegion = localRect.flatMap { rect -> SelectedRegion? in
                        guard let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else { return nil }
                        return SelectedRegion(
                            rect: ScreenCaptureRegionMapping.captureRect(
                                localRect: rect,
                                screenFrame: screen.frame,
                                mainScreenFrame: mainFrame
                            ),
                            displayID: displayID
                        )
                    }
                    self.finish(with: selectedRegion)
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
                window.ignoresMouseEvents = false
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
                window.contentView = overlay
                window.makeFirstResponder(overlay)
                windows.append(window)
                window.orderFrontRegardless()
            }

            // A nonactivating panel can become key without stealing focus from
            // the document app. Doing both operations together makes the first
            // drag and Escape reliably reach the overlay.
            let pointerWindow = windows.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? windows.first
            pointerWindow?.makeKeyAndOrderFront(nil)
            NSCursor.crosshair.push()
        }
    }

    private func finish(with region: SelectedRegion?) {
        guard let waiting = continuation else { return }
        continuation = nil
        for window in windows { window.orderOut(nil) }
        windows.removeAll()
        NSCursor.pop()
        waiting.resume(returning: region)
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
