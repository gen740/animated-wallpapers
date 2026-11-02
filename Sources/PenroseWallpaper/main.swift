import AppKit
import CoreGraphics

private struct Point {
    var x: CGFloat
    var y: CGFloat
}

private struct Rhomb {
    let corners: [CGPoint]
    let center: CGPoint
    let thin: Bool
    let tone: CGFloat
    let hue: CGFloat
    let goldSeedA: CGFloat
    let goldSeedB: CGFloat
    let bounds: CGRect

    func contains(_ p: CGPoint, at time: CGFloat) -> Bool {
        guard bounds.insetBy(dx: -16, dy: -16).contains(p) else { return false }
        // The same displacement is applied to shared vertices when drawing and hit-testing.
        let shape = corners.map { drift($0, at: time) }
        for n in 0..<4 {
            let a = shape[n], b = shape[(n + 1) % 4]
            if (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x) < -0.001 { return false }
        }
        return true
    }
}

// A continuous deformation field keeps every shared edge joined while the crystal breathes.
private func drift(_ p: CGPoint, at time: CGFloat) -> CGPoint {
    let dx = 4.2 * sin(p.x * 0.006 + p.y * 0.003 - time * 0.15)
           + 2.3 * sin(p.y * 0.009 + time * 0.11)
    let dy = 4.0 * sin(p.y * 0.005 - p.x * 0.002 + time * 0.13)
           + 2.0 * sin(p.x * 0.008 - time * 0.09)
    return CGPoint(x: p.x + dx, y: p.y + dy)
}

private enum Tiling {
    static let gamma: [CGFloat] = [0.071, 0.137, 0.193, -0.043, -0.358]
    static let directions: [Point] = (0..<5).map {
        let angle = CGFloat($0) * 2 * .pi / 5
        return Point(x: cos(angle), y: sin(angle))
    }

    static func hash(_ values: Int...) -> CGFloat {
        var h: UInt32 = 2_166_136_261
        for value in values {
            h = (h ^ UInt32(truncatingIfNeeded: value)) &* 16_777_619
        }
        h ^= h >> 16; h = h &* 0x7feb352d
        h ^= h >> 15; h = h &* 0x846ca68b
        h ^= h >> 16
        return CGFloat(h) / 4_294_967_296
    }

    static func make(in rect: CGRect, size: CGFloat) -> [Rhomb] {
        let w = rect.width, h = rect.height
        let origin = CGPoint(x: w * 0.516, y: h * 0.503)
        let limit = Int(ceil(hypot(w, h) / (5 * size))) + 9
        var tiles: [Rhomb] = []
        for i in 0..<5 {
            for j in (i + 1)..<5 {
                let a = directions[i], b = directions[j]
                let det = a.x * b.y - a.y * b.x
                for k in (-limit)...limit {
                    for l in (-limit)...limit {
                        let ak = CGFloat(k) - gamma[i], bl = CGFloat(l) - gamma[j]
                        let rx = (ak * b.y - a.y * bl) / det
                        let ry = (a.x * bl - ak * b.x) / det
                        var bx: CGFloat = 0, by: CGFloat = 0
                        for n in 0..<5 {
                            let d = directions[n]
                            let m: CGFloat = n == i ? CGFloat(k) : n == j ? CGFloat(l) :
                                ceil(d.x * rx + d.y * ry + gamma[n] - 1e-9)
                            bx += m * d.x; by += m * d.y
                        }
                        let x = origin.x + bx * size, y = origin.y + by * size
                        if x < -2 * size || x > w + 2 * size || y < -2 * size || y > h + 2 * size { continue }
                        let corners = [
                            CGPoint(x: x, y: y),
                            CGPoint(x: x + a.x * size, y: y + a.y * size),
                            CGPoint(x: x + (a.x + b.x) * size, y: y + (a.y + b.y) * size),
                            CGPoint(x: x + b.x * size, y: y + b.y * size)
                        ]
                        let center = CGPoint(x: x + (a.x + b.x) * size / 2,
                                             y: y + (a.y + b.y) * size / 2)
                        let minX = corners.map(\.x).min()!, maxX = corners.map(\.x).max()!
                        let minY = corners.map(\.y).min()!, maxY = corners.map(\.y).max()!
                        tiles.append(Rhomb(corners: corners, center: center, thin: j - i == 2 || j - i == 3,
                                           tone: hash(i + 17, j + 31, k, l),
                                           hue: hash(i + 53, j + 71, k, l),
                                           goldSeedA: hash(i, j, k, l),
                                           goldSeedB: hash(i + 101, j + 103, k, l),
                                           bounds: CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)))
                    }
                }
            }
        }
        return tiles
    }
}

