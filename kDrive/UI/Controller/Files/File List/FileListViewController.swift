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

import CocoaLumberjackSwift
import Combine
import DifferenceKit
import kDriveCore
import kDriveResources
import RealmSwift
import UIKit

extension SwipeCellAction {
    static let share = SwipeCellAction(identifier: "share", title: KDriveResourcesStrings.Localizable.buttonFileRights, backgroundColor: KDriveResourcesAsset.infomaniakColor.color, icon: KDriveResourcesAsset.share.image)
    static let delete = SwipeCellAction(identifier: "delete", title: KDriveResourcesStrings.Localizable.buttonDelete, backgroundColor: KDriveResourcesAsset.binColor.color, icon: KDriveResourcesAsset.delete.image)
}

extension SortType: Selectable {
    var title: String {
        return value.translation
    }
}

class FileListBarButton: UIBarButtonItem {
    private(set) var type: FileListBarButtonType = .cancel

    convenience init(type: FileListBarButtonType, target: Any?, action: Selector?) {
        switch type {
        case .selectAll:
            self.init(title: KDriveResourcesStrings.Localizable.buttonSelectAll, style: .plain, target: target, action: action)
        case .deselectAll:
            self.init(title: KDriveResourcesStrings.Localizable.buttonDeselectAll, style: .plain, target: target, action: action)
        case .loading:
            let activityView = UIActivityIndicatorView(style: .medium)
            activityView.startAnimating()
            self.init(customView: activityView)
        case .cancel:
            self.init(barButtonSystemItem: .stop, target: target, action: action)
            accessibilityLabel = KDriveResourcesStrings.Localizable.buttonClose
        case .search:
            self.init(barButtonSystemItem: .search, target: target, action: action)
        case .emptyTrash:
            self.init(title: KDriveResourcesStrings.Localizable.buttonEmptyTrash, style: .plain, target: target, action: action)
        }
        self.type = type
    }
}

class ConcreteFileListViewModel: ManagedFileListViewModel {
    required init(driveFileManager: DriveFileManager, currentDirectory: File?) {
        let configuration = FileListViewModel.Configuration(emptyViewType: .emptyFolder, supportsDrop: true, rightBarButtons: [.search])
        let currentDirectory = currentDirectory == nil ? driveFileManager.getRootFile() : currentDirectory
        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory!)
        self.files = AnyRealmCollection(self.currentDirectory.children)
    }

    override internal init(configuration: FileListViewModel.Configuration, driveFileManager: DriveFileManager, currentDirectory: File?) {
        let currentDirectory = currentDirectory == nil ? driveFileManager.getRootFile() : currentDirectory
        super.init(configuration: configuration, driveFileManager: driveFileManager, currentDirectory: currentDirectory!)
        self.files = AnyRealmCollection(self.currentDirectory.children)
    }

    override func loadFiles(page: Int = 1, forceRefresh: Bool = false) {
        guard !isLoading || page > 1 else { return }

        if currentDirectory.fullyDownloaded && !forceRefresh {
            loadActivities()
        } else {
            isLoading = true
            if page == 1 {
                showLoadingIndicatorIfNeeded()
            }

            driveFileManager.getFile(id: currentDirectory.id, page: page, sortType: sortType, forceRefresh: forceRefresh) { [weak self] file, _, error in
                self?.isLoading = false
                self?.isRefreshIndicatorHidden = true
                if let fetchedCurrentDirectory = file {
                    if !fetchedCurrentDirectory.fullyDownloaded {
                        self?.loadFiles(page: page + 1, forceRefresh: forceRefresh)
                    } else if !forceRefresh {
                        self?.loadActivities()
                    }
                } else if let error = error as? DriveError {
                    self?.onDriveError?(error)
                }
            }
        }
    }

    override func loadActivities() {
        driveFileManager.getFolderActivities(file: currentDirectory) { [weak self] _, _, error in
            if let error = error as? DriveError {
                self?.onDriveError?(error)
            }
        }
    }
}

class FileListViewController: MultipleSelectionViewController, UICollectionViewDataSource, SwipeActionCollectionViewDelegate, SwipeActionCollectionViewDataSource, FilesHeaderViewDelegate {
    class var storyboard: UIStoryboard { Storyboard.files }
    class var storyboardIdentifier: String { "FileListViewController" }

