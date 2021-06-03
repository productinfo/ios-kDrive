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

import UIKit
import InfomaniakCore
import kDriveCore

enum RightsSelectionType {
    case shareLinkSettings
    case addUserRights
    case officeOnly
}

protocol RightsSelectionDelegate: AnyObject {
    func didUpdateRightValue(newValue value: String)
    func didDeleteUserRight()
}

extension RightsSelectionDelegate {
    func didDeleteUserRight() { }
}

struct Right {
    var key: String
    var title: String
    var icon: UIImage
    var description: (String) -> String

    static let shareLinkRights = [
        Right(key: "public",
            title: KDriveStrings.Localizable.shareLinkPublicRightTitle,
            icon: KDriveAsset.view.image,
            description: { _ in KDriveStrings.Localizable.shareLinkPublicRightDescription }),
        Right(key: "inherit",
            title: KDriveStrings.Localizable.shareLinkDriveUsersRightTitle,
            icon: KDriveAsset.users.image,
            description: { driveName in KDriveStrings.Localizable.shareLinkDriveUsersRightDescription(driveName) }),
        Right(key: "password",
            title: KDriveStrings.Localizable.shareLinkPasswordRightTitle,
            icon: KDriveAsset.lock.image,
            description: { _ in KDriveStrings.Localizable.shareLinkPasswordRightDescription })
    ]
    static let onlyOfficeRights = [
        Right(key: "read",
            title: KDriveStrings.Localizable.shareLinkOfficePermissionReadTitle,
            icon: KDriveAsset.view.image,
            description: { _ in KDriveStrings.Localizable.shareLinkOfficePermissionReadDescription }),
        Right(key: "write",
            title: KDriveStrings.Localizable.shareLinkOfficePermissionWriteTitle,
            icon: KDriveAsset.edit.image,
            description: { _ in KDriveStrings.Localizable.shareLinkOfficePermissionWriteDescription })
    ]
}

class RightsSelectionViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var closeButton: UIButton!

    var userType: String!
    var user: DriveUser!
    var invitation: Invitation!
    var tag: Tag!

    var rightSelectionType = RightsSelectionType.addUserRights

    var rights = [Right]()
    var selectedRight = ""

    weak var delegate: RightsSelectionDelegate?

    var canDelete = true

    var driveFileManager: DriveFileManager!

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(cellView: RightsSelectionTableViewCell.self)
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listPaddingBottom, right: 0)

        navigationController?.setInfomaniakAppearanceNavigationBar()
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(cancelButtonPressed))
        navigationItem.leftBarButtonItem?.accessibilityLabel = KDriveStrings.Localizable.buttonClose
        navigationItem.largeTitleDisplayMode = .always

        setupView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Necessary for the large display to show up on initial view display, but why ?
        navigationController?.navigationBar.sizeToFit()
    }

    private func setupView() {
        switch rightSelectionType {
        case .shareLinkSettings:
            rights = Right.shareLinkRights
        case .addUserRights:
            let getUserRightDescription = { (permission: UserPermission) -> ((String) -> String) in
                switch permission {
                case .read:
                    return { _ in KDriveStrings.Localizable.userPermissionReadDescription }
                case .write:
                    return { _ in KDriveStrings.Localizable.userPermissionWriteDescription }
                case .manage:
                    return { _ in KDriveStrings.Localizable.userPermissionManageDescription }
                case .delete:
                    return { _ in KDriveStrings.Localizable.userPermissionRemove }
                }
            }
            let userPermissions = UserPermission.allCases.filter { $0 != .delete || canDelete } // Remove delete permission is `canDelete` is false
            rights = userPermissions.map { Right(key: $0.rawValue, title: $0.title, icon: $0.icon, description: getUserRightDescription($0)) }
        case .officeOnly:
            rights = Right.onlyOfficeRights
        }
        selectRight()
        closeButton.setTitle(KDriveStrings.Localizable.buttonSave, for: .normal)
    }

    private func selectRight() {
        guard let index = rights.firstIndex(where: { $0.key == selectedRight }) else {
            return
        }
        tableView.selectRow(at: IndexPath(row: index, section: 0), animated: true, scrollPosition: .none)
    }

    @IBAction func closeButtonPressed(_ sender: Any) {
        delegate?.didUpdateRightValue(newValue: rights[tableView.indexPathForSelectedRow?.row ?? 0].key)
        self.dismiss(animated: true)
    }

    @objc func cancelButtonPressed() {
        self.dismiss(animated: true)
    }

    class func instantiateInNavigationController() -> TitleSizeAdjustingNavigationController {
        let navigationController = TitleSizeAdjustingNavigationController(rootViewController: instantiate())
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }

    class func instantiate() -> RightsSelectionViewController {
        return UIStoryboard(name: "Files", bundle: nil).instantiateViewController(withIdentifier: "RightsSelectionViewController") as! RightsSelectionViewController
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource
extension RightsSelectionViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rights.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: RightsSelectionTableViewCell.self, for: indexPath)
        let right = rights[indexPath.row]
        var disable = false
        if right.key == "password" && driveFileManager.drive.pack == .free {
            disable = true
            cell.actionHandler = { [self] _ in
                let floatingPanelViewController = SecureLinkFloatingPanelViewController.instantiatePanel()
                (floatingPanelViewController.contentViewController as? SecureLinkFloatingPanelViewController)?.actionHandler = { _ in
                    UIConstants.openUrl("\(ApiRoutes.orderDrive())/\(driveFileManager.drive.id)", from: self)
                }
                self.present(floatingPanelViewController, animated: true)
            }
        } else if right.key == "manage" {
            var id: Int?
            if userType == "user" {
                id = user.id
            } else if userType == "invitation" {
                id = invitation.userId
            }
            if userType != "multiUser" && (id == nil || !driveFileManager.drive.users.internalUsers.contains(id!)) {
                disable = true
            }
        }
        cell.configureCell(right: right, type: rightSelectionType, driveName: driveFileManager.drive.name, disable: disable)

        return cell
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if let cell = tableView.cellForRow(at: indexPath) as? RightsSelectionTableViewCell, cell.isSelectable {
            return indexPath
        } else {
            return nil
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let right = rights[indexPath.row]
        if right.key == "delete" {
            var deleteUser: String
            if userType == "user" {
                deleteUser = user.displayName
            } else if userType == "invitation" {
                deleteUser = invitation.displayName ?? invitation.email
            } else {
                deleteUser = tag.name
            }
            let attrString = NSMutableAttributedString(string: KDriveStrings.Localizable.modalUserPermissionRemoveDescription(deleteUser), boldText: deleteUser)
            let alert = AlertTextViewController(title: KDriveStrings.Localizable.buttonDelete, message: attrString, action: KDriveStrings.Localizable.buttonDelete, destructive: true) {
                self.delegate?.didDeleteUserRight()
                self.presentingViewController?.dismiss(animated: true)
            }
            present(alert, animated: true)
            selectRight()
        } else {
            selectedRight = right.key
        }
    }

}
