import SwiftUI
import MacCleanCore

struct ContentView:View {
    @EnvironmentObject var model:AppModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var sidebarVisible=true
    var body:some View {
        GeometryReader { geometry in
            workspace.frame(width:geometry.size.width,height:geometry.size.height)
        }
        .sheet(isPresented:$model.review) { CleanupReview().environmentObject(model) }
        .sheet(isPresented:$model.engineReview) { EngineReview().environmentObject(model) }
        .preferredColorScheme(model.appearance == "Light" ? .light : model.appearance == "Dark" ? .dark : nil)
        .toolbar { ToolbarItem(placement:.navigation) { Button { sidebarVisible.toggle() } label: { Image(systemName:"sidebar.left") }.help(sidebarVisible ? "Hide sidebar" : "Show sidebar").accessibilityLabel(sidebarVisible ? "Hide sidebar" : "Show sidebar") } }
    }
    private var workspace:some View {
        HStack(spacing:0) {
          if sidebarVisible {
            VStack(alignment:.leading,spacing:12) {
                HStack(spacing:8) { Image(nsImage:BrandAssets.icon).resizable().frame(width:32,height:32).accessibilityHidden(true);Text("MacClean").font(.title2.bold()) }.padding(.horizontal,14).padding(.top,20)
                Text("Personal workspace").font(.caption).foregroundStyle(AppPalette.secondaryText).padding(.horizontal,14)
                List(AppSection.allCases,selection:$model.section) { section in Label(section.rawValue,systemImage:section.icon).tag(section) }.listStyle(.sidebar).scrollContentBackground(.hidden)
                VStack(alignment:.leading,spacing:5) {
                    Label(model.engine.ready ? "Mole \(model.engine.version ?? "")" : "Mole needs attention",systemImage:model.engine.ready ? "checkmark.circle" : "exclamationmark.circle")
                    Text("Installed engine + developer tools").foregroundStyle(AppPalette.secondaryText)
                }.font(.caption).padding(16)
            }.frame(width:220).frame(maxHeight:.infinity,alignment:.top).background(Color(nsColor:.controlBackgroundColor)).accessibilityElement(children:.contain)
            Divider()
          }
            VStack(spacing:0) {
                if model.busy { HStack { ProgressView().controlSize(.small);Text(model.progress).lineLimit(2).truncationMode(.middle);Spacer() }.font(.callout).padding(12).background(Color.blue.opacity(0.07)) }
                if let error=model.error { ErrorBanner(message:error){model.error=nil} }
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
                }.frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
                if !model.selected.isEmpty {
                    Divider()
                    HStack {
                        VStack(alignment:.leading,spacing:4) { Text("\(model.selected.count) selected · \(formatBytes(model.selectionBytes))").fontWeight(.semibold);Text("Move to Trash; space is reclaimed when Trash is emptied.").font(.caption).foregroundStyle(AppPalette.secondaryText) }
                        Spacer();Button("Clear selection"){model.selected.removeAll()};Button("Review selection"){model.acknowledgement=false;model.review=true}.buttonStyle(.borderedProminent).tint(Color(red:0.14,green:0.37,blue:0.80)).foregroundStyle(.white).disabled(model.busy)
                    }.padding(18)
                }
            }.frame(maxWidth:.infinity,maxHeight:.infinity).background(Color(nsColor:.windowBackgroundColor)).accessibilityElement(children:.contain)
        }
        .tint(colorScheme == .dark ? Color(red:0.55,green:0.70,blue:1.0) : Color(red:0.14,green:0.37,blue:0.80))
    }
}
struct ErrorBanner:View {
    let message:String
    let dismiss:()->Void
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack(alignment:.top) { Image(systemName:"exclamationmark.triangle");Text(message).lineLimit(2);Spacer();Button("Dismiss",action:dismiss) }
            DisclosureGroup("Show diagnostic details") { ScrollView { Text(message).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }.frame(height:100) }
        }.font(.callout).padding(12).background(Color.orange.opacity(0.12))
    }
}
struct PageHeading:View {
    var title:String;var subtitle:String
    var body:some View { VStack(alignment:.leading,spacing:8) { Text(title).font(.system(size:28,weight:.semibold));Text(subtitle).foregroundStyle(AppPalette.secondaryText).fixedSize(horizontal:false,vertical:true) }.frame(maxWidth:.infinity,alignment:.leading) }
}
struct OverviewView:View {
    @EnvironmentObject var model:AppModel
    var body:some View {
        ScrollView { VStack(alignment:.leading,spacing:28) {
            HStack(alignment:.top) { PageHeading(title:"A little more room to work.",subtitle:"Inspect your tools and projects. Keep what matters.");Button("Scan my Mac",action:model.scan).buttonStyle(.borderedProminent).tint(Color(red:0.14,green:0.37,blue:0.80)).foregroundStyle(.white).disabled(model.busy) }
            VStack(alignment:.leading,spacing:15) {
                HStack { Label("Macintosh storage",systemImage:"internaldrive").fontWeight(.semibold);Spacer();Text("\(formatBytes(model.freeBytes)) available").foregroundStyle(AppPalette.secondaryText) }
                if let total=model.totalBytes,let free=model.freeBytes,total>0 { ProgressView(value:Double(total-free),total:Double(total)).tint(.blue);Text("\(formatBytes(total-free)) used of \(formatBytes(total))").font(.caption).foregroundStyle(AppPalette.secondaryText) }
            }.padding(22).background(.background,in:RoundedRectangle(cornerRadius:12))
            HStack { Text(model.scannedAt == nil ? "Start with a scan" : "Findings from your Mac").font(.title3.weight(.semibold));Spacer();if let time=model.scannedAt { Text(time,style:.time).font(.caption).foregroundStyle(AppPalette.secondaryText) } }
            ForEach(FindingGroup.allCases,id:\.self) { group in
                let items=model.findings.filter{$0.group==group}
                Button { model.show(group) } label: {
                    HStack(spacing:16) {
                        Image(systemName:group == .caches ? "sparkles" : group == .projects ? "folder" : "shippingbox").font(.title3).frame(width:35).foregroundStyle(.blue)
                        VStack(alignment:.leading,spacing:6) { Text(group.rawValue).fontWeight(.semibold);Text("\(items.count) findings · \(items.filter(\.canClean).count) ready for review").font(.caption).foregroundStyle(AppPalette.secondaryText) }
                        Spacer();Text(model.scannedAt == nil ? "Not scanned" : items.isEmpty ? "No findings" : items.allSatisfy({$0.bytes == nil}) ? "Size not measured" : formatBytes(items.compactMap(\.bytes).reduce(0,+)) + (items.contains(where:{$0.bytes == nil}) ? " + unknown sizes" : "")).monospacedDigit();Image(systemName:"chevron.right").foregroundStyle(AppPalette.secondaryText)
                    }.padding(.vertical,15).contentShape(Rectangle())
                }.buttonStyle(.plain)
                Divider()
            }
            Text("Inventory sizes are not guaranteed disk savings. Container storage and worktrees are inspection-only in this first build.").font(.callout).foregroundStyle(AppPalette.secondaryText)
            ForEach(model.notices,id:\.self) { Text($0).font(.callout).foregroundStyle(AppPalette.secondaryText) }
        }.padding(32) }
    }
}
struct FindingsView:View {
    @EnvironmentObject var model:AppModel
    var group:FindingGroup
    @State private var search=""
    @State private var toolFilter="All tools"
    var rows:[Finding] { model.findings.filter { $0.group==group && (toolFilter=="All tools" || $0.tool==toolFilter) && (search.isEmpty || ($0.title+" "+$0.tool+" "+$0.path).localizedCaseInsensitiveContains(search)) } }
    var inspected:Finding? { rows.first(where:{$0.id==model.inspected}) ?? rows.first }
    var emptyTitle:String { model.scannedAt == nil ? "Scan to discover findings" : search.isEmpty && toolFilter=="All tools" ? "No findings in this category" : "No matching findings" }
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            HStack(alignment:.top) {
                PageHeading(title:group.rawValue,subtitle:group == .caches ? "Select known developer caches. Review recreation costs before removal." : group == .projects ? "Inspect project artifacts and Git checkouts. Source changes stay protected." : "Current Docker and Podman connections. Persistent storage stays protected.")
                Button(model.scannedAt == nil ? "Scan my Mac" : "Scan again",action:model.scan).disabled(model.busy)
            }.fixedSize(horizontal:false,vertical:true)
            HStack { TextField("",text:$search).textFieldStyle(.roundedBorder).overlay(alignment:.leading) { if search.isEmpty { Text("Search findings, tools or paths").foregroundStyle(AppPalette.secondaryText).padding(.horizontal,8).allowsHitTesting(false).accessibilityHidden(true) } }.accessibilityLabel("Search \(group.rawValue)");Picker("Tool",selection:$toolFilter){ Text("All tools").tag("All tools");ForEach(Array(Set(model.findings.filter{$0.group==group}.map(\.tool))).sorted(),id:\.self){Text($0).tag($0)} }.frame(width:180) }
            if !model.notices.isEmpty {
                DisclosureGroup("Scan notices (\(model.notices.count))") { ScrollView { VStack(alignment:.leading,spacing:8) { ForEach(model.notices,id:\.self){Text($0).font(.callout).textSelection(.enabled)} }.frame(maxWidth:.infinity,alignment:.leading) }.frame(maxHeight:100) }
            }
            // A SwiftUI stack keeps the empty list and inspector inside the window's bounds.
            HStack(alignment:.top,spacing:0) {
                VStack(spacing:0) {
                    if rows.isEmpty {
                        ContentUnavailableView {
                            Label(emptyTitle,systemImage:model.scannedAt == nil ? "sparkles" : "magnifyingglass")
                        } description: {
                            Text(model.scannedAt == nil ? "Inspect caches, containers and projects before choosing an action." : "Review scan notices for unavailable tools or partial results.").foregroundColor(AppPalette.secondaryText)
                        } actions: {
                            if !search.isEmpty || toolFilter != "All tools" { Button("Clear filters"){search="";toolFilter="All tools"} }
                        }.frame(maxWidth:.infinity,maxHeight:.infinity)
                    }
                    else { List(rows,selection:$model.inspected) { item in
                        HStack(alignment:.center,spacing:12) {
                            Toggle("Select \(item.title)",isOn:Binding(get:{model.selected.contains(item.id)},set:{if $0 {model.selected.insert(item.id)}else{model.selected.remove(item.id)}})).labelsHidden().toggleStyle(.checkbox).disabled(!item.canClean || model.busy)
                            VStack(alignment:.leading,spacing:6) { Text(item.title).fontWeight(.medium);Text(item.tool).font(.caption).foregroundStyle(AppPalette.secondaryText);Text(item.canClean ? "Rebuildable · Trash" : "Inspection only").font(.caption).foregroundStyle(item.canClean ? AppPalette.successText : AppPalette.secondaryText) }
                            Spacer();Text(formatBytes(item.bytes)).font(.callout).monospacedDigit()
                        }.padding(.vertical,6).tag(item.id)
                    }.listStyle(.inset) }
                }.frame(minWidth:330,maxWidth:.infinity,maxHeight:.infinity)
                Divider()
                ScrollView {
                    if let item=inspected {
                        VStack(alignment:.leading,spacing:18) {
                            Text(item.title).font(.title3.weight(.semibold));Text(formatBytes(item.bytes)).font(.title2).monospacedDigit()
                            Text(item.consequence).font(.callout).textSelection(.enabled)
                            if let report=item.engineReport { ContainerReportView(report:report) }
                            Text("Location").font(.caption).foregroundStyle(AppPalette.secondaryText);Text(item.path).font(.system(.caption,design:.monospaced)).textSelection(.enabled).fixedSize(horizontal:false,vertical:true)
                            if let blocked=item.blockedReason { Label(blocked,systemImage:"lock").font(.callout).foregroundStyle(AppPalette.secondaryText) }
                            if item.canClean { Button(model.selected.contains(item.id) ? "Remove from selection" : "Add to selection") { if model.selected.contains(item.id){model.selected.remove(item.id)}else{model.selected.insert(item.id)} }.disabled(model.busy) }
                            if item.group != .containers { Button("Reveal in Finder"){model.reveal(item.path)} }
                            Button("Exclude from future scans"){model.exclude(item)}.disabled(model.busy)
                        }.frame(maxWidth:.infinity,alignment:.leading).padding(20)
                    } else { Text("Finding details appear here.").foregroundStyle(AppPalette.secondaryText).frame(maxWidth:.infinity,alignment:.leading).padding(20) }
                }.frame(width:280).frame(maxHeight:.infinity)
            }.frame(maxWidth:.infinity,maxHeight:.infinity)
        }.padding(28).onAppear(perform:syncInspection)
        .onChange(of:rows.map(\.id)) { _,_ in syncInspection() }
        .onChange(of:group) { _,_ in toolFilter="All tools";search="" }
    }
    private func syncInspection() { if !rows.contains(where:{$0.id==model.inspected}) { model.inspected=rows.first?.id } }
}
struct CleanupReview:View {
    @EnvironmentObject var model:AppModel
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Review cleanup").font(.title2.bold());Text("Selected caches: \(model.selectedFindings.count) · \(formatBytes(model.selectionBytes))").foregroundStyle(AppPalette.secondaryText)
            ScrollView { VStack(alignment:.leading,spacing:18) { ForEach(model.selectedFindings){item in VStack(alignment:.leading,spacing:7){Text(item.title).fontWeight(.semibold);Text(item.consequence).font(.callout);Text(item.path).font(.system(.caption,design:.monospaced)).foregroundStyle(AppPalette.secondaryText);Divider()} } } }
            Text("These folders move to Finder’s Trash. Disk space is reclaimed only after you empty Trash. You can restore them before then. The app checks ownership and folder identity again before moving each cache.").font(.callout)
            Toggle("I reviewed these actions and their consequences",isOn:$model.acknowledgement)
            HStack { Spacer();Button("Keep reviewing"){model.review=false}.keyboardShortcut(.cancelAction);Button("Move selected caches to Trash",action:model.executeCleanup).buttonStyle(.borderedProminent).tint(Color(red:0.14,green:0.37,blue:0.80)).foregroundStyle(.white).disabled(!model.acknowledgement || model.busy || model.selectedFindings.isEmpty) }
        }.padding(28).frame(width:640,height:570)
    }
}
