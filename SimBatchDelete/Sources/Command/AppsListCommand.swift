//
//  AppsListCommand.swift
//

import Cocoa

struct AppInfo {

    let id: UUID
    let image: NSImage?
    let title: String
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

        let appBundleIds: [String]
        do {
            appBundleIds = try self.fetchBundleIds()
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

        for bundleId in appBundleIds {
            group.enter()
            self.getAppContainerPath(bundleId: bundleId) { result in
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

    private func fetchBundleIds() throws -> [String] {
        let url = try self.applicationsListPath(deviceId: deviceId)

        guard FileManager.default.fileExists(atPath: url.path) else {
            fatalError("File at path \(url.path) does not exist")
        }

        return try FileManager.default
            .contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
            .compactMap(fetchAppBundleId)
    }

    /// Fetched the full path to the .app
    private func getAppContainerPath(bundleId: String, then completion: @escaping (Result<URL, CommandError>) -> Void) {
        SimCtlCommand(command: .getAppContainer(deviceId: deviceId, appBundleId: bundleId, containerType: .app)).run { result in
            completion(
                result.flatMap { data in
                    guard let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                        return .failure(CommandError(message: "Command returned invalid string"))
                    }
                    guard FileManager.default.fileExists(atPath: path) else {
                        return .failure(CommandError(message: "Path does not exist: \(path)"))
                    }
                    print("'\(bundleId)': \(path)")
                    return .success(URL(fileURLWithPath: path, isDirectory: true))
                }
            )
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

    private func fetchAppBundleId(appUrl: URL) -> String? {
        let url = appUrl
            .appendingPathComponent(Self.appInfoPlistFileName)

        guard FileManager.default.fileExists(atPath: url.path) else {
            fatalError("File at path \(url.path) does not exist")
        }

        guard let result = NSDictionary(contentsOf: url) else {
            return nil
        }

        return result.value(forKey: "MCMMetadataIdentifier") as? String
    }

    /// Fetching an app info – icon and title
    private func fetchAppInfo(_ appUrl: URL) -> AppInfo {
        print("Fetch app info from \(appUrl)")
    }
}
