import SwiftUI
import AppKit

/// Opaque semantic colors keep small text readable in either app appearance.
enum AppPalette {
    static let secondaryText=adaptive("SecondaryText",light:NSColor(white:0.38,alpha:1),dark:NSColor(white:0.72,alpha:1))
    static let successText=adaptive("SuccessText",light:NSColor(red:0.15,green:0.40,blue:0.27,alpha:1),dark:NSColor(red:0.62,green:0.86,blue:0.67,alpha:1))
    static let warningText=adaptive("WarningText",light:NSColor(red:0.53,green:0.34,blue:0.05,alpha:1),dark:NSColor(red:0.94,green:0.76,blue:0.52,alpha:1))
    private static func adaptive(_ name:String,light:NSColor,dark:NSColor)->Color {
        Color(nsColor:NSColor(name:NSColor.Name("MacClean"+name),dynamicProvider:{ appearance in
            appearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? dark : light
        }))
    }
}
