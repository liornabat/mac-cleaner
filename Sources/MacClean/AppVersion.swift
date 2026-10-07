import Foundation

struct AppVersion {
    struct Metadata:Decodable {
        let version:String
        let build:Int
    }
    static let current=load()
    let version:String
    let build:String
    var display:String { "Version \(version) (build \(build))" }

    static func load(bundle:Bundle = .main,resourceBundle:Bundle? = nil)->Self {
        if let version=bundle.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String,
           let build=bundle.object(forInfoDictionaryKey:"CFBundleVersion") as? String {
            return Self(version:version,build:build)
        }
        let url=bundle.url(forResource:"AppVersion",withExtension:"json") ?? (resourceBundle ?? Bundle.module).url(forResource:"AppVersion",withExtension:"json")
        if let url,let data=try? Data(contentsOf:url),let metadata=try? JSONDecoder().decode(Metadata.self,from:data) {
            return Self(version:metadata.version,build:String(metadata.build))
        }
        return Self(version:"Unknown",build:"Unknown")
    }
}