private let rgbSpace = CGColorSpaceCreateDeviceRGB()

private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: rgbSpace, components: [r, g, b, alpha])!
}

// CSS hsl() uses lightness, not NSColor's HSV brightness. Keep the HTML palette intact.
private func hsl(_ degrees: CGFloat, _ saturation: CGFloat, _ lightness: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    let s = max(0, min(1, saturation / 100)), l = max(0, min(1, lightness / 100))
    let c = (1 - abs(2 * l - 1)) * s
    let h = ((degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)) / 60
    let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
    let m = l - c / 2
    let components: (CGFloat, CGFloat, CGFloat)
    switch h {
    case 0..<1: components = (c, x, 0)
    case 1..<2: components = (x, c, 0)
    case 2..<3: components = (0, c, x)
    case 3..<4: components = (0, x, c)
    case 4..<5: components = (x, 0, c)
    default: components = (c, 0, x)
    }
    return color(components.0 + m, components.1 + m, components.2 + m, alpha)
}

private func smooth(_ value: CGFloat) -> CGFloat {
    let x = max(0, min(1, value))
    return x * x * (3 - 2 * x)
}

private struct Ripple {
    let center: CGPoint
    let time: TimeInterval
}

private final class WallpaperView: NSView {
    private var tiles: [Rhomb] = []
    private var hovered: Int?
    private var lastRipple: TimeInterval = -.infinity
    private var ripples: [Ripple] = []
    private var pausedAt: TimeInterval?
    private var pausedDuration: TimeInterval = 0
    var paused = false {
        didSet {
            let current = ProcessInfo.processInfo.systemUptime
            if paused && !oldValue { pausedAt = current }
            if !paused && oldValue, let pausedAt {
                pausedDuration += current - pausedAt
                self.pausedAt = nil
            }
            needsDisplay = true
        }
    }

    private var animationTime: TimeInterval {
        (pausedAt ?? ProcessInfo.processInfo.systemUptime) - pausedDuration
    }

