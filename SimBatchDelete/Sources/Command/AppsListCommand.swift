//
//  AppsListCommand.swift
//

import Cocoa

struct AppInfo {

    let id: UUID
    let image: NSImage?
    let title: String
}

private struct AppInfoPlist: Decodable {

    private enum CodingKeys: String, CodingKey {

        case name = "CFBundleName"
        case version = "CFBundleShortVersionString"
        case buildNumber = "CFBundleVersion"
        case minSystemVersion = "MinimumOSVersion"
        case supportedDevices = "UIDeviceFamily"
        case icons = "CFBundleIcons"
    }

    enum DeviceFamily: Int, Decodable {

        case unknown
        case iphone
        case ipad
    }

    struct Icon: Decodable {

        private enum CodingKeys: String, CodingKey {

            case primary = "CFBundlePrimaryIcon"
        }

        // The primary icon for the Home screen and Settings app among others.
        let primary: PrimaryIcon
    }

    struct PrimaryIcon: Decodable {

        private enum CodingKeys: String, CodingKey {

            case iconName = "CFBundleIconName"
            case iconFiles = "CFBundleIconFiles"
        }

        // The name of the asset, from the bundle’s Asset Catalog, that represents the app icon
        let iconName: String
        // Each string in the array contains the name of an icon file.
        let iconFiles: [String] = []
    }

    let name: String
    let version: String
    let buildNumber: String
    let minSystemVersion: String
    let supportedDevices: [DeviceFamily]
    let icons: Icon?
}

struct AppsListCommand: Command {

    private static let devicePath = "Developer/CoreSimulator/Devices"
    private static let appsListPath = "data/Containers/Bundle/Application"
    private static let appInfoPlistFileName = ".com.apple.mobile_container_manager.metadata.plist"

    private let deviceId: UUID

    init(deviceId: UUID) {
        self.deviceId = deviceId
    }

    func run(then completion: @escaping (Result<[AppInfo], Error>) -> Void) {

        let appUrls: [URL]
        do {
            appUrls = try self.fetchBundleIds()
        }
        catch {
            completion(.failure(error))
            return
        }

        let appInfo: [AppInfo] = appUrls.compactMap { appUrl in
            let result = self.getAppContainerPath(appContainerUrl: appUrl)
            guard case let .success(path) = result else { return nil }
            return self.fetchAppInfo(from: path, appUUID: UUID(uuidString: appUrl.lastPathComponent)!)
        }

        completion(.success(appInfo))
    }

    private func fetchBundleIds() throws -> [URL] {
        let url = try self.applicationsListPath(deviceId: deviceId)

        guard FileManager.default.fileExists(atPath: url.path) else {
            // No installed apps
            return []
        }

        return try FileManager.default
            .contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
    }

    /// Fetched the full path to the .app
    private func getAppContainerPath(appContainerUrl: URL) -> Result<URL, CommandError> {
        do {
            guard let appUrl = try FileManager.default
                .contentsOfDirectory(at: appContainerUrl, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
                .filter({ $0.lastPathComponent.hasSuffix(".app") })
                .first else {
                    return .failure(.init(message: "App with UUID '\(appContainerUrl.lastPathComponent)' has no .app"))
            }
            return .success(appUrl)
        }
        catch {
            return .failure(.init(message: error.localizedDescription))
        }
    }

    /// Make an URL to the apps catalog for the specific device
    private func applicationsListPath(deviceId: UUID) throws -> URL {
        let libraryUrl = try FileManager.default.url(for: .libraryDirectory,
                                                     in: .userDomainMask,
                                                     appropriateFor: nil,
                                                     create: false)

        return URL(fileURLWithPath: Self.devicePath, isDirectory: true, relativeTo: libraryUrl)
            .appendingPathComponent(deviceId.uuidString, isDirectory: true)
            .appendingPathComponent(Self.appsListPath, isDirectory: true)
    }

    /// Fetching an app info – icon and title
    private func fetchAppInfo(from appUrl: URL, appUUID: UUID) -> AppInfo {
        let infoPlistUrl = appUrl.appendingPathComponent("Info.plist")

        guard FileManager.default.fileExists(atPath: infoPlistUrl.path) else {
            fatalError("There's no Info.plist in \(appUrl.path)")
        }
        do {
            let data = try Data(contentsOf: infoPlistUrl)
            let info = try PropertyListDecoder().decode(AppInfoPlist.self, from: data)

            dump(info)

            return AppInfo(id: appUUID, image: nil, title: info.name)
        }
        catch {
            fatalError("Can't read or decode Info.plist in \(appUrl.path): \(error.localizedDescription)")
        }
    }
}