    // MARK: - Constants

    private let leftRightInset = 12.0
    private let gridInnerSpacing = 16.0
    private let maxDiffChanges = Endpoint.itemsPerPage
    private let headerViewIdentifier = "FilesHeaderView"

    // MARK: - Properties

    var collectionViewLayout: UICollectionViewFlowLayout!
    var refreshControl = UIRefreshControl()
    private var headerView: FilesHeaderView?
    private lazy var floatingPanelViewController = DriveFloatingPanelController()
    private var quickActionsViewController: UIViewController!

    #if !ISEXTENSION
        lazy var filePresenter = FilePresenter(viewController: self, floatingPanelViewController: floatingPanelViewController)
    #endif

    var currentDirectory: File!
    var driveFileManager: DriveFileManager!

    private var networkObserver: ObservationToken?

    var viewModel: FileListViewModel!

    var bindStore = Set<AnyCancellable>()

    // MARK: - View controller lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.backButtonTitle = ""

        // Set up collection view
        collectionView.register(cellView: FileCollectionViewCell.self)
        collectionView.register(cellView: FileGridCollectionViewCell.self)
        collectionView.register(UINib(nibName: headerViewIdentifier, bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: headerViewIdentifier)
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: UIConstants.listPaddingBottom, right: 0)
        (collectionView as? SwipableCollectionView)?.swipeDataSource = self
        (collectionView as? SwipableCollectionView)?.swipeDelegate = self
        collectionViewLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
        collectionViewLayout?.sectionHeadersPinToVisibleBounds = true

        // Set up observers
        observeNetwork()
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    private func bindViewModels() {
        bindFileListViewModel()
        bindUploadCardViewModel()
        bindMultipleSelectionViewModel()
    }

