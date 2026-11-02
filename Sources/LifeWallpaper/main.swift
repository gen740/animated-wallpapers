import AppKit
import CoreGraphics

private let rgb = CGColorSpaceCreateDeviceRGB()
private func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: rgb, components: [r, g, b, a])!
}

private final class LifeView: NSView {
    private let pitch: CGFloat = 21
    private var columns = 0
    private var rows = 0
    private var cells: [Bool] = []
    private var opacity: [CGFloat] = []
    private var flips: [Int: TimeInterval] = [:]
    private var nextStep: TimeInterval = 0
    private var unchangedSteps = 0
    var paused = false { didSet { needsDisplay = true } }

    override var isOpaque: Bool { true }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        resizeBoard()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        resizeBoard()
    }

    private func resizeBoard() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let newColumns = Int(ceil(bounds.width / pitch))
        let newRows = Int(ceil(bounds.height / pitch))
        guard newColumns != columns || newRows != rows else { return }
        columns = newColumns
        rows = newRows
        reset()
    }

    func reset() {
        guard columns > 0 && rows > 0 else { return }
        cells = (0..<(columns * rows)).map { _ in Double.random(in: 0..<1) < 0.29 }
        opacity = cells.map { $0 ? 1 : 0 }
        flips.removeAll()
        unchangedSteps = 0
        nextStep = ProcessInfo.processInfo.systemUptime + 0.8
        needsDisplay = true
    }

    private func advance() {
        var next = cells
        var changes = 0
        for y in 0..<rows {
            for x in 0..<columns {
                var neighbors = 0
                for dy in -1...1 {
                    for dx in -1...1 where dx != 0 || dy != 0 {
                        let nx = (x + dx + columns) % columns
                        let ny = (y + dy + rows) % rows
                        if cells[ny * columns + nx] { neighbors += 1 }
                    }
                }
                let index = y * columns + x
                let alive = neighbors == 3 || (cells[index] && neighbors == 2)
                next[index] = alive
                if alive != cells[index] { changes += 1 }
            }
        }
        cells = next
        unchangedSteps = changes == 0 ? unchangedSteps + 1 : 0
        // A frozen or almost empty board is seeded afresh, rather than left blank.
        if unchangedSteps > 45 || cells.filter({ $0 }).count < max(3, cells.count / 150) {
            reset()
        }
    }

    func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        if !paused && now >= nextStep {
            advance()
            nextStep = now + 0.24
        }
        for index in opacity.indices {
            let target: CGFloat = cells[index] ? 1 : 0
            opacity[index] += (target - opacity[index]) * 0.22
            if abs(opacity[index] - target) < 0.004 { opacity[index] = target }
        }
        let wasAnimating = !flips.isEmpty
        flips = flips.filter { now - $0.value < 0.52 }
        if !paused || wasAnimating { needsDisplay = true }
    }

    func toggle(at screenPoint: NSPoint) {
        guard let window else { return }
        let point = convert(window.convertPoint(fromScreen: screenPoint), from: nil)
        guard bounds.contains(point), columns > 0, rows > 0 else { return }
        let x = Int(point.x / pitch), y = Int(point.y / pitch)
        guard x >= 0 && x < columns && y >= 0 && y < rows else { return }
        let index = y * columns + x
        cells[index].toggle()
        flips[index] = ProcessInfo.processInfo.systemUptime
        // Let the clicked tile finish its turn before the next Life generation.
        nextStep = ProcessInfo.processInfo.systemUptime + 0.75
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setFillColor(rgba(0.035, 0.034, 0.030))
        context.fill(bounds)
        guard columns > 0 && rows > 0 else { return }
        // The static hairline grid keeps dead cells visible without making them shine.
        let grid = CGMutablePath()
        for x in 0...columns {
            let px = CGFloat(x) * pitch + 0.5
            grid.move(to: CGPoint(x: px, y: 0))
            grid.addLine(to: CGPoint(x: px, y: bounds.height))
        }
        for y in 0...rows {
            let py = CGFloat(y) * pitch + 0.5
            grid.move(to: CGPoint(x: 0, y: py))
            grid.addLine(to: CGPoint(x: bounds.width, y: py))
        }
        context.addPath(grid)
        context.setStrokeColor(rgba(0.16, 0.14, 0.10, 0.56))
        context.setLineWidth(0.6)
        context.strokePath()

        let now = ProcessInfo.processInfo.systemUptime
        for index in cells.indices {
            let progress = flips[index].map { CGFloat((now - $0) / 0.52) }
            guard opacity[index] > 0.005 || progress != nil else { continue }
            let x = CGFloat(index % columns) * pitch
            let y = CGFloat(index / columns) * pitch
            let rect = CGRect(x: x + 1.8, y: y + 1.8, width: pitch - 3.6, height: pitch - 3.6)
            let seed = CGFloat((index &* 1103515245 &+ 12345) & 255) / 255
            let turning = progress != nil
            let faceAlive = progress.map { $0 < 0.5 ? !cells[index] : cells[index] } ?? cells[index]
            let alpha: CGFloat = turning ? 1 : opacity[index]
            context.saveGState()
            if let progress {
                let scale = max(0.045, abs(cos(.pi * progress)))
                context.translateBy(x: rect.midX, y: rect.midY)
                context.scaleBy(x: scale, y: 1)
                context.translateBy(x: -rect.midX, y: -rect.midY)
            }
            context.setFillColor(faceAlive
                ? rgba(0.46 + seed * 0.10, 0.34 + seed * 0.075, 0.17 + seed * 0.040, alpha)
                : rgba(0.090, 0.084, 0.065, alpha))
            context.fill(rect)
            context.setStrokeColor(faceAlive
                ? rgba(0.70, 0.57, 0.32, alpha * 0.52)
                : rgba(0.26, 0.22, 0.15, alpha * 0.6))
            context.setLineWidth(0.65)
            context.stroke(rect.insetBy(dx: 0.3, dy: 0.3))
            if faceAlive {
                // A short, low-contrast highlight reads as brushed matte metal.
                context.move(to: CGPoint(x: rect.minX + 2, y: rect.maxY - 2))
                context.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.maxY - 2))
                context.setStrokeColor(rgba(0.83, 0.70, 0.43, alpha * 0.24))
                context.setLineWidth(0.7)
                context.strokePath()
            }
            context.restoreGState()
        }
    }
}

