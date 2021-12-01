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

class FloatingPanelActionCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var disabledView: UIView!
    @IBOutlet weak var highlightedView: UIView!
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var progressView: RPCircularProgress!
    @IBOutlet weak var titleLabel: IKLabel!
    @IBOutlet weak var switchView: UISwitch!

    private var observationToken: ObservationToken?

    override var isHighlighted: Bool {
        didSet {
            setHighlighting()
        }
    }

    private func setHighlighting() {
        highlightedView.isHidden = !isHighlighted
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        switchView.isHidden = true
        progressView.setInfomaniakStyle()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        switchView.isHidden = true
        observationToken?.cancel()
    }

    func configure(with action: FloatingPanelAction, file: File?, showProgress: Bool) {
        titleLabel.text = action.name
        iconImageView.image = action.image
        iconImageView.tintColor = action.tintColor

        if let file = file {
            if action == .favorite && file.isFavorite {
                titleLabel.text = action.reverseName
                iconImageView.tintColor = KDriveAsset.favoriteColor.color
            }
            if action == .offline {
                configureAvailableOffline(with: file)
            } else {
                observeProgress(showProgress, file: file)
            }
        }
    }

    func configure(with action: FloatingPanelAction, filesAreFavorite: Bool, filesAvailableOffline: Bool, filesAreDirectory: Bool, showProgress: Bool, archiveId: String?) {
        configure(with: action, file: nil, showProgress: false)

        if action == .favorite && filesAreFavorite {
            titleLabel.text = action.reverseName
            iconImageView.tintColor = KDriveAsset.favoriteColor.color
        } else if action == .offline {
            switchView.isHidden = false
            iconImageView.image = filesAvailableOffline ? KDriveAsset.check.image : action.image
            iconImageView.tintColor = filesAvailableOffline ? KDriveAsset.greenColor.color : action.tintColor
            switchView.isOn = filesAvailableOffline
            setProgress(showProgress ? -1 : nil)
            // Disable cell if all selected items are folders
            setEnabled(!filesAreDirectory)
        } else if action == .download {
            if let archiveId = archiveId {
                observeProgress(true, archiveId: archiveId)
            } else {
                setProgress(showProgress ? -1 : nil)
            }
        }
    }

    func configureAvailableOffline(with file: File) {
        switchView.isHidden = false
        if switchView.isOn != file.isAvailableOffline {
            switchView.setOn(file.isAvailableOffline, animated: true)
        }

        let fileExists = FileManager.default.fileExists(atPath: file.localUrl.path)
        if file.isAvailableOffline && fileExists {
            iconImageView.image = KDriveAsset.check.image
            iconImageView.tintColor = KDriveAsset.greenColor.color
        } else {
            iconImageView.image = KDriveAsset.availableOffline.image
            iconImageView.tintColor = KDriveAsset.iconColor.color
        }

        observeProgress(file.isAvailableOffline && !fileExists, file: file)
    }

    func observeProgress(_ showProgress: Bool, file: File) {
        observationToken?.cancel()
        setProgress(showProgress ? -1 : nil)
        if showProgress {
            observationToken = DownloadQueue.instance.observeFileDownloadProgress(self, fileId: file.id) { _, progress in
                DispatchQueue.main.async { [weak self] in
                    self?.setProgress(CGFloat(progress))
                }
            }
        }
    }

    func observeProgress(_ showProgress: Bool, archiveId: String) {
        observationToken?.cancel()
        setProgress(showProgress ? -1 : nil)
        if showProgress {
            observationToken = DownloadQueue.instance.observeArchiveDownloadProgress(self, archiveId: archiveId) { _, progress in
                DispatchQueue.main.async { [weak self] in
                    self?.setProgress(CGFloat(progress))
                }
            }
        }
    }

    func setProgress(_ progress: CGFloat? = -1) {
        if let downloadProgress = progress, downloadProgress < 1 {
            iconImageView.isHidden = true
            progressView.isHidden = false
            if downloadProgress < 0 {
                progressView.enableIndeterminate()
            } else {
                progressView.enableIndeterminate(false)
                progressView.updateProgress(downloadProgress)
            }
        } else {
            iconImageView.isHidden = false
            progressView.isHidden = true
        }
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            disabledView.isHidden = true
            disabledView.superview?.sendSubviewToBack(disabledView)
            isUserInteractionEnabled = true
        } else {
            disabledView.backgroundColor = KDriveAsset.backgroundCardViewColor.color
            disabledView.isHidden = false
            disabledView.superview?.bringSubviewToFront(disabledView)
            isUserInteractionEnabled = false
        }
    }
}