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

import DifferenceKit
import InfomaniakCore
import kDriveCore
import UIKit

protocol HomeFileDelegate: AnyObject {
    func didSelect(index: Int, files: [File])
}

class HomeViewController: UIViewController, SwitchDriveDelegate, SwitchAccountDelegate, HomeFileDelegate, TopScrollable {
    func didSwitchDriveFileManager(newDriveFileManager: DriveFileManager) {
        driveFileManager = newDriveFileManager
    }

    func didUpdateCurrentAccountInformations(_ currentAccount: Account) {}

    func didSwitchCurrentAccount(_ newAccount: Account) {}

    func didSelect(index: Int, files: [File]) {}

    func scrollToTop() {}

    @IBOutlet var collectionView: UICollectionView!

    static let loadingCellCount = 10

    struct HomeViewModel {
        let topRows: [HomeTopRow]
        let showInsufficientStorage: Bool
        let recentFiles: [File]
        let recentFilesEmpty: Bool
        let isLoading: Bool

        var stagedChangeSet: [ArraySection<HomeSection, AnyDifferentiable>] {
            var sections = [
                ArraySection(model: HomeSection.top, elements: topRows.map { AnyDifferentiable($0) })
            ]
            if recentFilesEmpty {
                sections.append(ArraySection(model: HomeSection.recentFiles, elements: [AnyDifferentiable(HomeSpecialRow.empty)]))
            } else {
                var anyRecentFiles = recentFiles.map { AnyDifferentiable($0) }
                if isLoading {
                    anyRecentFiles.append(contentsOf: [AnyDifferentiable](repeating: AnyDifferentiable(HomeSpecialRow.loading), count: HomeViewController.loadingCellCount))
                }
                sections.append(ArraySection(model: HomeSection.recentFiles, elements: anyRecentFiles))
            }
            return sections
        }
    }

    internal enum HomeSection: Differentiable, CaseIterable {
        case top
        case recentFiles
    }

    internal enum HomeSpecialRow: Differentiable {
        case loading
        case empty
    }

    internal enum HomeTopRow: Differentiable {
        case offline
        case drive
        case search
        case insufficientStorage
        case uploadsInProgress
        case recentFilesSelector
    }

    private enum RecentFileRows {
        case recentFiles
    }

    private var uploadCountManager: UploadCountManager!
    var driveFileManager: DriveFileManager! {
        didSet {
            observeUploadCount()
        }
    }

    private var recentFilesController: HomeRecentFilesController!
    private var viewModel: HomeViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel = HomeViewModel(topRows: getTopRows(), showInsufficientStorage: false, recentFiles: [], recentFilesEmpty: false, isLoading: false)

        collectionView.register(cellView: HomeRecentFilesSelectorCollectionViewCell.self)
        collectionView.register(WrapperCollectionViewCell.self, forCellWithReuseIdentifier: "WrapperCollectionViewCell")
        collectionView.register(cellView: HomeFileSearchCollectionViewCell.self)
        collectionView.register(cellView: HomeOfflineCollectionViewCell.self)
        collectionView.register(cellView: InsufficientStorageCollectionViewCell.self)
        collectionView.register(cellView: UploadsInProgressCollectionViewCell.self)
        collectionView.register(cellView: FileCollectionViewCell.self)
        collectionView.register(cellView: FileGridCollectionViewCell.self)
        collectionView.register(cellView: HomeEmptyFilesCollectionViewCell.self)

