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

import InfomaniakCore
import kDriveCore
import UIKit

class UploadFolderTableViewCell: InsetTableViewCell {
    @IBOutlet weak var progressView: RPCircularProgress!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var folderLabel: IKLabel!
    @IBOutlet weak var subtitleLabel: IKLabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        progressView.setInfomaniakStyle()
    }

    func configure(with folder: File, drive: Drive) {
        if folder.isRoot {
            iconImageView.image = KDriveAsset.drive.image
            iconImageView.tintColor = UIColor(hex: drive.preferences.color)
            folderLabel.text = KDriveStrings.Localizable.allRootName(drive.name)
            subtitleLabel.isHidden = true
        } else {
            iconImageView.image = KDriveAsset.folderFilled.image
            iconImageView.tintColor = nil
            folderLabel.text = folder.name
            subtitleLabel.text = folder.path.isEmpty ? nil : folder.path
            subtitleLabel.isHidden = folder.path.isEmpty
        }
        progressView.enableIndeterminate()
    }
}