    private func bindFileListViewModel() {
        viewModel.onFileListUpdated = { [weak self] deletions, insertions, modifications, shouldReload in
            guard !shouldReload else {
                self?.collectionView.reloadData()
                return
            }
            self?.collectionView.performBatchUpdates {
                // Always apply updates in the following order: deletions, insertions, then modifications.
                // Handling insertions before deletions may result in unexpected behavior.
                self?.collectionView.deleteItems(at: deletions.map { IndexPath(item: $0, section: 0) })
                self?.collectionView.insertItems(at: insertions.map { IndexPath(item: $0, section: 0) })
                self?.collectionView.reloadItems(at: modifications.map { IndexPath(item: $0, section: 0) })
            }
        }

        headerView?.sortButton.setTitle(viewModel.sortType.value.translation, for: .normal)

        navigationItem.title = viewModel.title
        viewModel.$title.receiveOnMain(store: &bindStore) { [weak self] title in
            self?.navigationItem.title = title
        }

        viewModel.$isRefreshIndicatorHidden.receiveOnMain(store: &bindStore) { [weak self] isRefreshIndicatorHidden in
            guard let self = self,
                  self.refreshControl.isRefreshing == isRefreshIndicatorHidden
            else { return }

            if isRefreshIndicatorHidden {
                self.refreshControl.endRefreshing()
            } else {
                self.refreshControl.beginRefreshing()
                let offsetPoint = CGPoint(x: 0, y: self.collectionView.contentOffset.y - self.refreshControl.frame.size.height)
                self.collectionView.setContentOffset(offsetPoint, animated: true)
            }
        }

        showEmptyView(viewModel.isEmptyViewHidden)
        viewModel.$isEmptyViewHidden.receiveOnMain(store: &bindStore) { [weak self] isEmptyViewHidden in
            guard let self = self else { return }
            self.showEmptyView(isEmptyViewHidden)
        }

        viewModel.$listStyle.receiveOnMain(store: &bindStore) { [weak self] listStyle in
            guard let self = self else { return }
            self.headerView?.listOrGridButton.setImage(listStyle.icon, for: .normal)
            UIView.transition(with: self.collectionView, duration: 0.25, options: .transitionCrossDissolve) {
                self.collectionView.reloadData()
                self.setSelectedCells()
            }
        }

        viewModel.onDriveError = { [weak self] driveError in
            if driveError == .objectNotFound {
                self?.navigationController?.popViewController(animated: true)
            } else if driveError != .searchCancelled {
                UIConstants.showSnackBar(message: driveError.localizedDescription)
            }
        }

        viewModel.onFilePresented = { [weak self] file in
            guard let self = self else { return }
            #if !ISEXTENSION
                self.filePresenter.present(driveFileManager: self.viewModel.driveFileManager,
                                           file: file,
                                           files: self.viewModel.getAllFiles(),
                                           normalFolderHierarchy: self.viewModel.configuration.normalFolderHierarchy,
                                           fromActivities: self.viewModel.configuration.fromActivities)
            #endif
        }

        viewModel.$currentLeftBarButtons.receiveOnMain(store: &bindStore) { [weak self] leftBarButtons in
            guard let self = self else { return }
            self.navigationItem.leftBarButtonItems = leftBarButtons?.map { FileListBarButton(type: $0, target: self, action: #selector(self.barButtonPressed(_:))) }
        }

        navigationItem.rightBarButtonItems = viewModel.currentRightBarButtons?.map { FileListBarButton(type: $0, target: self, action: #selector(self.barButtonPressed(_:))) }
        viewModel.$currentRightBarButtons.receiveOnMain(store: &bindStore) { [weak self] rightBarButtons in
            guard let self = self else { return }
            self.navigationItem.rightBarButtonItems = rightBarButtons?.map { FileListBarButton(type: $0, target: self, action: #selector(self.barButtonPressed(_:))) }
        }

        viewModel.onPresentViewController = { [weak self] presentationType, viewController, animated in
            if presentationType == .push,
               let navigationController = self?.navigationController {
                navigationController.pushViewController(viewController, animated: animated)
            } else {
                self?.present(viewController, animated: animated)
            }
        }

        viewModel.onPresentQuickActionPanel = { [weak self] files, type in
            self?.showQuickActionsPanel(files: files, actionType: type)
        }
    }

    private func bindUploadCardViewModel() {
        viewModel.uploadViewModel?.$uploadCount.receiveOnMain(store: &bindStore) { [weak self] uploadCount in
            guard let self = self else { return }
            let shouldHideUploadCard: Bool
            if uploadCount > 0 {
                self.headerView?.uploadCardView.setUploadCount(uploadCount)
                shouldHideUploadCard = false
            } else {
                shouldHideUploadCard = true
            }
            // Only perform reload if needed
            if shouldHideUploadCard != self.headerView?.uploadCardView.isHidden {
                self.headerView?.uploadCardView.isHidden = shouldHideUploadCard
                self.collectionView.performBatchUpdates(nil)
            }
        }
    }

    private func bindMultipleSelectionViewModel() {
        viewModel.multipleSelectionViewModel?.$isMultipleSelectionEnabled.receiveOnMain(store: &bindStore) { [weak self] isMultipleSelectionEnabled in
            self?.toggleMultipleSelection(isMultipleSelectionEnabled)
        }

        viewModel.multipleSelectionViewModel?.$selectedCount.receiveOnMain(store: &bindStore) { [weak self] selectedCount in
            self?.headerView?.selectView.updateTitle(selectedCount)
        }

        viewModel.multipleSelectionViewModel?.onItemSelected = { [weak self] itemIndex in
            self?.collectionView.selectItem(at: IndexPath(item: itemIndex, section: 0), animated: true, scrollPosition: .init(rawValue: 0))
        }

        viewModel.multipleSelectionViewModel?.onSelectAll = { [weak self] in
            for indexPath in self?.collectionView.indexPathsForVisibleItems ?? [] {
                self?.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
            }
        }

        viewModel.multipleSelectionViewModel?.onDeselectAll = { [weak self] in
            for indexPath in self?.collectionView.indexPathsForSelectedItems ?? [] {
                self?.collectionView.deselectItem(at: indexPath, animated: false)
            }
        }

        viewModel.multipleSelectionViewModel?.$multipleSelectionActions.receiveOnMain(store: &bindStore) { [weak self] actions in
            self?.headerView?.selectView.setActions(actions)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func appWillEnterForeground() {
        viewWillAppear(true)
    }

    private func setupViewModel() {
        if viewModel == nil {
            viewModel = ConcreteFileListViewModel(driveFileManager: driveFileManager, currentDirectory: currentDirectory)
        }
        bindViewModels()
        if viewModel.configuration.isRefreshControlEnabled {
            refreshControl.addTarget(self, action: #selector(forceRefresh), for: .valueChanged)
            collectionView.refreshControl = refreshControl
        }
        // Set up multiple selection gesture
        if viewModel.multipleSelectionViewModel != nil {
            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
            collectionView.addGestureRecognizer(longPressGesture)
        }

        if viewModel.droppableFileListViewModel != nil {
            collectionView.dropDelegate = self
        }

        if viewModel.draggableFileListViewModel != nil {
            collectionView.dragDelegate = self
        }
        viewModel.isBound = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setInfomaniakAppearanceNavigationBar()

        #if !ISEXTENSION
            (tabBarController as? MainTabViewController)?.tabBar.centerButton?.isEnabled = viewModel.currentDirectory.capabilities.canCreateFile
        #endif

        if !viewModel.isBound {
            setupViewModel()
            viewModel.onViewDidLoad()
        } else {
            viewModel.onViewWillAppear()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MatomoUtils.track(view: ["FileList"])
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if let emptyView = collectionView?.backgroundView as? EmptyTableView {
            updateEmptyView(emptyView)
        }
        coordinator.animate { _ in
            self.collectionView?.reloadItems(at: self.collectionView.indexPathsForVisibleItems)
            self.setSelectedCells()
        }
    }

    @objc func handleLongPress(_ sender: UILongPressGestureRecognizer) {
        guard let multipleSelectionViewModel = viewModel.multipleSelectionViewModel,
              !multipleSelectionViewModel.isMultipleSelectionEnabled
        else { return }

        let pos = sender.location(in: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: pos) {
            multipleSelectionViewModel.isMultipleSelectionEnabled = true
            // Necessary for events to trigger in the right order
            DispatchQueue.main.async { [unowned self] in
                if let file = self.viewModel.getFile(at: indexPath.item) {
                    multipleSelectionViewModel.didSelectFile(file, at: indexPath.item)
                }
            }
        }
    }

    @objc func barButtonPressed(_ sender: FileListBarButton) {
        viewModel.barButtonPressed(type: sender.type)
    }

    // MARK: - Overridable methods

    func getFiles(page: Int, sortType: SortType, forceRefresh: Bool, completion: @escaping (Result<[File], Error>, Bool, Bool) -> Void) {}

    func getNewChanges() {}

    func setUpHeaderView(_ headerView: FilesHeaderView, isEmptyViewHidden: Bool) {
        headerView.delegate = self

        headerView.sortView.isHidden = !isEmptyViewHidden

        headerView.sortButton.isHidden = viewModel.configuration.sortingOptions.isEmpty
        UIView.performWithoutAnimation {
            headerView.sortButton.setTitle(viewModel.sortType.value.translation, for: .normal)
            headerView.sortButton.layoutIfNeeded()
            headerView.listOrGridButton.setImage(viewModel.listStyle.icon, for: .normal)
            headerView.listOrGridButton.layoutIfNeeded()
        }

        if let uploadViewModel = viewModel.uploadViewModel {
            headerView.uploadCardView.isHidden = uploadViewModel.uploadCount == 0
            headerView.uploadCardView.titleLabel.text = KDriveResourcesStrings.Localizable.uploadInThisFolderTitle
            headerView.uploadCardView.setUploadCount(uploadViewModel.uploadCount)
            headerView.uploadCardView.progressView.enableIndeterminate()
        }
    }

    // MARK: - Public methods

    final func reloadData(page: Int = 1, forceRefresh: Bool = false, showRefreshControl: Bool = true, withActivities: Bool = true) {}

    @objc func forceRefresh() {
        viewModel.forceRefresh()
    }

    final func observeNetwork() {
        guard networkObserver == nil else { return }
        networkObserver = ReachabilityListener.instance.observeNetworkChange(self) { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.headerView?.offlineView.isHidden = status != .offline
                self.collectionView.collectionViewLayout.invalidateLayout()
                self.collectionView.reloadItems(at: self.collectionView.indexPathsForVisibleItems)
            }
        }
    }

    private func showEmptyView(_ isHidden: Bool) {
        let emptyView = EmptyTableView.instantiate(type: viewModel.configuration.emptyViewType, button: false)
        emptyView.actionHandler = { [weak self] _ in
            self?.forceRefresh()
        }
        collectionView.backgroundView = isHidden ? nil : emptyView
        if let headerView = headerView {
            setUpHeaderView(headerView, isEmptyViewHidden: isHidden)
        }
    }

    final func removeFileFromList(id: Int) {}

    static func instantiate(viewModel: FileListViewModel) -> Self {
        let viewController = storyboard.instantiateViewController(withIdentifier: storyboardIdentifier) as! Self
        viewController.viewModel = viewModel
        viewController.driveFileManager = viewModel.driveFileManager
        return viewController
    }

    func getViewModel(viewModelName: String, driveFileManager: DriveFileManager, currentDirectory: File?) -> FileListViewModel? {
        // TODO: discuss this as this feels a little bit hacky
        if let viewModelClass = Bundle.main.classNamed("kDrive.\(viewModelName)") as? FileListViewModel.Type {
            let viewModel = viewModelClass.init(driveFileManager: driveFileManager, currentDirectory: currentDirectory)
            return viewModel
        } else {
            return nil
        }
    }

    // MARK: - Private methods

    private func updateEmptyView(_ emptyBackground: EmptyTableView) {
        if UIDevice.current.orientation.isPortrait {
            emptyBackground.emptyImageFrameViewHeightConstant.constant = 200
        }
        if UIDevice.current.orientation.isLandscape {
            emptyBackground.emptyImageFrameViewHeightConstant.constant = 120
        }
        emptyBackground.emptyImageFrameView.cornerRadius = emptyBackground.emptyImageFrameViewHeightConstant.constant / 2
    }

    private func reloadCollectionView(with files: [File]) {}

    func showQuickActionsPanel(files: [File], actionType: FileListQuickActionType) {
        #if !ISEXTENSION
            floatingPanelViewController.isRemovalInteractionEnabled = true
            switch actionType {
            case .file:
                var fileInformationsViewController = quickActionsViewController as? FileActionsFloatingPanelViewController
                if fileInformationsViewController == nil || type(of: quickActionsViewController) != FileActionsFloatingPanelViewController.self {
                    fileInformationsViewController = FileActionsFloatingPanelViewController()
                    fileInformationsViewController!.presentingParent = self
                    fileInformationsViewController!.normalFolderHierarchy = viewModel.configuration.normalFolderHierarchy

                    floatingPanelViewController.layout = FileFloatingPanelLayout(initialState: .half, hideTip: true, backdropAlpha: 0.2)
                    floatingPanelViewController.set(contentViewController: fileInformationsViewController!)

                    floatingPanelViewController.track(scrollView: fileInformationsViewController!.collectionView)
                }
                if let file = files.first {
                    fileInformationsViewController?.setFile(file, driveFileManager: driveFileManager)
                }
                quickActionsViewController = fileInformationsViewController
            case .trash:
                var trashFloatingPanelTableViewController = quickActionsViewController as? TrashFloatingPanelTableViewController
                if trashFloatingPanelTableViewController == nil {
                    trashFloatingPanelTableViewController = TrashFloatingPanelTableViewController()
                    trashFloatingPanelTableViewController!.delegate = (viewModel as? TrashListViewModel)

                    floatingPanelViewController.layout = PlusButtonFloatingPanelLayout(height: 200)
                    floatingPanelViewController.set(contentViewController: trashFloatingPanelTableViewController!)
                }
                trashFloatingPanelTableViewController?.trashedFiles = files
                quickActionsViewController = trashFloatingPanelTableViewController
            case .multipleSelection:
                var selectViewController = quickActionsViewController as? SelectFloatingPanelTableViewController
                if selectViewController == nil {
                    selectViewController = SelectFloatingPanelTableViewController()
                    selectViewController?.files = files
                    selectViewController?.driveFileManager = driveFileManager
                    floatingPanelViewController.layout = PlusButtonFloatingPanelLayout(height: 260)
                    selectViewController!.reloadAction = { [weak self] in
                        self?.viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled = false
                    }

                    floatingPanelViewController.set(contentViewController: selectViewController!)
                    floatingPanelViewController.track(scrollView: selectViewController!.collectionView)
                } else {
                    selectViewController?.files = files
                    selectViewController?.driveFileManager = driveFileManager
                    selectViewController?.setupContent()
                }

                quickActionsViewController = selectViewController
            }
            present(floatingPanelViewController, animated: true)
        #endif
    }

    // MARK: - Multiple selection

    func toggleMultipleSelection(_ on: Bool) {
        if on {
            navigationItem.title = nil
            headerView?.selectView.isHidden = false
            headerView?.selectView.setActions(viewModel.multipleSelectionViewModel?.multipleSelectionActions ?? [])
            collectionView.allowsMultipleSelection = true
            navigationController?.navigationBar.prefersLargeTitles = false
            let generator = UIImpactFeedbackGenerator()
            generator.prepare()
            generator.impactOccurred()
        } else {
            headerView?.selectView.isHidden = true
            collectionView.allowsMultipleSelection = false
            navigationController?.navigationBar.prefersLargeTitles = true
            navigationItem.title = viewModel.title
        }
        collectionView.reloadItems(at: collectionView.indexPathsForVisibleItems)
    }

    func getItem(at indexPath: IndexPath) -> File? {
        return viewModel.getFile(at: indexPath.item)
    }

    func getAllItems() -> [File] {
        return viewModel.getAllFiles()
    }

    func setSelectedCells() {
        guard let multipleSelectionViewModel = viewModel.multipleSelectionViewModel else { return }
        if multipleSelectionViewModel.isSelectAllModeEnabled {
            for i in 0 ..< viewModel.fileCount {
                collectionView.selectItem(at: IndexPath(row: i, section: 0), animated: false, scrollPosition: [])
            }
        } else {
            if multipleSelectionViewModel.isMultipleSelectionEnabled && !multipleSelectionViewModel.selectedItems.isEmpty {
                for i in 0 ..< viewModel.fileCount where multipleSelectionViewModel.selectedItems.contains(viewModel.getFile(at: i)!) {
                    collectionView.selectItem(at: IndexPath(row: i, section: 0), animated: false, scrollPosition: .centeredVertically)
                }
            }
        }
    }

    // MARK: - Collection view data source

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.fileCount
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: headerViewIdentifier, for: indexPath) as! FilesHeaderView
        setUpHeaderView(headerView, isEmptyViewHidden: viewModel.isEmptyViewHidden)
        self.headerView = headerView
        return headerView
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cellType: UICollectionViewCell.Type
        switch viewModel.listStyle {
        case .list:
            cellType = FileCollectionViewCell.self
        case .grid:
            cellType = FileGridCollectionViewCell.self
        }
        let cell = collectionView.dequeueReusableCell(type: cellType, for: indexPath) as! FileCollectionViewCell

        let file = viewModel.getFile(at: indexPath.item)!
        cell.initStyle(isFirst: indexPath.item == 0, isLast: indexPath.item == viewModel.fileCount - 1)
        cell.configureWith(driveFileManager: viewModel.driveFileManager, file: file, selectionMode: viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled == true)
        cell.delegate = self
        if ReachabilityListener.instance.currentStatus == .offline && !file.isDirectory && !file.isAvailableOffline {
            cell.setEnabled(false)
        } else {
            cell.setEnabled(true)
        }
        if viewModel.configuration.fromActivities {
            cell.moreButton.isHidden = true
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if viewModel.multipleSelectionViewModel?.isSelectAllModeEnabled == true {
            collectionView.selectItem(at: indexPath, animated: true, scrollPosition: [])
        }
    }

    // MARK: - Collection view delegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled == true {
            viewModel.multipleSelectionViewModel?.didSelectFile(viewModel.getFile(at: indexPath.item)!, at: indexPath.item)
        } else {
            viewModel.didSelectFile(at: indexPath.item)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard viewModel.multipleSelectionViewModel?.isMultipleSelectionEnabled == true,
              let file = viewModel.getFile(at: indexPath.item) else {
            return
        }
        viewModel.multipleSelectionViewModel?.didDeselectFile(file, at: indexPath.item)
    }

    // MARK: - Swipe action collection view delegate

    func collectionView(_ collectionView: SwipableCollectionView, didSelect action: SwipeCellAction, at indexPath: IndexPath) {
        viewModel.didSelectSwipeAction(action, at: indexPath.item)
    }

    // MARK: - Swipe action collection view data source

    func collectionView(_ collectionView: SwipableCollectionView, actionsFor cell: SwipableCell, at indexPath: IndexPath) -> [SwipeCellAction]? {
        return viewModel.getSwipeActions(at: indexPath.item)
    }

    // MARK: - State restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(viewModel.driveFileManager.drive.id, forKey: "DriveID")
        coder.encode(viewModel.currentDirectory.id, forKey: "DirectoryID")
        if let viewModel = viewModel {
            coder.encode(String(describing: type(of: viewModel)), forKey: "ViewModel")
        }
    }

    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)

        let driveId = coder.decodeInteger(forKey: "DriveID")
        let directoryId = coder.decodeInteger(forKey: "DirectoryID")
        let viewModelName = coder.decodeObject(of: NSString.self, forKey: "ViewModel") as String?

        // Drive File Manager should be consistent
        let maybeDriveFileManager: DriveFileManager?
        #if ISEXTENSION
            maybeDriveFileManager = AccountManager.instance.getDriveFileManager(for: driveId, userId: AccountManager.instance.currentUserId)
        #else
            if !(self is SharedWithMeViewController) {
                maybeDriveFileManager = (tabBarController as? MainTabViewController)?.driveFileManager
            } else {
                maybeDriveFileManager = AccountManager.instance.getDriveFileManager(for: driveId, userId: AccountManager.instance.currentUserId)
            }
        #endif
        guard let driveFileManager = maybeDriveFileManager else {
            // Handle error?
            return
        }
        let maybeCurrentDirectory = driveFileManager.getCachedFile(id: directoryId)

        if !(maybeCurrentDirectory == nil && directoryId > DriveFileManager.constants.rootID),
           let viewModelName = viewModelName,
           let viewModel = getViewModel(viewModelName: viewModelName, driveFileManager: driveFileManager, currentDirectory: maybeCurrentDirectory) {
            self.viewModel = viewModel
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    // MARK: - Files header view delegate

    func sortButtonPressed() {
        let floatingPanelViewController = FloatingPanelSelectOptionViewController<SortType>.instantiatePanel(options: viewModel.configuration.sortingOptions,
                                                                                                             selectedOption: viewModel.sortType,
                                                                                                             headerTitle: KDriveResourcesStrings.Localizable.sortTitle,
                                                                                                             delegate: self)
        present(floatingPanelViewController, animated: true)
    }

    func gridButtonPressed() {
        MatomoUtils.track(eventWithCategory: .displayList, name: listStyle == .grid ? "viewGrid" : "viewList")
        // Toggle grid/list
        FileListOptions.instance.currentStyle = viewModel.listStyle == .grid ? .list : .grid
        // Collection view will be reloaded via the observer
    }

    #if !ISEXTENSION
        func uploadCardSelected() {
            let uploadViewController = UploadQueueViewController.instantiate()
            uploadViewController.currentDirectory = currentDirectory
            navigationController?.pushViewController(uploadViewController, animated: true)
        }

    #endif
    func multipleSelectionActionButtonPressed(_ button: SelectView.MultipleSelectionActionButton) {
        viewModel.multipleSelectionViewModel?.actionButtonPressed(action: button.action)
    }

    func removeFilterButtonPressed(_ filter: Filterable) {}
}

// MARK: - Collection view delegate flow layout

extension FileListViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        switch viewModel.listStyle {
        case .list:
            // Important: subtract safe area insets
            let cellWidth = collectionView.bounds.width - collectionView.safeAreaInsets.left - collectionView.safeAreaInsets.right - leftRightInset * 2
            return CGSize(width: cellWidth, height: UIConstants.fileListCellHeight)
        case .grid:
            // Adjust cell size based on screen size
            let totalWidth = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
            let cellWidth = floor((totalWidth - gridInnerSpacing) / 2 - leftRightInset)
            return CGSize(width: min(cellWidth, 174), height: min(floor(cellWidth * 130 / 174), 130))
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        switch viewModel.listStyle {
        case .list:
            return 0
        case .grid:
            return gridInnerSpacing
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        switch viewModel.listStyle {
        case .list:
            return 0
        case .grid:
            return gridInnerSpacing
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: leftRightInset, bottom: 0, right: leftRightInset)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if headerView == nil {
            headerView = self.collectionView(collectionView, viewForSupplementaryElementOfKind: UICollectionView.elementKindSectionHeader, at: IndexPath(row: 0, section: section)) as? FilesHeaderView
        }
        return headerView!.systemLayoutSizeFitting(CGSize(width: collectionView.frame.width, height: UIView.layoutFittingCompressedSize.height), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
    }

    func collectionView(_ collectionView: UICollectionView, targetIndexPathForMoveOfItemFromOriginalIndexPath originalIndexPath: IndexPath, atCurrentIndexPath currentIndexPath: IndexPath, toProposedIndexPath proposedIndexPath: IndexPath) -> IndexPath {
        return originalIndexPath
    }
}

// MARK: - File cell delegate

extension FileListViewController: FileCellDelegate {
    @objc func didTapMoreButton(_ cell: FileCollectionViewCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else {
            return
        }
        viewModel.didTapMore(at: indexPath.item)
    }
}

// MARK: - Sort options delegate

extension FileListViewController: SelectDelegate {
    func didSelect(option: Selectable) {
        guard let type = option as? SortType else { return }
        MatomoUtils.track(eventWithCategory: .fileList, name: "sort-\(type.rawValue)")
        // Collection view will be reloaded via the observer
        FileListOptions.instance.currentSortType = type
    }
}

// MARK: - Switch drive delegate

#if !ISEXTENSION
    extension FileListViewController: SwitchDriveDelegate {
        func didSwitchDriveFileManager(newDriveFileManager: DriveFileManager) {
            let isDifferentDrive = newDriveFileManager.drive.objectId != driveFileManager.drive.objectId
            driveFileManager = newDriveFileManager
            if isDifferentDrive {
                currentDirectory = driveFileManager.getCachedRootFile()
                viewModel = (type(of: viewModel) as FileListViewModel.Type).init(driveFileManager: driveFileManager, currentDirectory: currentDirectory)
                bindViewModels()
                viewModel.onViewDidLoad()
                navigationController?.popToRootViewController(animated: false)
            } else {
                viewModel.driveFileManager = driveFileManager
            }
        }
    }
#endif

// MARK: - Top scrollable

extension FileListViewController: TopScrollable {
    func scrollToTop() {
        if isViewLoaded {
            collectionView.scrollToTop(animated: true, navigationController: navigationController)
        }
    }
}

// MARK: - UICollectionViewDragDelegate

extension FileListViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        if let draggableViewModel = viewModel.draggableFileListViewModel,
           let draggedFile = viewModel.getFile(at: indexPath.item) {
            return draggableViewModel.dragItems(for: draggedFile, in: collectionView, at: indexPath, with: session)
        } else {
            return []
        }
    }
}

// MARK: - UICollectionViewDropDelegate

extension FileListViewController: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        if let droppableViewModel = viewModel.droppableFileListViewModel {
            let file = destinationIndexPath != nil ? viewModel.getFile(at: destinationIndexPath!.item) : nil
            return droppableViewModel.updateDropSession(session, in: collectionView, with: destinationIndexPath, destinationFile: file)
        } else {
            return UICollectionViewDropProposal(operation: .cancel, intent: .unspecified)
        }
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        if let droppableViewModel = viewModel.droppableFileListViewModel {
            var destinationDirectory = viewModel.currentDirectory

            if let indexPath = coordinator.destinationIndexPath,
               indexPath.item < viewModel.fileCount,
               let file = viewModel.getFile(at: indexPath.item) {
                if file.isDirectory && file.rights?.uploadNewFile == true {
                    destinationDirectory = file
                }
            }

            droppableViewModel.performDrop(with: coordinator, in: collectionView, destinationDirectory: destinationDirectory)
        }
    }
}
