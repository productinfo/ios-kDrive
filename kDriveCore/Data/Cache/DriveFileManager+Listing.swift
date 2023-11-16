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
import RealmSwift

public extension DriveFileManager {
    func fileListing(in directory: ProxyFile,
                     sortType: SortType = .nameAZ,
                     forceRefresh: Bool = false) async throws -> (files: [File], nextCursor: String?) {
        guard !directory.isRoot else {
            return try await files(in: directory, cursor: nil, sortType: sortType, forceRefresh: forceRefresh)
        }

        let lastCursor = forceRefresh ? nil : try directory.resolve(using: getRealm()).lastCursor

        let result = try await apiFetcher.files(in: directory, listingCursor: lastCursor, sortType: sortType)

        let children = result.data.files
        let nextCursor = result.response.cursor
        let hasMore = result.response.hasMore

        let realm = getRealm()
        // Keep cached properties for children
        for child in children {
            keepCacheAttributesForFile(newFile: child, keepProperties: [.standard, .extras], using: realm)
        }

        let managedParent = try directory.resolve(using: realm)

        try realm.write {
            realm.add(children, update: .modified)

            if lastCursor == nil {
                managedParent.children.removeAll()
            }
            managedParent.children.insert(objectsIn: children)

            handleActions(result.data.actions, actionsFiles: result.data.actionsFiles, directory: managedParent, using: realm)

            managedParent.lastCursor = nextCursor
            managedParent.versionCode = DriveFileManager.constants.currentVersionCode
        }

        return (
            getLocalSortedDirectoryFiles(directory: managedParent, sortType: sortType),
            hasMore ? nextCursor : nil
        )
    }

    func handleActions(_ actions: [FileAction], actionsFiles: [File], directory: File, using realm: Realm) {
        let mappedActionsFiles = Dictionary(grouping: actionsFiles, by: \.id)

        for fileAction in actions {
            guard let actionFile = mappedActionsFiles[fileAction.fileId]?.first else { continue }

            switch fileAction.action {
            case .fileDelete, .fileTrash:
                removeFileInDatabase(fileId: fileAction.fileId, cascade: true, withTransaction: false, using: realm)

            case .fileMoveOut:
                guard let movedOutFile: File = realm.getObject(id: fileAction.fileId),
                      let oldParent = movedOutFile.parent else { continue }

                oldParent.children.remove(movedOutFile)

            case .fileRename:
                guard let oldFile: File = realm.getObject(id: fileAction.fileId) else { continue }
                try? renameCachedFile(updatedFile: actionFile, oldFile: oldFile)
                // If the file is a folder we have to copy the old attributes which are not returned by the API
                keepCacheAttributesForFile(newFile: actionFile, keepProperties: [.standard, .extras], using: realm)
                realm.add(actionFile, update: .modified)
                actionFile.applyLastModifiedDateToLocalFile()

            case .fileMoveIn, .fileRestore, .fileCreate:
                keepCacheAttributesForFile(newFile: actionFile, keepProperties: [.standard, .extras], using: realm)
                realm.add(actionFile, update: .modified)

                if let existingFile: File = realm.getObject(id: fileAction.fileId),
                   let oldParent = existingFile.parent {
                    oldParent.children.remove(existingFile)
                }
                directory.children.insert(actionFile)

            case .fileFavoriteCreate, .fileFavoriteRemove, .fileUpdate, .fileShareCreate, .fileShareUpdate, .fileShareDelete,
                 .collaborativeFolderCreate, .collaborativeFolderUpdate, .collaborativeFolderDelete, .fileColorUpdate,
                 .fileColorDelete:
                guard actionFile.isTrashed else {
                    removeFileInDatabase(fileId: fileAction.fileId, cascade: true, withTransaction: false, using: realm)
                    continue
                }

                keepCacheAttributesForFile(newFile: actionFile, keepProperties: [.standard, .extras], using: realm)
                realm.add(actionFile, update: .modified)
                directory.children.insert(actionFile)

            default:
                break
            }
        }
    }
}