        recentFilesController = HomeLastModificationsController(driveFileManager: driveFileManager, homeViewController: self)
        collectionView.collectionViewLayout = createLayout()
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listPaddingBottom, right: 0)

        ReachabilityListener.instance.observeNetworkChange(self) { [unowned self] status in
            DispatchQueue.main.async {
                self.reloadTopRows()
                if status != .offline {}
            }
        }

        recentFilesController?.loadNextPage()
    }

    private func getTopRows() -> [HomeTopRow] {
        var topRows: [HomeTopRow]
        if ReachabilityListener.instance.currentStatus == .offline {
            topRows = [.offline, .drive, .search]
        } else {
            topRows = [.drive, .search, .recentFilesSelector]
        }

        if uploadCountManager != nil && uploadCountManager.uploadCount > 0 {
            topRows.append(.uploadsInProgress)
        }

        guard driveFileManager != nil && driveFileManager.drive.size > 0 else {
            return topRows
        }
        let storagePercentage = Double(driveFileManager.drive.usedSize) / Double(driveFileManager.drive.size) * 100
        if (storagePercentage > UIConstants.insufficientStorageMinimumPercentage) && viewModel.showInsufficientStorage {
            topRows.append(.insufficientStorage)
        }
        return topRows
    }

    private func observeUploadCount() {
        guard driveFileManager != nil else { return }
        uploadCountManager = UploadCountManager(driveFileManager: driveFileManager) { [weak self] in
            guard let self = self else { return }
            if let index = self.viewModel.topRows.firstIndex(where: { $0 == .uploadsInProgress }),
               let cell = self.collectionView.cellForItem(at: IndexPath(row: index, section: 0)) as? UploadsInProgressCollectionViewCell,
               self.uploadCountManager.uploadCount > 0 {
                // Update cell
                cell.setUploadCount(self.uploadCountManager.uploadCount)
            } else {
                // Delete / Add cell
                self.reloadTopRows()
            }
        }
    }

    func reloadTopRows() {
        let newViewModel = HomeViewModel(topRows: getTopRows(),
                                         showInsufficientStorage: viewModel.showInsufficientStorage,
                                         recentFiles: viewModel.recentFiles,
                                         recentFilesEmpty: viewModel.recentFilesEmpty,
                                         isLoading: viewModel.isLoading)
        reload(newViewModel: newViewModel)
    }

    func reloadWith(fetchedFiles: [File], isEmpty: Bool) {
        var newFiles = viewModel.recentFiles
        if isEmpty {
            newFiles = []
        } else {
            newFiles.append(contentsOf: fetchedFiles)
        }
        let newViewModel = HomeViewModel(topRows: viewModel.topRows,
                                         showInsufficientStorage: viewModel.showInsufficientStorage,
                                         recentFiles: newFiles,
                                         recentFilesEmpty: isEmpty,
                                         isLoading: false)
        reload(newViewModel: newViewModel)
    }

    func reload(newViewModel: HomeViewModel) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let changeset = StagedChangeset(source: self.viewModel.stagedChangeSet, target: newViewModel.stagedChangeSet)
            self.collectionView.reload(using: changeset) { _ in
                self.viewModel = newViewModel
            }
        }
    }

    func presentedFromTabBar() {}

    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] section, _ in
            guard let self = self else { return nil }
            switch HomeSection.allCases[section] {
            case .top:
                return self.generateTopSectionLayout()
            case .recentFiles:
                if self.recentFilesController.empty {
                    return self.recentFilesController.getEmptyLayout()
                } else {
                    return self.recentFilesController.getLayout(for: .grid)
                }
            }
        }
        return layout
    }

    private func generateTopSectionLayout() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(50))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
        return NSCollectionLayoutSection(group: group)
    }
}

