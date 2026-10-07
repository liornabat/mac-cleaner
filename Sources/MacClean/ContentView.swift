import SwiftUI
import MacCleanCore

struct ContentView:View {
    @EnvironmentObject var model:AppModel
    @Environment(\.colorScheme) private var colorScheme
    var body:some View {
        NavigationSplitView {
            VStack(alignment:.leading,spacing:12) {
                Label("MacClean",systemImage:"square.dashed.inset.filled").font(.title2.bold()).padding(.horizontal,14).padding(.top,20)
                Text("Personal workspace").font(.caption).foregroundStyle(.secondary).padding(.horizontal,14)
                List(AppSection.allCases,selection:$model.section) { section in Label(section.rawValue,systemImage:section.icon).tag(section) }
                VStack(alignment:.leading,spacing:5) {
                    Label(model.engine.ready ? "Mole \(model.engine.version ?? "")" : "Mole needs attention",systemImage:model.engine.ready ? "checkmark.circle" : "exclamationmark.circle")
                    Text("Installed engine + developer tools").foregroundStyle(.secondary)
                }.font(.caption).padding(16)
            }.navigationSplitViewColumnWidth(min:200,ideal:220,max:260)
        } detail: {
            VStack(spacing:0) {
                if model.busy { HStack { ProgressView().controlSize(.small);Text(model.progress);Spacer() }.font(.callout).padding(12).background(Color.blue.opacity(0.07)) }
                if let error=model.error { HStack(alignment:.top) { Image(systemName:"exclamationmark.triangle");Text(error).textSelection(.enabled);Spacer();Button("Dismiss"){model.error=nil} }.font(.callout).padding(12).background(Color.orange.opacity(0.12)) }
                Group {
                    switch model.section {
                    case .overview:OverviewView()
                    case .cleanup:FindingsView(group:.caches)
                    case .projects:FindingsView(group:.projects)
                    case .storage:StorageView()
                    case .tools:ToolsView()
                    case .engine:EngineView()
                    case .history:HistoryView()
                    case .settings:SettingsView()
                    }
                }.frame(maxWidth:.infinity,maxHeight:.infinity)
                if !model.selected.isEmpty {
                    Divider()
                    HStack {
                        VStack(alignment:.leading,spacing:4) { Text("\(model.selected.count) selected · \(formatBytes(model.selectionBytes))").fontWeight(.semibold);Text("Move to Trash; space is reclaimed when Trash is emptied.").font(.caption).foregroundStyle(.secondary) }
                        Spacer();Button("Clear selection"){model.selected.removeAll()};Button("Review selection"){model.acknowledgement=false;model.review=true}.buttonStyle(.borderedProminent).tint(Color(red:0.14,green:0.37,blue:0.80)).foregroundStyle(.white).disabled(model.busy)
                    }.padding(18)
                }
            }.background(Color(nsColor:.windowBackgroundColor))
        }.tint(colorScheme == .dark ? Color(red:0.55,green:0.70,blue:1.0) : Color(red:0.14,green:0.37,blue:0.80))
        .sheet(isPresented:$model.review) { CleanupReview().environmentObject(model) }
        .sheet(isPresented:$model.engineReview) { EngineReview().environmentObject(model) }
    }
}
struct PageHeading:View {
    var title:String;var subtitle:String
    var body:some View { VStack(alignment:.leading,spacing:8) { Text(title).font(.system(size:28,weight:.semibold));Text(subtitle).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) }.frame(maxWidth:.infinity,alignment:.leading) }
}
struct OverviewView:View {
    @EnvironmentObject var model:AppModel
    var body:some View {
        ScrollView { VStack(alignment:.leading,spacing:28) {
            HStack(alignment:.top) { PageHeading(title:"A little more room to work.",subtitle:"Inspect your tools and projects. Keep what matters.");Button("Scan my Mac",action:model.scan).buttonStyle(.borderedProminent).tint(Color(red:0.14,green:0.37,blue:0.80)).foregroundStyle(.white).disabled(model.busy) }
            VStack(alignment:.leading,spacing:15) {
                HStack { Label("Macintosh storage",systemImage:"internaldrive").fontWeight(.semibold);Spacer();Text("\(formatBytes(model.freeBytes)) available").foregroundStyle(.secondary) }
                if let total=model.totalBytes,let free=model.freeBytes,total>0 { ProgressView(value:Double(total-free),total:Double(total)).tint(.blue);Text("\(formatBytes(total-free)) used of \(formatBytes(total))").font(.caption).foregroundStyle(.secondary) }
            }.padding(22).background(.background,in:RoundedRectangle(cornerRadius:12))
            HStack { Text(model.scannedAt == nil ? "Start with a scan" : "Findings from your Mac").font(.title3.weight(.semibold));Spacer();if let time=model.scannedAt { Text(time,style:.time).font(.caption).foregroundStyle(.secondary) } }
            ForEach(FindingGroup.allCases,id:\.self) { group in
                let items=model.findings.filter{$0.group==group}
                Button { model.section=group == .caches ? .cleanup : group == .projects ? .projects : .storage } label: {
                    HStack(spacing:16) {
                        Image(systemName:group == .caches ? "sparkles" : group == .projects ? "folder" : "shippingbox").font(.title3).frame(width:35).foregroundStyle(.blue)
                        VStack(alignment:.leading,spacing:6) { Text(group.rawValue).fontWeight(.semibold);Text("\(items.count) findings · \(items.filter(\.canClean).count) ready for review").font(.caption).foregroundStyle(.secondary) }
                        Spacer();Text(model.scannedAt == nil ? "Not scanned" : items.isEmpty ? "No findings" : items.allSatisfy({$0.bytes == nil}) ? "Size not measured" : formatBytes(items.compactMap(\.bytes).reduce(0,+)) + (items.contains(where:{$0.bytes == nil}) ? " + unknown sizes" : "")).monospacedDigit();Image(systemName:"chevron.right").foregroundStyle(.secondary)
                    }.padding(.vertical,15).contentShape(Rectangle())
                }.buttonStyle(.plain)
                Divider()
            }
            Text("Inventory sizes are not guaranteed disk savings. Container storage and worktrees are inspection-only in this first build.").font(.callout).foregroundStyle(.secondary)
            ForEach(model.notices,id:\.self) { Text($0).font(.callout).foregroundStyle(.secondary) }
        }.padding(32) }
    }
}
struct FindingsView:View {
    @EnvironmentObject var model:AppModel
    var group:FindingGroup
    var rows:[Finding] { model.findings.filter { $0.group==group && (model.toolFilter=="All tools" || $0.tool==model.toolFilter) && (model.search.isEmpty || ($0.title+" "+$0.tool+" "+$0.path).localizedCaseInsensitiveContains(model.search)) } }
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            PageHeading(title:group.rawValue,subtitle:group == .caches ? "Select known developer caches. Review recreation costs before removal." : group == .projects ? "Inspect project artifacts and Git checkouts. Source changes stay protected." : "Current Docker and Podman connections. Persistent storage stays protected.")
            HStack { TextField("Search findings, tools or paths",text:$model.search).textFieldStyle(.roundedBorder);Picker("Tool",selection:$model.toolFilter){ Text("All tools").tag("All tools");ForEach(Array(Set(model.findings.filter{$0.group==group}.map(\.tool))).sorted(),id:\.self){Text($0).tag($0)} }.frame(width:180) }
            HSplitView {
                VStack(spacing:0) {
                    if rows.isEmpty { ContentUnavailableView("No findings",systemImage:"magnifyingglass",description:Text(model.scannedAt == nil ? "Run a scan from Overview to inspect your Mac." : "Change the filter or scan again.")) }
                    else { List(rows,selection:$model.inspected) { item in
                        HStack(alignment:.center,spacing:12) {
                            Toggle("Select \(item.title)",isOn:Binding(get:{model.selected.contains(item.id)},set:{if $0 {model.selected.insert(item.id)}else{model.selected.remove(item.id)}})).labelsHidden().toggleStyle(.checkbox).disabled(!item.canClean || model.busy)
                            VStack(alignment:.leading,spacing:6) { Text(item.title).fontWeight(.medium);Text(item.tool).font(.caption).foregroundStyle(.secondary);Text(item.canClean ? "Rebuildable · Trash" : "Inspection only").font(.caption).foregroundStyle(item.canClean ? .green : .secondary) }
                            Spacer();Text(formatBytes(item.bytes)).font(.callout).monospacedDigit()
                        }.padding(.vertical,6).tag(item.id)
                    }.listStyle(.inset) }
                }.frame(minWidth:330)
                ScrollView {
                    if let item=model.findings.first(where:{$0.id==model.inspected && $0.group==group}) ?? rows.first {
                        VStack(alignment:.leading,spacing:18) {
                            Text(item.title).font(.title3.weight(.semibold));Text(formatBytes(item.bytes)).font(.title2).monospacedDigit()
                            Text(item.consequence).font(.callout).textSelection(.enabled)
                            Text("Location").font(.caption).foregroundStyle(.secondary);Text(item.path).font(.system(.caption,design:.monospaced)).textSelection(.enabled)
                            if let blocked=item.blockedReason { Label(blocked,systemImage:"lock").font(.callout).foregroundStyle(.secondary) }
                            if item.canClean { Button(model.selected.contains(item.id) ? "Remove from selection" : "Add to selection") { if model.selected.contains(item.id){model.selected.remove(item.id)}else{model.selected.insert(item.id)} }.disabled(model.busy) }
                            if item.group != .containers { Button("Reveal in Finder"){model.reveal(item.path)} }
                            Button("Exclude from future scans"){model.exclude(item)}.disabled(model.busy)
                        }.frame(maxWidth:.infinity,alignment:.leading).padding(20)
                    }
                }.frame(minWidth:250,idealWidth:290,maxWidth:380)
            }
        }.padding(28).onAppear { model.toolFilter="All tools";model.search="" }
    }
}
struct CleanupReview:View {
    @EnvironmentObject var model:AppModel
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Review cleanup").font(.title2.bold());Text("\(model.selected.count) caches · \(formatBytes(model.selectionBytes))").foregroundStyle(.secondary)
            ScrollView { VStack(alignment:.leading,spacing:18) { ForEach(model.selectedFindings){item in VStack(alignment:.leading,spacing:7){Text(item.title).fontWeight(.semibold);Text(item.consequence).font(.callout);Text(item.path).font(.system(.caption,design:.monospaced)).foregroundStyle(.secondary);Divider()} } } }
            Text("These folders move to Finder’s Trash. Disk space is reclaimed only after you empty Trash. You can restore them before then. The app checks ownership and folder identity again before moving each cache.").font(.callout)
            Toggle("I reviewed these actions and their consequences",isOn:$model.acknowledgement)
            HStack { Spacer();Button("Keep reviewing"){model.review=false};Button("Move selected caches to Trash",action:model.executeCleanup).buttonStyle(.borderedProminent).tint(Color(red:0.14,green:0.37,blue:0.80)).foregroundStyle(.white).disabled(!model.acknowledgement || model.busy) }
        }.padding(28).frame(width:640,height:570)
    }
}
