/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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
import InfomaniakCore
import InfomaniakDI
import kDriveCore
import RealmSwift

class RootEnumerator: NSObject, NSFileProviderEnumerator {
    @LazyInjectService private var fileProviderManager: FileProviderManager

    let containerItemIdentifier = NSFileProviderItemIdentifier.rootContainer

    func invalidate() {}

    func fetchRoot(page: NSFileProviderPage) async throws -> (files: [File], nextCursor: String?) {
        let parentDirectory = try fileProviderManager.getFile(for: containerItemIdentifier)

        guard !parentDirectory.fullyDownloaded else {
            return (Array(parentDirectory.children) + [parentDirectory], nil)
        }

        let currentPageCursor = page.isInitialPage ? nil : page.toCursor
        let (files, response) = try await fileProviderManager.driveApiFetcher.rootFiles(
            drive: fileProviderManager.drive,
            cursor: currentPageCursor
        )

        let realm = fileProviderManager.getRealm()
        let liveParentDirectory = try fileProviderManager.getFile(for: containerItemIdentifier, using: realm, shouldFreeze: false)

        let updatedFiles = try fileProviderManager.writeChildrenToParent(
            liveParentDirectory,
            children: files,
            shouldClearChildren: page.isInitialPage,
            using: realm
        )

        try updateAnchor(for: liveParentDirectory, from: response, using: realm)

        return (updatedFiles + [liveParentDirectory.freezeIfNeeded()], response.hasMore ? response.cursor : nil)
    }

    func updateAnchor(for parent: File, from response: ApiResponse<[File]>, using realm: Realm) throws {
        try realm.write {
            parent.responseAt = response.responseAt ?? Int(Date().timeIntervalSince1970)
            parent.lastCursor = response.cursor
            parent.fullyDownloaded = response.hasMore
        }
    }

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        Task {
            do {
                let (files, nextCursor) = try await self.fetchRoot(page: page)
                observer.didEnumerate(files.map { FileProviderItem(file: $0, domain: fileProviderManager.domain) })

                // there should never be more cursors but still implement next page logic just in case
                if let nextCursor {
                    observer.finishEnumerating(upTo: NSFileProviderPage(nextCursor))
                } else {
                    observer.finishEnumerating(upTo: nil)
                }
            } catch let error as NSFileProviderError {
                observer.finishEnumeratingWithError(error)
            } catch {
                observer.finishEnumeratingWithError(NSFileProviderError(.serverUnreachable))
            }
        }
    }

    /* func enumerateChanges(for observer: NSFileProviderChangeObserver, from syncAnchor: NSFileProviderSyncAnchor) {
         guard let datedCursor = syncAnchor.toDatedCursor else {
             observer.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired))
             return
         }

         Task {
             let (driveFiles, response) = try await fileProviderManager.driveApiFetcher.rootFiles(
                 drive: fileProviderManager.drive,
                 cursor: datedCursor.cursor
             )
             let files = driveFiles.map { FPFile(file: $0) }

             let realm = fileProviderManager.getRealm()
             guard let liveParentDirectory = try? fileProviderManager.getFile(
                 for: containerItemIdentifier,
                 using: realm,
                 shouldFreeze: false
             ) else {
                 observer.finishEnumeratingWithError(NSFileProviderError(.noSuchItem))
                 return
             }

             guard let syncAnchor = NSFileProviderSyncAnchor(response.cursor) else {
                 observer.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired))
                 return
             }

             let childIdsBeforeUpdate = Set(liveParentDirectory.children.map { $0.id })
             let updatedFiles = try fileProviderManager.writeChildrenToParent(
                 liveParentDirectory,
                 children: files,
                 shouldClearChildren: false,
                 using: realm
             )
             let childIdsAfterUpdate = Set(liveParentDirectory.children.map { $0.id })

             // Manual diffing since we don't have activities for root
             let deletedIds = childIdsAfterUpdate.subtracting(childIdsBeforeUpdate)

             observer.didUpdate(updatedFiles + [liveParentDirectory.freezeIfNeeded()])
             observer.didDeleteItems(withIdentifiers: deletedIds.map { NSFileProviderItemIdentifier($0) })
             observer.finishEnumeratingChanges(
                 upTo: syncAnchor,
                 moreComing: response.hasMore
             )
         }
     } */

    func currentSyncAnchor() async -> NSFileProviderSyncAnchor? {
        return nil
    }
}
