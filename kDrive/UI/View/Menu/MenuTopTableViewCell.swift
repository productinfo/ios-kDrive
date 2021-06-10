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
import kDriveCore
import InfomaniakCore

class MenuTopTableViewCell: UITableViewCell {

    @IBOutlet weak var userAvatarContainerView: UIView!
    @IBOutlet weak var userAvatarImageView: UIImageView!
    @IBOutlet weak var userDisplayNameLabel: UILabel!
    @IBOutlet weak var userEmailLabel: UILabel!
    @IBOutlet weak var driveNameLabel: UILabel!
    @IBOutlet weak var driveImageView: UIImageView!
    @IBOutlet weak var switchDriveButton: UIButton!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!

    func configureCell(with drive: Drive, and account: Account) {
        userAvatarContainerView.clipsToBounds = false
        userAvatarContainerView.layer.shadowOpacity = 0.3
        userAvatarContainerView.layer.shadowOffset = .zero
        userAvatarContainerView.layer.shadowRadius = 15
        userAvatarContainerView.layer.cornerRadius = userAvatarContainerView.frame.width / 2
        userAvatarContainerView.layer.shadowPath = UIBezierPath(ovalIn: userAvatarContainerView.bounds).cgPath
        // User image rounded
        userAvatarImageView.clipsToBounds = true
        userAvatarImageView.layer.cornerRadius = userAvatarImageView.frame.width / 2

        switchDriveButton.tintColor = KDriveAsset.actionColor.color
        switchDriveButton.accessibilityLabel = KDriveStrings.Localizable.buttonSwitchDrive

        driveNameLabel.text = drive.name
        driveImageView.tintColor = UIColor(hex: drive.preferences.color)
        userDisplayNameLabel.text = account.user.displayName
        userEmailLabel.text = account.user.email
        userAvatarImageView.image = KDriveAsset.placeholderAvatar.image
        account.user.getAvatar(size: CGSize(width: 512, height: 512)) { image in
            self.userAvatarImageView.image = image
        }

        if drive.size == 0 {
            progressView.isHidden = true
            progressLabel.isHidden = true
        } else {
            progressView.isHidden = false
            progressLabel.isHidden = false
            progressView.progress = Float(drive.usedSize) / Float(drive.size)
            progressLabel.text = "\(Constants.formatFileSize(drive.usedSize, decimals: 1)) / \(Constants.formatFileSize(drive.size))"
        }
    }
}
