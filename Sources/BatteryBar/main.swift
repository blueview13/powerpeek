import AppKit
import Combine
import IOKit.ps
import ServiceManagement
import SwiftUI

@main
struct BatteryBarMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

enum PercentageFontWeight: String, CaseIterable, Identifiable {
    case light
    case normal
    case bold

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: return "Light"
        case .normal: return "Normal"
        case .bold: return "Bold"
        }
    }

    var font: NSFont {
        switch self {
        case .light: return NSFont.systemFont(ofSize: 14, weight: .light)
        case .normal: return NSFont.systemFont(ofSize: 14, weight: .regular)
        case .bold: return NSFont.systemFont(ofSize: 14, weight: .bold)
        }
    }
}

enum BatteryIconStyle: String, CaseIterable, Identifiable {
    case `default`
    case tahoe

    var id: String { rawValue }

    var label: String {
        switch self {
        case .default: return "Default"
        case .tahoe: return "Mac OS Tahoe"
        }
    }
}

func customBatteryImage(for reading: BatteryReading, size: CGFloat, style: BatteryIconStyle) -> NSImage? {
    switch style {
    case .default:
        let symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: 18,
            weight: .bold,
            scale: .medium
        )
        let paletteConfiguration = NSImage.SymbolConfiguration(
            paletteColors: [reading.displayColor, reading.isCharging ? .systemGreen : reading.displayColor]
        )
        return NSImage(
            systemSymbolName: reading.symbolName,
            accessibilityDescription: reading.accessibilityDescription
        )?.withSymbolConfiguration(symbolConfiguration.applying(paletteConfiguration))

    case .tahoe:
        let imageWidth = max(size * 1.45, 20)
        let imageHeight = max(size * 0.78, 13)
        let image = NSImage(size: NSSize(width: imageWidth, height: imageHeight), flipped: false) { rect in
            let outlineColor = NSColor(
                named: "BatteryIconOutline"
            ) ?? (UserDefaults.standard.string(forKey: "menuBarTextColor") == "white" ? .white : .black)
            let fillColor = reading.isCharging ? NSColor.systemGreen : reading.displayColor
            let outerPadding: CGFloat = 1.5
            let capWidth: CGFloat = 3.0
            let capHeight: CGFloat = max(5.2, rect.height * 0.47)
            let bodyWidth = rect.width - capWidth - outerPadding * 2.2
            let bodyHeight = rect.height - outerPadding * 2.0
            let bodyRect = NSRect(
                x: outerPadding,
                y: outerPadding,
                width: bodyWidth,
                height: bodyHeight
            )
            let capRect = NSRect(
                x: rect.maxX - capWidth - outerPadding * 0.8,
                y: (rect.height - capHeight) / 2.0,
                width: capWidth,
                height: capHeight
            )
            let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 2.4, yRadius: 2.4)
            let capPath = NSBezierPath(roundedRect: capRect, xRadius: 1.3, yRadius: 1.3)

            outlineColor.setStroke()
            bodyPath.lineWidth = 1.15
            bodyPath.stroke()

            let fillRatio = max(0, min(1.0, CGFloat(reading.percentage) / 100.0))
            let fillWidth = max(1.2, (bodyRect.width - 2.2) * fillRatio)
            let fillRect = NSRect(
                x: bodyRect.minX + 1.1,
                y: bodyRect.minY + 1.0,
                width: fillWidth,
                height: bodyRect.height - 2.0
            )
            if fillRect.width > 0.8 {
                let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 1.7, yRadius: 1.7)
                fillColor.setFill()
                fillPath.fill()
            }

            outlineColor.setFill()
            capPath.fill()

            if reading.isCharging {
                let boltPath = NSBezierPath()
                let centerX = rect.midX - 0.2
                let centerY = rect.midY + 0.6
                boltPath.move(to: NSPoint(x: centerX - 2.2, y: centerY - 3.6))
                boltPath.line(to: NSPoint(x: centerX + 1.0, y: centerY - 3.6))
                boltPath.line(to: NSPoint(x: centerX + 1.0, y: centerY - 0.7))
                boltPath.line(to: NSPoint(x: centerX + 3.8, y: centerY - 0.7))
                boltPath.line(to: NSPoint(x: centerX - 0.6, y: centerY + 4.4))
                boltPath.line(to: NSPoint(x: centerX - 0.6, y: centerY + 0.9))
                boltPath.line(to: NSPoint(x: centerX - 2.9, y: centerY + 0.9))
                boltPath.close()
                NSColor.white.setFill()
                boltPath.fill()
            }

            return true
        }
        image.isTemplate = false
        image.size = NSSize(width: imageWidth, height: imageHeight)
        return image
    }
}

