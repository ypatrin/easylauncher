import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
   let icon = NSImage(contentsOf: iconURL) {
    app.applicationIconImage = icon
}

app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
