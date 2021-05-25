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

class ThemeSelectionTableViewCell: InsetTableViewCell {

    @IBOutlet weak var themeLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        contentInsetView.backgroundColor = KDriveAsset.backgroundCardViewColor.color
        if selected {
            contentInsetView.borderColor = KDriveAsset.infomaniakColor.color
            contentInsetView.borderWidth = 2
        } else {
            contentInsetView.borderColor = KDriveAsset.borderColor.color
            contentInsetView.borderWidth = 1
        }
    }
}