struct BatteryReading: Equatable {
    var percentage: Int = 0
    var isCharging = false
    var isFullyCharged = false
    var powerSource = "Unknown"
    var timeRemaining: String?
    var hasBattery = false
    var lastUpdated = Date()

    var statusText: String {
        if !hasBattery { return "No battery detected" }
        if isFullyCharged { return "Fully charged" }
        if isCharging { return "Charging" }
        return "Discharging"
    }

    var accessibilityDescription: String {
        guard hasBattery else { return statusText }
        let time = timeRemaining.map { ", \($0) remaining" } ?? ""
        return "Battery \(percentage) percent, \(statusText.lowercased())\(time)"
    }

    var hoverDescription: String {
        guard hasBattery else { return statusText }
        return "\(percentage)% - \(isCharging ? "Charging" : "Not charging")"
    }

    var symbolName: String {
        if !hasBattery { return "battery.0" }
        if isCharging { return "battery.100.bolt" }
        switch percentage {
        case 0..<10: return "battery.0percent"
        case 10..<35: return "battery.25percent"
        case 35..<65: return "battery.50percent"
        case 65..<90: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
    
    var displayColor: NSColor {
        switch percentage {
        case 0...20: return .systemRed
        case 21...55: return .systemOrange
        default: return .systemGreen
        }
    }
}

@MainActor
final class BatteryStore: ObservableObject {
    @Published private(set) var reading = BatteryReading()

    private var refreshTimer: Timer?

    init() {
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    func refresh() {
        reading = BatteryProvider.read()
    }
}

enum BatteryProvider {
    static func read() -> BatteryReading {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              let sourceRef = list.first,
              let description = IOPSGetPowerSourceDescription(blob, sourceRef)?.takeUnretainedValue() as? [String: Any]
        else {
            return BatteryReading(lastUpdated: Date())
        }

        let current = (description[kIOPSCurrentCapacityKey] as? NSNumber)?.intValue ?? 0
        let maximum = (description[kIOPSMaxCapacityKey] as? NSNumber)?.intValue ?? 100
        let percentage = maximum > 0 ? min(100, max(0, Int((Double(current) / Double(maximum) * 100).rounded()))) : 0
        let fullyCharged = (description[kIOPSIsChargedKey] as? NSNumber)?.boolValue ?? false
        let powerState = description[kIOPSPowerSourceStateKey] as? String ?? "Unknown"
        let chargingFlag = (description[kIOPSIsChargingKey] as? NSNumber)?.boolValue ?? false
        let charging = chargingFlag || (powerState == kIOPSACPowerValue && current < maximum && !fullyCharged)
        let time = timeRemaining(from: description)

        return BatteryReading(
            percentage: percentage,
            isCharging: charging,
            isFullyCharged: fullyCharged,
            powerSource: powerState == kIOPSACPowerValue ? "Power adapter" : "Battery",
            timeRemaining: time,
            hasBattery: true,
            lastUpdated: Date()
        )
    }

    private static func timeRemaining(from description: [String: Any]) -> String? {
        guard let minutes = description[kIOPSTimeToEmptyKey] as? Int, minutes >= 0 else { return nil }
        if Double(minutes) == kIOPSTimeRemainingUnlimited { return nil }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours > 0 { return "\(hours) hr \(remainingMinutes) min" }
        return "\(remainingMinutes) min"
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = BatteryStore()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var hoverWindow: NSWindow?
    private var hoverTimer: Timer?
    private var isHoveringStatusItem = false
    private var settingsWindowController: NSWindowController?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var preferencesObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "showPercentage": true,
            "showIcon": true,
            "menuBarTextColor": "black",
            "batteryIconStyle": BatteryIconStyle.default.rawValue,
            "percentageFontWeight": PercentageFontWeight.normal.rawValue,
            "lowBatteryThreshold": 20.0
        ])
        configureStatusItem()
        configurePopover()
        observeSleepAndWake()
        observePreferences()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hoverTimer?.invalidate()
        if let sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver) }
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        if let preferencesObserver { NotificationCenter.default.removeObserver(preferencesObserver) }
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.imagePosition = .imageLeading
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateHoverState() }
        }
        store.objectWillChange.sink { [weak self] in
            Task { @MainActor in self?.updateStatusItem() }
        }.store(in: &cancellables)
        updateStatusItem()
    }

    private func configurePopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 330, height: 300)
        popover.contentViewController = NSHostingController(
            rootView: BatteryPopoverView(store: store) { [weak self] in self?.showSettings() }
        )
    }

    private func observeSleepAndWake() {
        let center = NSWorkspace.shared.notificationCenter
        sleepObserver = center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.store.refresh() }
        }
        wakeObserver = center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.store.refresh() }
        }
    }

    private func observePreferences() {
        preferencesObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.updateStatusItem() }
        }
    }

    private var cancellables = Set<AnyCancellable>()

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        let reading = store.reading
        let defaults = UserDefaults.standard
        let showIcon = defaults.bool(forKey: "showIcon")
        let showPercentage = defaults.bool(forKey: "showPercentage")
        let menuBarTextColor = defaults.string(forKey: "menuBarTextColor") == "white" ? NSColor.white : NSColor.black
        let batteryIconStyle = BatteryIconStyle(rawValue: defaults.string(forKey: "batteryIconStyle") ?? "") ?? .default
        let percentageFontWeight = PercentageFontWeight(
            rawValue: defaults.string(forKey: "percentageFontWeight") ?? ""
        ) ?? .normal

        button.image = showIcon ? customBatteryImage(for: reading, size: 18.5, style: batteryIconStyle) : nil
        let title = showPercentage ? "\(reading.percentage)%" : ""
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: percentageFontWeight.font,
                .foregroundColor: menuBarTextColor
            ]
        )
        button.contentTintColor = reading.displayColor
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = nil
        button.setAccessibilityLabel(reading.accessibilityDescription)
        button.setAccessibilityValue("\(reading.percentage) percent")
    }

    private func updateHoverState() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)
        let isHovering = screenRect.contains(NSEvent.mouseLocation)

        if isHovering && !isHoveringStatusItem {
            isHoveringStatusItem = true
            showHoverWindow()
        } else if !isHovering && isHoveringStatusItem {
            isHoveringStatusItem = false
            hideHoverWindow()
        } else if isHovering && hoverWindow == nil {
            showHoverWindow()
        }
    }

    private func showHoverWindow() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }

        let label = NSTextField(labelWithString: store.reading.hoverDescription)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor
        label.alignment = .center
        label.sizeToFit()

        let horizontalPadding: CGFloat = 12
        let verticalPadding: CGFloat = 7
        let windowSize = NSSize(
            width: label.fittingSize.width + horizontalPadding * 2,
            height: label.fittingSize.height + verticalPadding * 2
        )
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false

        let contentView = NSView(frame: NSRect(origin: .zero, size: windowSize))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        contentView.layer?.cornerRadius = 6
        contentView.layer?.borderWidth = 1
        contentView.layer?.borderColor = NSColor.separatorColor.cgColor
        label.frame = NSRect(
            x: horizontalPadding,
            y: verticalPadding,
            width: windowSize.width - horizontalPadding * 2,
            height: windowSize.height - verticalPadding * 2
        )
        contentView.addSubview(label)
        panel.contentView = contentView

        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)
        let origin = NSPoint(
            x: screenRect.midX - windowSize.width / 2,
            y: screenRect.minY - windowSize.height - 8
        )
        panel.setFrameOrigin(origin)
        hoverWindow?.orderOut(nil)
        hoverWindow = panel
        panel.orderFrontRegardless()
    }

    private func hideHoverWindow() {
        hoverWindow?.orderOut(nil)
        hoverWindow = nil
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "Quit PowerPeek", action: #selector(quitApplication), keyEquivalent: "")
            menu.items.first?.target = self
            NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent ?? NSEvent(), for: button)
            return
        }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            store.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }

    private func showSettings() {
        if let settingsWindowController {
            settingsWindowController.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView()
        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "PowerPeek Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 420, height: 360))
        window.center()
        settingsWindowController = NSWindowController(window: window)
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct BatteryPopoverView: View {
    @ObservedObject var store: BatteryStore
    let openSettings: () -> Void

    var body: some View {
        let reading = store.reading
        let batteryIconStyle = BatteryIconStyle(
            rawValue: UserDefaults.standard.string(forKey: "batteryIconStyle") ?? ""
        ) ?? .default

        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                Group {
                    if batteryIconStyle == .default {
                        Image(systemName: reading.symbolName)
                            .symbolRenderingMode(reading.isCharging ? .palette : .hierarchical)
                            .font(.system(size: 65, weight: .bold))
                            .foregroundStyle(
                                Color(nsColor: reading.displayColor),
                                Color(nsColor: reading.isCharging ? .systemGreen : reading.displayColor)
                            )
                    } else {
                        Image(nsImage: customBatteryImage(for: reading, size: 70, style: .tahoe) ?? NSImage())
                            .resizable()
                            .scaledToFit()
                            .frame(width: 70, height: 70)
                    }
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(reading.percentage)%")
                        .font(.system(size: 39, weight: .bold, design: .rounded))
                    Text(reading.statusText)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 9) {
                DetailRow(label: "Power source", value: reading.powerSource)
                if let timeRemaining = reading.timeRemaining {
                    DetailRow(label: "Time remaining", value: timeRemaining)
                }
                DetailRow(label: "Updated", value: reading.lastUpdated.formatted(date: .omitted, time: .shortened))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(reading.accessibilityDescription)

            HStack {
                Button("Refresh") { store.refresh() }
                Spacer()
                Button("Settings") { openSettings() }
            }
            .buttonStyle(.bordered)
        }
        .padding(22)
        .frame(width: 330)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
    }
}

struct BlackSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.2))
                    .frame(height: 4)
                Capsule()
                    .fill(Color.black)
                    .frame(width: max(4, width * progress), height: 4)
                Circle()
                    .fill(Color.black)
                    .frame(width: 14, height: 14)
                    .offset(x: max(0, min(width - 14, width * progress - 7)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        value = value(at: gesture.location.x, width: width)
                    }
            )
        }
        .frame(height: 20)
        .accessibilityElement()
        .accessibilityLabel("Warn below")
        .accessibilityValue("\(Int(value)) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = min(value + step, range.upperBound)
            case .decrement:
                value = max(value - step, range.lowerBound)
            @unknown default:
                break
            }
        }
    }

    private func value(at location: CGFloat, width: CGFloat) -> Double {
        let normalized = min(max(Double(location / width), 0), 1)
        let rawValue = range.lowerBound + normalized * (range.upperBound - range.lowerBound)
        let steppedValue = ((rawValue - range.lowerBound) / step).rounded() * step + range.lowerBound
        return min(max(steppedValue, range.lowerBound), range.upperBound)
    }
}

