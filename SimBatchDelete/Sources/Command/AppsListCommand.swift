//
//  AppsListCommand.swift
//

import Cocoa

struct AppInfo {

    let id: UUID
    let image: NSImage?
    let title: String
}

private struct AppFetchInfo {

    let id: UUID
    let bundleId: String
    let url: URL
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

        let fetchItems: [AppFetchInfo]
        do {
            fetchItems = try self.fetchBundleIds()
        }
        catch {
            completion(.failure(error))
            return
        }

        var appContainerPaths = [AppInfo]()

        let group = DispatchGroup()
        group.notify(queue: .main) {
            completion(.success(appContainerPaths))
        }

        for item in fetchItems {
            group.enter()
            self.getAppContainerPath(bundleId: item.bundleId, appId: item.id) { result in
                guard case let .success(path) = result else {
                    group.leave()
                    return
                }

                let app = self.fetchAppInfo(path)
                DispatchQueue.main.async {
                    appContainerPaths.append(app)
                    group.leave()
                }
            }
        }
    }

    private func fetchBundleIds() throws -> [AppFetchInfo] {
        let url = try self.applicationsListPath(deviceId: deviceId)

        guard FileManager.default.fileExists(atPath: url.path) else {
            fatalError("File at path \(url.path) does not exist")
        }

        return try FileManager.default
            .contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            .compactMap(fetchAppBundleId)
    }

    /// Fetched the full path to the .app
    private func getAppContainerPath(bundleId: String, appId: UUID, then completion: @escaping (Result<URL, CommandError>) -> Void) {
        do {
            let appContainerUrl = try self.applicationsListPath(deviceId: self.deviceId)
                .appendingPathComponent(appId.uuidString)

            guard let appUrl = try FileManager.default
                .contentsOfDirectory(at: appContainerUrl, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
                .filter({ $0.lastPathComponent.hasSuffix(".app") })
                .first else {
                    completion(.failure(.init(message: "App with bundle ID '\(bundleId)' has no .app")))
                    return
            }

            print("'\(bundleId)': \(appUrl)")
            completion(.success(appUrl))
        }
        catch {
            completion(.failure(.init(message: error.localizedDescription)))
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

    private func fetchAppBundleId(appUrl: URL) -> AppFetchInfo? {
        let url = appUrl
            .appendingPathComponent(Self.appInfoPlistFileName)

        guard FileManager.default.fileExists(atPath: url.path) else {
            fatalError("File at path \(url.path) does not exist")
        }
        guard let result = NSDictionary(contentsOf: url) else {
            return nil
        }
        guard let bundleId = result.value(forKey: "MCMMetadataIdentifier") as? String else {
            return nil
        }

        return AppFetchInfo(id: UUID(uuidString: appUrl.lastPathComponent)!, bundleId: bundleId, url: appUrl)
    }

    /// Fetching an app info – icon and title
    private func fetchAppInfo(_ appUrl: URL) -> AppInfo {
        print("Fetch app info from \(appUrl.lastPathComponent)")
        return AppInfo(id: UUID(), image: nil, title: "An App")
    }
}