private final class LifeWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        ignoresMouseEvents = true
        isOpaque = true
        hasShadow = false
        backgroundColor = NSColor(red: 0.035, green: 0.034, blue: 0.030, alpha: 1)
        contentView = LifeView(frame: CGRect(origin: .zero, size: screen.frame.size))
        orderFrontRegardless()
    }
}

private final class LifeApp: NSObject, NSApplicationDelegate {
    private var windows: [LifeWindow] = []
    private var timer: Timer?
    private var globalClickMonitor: Any?
    private var status: NSStatusItem?
    private var pauseItem: NSMenuItem?
    private var paused = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "▦"
        item.button?.toolTip = "Life — Matte Gold"
        let menu = NSMenu()
        let pause = NSMenuItem(title: "一時停止", action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)
        let restart = NSMenuItem(title: "ランダムに再生成", action: #selector(restartBoards), keyEquivalent: "")
        restart.target = self
        menu.addItem(restart)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "終了", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        status = item
        pauseItem = pause
        installWindows()
        // The desktop window itself is click-through. Observe clicks handled by
        // Finder and other apps too, so interaction works behind normal windows.
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.toggleAtCursor()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            self?.windows.forEach { ($0.contentView as? LifeView)?.tick() }
        }
        timer?.tolerance = 0.005
    }

    private func installWindows() {
        windows.forEach { $0.orderOut(nil); $0.close() }
        windows = NSScreen.screens.map { LifeWindow(screen: $0) }
        windows.forEach { ($0.contentView as? LifeView)?.paused = paused }
    }

    private func toggleAtCursor() {
        let point = NSEvent.mouseLocation
        for window in windows where window.frame.contains(point) {
            (window.contentView as? LifeView)?.toggle(at: point)
            break
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
    }

    @objc private func screensChanged() { installWindows() }
    @objc private func restartBoards() { windows.forEach { ($0.contentView as? LifeView)?.reset() } }
    @objc private func togglePause() {
        paused.toggle()
        pauseItem?.title = paused ? "再開" : "一時停止"
        windows.forEach { ($0.contentView as? LifeView)?.paused = paused }
    }
    @objc private func quitApp() { NSApp.terminate(nil) }
}

let application = NSApplication.shared
private let delegate = LifeApp()
application.delegate = delegate
application.run()
