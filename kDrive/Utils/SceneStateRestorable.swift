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

import kDriveCore
import UIKit

/// Express a current state for scene based restoration.
public protocol SceneStateRestorable {
    /// Metadata used to restore a specific screen within a scene, testable.
    var currentSceneMetadata: [AnyHashable: Any] { get }
}

/// Activity identifiers of the app
public enum SceneActivityIdentifier {
    static let mainSceneActivityType: String = {
        let activityTypes = Bundle.main.infoDictionary?["NSUserActivityTypes"] as? [String]
        guard let activity = activityTypes?.first else {
            fatalError("Unable to read NSUserActivity config from app plist. Please update Plist for your target.")
        }

        return activity
    }()
}

public extension UIViewController {
    /// Saves the current state within a scene, for state restoration
    func saveSceneState() {
        Log.sceneDelegate("saveSceneState")
        guard let restorableViewController = self as? SceneStateRestorable else {
            Log.sceneDelegate("Implement SceneStateRestorable to \(self) to save its state", level: .error)
            return
        }

        let metadata = restorableViewController.currentSceneMetadata
        let userActivity = currentUserActivity
        userActivity.addUserInfoEntries(from: metadata)

        guard let scene = view.window?.windowScene else {
            Log.sceneDelegate("no scene linked to \(self)", level: .error)
            return
        }

        scene.userActivity = userActivity
    }

    /// Current NSUserActivity for a given UIViewController
    var currentUserActivity: NSUserActivity {
        let activity: NSUserActivity
        if let currentUserActivity = view.window?.windowScene?.userActivity {
            activity = currentUserActivity
        } else {
            activity = NSUserActivity(activityType: SceneActivityIdentifier.mainSceneActivityType)
        }
        return activity
    }
}
