import SwiftUI
import AppKit

@main struct MacCleanApp:App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model=AppModel()
    var body:some Scene {
        WindowGroup("MacClean") { ContentView().environmentObject(model).frame(minWidth:960,minHeight:650).task { if model.engine.path == nil { model.detect() } } }
        .defaultSize(width:1220,height:820)
        .commands {
            CommandGroup(replacing:.newItem) {}
            CommandMenu("Scan") { Button("Scan my Mac",action:model.scan).keyboardShortcut("r",modifiers:.command).disabled(model.busy) }
        }
    }
}
final class AppDelegate:NSObject,NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification:Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.applicationIconImage=BrandAssets.icon
        NSApp.activate(ignoringOtherApps:true)
    }
}
