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
import UIKit

/// Something that centralize the App Restoration logic
public protocol AppRestorationServiceable {
    func shouldSaveApplicationState(coder: NSCoder) -> Bool

    func shouldRestoreApplicationState(coder: NSCoder) -> Bool

    var shouldRestoreApplicationState: Bool { get }

    func reloadAppUI(for driveId: Int, userId: Int) async
}

public final class AppRestorationService: AppRestorationServiceable {
    @LazyInjectService var appNavigable: AppNavigable

    /// Path where the state restoration state is saved
    private static let statePath = FileManager.default
        .urls(for: .libraryDirectory, in: .userDomainMask)
        .first?
        .appendingPathComponent("Saved Application State")

    @LazyInjectService private var accountManager: AccountManageable

    /// State restoration version
    private static let currentStateVersion = 4

    /// State restoration key
    private static let appStateVersionKey = "appStateVersionKey"

    public init() {
        // META: keep SonarCloud happy
    }

    public func shouldSaveApplicationState(coder: NSCoder) -> Bool {
        Log.appDelegate("shouldSaveApplicationState")
        Log.appDelegate("Restoration files:\(String(describing: Self.statePath))")
        coder.encode(Self.currentStateVersion, forKey: Self.appStateVersionKey)
        return true
    }

    public func shouldRestoreApplicationState(coder: NSCoder) -> Bool {
        let encodedVersion = coder.decodeInteger(forKey: Self.appStateVersionKey)
        let shouldRestoreApplicationState = Self.currentStateVersion == encodedVersion &&
            !(UserDefaults.shared.legacyIsFirstLaunch || accountManager.accounts.isEmpty)
        Log.appDelegate("shouldRestoreApplicationState:\(shouldRestoreApplicationState)")
        return shouldRestoreApplicationState
    }

    public var shouldRestoreApplicationState: Bool {
        return true

        // TODO: Use user defaults
        /*
         let encodedVersion = coder.decodeInteger(forKey: Self.appStateVersionKey)
         let shouldRestoreApplicationState = Self.currentStateVersion == encodedVersion &&
             !(UserDefaults.shared.legacyIsFirstLaunch || accountManager.accounts.isEmpty)
         Log.appDelegate("shouldRestoreApplicationState:\(shouldRestoreApplicationState)")
         return shouldRestoreApplicationState
          */
    }

    public func reloadAppUI(for driveId: Int, userId: Int) async {
        accountManager.setCurrentDriveForCurrentAccount(for: driveId, userId: userId)
        accountManager.saveAccounts()

        guard let currentDriveFileManager = accountManager.currentDriveFileManager else {
            return
        }

        // Read the last tab selected in order to properly reload the App's UI.
        // This should be migrated to NSUserActivity at some point
        let lastSelectedTab = UserDefaults.shared.lastSelectedTab
        let newMainTabViewController = await MainTabViewController(
            driveFileManager: currentDriveFileManager,
            selectedIndex: lastSelectedTab
        )

        await appNavigable.setRootViewController(newMainTabViewController, animated: true)
    }
}
