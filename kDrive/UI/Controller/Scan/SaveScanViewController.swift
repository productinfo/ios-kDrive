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
import kDriveResources
import PDFKit
import UIKit
import Vision
import VisionKit

class SaveScanViewController: SaveFileViewController {
    var scan: VNDocumentCameraScan!
    var scanType = ScanFileFormat(rawValue: 0)!

    override func viewDidLoad() {
        tableView.register(cellView: ScanTypeTableViewCell.self)
        super.viewDidLoad()
        sections = [.fileName, .fileType, .directorySelection]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: true)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .fileType:
            let cell = tableView.dequeueReusableCell(type: ScanTypeTableViewCell.self, for: indexPath)
            cell.didSelectIndex = { [weak self] index in
                self?.scanType = ScanFileFormat(rawValue: index)!
            }
            cell.configureWith(scan: scan)
            return cell
        default:
            return super.tableView(tableView, cellForRowAt: indexPath)
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch sections[section] {
        case .fileType:
            return HomeTitleView.instantiate(title: KDriveResourcesStrings.Localizable.searchFilterTitle)
        default:
            return super.tableView(tableView, viewForHeaderInSection: section)
        }
    }

    override func didClickOnButton() {
        let footer = tableView.footerView(forSection: sections.count - 1) as! FooterButtonView
        footer.footerButton.setLoading(true)
        guard let filename = items.first?.name,
              let selectedDriveFileManager = selectedDriveFileManager,
              let selectedDirectory = selectedDirectory else {
            footer.footerButton.setLoading(false)
            return
        }

        DispatchQueue.global(qos: .userInteractive).async { [self] in
            do {
                try FileImportHelper.instance.upload(scan: scan, name: filename, scanType: scanType, in: selectedDirectory, drive: selectedDriveFileManager.drive)
                Task {
                    let parent = presentingViewController
                    footer.footerButton.setLoading(false)
                    dismiss(animated: true) {
                        parent?.dismiss(animated: true) {
                            UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.allUploadInProgress(filename))
                        }
                    }
                }
            } catch {
                Task {
                    footer.footerButton.setLoading(false)
                    UIConstants.showSnackBar(message: KDriveResourcesStrings.Localizable.errorUpload)
                }
            }
        }
    }

    override class func instantiate(driveFileManager: DriveFileManager?) -> SaveScanViewController {
        let viewController = Storyboard.scan.instantiateViewController(withIdentifier: "SaveScanViewController") as! SaveScanViewController
        viewController.selectedDriveFileManager = driveFileManager
        return viewController
    }
}