    override var isOpaque: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        rebuild()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        rebuild()
    }

    private func rebuild() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        // Slightly finer facets than the source, without making the mesh too dense.
        let size = max(30.6, min(52.2, hypot(bounds.width, bounds.height) / 46.67))
        tiles = Tiling.make(in: bounds, size: size)
        hovered = nil
        lastRipple = -.infinity
        ripples.removeAll()
        needsDisplay = true
    }

    func tick() {
        guard !paused, let window else { return }
        let mouse = convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        let next: Int? = bounds.contains(mouse) ? tiles.indices.reversed().first(where: { tiles[$0].contains(mouse, at: CGFloat(animationTime)) }) : nil
        let now = animationTime
        if next != hovered {
            if let next, now - lastRipple >= 0.22 {
                lastRipple = now
                let center = drift(tiles[next].center, at: CGFloat(now))
                ripples.append(Ripple(center: center, time: now))
            }
            hovered = next
        }
        ripples.removeAll { now - $0.time > 1.5 }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let w = bounds.width, h = bounds.height
        let now = animationTime
        let time = CGFloat(now)
        ctx.setFillColor(color(8 / 255, 18 / 255, 28 / 255))
        ctx.fill(bounds)
        if let gradient = CGGradient(colorsSpace: rgbSpace,
                                     colors: [color(34 / 255, 57 / 255, 66 / 255),
                                              color(20 / 255, 41 / 255, 53 / 255),
                                              color(8 / 255, 18 / 255, 28 / 255)] as CFArray,
                                     locations: [0, 0.38, 1]) {
            ctx.drawRadialGradient(gradient,
                                   startCenter: CGPoint(x: w * 0.51, y: h * 0.51), startRadius: 0,
                                   endCenter: CGPoint(x: w * 0.51, y: h * 0.51), endRadius: w * 0.69,
                                   options: [.drawsAfterEndLocation])
        }
        for (index, tile) in tiles.enumerated() {
            let shape = tile.corners.map { drift($0, at: time) }
            let center = CGPoint(x: (shape[0].x + shape[2].x) / 2,
                                 y: (shape[0].y + shape[2].y) / 2)
            // Each facet has its own clock and offset. There is no global gold swap.
            let goldPeriod = 7.0 + Double(tile.goldSeedB) * 16.0
            let localTime = now + Double(tile.goldSeedA) * goldPeriod
            let epoch = Int(floor(localTime / goldPeriod))
            let phase = CGFloat(localTime / goldPeriod - Double(epoch))
            let blend = smooth((phase - (1 - 2.8 / CGFloat(goldPeriod))) * CGFloat(goldPeriod) / 2.8)
            let seed = Int(tile.goldSeedA * 1_000_000)
            let oldGold = Tiling.hash(seed, epoch) < 0.020
            let newGold = Tiling.hash(seed, epoch + 1) < 0.020
            let goldAmount: CGFloat = (oldGold ? 1 - blend : 0) + (newGold ? blend : 0)
            let proximity = max(0, 1 - hypot((center.x - w * 0.5) / (w * 0.69),
                                              (center.y - h * 0.5) / (h * 0.88)))
            // Broad traveling illumination plus two tile-specific, nonmatching rhythms.
            let field = sin(center.x * 0.009 + center.y * 0.004 - time * 0.31)
                      * cos(center.y * 0.007 - center.x * 0.003 + time * 0.22)
            let shimmer = sin(time * (0.09 + tile.hue * 0.23) + tile.goldSeedA * 6.28)
            let swell = sin(time * (0.065 + tile.tone * 0.16) + tile.goldSeedB * 6.28)
            let light = 12 + proximity * 7 + tile.tone * 8 + (tile.thin ? 2 : 0)
                      + field * 2.4 + shimmer * 2.4 + swell * 1.6
            let base = hsl(189 + tile.hue * 20 + field * 4 + shimmer * 5 + swell * 2,
                           19 + tile.tone * 10 + swell * 2, light)
            let hover: CGFloat = hovered == index ? 1 : 0
            let pulse = ripples.reduce(CGFloat(0)) { intensity, ripple in
                let distance = hypot(center.x - ripple.center.x, center.y - ripple.center.y)
                let arrival = CGFloat(now - ripple.time) - distance / 380
                return max(intensity, max(0, 1 - abs(arrival - 0.16) / 0.29) * max(0, 1 - distance / 210))
            }
            let path = CGMutablePath()
            path.move(to: shape[0])
            for corner in shape.dropFirst() { path.addLine(to: corner) }
            path.closeSubpath()
            ctx.saveGState()
            // Hover illuminates a single facet; neighbors receive only a soft fading halo.
            let glow = max(goldAmount * 0.65, pulse * 0.48, hover * 0.9)
            if glow > 0.04 {
                ctx.saveGState()
                ctx.setShadow(offset: .zero, blur: 12 + 8 * glow,
                              color: hover > 0 ? color(0.49, 0.91, 0.92, 0.82) :
                                  color(1, 0.73 + 0.12 * pulse, 0.34 + 0.27 * pulse, glow * 0.7))
                ctx.addPath(path)
                ctx.setFillColor(hover > 0 ? color(0.38, 0.76, 0.79, 0.34) :
                                     color(0.64, 0.46, 0.22, glow * 0.55))
                ctx.fillPath()
                ctx.restoreGState()
            }
            ctx.addPath(path)
            ctx.setFillColor(base)
            ctx.fillPath()
            if goldAmount > 0.001 {
                ctx.saveGState()
                ctx.addPath(path); ctx.clip()
                let strength = goldAmount
                let glint = CGFloat(0.5 + 0.5 * sin(time * (0.21 + tile.hue * 0.33) + tile.goldSeedB * 6.28))
                let goldHue: CGFloat = 37 + tile.hue * 5
                let goldLight: CGFloat = 31 + tile.tone * 9
                if let metal = CGGradient(colorsSpace: rgbSpace, colors: [
                    hsl(goldHue, 32, goldLight, strength),
                    hsl(goldHue, 38, goldLight + 19 + glint * 5, strength),
                    hsl(goldHue, 34, goldLight + 6, strength)
                ] as CFArray, locations: [0, 0.46, 1]) {
                    let shimmer = CGFloat(sin(time * (0.16 + tile.tone * 0.31) + tile.goldSeedB * 7)) * 17
                    ctx.drawLinearGradient(metal,
                                           start: CGPoint(x: center.x - 74 + shimmer, y: center.y - 74),
                                           end: CGPoint(x: center.x + 74 + shimmer, y: center.y + 74),
                                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                }
                ctx.restoreGState()
            }
            if pulse > 0.01 || hover > 0 {
                ctx.saveGState()
                ctx.addPath(path); ctx.clip()
                let flash = max(pulse * 0.10, hover * 0.17)
                if let sweep = CGGradient(colorsSpace: rgbSpace,
                                          colors: [color(0.50, 0.83, 0.86, 0), color(0.66, 0.94, 0.91, flash),
                                                   color(0.88, 0.77, 0.47, 0)] as CFArray,
                                          locations: [0, 0.5, 1]) {
                    let offset = CGFloat(now * 105).truncatingRemainder(dividingBy: 165)
                    ctx.drawLinearGradient(sweep,
                                           start: CGPoint(x: center.x - 110 + offset, y: center.y - 70),
                                           end: CGPoint(x: center.x + 55 + offset, y: center.y + 70),
                                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                }
                ctx.restoreGState()
            }
            ctx.addPath(path)
            ctx.setStrokeColor(hover > 0 ? color(0.65, 0.96, 0.94, 0.88) :
                               pulse > 0.02 ? color(0.75, 0.91, 0.88, 0.38 + pulse * 0.32) :
                               goldAmount > 0.3 ? color(223 / 255, 191 / 255, 130 / 255, 0.65) :
                               color(166 / 255, 195 / 255, 195 / 255, 0.36))
            ctx.setLineWidth(1.05 + pulse * 0.7 + hover * 0.7)
            ctx.strokePath()
            ctx.restoreGState()
        }
        if let shade = CGGradient(colorsSpace: rgbSpace,
                                  colors: [color(3 / 255, 9 / 255, 16 / 255, 0),
                                           color(2 / 255, 6 / 255, 13 / 255, 0.54)] as CFArray,
                                  locations: [0, 1]) {
            ctx.drawRadialGradient(shade, startCenter: CGPoint(x: w * 0.5, y: h * 0.51), startRadius: w * 0.22,
                                   endCenter: CGPoint(x: w * 0.5, y: h * 0.51), endRadius: w * 0.78,
                                   options: [.drawsAfterEndLocation])
        }
    }
}

private final class WallpaperWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        ignoresMouseEvents = true
        isOpaque = true
        backgroundColor = NSColor(red: 0.031, green: 0.071, blue: 0.11, alpha: 1)
        hasShadow = false
        contentView = WallpaperView(frame: NSRect(origin: .zero, size: screen.frame.size))
        orderFrontRegardless()
    }
}

