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
import InfomaniakDI
import kDriveCore

final class DirectoryEnumerator: NSObject, NSFileProviderEnumerator {
    @LazyInjectService var additionalState: FileProviderExtensionAdditionalStatable

    let containerItemIdentifier: NSFileProviderItemIdentifier
    let driveFileManager: DriveFileManager
    let domain: NSFileProviderDomain?

    init(
        containerItemIdentifier: NSFileProviderItemIdentifier,
        driveFileManager: DriveFileManager,
        domain: NSFileProviderDomain?
    ) {
        self.containerItemIdentifier = containerItemIdentifier
        self.driveFileManager = driveFileManager
        self.domain = domain
        super.init()
    }

    func invalidate() {}

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        Task { [weak self] in
            guard let self else {
                observer.finishEnumeratingWithError(NSFileProviderError(.serverUnreachable))
                return
            }

            let parentDirectory = try driveFileManager.getCachedFile(itemIdentifier: containerItemIdentifier)

            guard !parentDirectory.fullyDownloaded else {
                let files = Array(parentDirectory.children) + [parentDirectory]
                observer.didEnumerate(files.map { FileProviderItem(file: $0, domain: self.domain) })
                observer.finishEnumerating(upTo: nil)
                return
            }

            do {
                let currentPageCursor = page.isInitialPage ? nil : page.toCursor
                let (listingResult, response) = try await driveFileManager.apiFetcher.files(
                    in: parentDirectory.proxify(),
                    advancedListingCursor: currentPageCursor,
                    sortType: .nameAZ
                )

                let realm = driveFileManager.getRealm()
                let liveParentDirectory = try driveFileManager.getCachedFile(
                    itemIdentifier: containerItemIdentifier,
                    freeze: false,
                    using: realm
                )

                for child in listingResult.files {
                    driveFileManager.keepCacheAttributesForFile(newFile: child, keepProperties: [.standard], using: realm)
                }

                try driveFileManager.writeChildrenToParent(
                    listingResult.files,
                    liveParent: liveParentDirectory,
                    responseAt: response.responseAt,
                    isInitialCursor: page.isInitialPage,
                    using: realm
                )

                try realm.write {
                    if let nextCursor = response.cursor {
                        // Last page can contain BOTH files and actions and cannot be handled this way on file provider.
                        // So we process the files and save the previous cursor to get the actions in the enumerate changes
                        if !listingResult.actions.isEmpty {
                            liveParentDirectory.lastCursor = currentPageCursor
                        } else {
                            liveParentDirectory.lastCursor = nextCursor
                        }
                        liveParentDirectory.fullyDownloaded = !response.hasMore
                    }
                }

                observer.didEnumerate(
                    listingResult.files.map { FileProviderItem(file: $0, domain: self.domain) } +
                        [FileProviderItem(file: liveParentDirectory, domain: domain)]
                )

                if response.hasMore,
                   let nextCursor = response.cursor {
                    observer.finishEnumerating(upTo: NSFileProviderPage(nextCursor))
                } else {
                    observer.finishEnumerating(upTo: nil)
                }
            } catch let error as NSFileProviderError {
                observer.finishEnumeratingWithError(error)
            } catch {
                Log.fileProvider("DirectoryEnumerator - Error in enumerateItems \(error)", level: .error)
                observer.finishEnumeratingWithError(NSFileProviderError(.serverUnreachable))
            }
        }
    }

    func enumerateChanges(for observer: NSFileProviderChangeObserver, from syncAnchor: NSFileProviderSyncAnchor) {
        Task { [weak self] in
            guard let self else {
                observer.finishEnumeratingWithError(NSFileProviderError(.serverUnreachable))
                return
            }

            guard containerItemIdentifier != .rootContainer,
                  let fileId = containerItemIdentifier.toFileId(),
                  let cursor = syncAnchor.toCursor else {
                observer.finishEnumeratingWithError(NSFileProviderError(.syncAnchorExpired))
                return
            }

            do {
                let proxyFile = ProxyFile(driveId: driveFileManager.drive.id, id: fileId)
                let (result, response) = try await driveFileManager.apiFetcher.files(
                    in: proxyFile,
                    advancedListingCursor: cursor,
                    sortType: .nameAZ
                )

                let (updatedFiles, deletedFiles) = handleActions(result.actions, actionsFiles: result.actionsFiles)

                var updatedItems = [File]()
                var deletedItems = [NSFileProviderItemIdentifier]()
                deletedItems += additionalState.deleteAlreadyEnumeratedImportedDocuments(forParent: containerItemIdentifier)

                let realm = driveFileManager.getRealm()
                let parentDirectory = try driveFileManager.getCachedFile(
                    itemIdentifier: containerItemIdentifier,
                    freeze: false,
                    using: realm
                )

                try realm.write {
                    for updatedChild in updatedFiles {
                        driveFileManager.keepCacheAttributesForFile(
                            newFile: updatedChild,
                            keepProperties: [.standard],
                            using: realm
                        )
                        realm.add(updatedChild, update: .all)
                        parentDirectory.children.insert(updatedChild)
                        updatedItems.append(updatedChild)
                    }
                    for deletedChild in deletedFiles {
                        deletedItems.append(NSFileProviderItemIdentifier(deletedChild.id))
                        realm.delete(deletedChild)
                    }
                    parentDirectory.lastCursor = response.cursor
                }

                observer.didUpdate(updatedItems.map { FileProviderItem(file: $0, domain: domain) })
                observer.didDeleteItems(withIdentifiers: deletedItems)

                guard let newLastCursor = response.cursor,
                      let nextAnchor = NSFileProviderSyncAnchor(newLastCursor) else {
                    observer.finishEnumeratingWithError(NSFileProviderError(.serverUnreachable))
                    return
                }

                observer.finishEnumeratingChanges(
                    upTo: nextAnchor,
                    moreComing: response.hasMore
                )
            } catch let error as NSFileProviderError {
                observer.finishEnumeratingWithError(error)
            } catch {
                Log.fileProvider("DirectoryEnumerator - Error in enumerateChanges \(error)", level: .error)
                observer.finishEnumeratingWithError(NSFileProviderError(.serverUnreachable))
            }
        }
    }

    func handleActions(_ actions: [FileAction], actionsFiles: [File])
        -> (updated: Set<File>, deleted: Set<File>) {
        let mappedActionsFiles = Dictionary(grouping: actionsFiles, by: \.id)

        var deletedFiles = Set<File>()
        var updatedFiles = Set<File>()

        for fileAction in actions {
            guard let actionFile = mappedActionsFiles[fileAction.fileId]?.first else { continue }

            switch fileAction.action {
            case .fileDelete, .fileTrash, .fileMoveOut:
                deletedFiles.insert(actionFile)
            case .fileRename, .fileMoveIn, .fileRestore, .fileCreate, .fileFavoriteCreate, .fileFavoriteRemove, .fileUpdate,
                 .fileShareCreate, .fileShareUpdate, .fileShareDelete, .collaborativeFolderCreate, .collaborativeFolderUpdate,
                 .collaborativeFolderDelete, .fileColorUpdate, .fileColorDelete:
                updatedFiles.insert(actionFile)
            default:
                break
            }
        }
        return (updatedFiles, deletedFiles)
    }

    func currentSyncAnchor() async -> NSFileProviderSyncAnchor? {
        guard let file = try? driveFileManager.getCachedFile(itemIdentifier: containerItemIdentifier) else {
            return nil
        }

        guard let lastCursor = file.lastCursor,
              file.fullyDownloaded,
              let anchor = NSFileProviderSyncAnchor(lastCursor) else {
            return nil
        }

        return anchor
    }
}
