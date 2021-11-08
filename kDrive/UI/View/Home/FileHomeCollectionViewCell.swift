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

class FileHomeCollectionViewCell: FileGridCollectionViewCell {
    @IBOutlet weak var timeStackView: UIStackView!
    @IBOutlet weak var timeLabel: IKLabel!

    override var checkmarkImage: UIImageView? {
        return nil
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        logoImage.layer.masksToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentInsetView.cornerRadius = UIConstants.cornerRadius
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        titleLabel.textAlignment = .natural
        largeIconImageView.isHidden = true
        logoImage.isHidden = false
        logoImage.backgroundColor = nil
        iconImageView.backgroundColor = nil
        timeLabel.text = ""
        timeStackView.isHidden = false
    }

    override func initStyle(isFirst: Bool, isLast: Bool) {}

    override func configureWith(file: File, selectionMode: Bool = false) {
        super.configureWith(file: file, selectionMode: selectionMode)
        iconImageView.isHidden = file.isDirectory
        if file.isDirectory || !file.hasThumbnail {
            logoImage.isHidden = true
            largeIconImageView.isHidden = false
            moreButton.tintColor = KDriveAsset.primaryTextColor.color
            moreButton.backgroundColor = nil
        } else {
            logoImage.isHidden = false
            largeIconImageView.isHidden = true
            iconImageView.isHidden = false
            moreButton.tintColor = .white
            moreButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
            moreButton.cornerRadius = moreButton.frame.width / 2
        }
        logoImage.contentMode = .scaleAspectFill
        titleLabel.textAlignment = file.isDirectory ? .center : .natural
        checkmarkImage?.isHidden = !selectionMode
        iconImageView.image = file.icon
        largeIconImageView.image = file.icon
        if file.isDirectory {
            file.getThumbnail { image, _ in
                self.largeIconImageView.image = image
            }
        }
        timeLabel.text = Constants.formatDate(file.lastModifiedDate, style: .datetime, relative: true)
    }

    override func setThumbnailFor(file: File) {
        let fileId = file.id
        logoImage.image = nil
        logoImage.backgroundColor = KDriveAsset.loaderDarkerDefaultColor.color
        file.getThumbnail { image, _ in
            if fileId == self.file.id {
                self.logoImage.image = image
                self.logoImage.backgroundColor = nil
            }
        }
    }

    override func configureLoading() {
        timeStackView.isHidden = true
        titleLabel.text = " "
        let titleLayer = CALayer()
        titleLayer.anchorPoint = .zero
        titleLayer.bounds = CGRect(x: 0, y: 0, width: 100, height: 15)
        titleLayer.backgroundColor = KDriveAsset.loaderDarkerDefaultColor.color.cgColor
        titleLabel.layer.addSublayer(titleLayer)
        logoImage.image = nil
        logoImage.backgroundColor = KDriveAsset.loaderDarkerDefaultColor.color
        largeIconImageView.isHidden = true
        iconImageView.isHidden = false
        iconImageView.image = nil
        iconImageView.backgroundColor = KDriveAsset.loaderDarkerDefaultColor.color
        moreButton.isHidden = true
        checkmarkImage?.isHidden = true
    }
}