struct SettingsView: View {
    @AppStorage("showPercentage") private var showPercentage = true
    @AppStorage("showIcon") private var showIcon = true
    @AppStorage("menuBarTextColor") private var menuBarTextColor = "black"
    @AppStorage("batteryIconStyle") private var batteryIconStyle = BatteryIconStyle.default.rawValue
    @AppStorage("percentageFontWeight") private var percentageFontWeight = PercentageFontWeight.normal.rawValue
    @AppStorage("lowBatteryThreshold") private var lowBatteryThreshold = 20.0
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        Form {
            Section("Menu bar") {
                Picker("Battery Icon", selection: $batteryIconStyle) {
                    ForEach(BatteryIconStyle.allCases) { style in
                        Text(style.label).tag(style.rawValue)
                    }
                }
                Toggle("Show battery icon", isOn: $showIcon)
                Toggle("Show percentage", isOn: $showPercentage)
                Picker("Battery text color", selection: $menuBarTextColor) {
                    Text("Black").tag("black")
                    Text("White").tag("white")
                }
                Picker("Text Weight", selection: $percentageFontWeight) {
                    ForEach(PercentageFontWeight.allCases) { weight in
                        Text(weight.label).tag(weight.rawValue)
                    }
                }
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { enabled in
                        setLaunchAtLogin(enabled)
                    }
            }

            Section("Low battery warning") {
                HStack {
                    Text("Warn below")
                    Spacer()
                    Text("\(Int(lowBatteryThreshold))%")
                        .monospacedDigit()
                }
                BlackSlider(value: $lowBatteryThreshold, range: 5...50, step: 5)
            }

            Section {
                Button("Quit PowerPeek") {
                    NSApplication.shared.terminate(nil)
                }
                .foregroundStyle(.red)
            }

            Section {
                Text("PowerPeek reads battery information locally and does not require network access.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420, height: 360)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
