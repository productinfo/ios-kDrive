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
import kDriveCore

class UploadCountManager {
    private let driveFileManager: DriveFileManager
    private let didUploadCountChange: () -> Void
    private let uploadCountThrottler = Throttler<Int>(timeInterval: 1, queue: .main)

    public var uploadCount = 0

    private var uploadsObserver: ObservationToken?

    init(driveFileManager: DriveFileManager, didUploadCountChange: @escaping () -> Void) {
        self.driveFileManager = driveFileManager
        self.didUploadCountChange = didUploadCountChange
        updateUploadCount()
        observeUploads()
    }

    @discardableResult
    func updateUploadCount() -> Int {
        uploadCount = UploadQueue.instance.getUploadingFiles(userId: driveFileManager.drive.userId, driveId: driveFileManager.drive.id).count
        return uploadCount
    }

    private func observeUploads() {
        guard uploadsObserver == nil else { return }

        uploadCountThrottler.handler = { [unowned self] newUploadCount in
            uploadCount = newUploadCount
            didUploadCountChange()
        }

        uploadsObserver = UploadQueue.instance.observeUploadCount(self, driveId: driveFileManager.drive.id) { [unowned self] _, uploadCount in
            self.uploadCountThrottler.call(uploadCount)
        }
    }
}
