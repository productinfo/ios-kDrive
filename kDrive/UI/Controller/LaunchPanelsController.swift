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

import kDriveCore
import UIKit

struct LaunchPanel: Comparable {
    let makePanelController: () -> DriveFloatingPanelController
    let displayCondition: () -> Bool
    let onDisplay: (() -> Void)?
    let priority: Int

    static func < (lhs: LaunchPanel, rhs: LaunchPanel) -> Bool {
        return lhs.priority < rhs.priority
    }

    static func == (lhs: LaunchPanel, rhs: LaunchPanel) -> Bool {
        return lhs.priority == rhs.priority
    }

    init(makePanelController: @escaping () -> DriveFloatingPanelController, displayCondition: @autoclosure @escaping () -> Bool, onDisplay: (() -> Void)? = nil, priority: Int) {
        self.makePanelController = makePanelController
        self.displayCondition = displayCondition
        self.onDisplay = onDisplay
        self.priority = priority
    }
}

class LaunchPanelsController {
    private static let appStoreLink = "https://apps.apple.com/app/infomaniak-kdrive/id1482778676"
    private static let testFlightInviteLink = "https://testflight.apple.com/join/qZHSGy5B"

    private var panels: [LaunchPanel] = [
        // Update available
        LaunchPanel(
            makePanelController: {
                let driveFloatingPanelController = UpdateFloatingPanelViewController.instantiatePanel()
                let floatingPanelViewController = driveFloatingPanelController.contentViewController as? UpdateFloatingPanelViewController
                floatingPanelViewController?.actionHandler = { _ in
                    // If app was downloaded in TestFlight, open TestFlight. Else, open App Store
                    let link = Bundle.main.isRunningInTestFlight ? testFlightInviteLink : appStoreLink
                    if let url = URL(string: link) {
                        UserDefaults.shared.updateLater = false
                        UIApplication.shared.open(url)
                    }
                }
                return driveFloatingPanelController
            },
            displayCondition: AppVersion.showUpdateFloatingPanel(),
            priority: 4
        ),
        // Photo sync activation
        LaunchPanel(
            makePanelController: {
                guard let currentDriveFileManager = AccountManager.instance.currentDriveFileManager else {
                    fatalError("Tried to display save photos floating panel with nil currentDriveFileManager")
                }
                let driveFloatingPanelController = SavePhotosFloatingPanelViewController.instantiatePanel(drive: currentDriveFileManager.drive)
                let floatingPanelViewController = driveFloatingPanelController.contentViewController as? SavePhotosFloatingPanelViewController
                floatingPanelViewController?.actionHandler = { _ in
                    let photoSyncSettingsVC = PhotoSyncSettingsViewController.instantiate()
                    let mainTabVC = UIApplication.shared.delegate?.window??.rootViewController as? MainTabViewController
                    guard let currentVC = mainTabVC?.selectedViewController as? UINavigationController else {
                        return
                    }
                    currentVC.dismiss(animated: true)
                    currentVC.setInfomaniakAppearanceNavigationBar()
                    currentVC.pushViewController(photoSyncSettingsVC, animated: true)
                }
                return driveFloatingPanelController
            },
            displayCondition: AccountManager.instance.currentDriveFileManager != nil && UserDefaults.shared.numberOfConnections == 1 && !PhotoLibraryUploader.instance.isSyncEnabled,
            priority: 3
        ),
        // Category feature
        LaunchPanel(
            makePanelController: {
                let driveFloatingPanelController = CategoryFloatingPanelViewController.instantiatePanel()
                let floatingPanelViewController = driveFloatingPanelController.contentViewController as? CategoryFloatingPanelViewController
                floatingPanelViewController?.actionHandler = { _ in
                    driveFloatingPanelController.dismiss(animated: true)
                }
                return driveFloatingPanelController
            },
            displayCondition: !UserDefaults.shared.categoryPanelDisplayed,
            onDisplay: { UserDefaults.shared.categoryPanelDisplayed = true },
            priority: 2
        ),
        // Beta invitation
        LaunchPanel(
            makePanelController: {
                let driveFloatingPanelController = BetaInviteFloatingPanelViewController.instantiatePanel()
                let floatingPanelViewController = driveFloatingPanelController.contentViewController as? BetaInviteFloatingPanelViewController
                floatingPanelViewController?.actionHandler = { _ in
                    if let url = URL(string: testFlightInviteLink) {
                        UIApplication.shared.open(url)
                        driveFloatingPanelController.dismiss(animated: true)
                    }
                }
                return driveFloatingPanelController
            },
            displayCondition: !UserDefaults.shared.betaInviteDisplayed && !Bundle.main.isRunningInTestFlight,
            onDisplay: { UserDefaults.shared.betaInviteDisplayed = true },
            priority: 1
        )
    ]

    /// Pick a panel to display from the list based on the display condition and priority.
    ///
    /// This call should be called on a background queue because we may do some heavy work at some point.
    /// - Returns: The panel to display, if any.
    private func pickPanelToDisplay() -> LaunchPanel? {
        let potentialPanels = panels.filter { $0.displayCondition() }
        return potentialPanels.sorted().reversed().first
    }

    /// Pick and display a panel, if any, on the specified view controller.
    /// - Parameter viewController: View controller to present the panel.
    func pickAndDisplayPanel(viewController: UIViewController) {
        DispatchQueue.global().async {
            if let panel = self.pickPanelToDisplay() {
                DispatchQueue.main.async {
                    viewController.present(panel.makePanelController(), animated: true, completion: panel.onDisplay)
                }
            }
        }
    }
}
