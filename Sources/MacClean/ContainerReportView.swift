import SwiftUI
import Foundation

struct ContainerReportRow:Identifiable {
    var id:Int
    var type:String
    var count:String
    var active:String
    var size:String
    var reclaimable:String
    static func parse(_ report:String)->[Self] {
        var objects=[[String:Any]]()
        if let json=try? JSONSerialization.jsonObject(with:Data(report.utf8)) {
            if let rows=json as? [[String:Any]] { objects=rows }
            else if let row=json as? [String:Any] { objects=[row] }
        } else {
            objects=report.split(separator:"\n").compactMap { (try? JSONSerialization.jsonObject(with:Data($0.utf8))) as? [String:Any] }
        }
        return objects.enumerated().compactMap { index,object in
            guard let type=object["Type"] as? String else {return nil}
            func value(_ key:String)->String { object[key].map{String(describing:$0)} ?? "Unknown" }
            return Self(id:index,type:type,count:value("TotalCount"),active:value("Active"),size:value("Size"),reclaimable:value("Reclaimable"))
        }
    }
}
struct ContainerReportView:View {
    let report:String
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            ForEach(ContainerReportRow.parse(report)) { row in
                VStack(alignment:.leading,spacing:6) {
                    Text(row.type).fontWeight(.semibold)
                    LabeledContent("Items",value:row.count)
                    LabeledContent("In use",value:row.active)
                    LabeledContent("Reported size",value:row.size)
                    LabeledContent("Reclaimable",value:row.reclaimable)
                }.font(.caption)
            }
            Text("Engine figures include shared or virtual storage. They are not guaranteed disk savings.").font(.caption).foregroundStyle(AppPalette.secondaryText)
            DisclosureGroup("Raw engine report") { Text(report).font(.system(.caption,design:.monospaced)).textSelection(.enabled).fixedSize(horizontal:false,vertical:true) }
        }
    }
}
