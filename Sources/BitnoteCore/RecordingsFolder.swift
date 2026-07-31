import Foundation

public func recordingsFolderName(forBundleID bundleID: String?) -> String {
    switch bundleID {
    case "com.bitnote.app.dev":
        return "Bitnote-dev"
    default:
        return "Bitnote"
    }
}
