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
import Photos

public extension PhotoLibraryUploader {
    /// Wrapper type to map an "UploadFile" to a "PHAsset"
    struct PicturesAssets {
        /// Collection of primary keys of "UploadFile"
        public let filesPrimaryKeys: [String]

        /// collection of PHAsset
        public let assets: PHFetchResult<PHAsset>
    }

    typealias UploadFileAssetIdentifier = (uploadFileId: String, assetIdentifierId: String)

    // TODO: Background batch
    func getPicturesToRemove() -> PicturesAssets? {
        Log.photoLibraryUploader("getPicturesToRemove")
        // Check that we have photo sync enabled with the delete option
        guard let settings, settings.deleteAssetsAfterImport else {
            Log.photoLibraryUploader("no settings")
            return nil
        }

        var assetsToRemove = [UploadFileAssetIdentifier]()
        BackgroundRealm.uploads.execute { realm in
            let uploadFilesToClean = uploadQueue
                .getUploadedFiles(using: realm)
                .filter("rawType = %@", UploadFileType.phAsset.rawValue)

            assetsToRemove = uploadFilesToClean.compactMap { uploadFile in
                guard let assetIdentifier = uploadFile.assetLocalIdentifier else {
                    return nil
                }

                return (uploadFile.id, assetIdentifier)
            }
        }

        let allUploadFileIds = assetsToRemove.map(\.uploadFileId)
        let allAssetsIds = assetsToRemove.map(\.assetIdentifierId)

        let toRemoveAssetsFetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: allAssetsIds,
            options: nil
        )

        guard assetsToRemove.count >= Self.removeAssetsCountThreshold,
              uploadQueue.operationQueue.operationCount == 0 else {
            return nil
        }

        return PicturesAssets(filesPrimaryKeys: allUploadFileIds, assets: toRemoveAssetsFetchResult)
    }

    func removePicturesFromPhotoLibrary(_ toRemoveItems: PicturesAssets) {
        Log.photoLibraryUploader("removePicturesFromPhotoLibrary toRemoveItems:\(toRemoveItems.filesPrimaryKeys.count)")
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(toRemoveItems.assets)
        } completionHandler: { success, _ in
            guard success else {
                return
            }

            BackgroundRealm.uploads.execute { realm in
                do {
                    try realm.write {
                        let filesInContext = realm
                            .objects(UploadFile.self)
                            .filter("id IN %@", toRemoveItems.filesPrimaryKeys)
                            .filter { $0.isInvalidated == false }
                        realm.delete(filesInContext)
                    }
                    Log.photoLibraryUploader("removePicturesFromPhotoLibrary success")
                } catch {
                    Log.photoLibraryUploader("removePicturesFromPhotoLibrary error:\(error)", level: .error)
                }
            }
        }
    }
}
