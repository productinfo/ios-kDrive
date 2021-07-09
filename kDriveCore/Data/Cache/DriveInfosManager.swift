/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2021 Infomaniak Network SA

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation
import FileProvider
import RealmSwift
import InfomaniakCore
import CocoaLumberjackSwift

public class DriveInfosManager {

    public static let instance = DriveInfosManager()
    private static let currentDbVersion: UInt64 = 1
    public let realmConfiguration: Realm.Configuration
    private let dbName = "DrivesInfos.realm"
    private var fileProviderManagers: [String: NSFileProviderManager] = [:]

    private init() {
        realmConfiguration = Realm.Configuration(
            fileURL: DriveFileManager.constants.rootDocumentsURL.appendingPathComponent(dbName),
            schemaVersion: DriveInfosManager.currentDbVersion,
            migrationBlock: { _, oldSchemaVersion in
                if oldSchemaVersion < DriveInfosManager.currentDbVersion {
                    // No migration needed from version 0 to version 1
                }
            },
            objectTypes: [Drive.self, DrivePackFunctionality.self, DrivePreferences.self, DriveUsersCategories.self, DriveUser.self, Tag.self])
    }

    public func getRealm() -> Realm {
        // swiftlint:disable force_try
        return try! Realm(configuration: realmConfiguration)
    }

    private func initDriveForRealm(drive: Drive, userId: Int, sharedWithMe: Bool) {
        drive.userId = userId
        drive.sharedWithMe = sharedWithMe
    }

