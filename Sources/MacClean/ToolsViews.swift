import SwiftUI
import AppKit
import MacCleanCore

struct EngineView:View {
    @EnvironmentObject var model:AppModel
    var body:some View {
        ScrollView { VStack(alignment:.leading,spacing:24) {
            PageHeading(title:"Mole engine",subtitle:"Detect and maintain the installed engine without adding duplicate copies.")
            GroupBox {
                VStack(alignment:.leading,spacing:15) {
                    Label(model.engine.ready ? "Mole detected" : model.engine.path == nil ? "Mole not found" : "Mole could not be verified",systemImage:model.engine.ready ? "checkmark.circle" : "exclamationmark.circle").font(.title3.weight(.semibold))
                    LabeledContent("Installed version",value:model.engine.version ?? "Unknown")
                    LabeledContent("Installation source",value:model.engine.homebrew ? "Homebrew" : model.engine.path == nil ? "Not detected" : "Custom or script installation")
                    LabeledContent("Executable") { Text(model.engine.path ?? "Not found").font(.system(.caption,design:.monospaced)).textSelection(.enabled) }
                    LabeledContent("Update status",value:model.updateMessage)
                    if let error=model.engine.error { Text(error).foregroundStyle(.orange).textSelection(.enabled) }
                    HStack {
                        Button("Detect again",action:model.detect);Button("Choose executable",action:model.chooseEngine)
                        Button("Check for updates",action:model.checkUpdates)
                        if model.engine.path == nil || model.engine.homebrew { Button(model.engine.path == nil ? "Review installation" : "Review upgrade"){model.engineReview=true}.buttonStyle(.borderedProminent).tint(Color(red:0.14,green:0.37,blue:0.80)).foregroundStyle(.white) }
                    }.disabled(model.busy)
                }.padding(12).frame(maxWidth:.infinity,alignment:.leading)
            }
            Text("Update checks use Homebrew’s published Mole version. Homebrew installations update through Homebrew. Custom installations use their original installer.").font(.callout).foregroundStyle(.secondary)
            Text("Installation and upgrades require review. The app waits for other operations to finish and detects Mole again afterward.").font(.callout).foregroundStyle(.secondary)
            Link("Mole installation instructions",destination:URL(string:"https://github.com/tw93/Mole#quick-start")!)
        }.padding(32) }
    }
}
struct EngineReview:View {
    @EnvironmentObject var model:AppModel
    var body:some View {
        VStack(alignment:.leading,spacing:20) {
            Text(model.engine.path == nil ? "Install Mole" : "Upgrade Mole").font(.title2.bold())
            Text("This changes the Mole package on your Mac using your existing Homebrew installation.")
            Text(model.engine.path == nil ? "brew install mole" : "brew upgrade mole").font(.system(.body,design:.monospaced)).textSelection(.enabled)
            Text("Homebrew installs its current supported release. It can also update required dependencies. The app does not collect your administrator password.").foregroundStyle(.secondary)
            Text("If Homebrew is missing or requires interactive permission, the operation will report the problem and offer manual setup. It will not install Homebrew automatically.").font(.callout).foregroundStyle(.secondary)
            HStack { Spacer();Button("Cancel"){model.engineReview=false};Button(model.engine.path == nil ? "Install Mole" : "Upgrade Mole",action:model.executeEngineChange).buttonStyle(.borderedProminent).tint(Color(red:0.14,green:0.37,blue:0.80)).foregroundStyle(.white).disabled(model.busy) }
        }.padding(28).frame(width:580)
    }
}
struct StorageView:View {
    @EnvironmentObject var model:AppModel
    @State private var tab="Folders"
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            Picker("Storage view",selection:$tab){Text("Folders").tag("Folders");Text("Containers").tag("Containers")}.pickerStyle(.segmented).frame(width:280).padding(.horizontal,28).padding(.top,24)
            if tab == "Containers" { FindingsView(group:.containers) }
            else {
                VStack(alignment:.leading,spacing:22) {
                    HStack { PageHeading(title:"Disk explorer",subtitle:"Mole measures the folder you choose. Browse without deleting files.");Button("Choose folder",action:model.chooseAnalysisFolder).disabled(model.busy || !model.engine.ready) }
                    if let analysis=model.analysis {
                        HStack { Text(analysis.path).font(.system(.callout,design:.monospaced)).textSelection(.enabled);Spacer();Button("Parent folder"){model.analyze(URL(fileURLWithPath:analysis.path).deletingLastPathComponent().path)}.disabled(model.busy || analysis.path=="/") }
                        List(analysis.entries.sorted{$0.size>$1.size}) { entry in
                            HStack { Image(systemName:entry.is_dir ? "folder" : "doc").foregroundStyle(.secondary);Text(entry.name);Spacer();Text(formatBytes(entry.size)).monospacedDigit();Button("Reveal"){model.reveal(entry.path)};if entry.is_dir { Button("Open"){model.analyze(entry.path)}.disabled(model.busy) } }.padding(.vertical,8)
                        }.listStyle(.inset)
                    } else { ContentUnavailableView("Choose a folder to inspect",systemImage:"internaldrive",description:Text(model.engine.ready ? "Folder analysis uses your installed Mole engine." : "Install or verify Mole to enable folder analysis.")) }
                }.padding(28)
            }
        }
    }
}
struct ToolsView:View {
    @EnvironmentObject var model:AppModel
    @State private var tab="System status"
    var body:some View {
        VStack(alignment:.leading,spacing:22) {
            PageHeading(title:"Tools",subtitle:"Real system information and a read-only Mole cleanup report.")
            Picker("Tool",selection:$tab){Text("System status").tag("System status");Text("Mole cleanup preview").tag("Mole cleanup preview")}.pickerStyle(.segmented).frame(width:360)
            if tab=="System status" {
                Button("Refresh snapshot",action:model.refreshStatus).disabled(model.busy || !model.engine.ready)
                if let s=model.snapshot {
                    Grid(alignment:.leading,horizontalSpacing:45,verticalSpacing:22) {
                        GridRow { metric("Processor use",String(format:"%.1f%%",s.cpu.usage));metric("Memory used",formatBytes(s.memory.used)) }
                        GridRow { metric("Memory total",formatBytes(s.memory.total));metric("Uptime",s.uptime) }
                    }.padding(.vertical,20)
                    Text("Snapshot from Mole. Refresh to collect current measurements.").foregroundStyle(.secondary)
                } else { ContentUnavailableView("No system snapshot yet",systemImage:"waveform.path.ecg",description:Text("Refresh to collect measurements from Mole.")) }
            } else {
                Button("Run read-only preview",action:model.previewMole).disabled(model.busy || !model.engine.ready)
                Text("Mole 1.56 does not support arbitrary selected-file cleanup. This report never runs its destructive clean command. Use developer cache findings for reviewed removal.").font(.callout).foregroundStyle(.secondary)
                ScrollView { Text(model.moleReport.isEmpty ? "The report appears here after the preview finishes." : model.moleReport).font(.system(.callout,design:.monospaced)).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading).padding(15) }.background(.background,in:RoundedRectangle(cornerRadius:8))
            }
            Spacer(minLength:0)
        }.padding(32)
    }
    func metric(_ name:String,_ value:String)->some View { VStack(alignment:.leading,spacing:10){Text(name).foregroundStyle(.secondary);Text(value).font(.title2.weight(.semibold)).monospacedDigit()}.frame(minWidth:220,alignment:.leading) }
}
struct HistoryView:View {
    @EnvironmentObject var model:AppModel
    var body:some View {
        VStack(alignment:.leading,spacing:20) {
            PageHeading(title:"Operation history",subtitle:"Every result is recorded locally, including skipped and failed actions.")
            if model.operations.isEmpty { ContentUnavailableView("No operations yet",systemImage:"clock",description:Text("Reviewed cache removals and engine changes appear here.")) }
            else { List(model.operations) { operation in VStack(alignment:.leading,spacing:8){HStack{Text(operation.title).fontWeight(.semibold);Spacer();Text(operation.outcome).foregroundStyle(operation.outcome=="Skipped" || operation.outcome=="Failed" ? .orange : .green)};Text(operation.date,style:.date).font(.caption).foregroundStyle(.secondary);Text(operation.detail).font(.callout).textSelection(.enabled)}.padding(.vertical,10) }.listStyle(.inset) }
        }.padding(28)
    }
}
struct SettingsView:View {
    @EnvironmentObject var model:AppModel
    var body:some View {
        ScrollView { VStack(alignment:.leading,spacing:24) {
            PageHeading(title:"Settings & exclusions",subtitle:"Choose project roots and keep specific findings out of future scans.")
            HStack { Text("Project scan roots").font(.title3.weight(.semibold));Spacer();Button("Add folder",action:model.addRoot).disabled(model.busy) }
            Text("Discovery looks up to three directory levels for repositories, with a limit of 60 per root. Only the current Docker and Podman connections are inspected.").font(.callout).foregroundStyle(.secondary)
            ForEach(model.roots,id:\.self) { root in HStack { Text(root).font(.system(.callout,design:.monospaced)).textSelection(.enabled);Spacer();Button("Remove"){model.roots.removeAll{$0==root};model.persist()}.disabled(model.busy) };Divider() }
            Text("Excluded paths").font(.title3.weight(.semibold))
            if model.exclusions.isEmpty { Text("No exclusions yet. Exclude a finding from its details panel.").foregroundStyle(.secondary) }
            ForEach(Array(model.exclusions).sorted(),id:\.self) { path in HStack { Text(path).font(.system(.callout,design:.monospaced)).textSelection(.enabled);Spacer();Button("Restore"){model.exclusions.remove(path);model.persist()}.disabled(model.busy) };Divider() }
            Text("Permissions").font(.title3.weight(.semibold))
            Text("The app uses your current permissions. Unreadable locations are reported rather than counted as empty. Full Disk Access can expand Mole’s inspection scope.").font(.callout).foregroundStyle(.secondary)
            Button("Open Full Disk Access settings") { NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!) }
            Text("Privacy").font(.title3.weight(.semibold))
            Text("Settings and history stay on this Mac. Network access is used for explicit update checks and package-manager operations. Scans do not upload file information.").font(.callout).foregroundStyle(.secondary)
        }.padding(32) }
    }
}