extension HomeViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch HomeSection.allCases[section] {
        case .top:
            return viewModel.topRows.count
        case .recentFiles:
            if viewModel.recentFilesEmpty {
                return 1
            } else if viewModel.isLoading {
                return viewModel.recentFiles.count + HomeViewController.loadingCellCount
            } else {
                return viewModel.recentFiles.count
            }
        }
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return HomeSection.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch HomeSection.allCases[indexPath.section] {
        case .top:
            switch viewModel.topRows[indexPath.row] {
            case .offline:
                let cell = collectionView.dequeueReusableCell(type: HomeOfflineCollectionViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                return cell
            case .drive:
                let cell = collectionView.dequeueReusableCell(type: WrapperCollectionViewCell.self, for: indexPath)
                let tableCell = cell.initWith(cell: DriveSwitchTableViewCell.self)
                tableCell.style = .home
                tableCell.initWithPositionAndShadow(isFirst: true, isLast: true)
                tableCell.configureWith(drive: driveFileManager.drive)
                return cell
            case .search:
                let cell = collectionView.dequeueReusableCell(type: HomeFileSearchCollectionViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                return cell
            case .insufficientStorage:
                let cell = collectionView.dequeueReusableCell(type: InsufficientStorageCollectionViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                cell.configureCell(with: driveFileManager.drive)
                cell.actionHandler = { [weak self] _ in
                    guard let self = self else { return }
                    StorePresenter.showStore(from: self, driveFileManager: self.driveFileManager)
                }
                cell.closeHandler = { [weak self] _ in
                    guard let self = self else { return }
                    let newViewModel = HomeViewModel(topRows: self.getTopRows(),
                                                     showInsufficientStorage: false,
                                                     recentFiles: self.viewModel.recentFiles,
                                                     recentFilesEmpty: self.viewModel.recentFilesEmpty,
                                                     isLoading: self.viewModel.isLoading)
                    self.reload(newViewModel: newViewModel)
                }
                return cell
            case .uploadsInProgress:
                let cell = collectionView.dequeueReusableCell(type: UploadsInProgressCollectionViewCell.self, for: indexPath)
                cell.initWithPositionAndShadow(isFirst: true, isLast: true)
                cell.progressView.enableIndeterminate()
                cell.setUploadCount(uploadCountManager.uploadCount)
                return cell
            case .recentFilesSelector:
                let cell = collectionView.dequeueReusableCell(type: HomeRecentFilesSelectorCollectionViewCell.self, for: indexPath)
                cell.valueChangeHandler = { [weak self] selector in
                    guard let self = self else { return }
                    self.recentFilesController.cancelLoading()
                    self.reload(newViewModel: HomeViewModel(topRows: self.viewModel.topRows,
                                                            showInsufficientStorage: self.viewModel.showInsufficientStorage,
                                                            recentFiles: [],
                                                            recentFilesEmpty: false,
                                                            isLoading: true))
                    switch selector.selectedSegmentIndex {
                    case 0:
                        self.recentFilesController = HomeLastModificationsController(driveFileManager: self.driveFileManager, homeViewController: self)
                    case 1:
                        self.recentFilesController = HomeOfflineFilesController(driveFileManager: self.driveFileManager, homeViewController: self)
                    case 2:
                        self.recentFilesController = HomePhotoListController(driveFileManager: self.driveFileManager, homeViewController: self)
                    default:
                        break
                    }
                    self.recentFilesController.loadNextPage()
                }
                return cell
            }
        case .recentFiles:
            if viewModel.recentFilesEmpty {
                let cell = collectionView.dequeueReusableCell(type: HomeEmptyFilesCollectionViewCell.self, for: indexPath)
                recentFilesController?.configureEmptyCell(cell)
                return cell
            } else {
                let cellType = recentFilesController.getCell(for: .grid)
                let cell = collectionView.dequeueReusableCell(type: cellType, for: indexPath) as! FileCollectionViewCell

                if viewModel.isLoading && indexPath.row > viewModel.recentFiles.count - 1 {
                    cell.initStyle(isFirst: indexPath.row == 0, isLast: indexPath.row == viewModel.recentFiles.count - 1 + HomeViewController.loadingCellCount)
                    cell.configureLoading()
                } else {
                    let file = viewModel.recentFiles[indexPath.row]
                    cell.initStyle(isFirst: indexPath.row == 0, isLast: indexPath.row == viewModel.recentFiles.count - 1)
                    cell.configureWith(file: file, selectionMode: false)
                }

                return cell
            }
        }
    }
}

extension HomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch HomeSection.allCases[indexPath.section] {
        case .top:
            switch viewModel.topRows[indexPath.row] {
            case .offline, .insufficientStorage, .recentFilesSelector:
                return
            case .uploadsInProgress:
                let uploadViewController = UploadQueueFoldersViewController.instantiate(driveFileManager: driveFileManager)
                navigationController?.pushViewController(uploadViewController, animated: true)
            case .drive:
                performSegue(withIdentifier: "switchDriveSegue", sender: nil)
            case .search:
                present(SearchViewController.instantiateInNavigationController(driveFileManager: driveFileManager), animated: true)
            }
        case .recentFiles:
            break
        }
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if HomeSection.allCases[indexPath.section] == .recentFiles {
            if indexPath.row >= viewModel.recentFiles.count - 10 && !recentFilesController.loading && recentFilesController.moreComing {
                reload(newViewModel: HomeViewModel(topRows: viewModel.topRows,
                                                   showInsufficientStorage: viewModel.showInsufficientStorage,
                                                   recentFiles: viewModel.recentFiles,
                                                   recentFilesEmpty: false,
                                                   isLoading: true))
                recentFilesController?.loadNextPage()
            }
        }
    }
}
