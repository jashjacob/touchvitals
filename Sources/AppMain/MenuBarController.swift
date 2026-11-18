import AppKit

/// A small menu bar status item — the one visible, discoverable control surface for an otherwise
/// invisible accessory app: lets the user see it's running, toggle the sparkline graphs, see
/// About info, and quit. Deliberately far smaller than TokenBar's multi-pane Settings window
/// (General/Touch Bar/Sources/Insights/About) — TouchVitals has one real preference right now, so
/// a single menu covers it without the overhead of a settings window nobody would use yet.
@MainActor
public final class MenuBarController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    public override init() {
        super.init()
        if let button = item.button {
            let icon = NSImage(systemSymbolName: "gauge.with.dots.needle.67percent", accessibilityDescription: AppInfo.name)
            icon?.isTemplate = true
            button.image = icon
        }
        item.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let graphs = NSMenuItem(title: "Show Graphs", action: #selector(toggleGraphs(_:)), keyEquivalent: "")
        graphs.target = self
        graphs.state = GraphsPreference.isEnabled ? .on : .off
        menu.addItem(graphs)

        let restartHint = NSMenuItem(title: "Takes effect next launch", action: nil, keyEquivalent: "")
        restartHint.isEnabled = false
        menu.addItem(restartHint)

        menu.addItem(.separator())

        let about = NSMenuItem(title: "About \(AppInfo.name)", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "Quit \(AppInfo.name)", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc private func toggleGraphs(_ sender: NSMenuItem) {
        GraphsPreference.isEnabled.toggle()
        sender.state = GraphsPreference.isEnabled ? .on : .off
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: AppInfo.name,
            .applicationVersion: AppInfo.version,
            .credits: NSAttributedString(
                string: "\(AppInfo.credit)\n\(AppInfo.repositoryURL)",
                attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
            ),
        ])
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
