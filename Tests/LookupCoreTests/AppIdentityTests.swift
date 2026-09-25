import Foundation
import Testing

@Test
func appUsesInstaLingoPermissionIdentity() throws {
    let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let infoPlist = repositoryRoot.appending(path: "App/Info.plist")
    let data = try Data(contentsOf: infoPlist)
    let plist = try #require(
        PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    )

    #expect(plist["CFBundleIdentifier"] as? String == "com.k2tam.InstaLingo")
}
