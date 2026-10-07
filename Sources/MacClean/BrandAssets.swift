import AppKit

enum BrandAssets {
    static var icon:NSImage {
        // Packaged apps use standard bundle resources; `swift run` uses SwiftPM's bundle.
        let url=Bundle.main.url(forResource:"MacCleanIcon",withExtension:"png") ?? Bundle.module.url(forResource:"MacCleanIcon",withExtension:"png")
        return url.flatMap{NSImage(contentsOf:$0)} ?? NSImage(size:NSSize(width:32,height:32))
    }
}
