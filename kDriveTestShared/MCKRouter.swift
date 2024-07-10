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
import kDrive
import kDriveCore
import UIKit

/// A NOOP implementation of AppNavigable
public final class MCKRouter: AppNavigable {
    public init(topMostViewController: UIViewController? = nil) {
        self.topMostViewController = topMostViewController
    }

    private func logNoop(function: String = #function) {
        print("MCKRouter: NOOP \(function) called")
    }

    public func askForReview() async {
        logNoop()
    }

    public func presentAccountViewController(navigationController: UINavigationController, animated: Bool) {
        logNoop()
    }

    public func askUserToRemovePicturesIfNecessary() async {
        logNoop()
    }

    public func refreshCacheScanLibraryAndUpload(preload: Bool, isSwitching: Bool) async {
        logNoop()
    }

    public func showMainViewController(driveFileManager: kDriveCore.DriveFileManager,
                                       selectedIndex: Int?) -> UITabBarController? {
        logNoop()
        return nil
    }

    public func showPreloading(currentAccount: InfomaniakCore.Account) {
        logNoop()
    }

    public func showOnboarding() {
        logNoop()
    }

    public func showAppLock() {
        logNoop()
    }

    public func showLaunchFloatingPanel() {
        logNoop()
    }

    public func showUpdateRequired() {
        logNoop()
    }

    public func showPhotoSyncSettings() {
        logNoop()
    }

    public func present(file: kDriveCore.File, driveFileManager: kDriveCore.DriveFileManager) {
        logNoop()
    }

    public func present(file: kDriveCore.File, driveFileManager: kDriveCore.DriveFileManager, office: Bool) {
        logNoop()
    }

    public func presentFileList(
        frozenFolder: kDriveCore.File,
        driveFileManager: kDriveCore.DriveFileManager,
        navigationController: UINavigationController
    ) {
        logNoop()
    }

    public func presentPreviewViewController(
        frozenFiles: [kDriveCore.File],
        index: Int,
        driveFileManager: kDriveCore.DriveFileManager,
        normalFolderHierarchy: Bool,
        fromActivities: Bool,
        navigationController: UINavigationController,
        animated: Bool
    ) {
        logNoop()
    }

    public func presentFileDetails(
        frozenFile: kDriveCore.File,
        driveFileManager: kDriveCore.DriveFileManager,
        navigationController: UINavigationController,
        animated: Bool
    ) {
        logNoop()
    }

    public func presentStoreViewController(
        driveFileManager: kDriveCore.DriveFileManager,
        navigationController: UINavigationController,
        animated: Bool
    ) {
        logNoop()
    }

    public func setRootViewController(_ viewController: UIViewController, animated: Bool) {
        logNoop()
    }

    public func prepareRootViewController(currentState: RootViewControllerState, restoration: Bool) {
        logNoop()
    }

    public func updateTheme() {
        logNoop()
    }

    public var topMostViewController: UIViewController?
}