    private func initFileProviderDomains(drives: [Drive], user: UserProfile) {
        let updatedDomains = drives.map { NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier($0.objectId), displayName: "\($0.name) (\(user.email))", pathRelativeToDocumentStorage: "\($0.id)") }
        NSFileProviderManager.getDomainsWithCompletionHandler { allDomains, error in
            if let error = error {
                DDLogError("Error while getting domains: \(error)")
            }

            var domainsForCurrentUser = allDomains.filter { $0.identifier.rawValue.hasSuffix("_\(user.id)") }
            for newDomain in updatedDomains {
                // Check if domain already added
                if let existingDomainIndex = domainsForCurrentUser.firstIndex(where: { $0.identifier == newDomain.identifier }) {
                    let existingDomain = domainsForCurrentUser.remove(at: existingDomainIndex)
                    // Domain exists but its name could have changed
                    if existingDomain.displayName != newDomain.displayName {
                        NSFileProviderManager.remove(existingDomain) { error in
                            if let error = error {
                                DDLogError("Error while removing domain \(existingDomain.displayName): \(error)")
                            } else {
                                NSFileProviderManager.add(newDomain) { error in
                                    if let error = error {
                                        DDLogError("Error while adding domain \(newDomain.displayName): \(error)")
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Domain didn't exist we have to add it
                    NSFileProviderManager.add(newDomain) { error in
                        if let error = error {
                            DDLogError("Error while adding domain \(newDomain.displayName): \(error)")
                        }
                    }
                }
            }

            // Remove left domains
            for domain in domainsForCurrentUser {
                NSFileProviderManager.remove(domain) { error in
                    if let error = error {
                        DDLogError("Error while removing domain \(domain.displayName): \(error)")
                    }
                }
            }
        }
    }

    func deleteFileProviderDomains(for userId: Int) {
        NSFileProviderManager.getDomainsWithCompletionHandler { allDomains, error in
            if let error = error {
                DDLogError("Error while getting domains: \(error)")
            }

            let domainsForCurrentUser = allDomains.filter { $0.identifier.rawValue.hasSuffix("_\(userId)") }
            for domain in domainsForCurrentUser {
                NSFileProviderManager.remove(domain) { error in
                    if let error = error {
                        DDLogError("Error while removing domain \(domain.displayName): \(error)")
                    }
                }
            }
        }
    }

    func getFileProviderDomain(for driveId: String, completion: @escaping (NSFileProviderDomain?) -> Void) {
        NSFileProviderManager.getDomainsWithCompletionHandler { domains, error in
            if let error = error {
                DDLogError("Error while getting domains: \(error)")
                completion(nil)
            } else {
                completion(domains.first { $0.identifier.rawValue == driveId })
            }
        }
    }

    public func getFileProviderManager(for drive: Drive, completion: @escaping (NSFileProviderManager) -> Void) {
        getFileProviderManager(for: drive.objectId, completion: completion)
    }

    public func getFileProviderManager(driveId: Int, userId: Int, completion: @escaping (NSFileProviderManager) -> Void) {
        let objectId = DriveInfosManager.getObjectId(driveId: driveId, userId: userId)
        getFileProviderManager(for: objectId, completion: completion)
    }

    public func getFileProviderManager(for driveId: String, completion: @escaping (NSFileProviderManager) -> Void) {
        getFileProviderDomain(for: driveId) { domain in
            if let domain = domain {
                completion(NSFileProviderManager(for: domain) ?? .default)
            } else {
                completion(.default)
            }
        }
    }

    @discardableResult
    func storeDriveResponse(user: UserProfile, driveResponse: DriveResponse) -> [Drive] {
        var driveList = [Drive]()
        for drive in driveResponse.drives.main {
            initDriveForRealm(drive: drive, userId: user.id, sharedWithMe: false)
            driveList.append(drive)
        }

        for drive in driveResponse.drives.sharedWithMe {
            initDriveForRealm(drive: drive, userId: user.id, sharedWithMe: true)
            driveList.append(drive)
        }

        initFileProviderDomains(drives: driveResponse.drives.main, user: user)

        let realm = getRealm()
        let driveRemoved = getDrives(for: user.id, sharedWithMe: nil, using: realm).filter { currentDrive in !driveList.contains { newDrive in newDrive.objectId == currentDrive.objectId } }
        let driveRemovedIds = driveRemoved.map(\.objectId)
        try? realm.write {
            realm.delete(realm.objects(Drive.self).filter("objectId IN %@", driveRemovedIds))
            realm.add(driveList, update: .modified)
            realm.add(driveResponse.users.values, update: .modified)
            realm.add(driveResponse.tags, update: .modified)
        }
        return driveRemoved
    }

    public static func getObjectId(driveId: Int, userId: Int) -> String {
        return "\(driveId)_\(userId)"
    }

    public func getDrives(for userId: Int? = nil, sharedWithMe: Bool? = false, using realm: Realm? = nil) -> [Drive] {
        let realm = realm ?? getRealm()
        var realmDriveList = realm.objects(Drive.self)
            .sorted(byKeyPath: "id", ascending: true)
        if let userId = userId {
            let filterPredicate: NSPredicate
            if let sharedWithMe = sharedWithMe {
                filterPredicate = NSPredicate(format: "userId = %d AND sharedWithMe = %@", userId, NSNumber(value: sharedWithMe))
            } else {
                filterPredicate = NSPredicate(format: "userId = %d", userId)
            }
            realmDriveList = realmDriveList.filter(filterPredicate)
        }
        return Array(realmDriveList.map { $0.freeze() })
    }

    public func getDrive(id: Int, userId: Int, using realm: Realm? = nil) -> Drive? {
        return getDrive(objectId: DriveInfosManager.getObjectId(driveId: id, userId: userId), using: realm)
    }

    public func getDrive(objectId: String, using realm: Realm? = nil) -> Drive? {
        let realm = realm ?? getRealm()
        return realm.object(ofType: Drive.self, forPrimaryKey: objectId)?.freeze()
    }

    public func getUsers(for driveId: Int, using realm: Realm? = nil) -> [DriveUser] {
        let realm = realm ?? getRealm()
        let drive = getDrive(id: driveId, userId: AccountManager.instance.currentAccount.userId)
        let realmUserList = realm.objects(DriveUser.self)
            .sorted(byKeyPath: "id", ascending: true)
        var users: [DriveUser] = []
        if let drive = drive {
            for user in realmUserList {
                if drive.users.account.contains(user.id) {
                    users.append(user)
                }
            }
        }
        return users
    }

    public func getUser(id: Int, using realm: Realm? = nil) -> DriveUser? {
        let realm = realm ?? getRealm()
        return realm.object(ofType: DriveUser.self, forPrimaryKey: id)?.freeze()
    }

    public func getTags(using realm: Realm? = nil) -> [Tag] {
        let realm = realm ?? getRealm()
        return realm.objects(Tag.self).sorted(byKeyPath: "id", ascending: true).map { $0 }
    }

    public func getTag(id: Int, using realm: Realm? = nil) -> Tag? {
        let realm = realm ?? getRealm()
        return realm.object(ofType: Tag.self, forPrimaryKey: id)?.freeze()
    }
}