private final class WallpaperApp: NSObject, NSApplicationDelegate {
    private var windows: [WallpaperWindow] = []
    private var timer: Timer?
    private var status: NSStatusItem?
    private var pauseItem: NSMenuItem?
    private var paused = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "◇"
        item.button?.toolTip = "Penrose Nocturne"
        let menu = NSMenu()
        let pause = NSMenuItem(title: "アニメーションを一時停止", action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "終了", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        status = item
        pauseItem = pause
        installWindows()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24, repeats: true) { [weak self] _ in
            self?.windows.forEach { ($0.contentView as? WallpaperView)?.tick() }
        }
        timer?.tolerance = 0.005
    }

    private func installWindows() {
        windows.forEach { $0.orderOut(nil); $0.close() }
        windows = (NSScreen.screens).map { WallpaperWindow(screen: $0) }
        windows.forEach { ($0.contentView as? WallpaperView)?.paused = paused }
    }

    @objc private func screensChanged() { installWindows() }
    @objc private func togglePause() {
        paused.toggle()
        pauseItem?.title = paused ? "アニメーションを再開" : "アニメーションを一時停止"
        windows.forEach { ($0.contentView as? WallpaperView)?.paused = paused }
    }
    @objc private func quitApp() { NSApp.terminate(nil) }
}

let application = NSApplication.shared
private let delegate = WallpaperApp()
application.delegate = delegate
application.run()
