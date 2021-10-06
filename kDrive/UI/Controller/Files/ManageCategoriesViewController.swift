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
import RealmSwift
import UIKit

class ManageCategoriesViewController: UITableViewController {
    var driveFileManager: DriveFileManager!
    var file: File!

    lazy var categories = Array(driveFileManager.drive.categories)
    var filteredCategories = [kDriveCore.Category]()

    private var isSearchBarEmpty: Bool {
        return searchController.searchBar.text?.isEmpty ?? true
    }

    private var isFiltering: Bool {
        return searchController.isActive && !isSearchBarEmpty
    }

    private let searchController = UISearchController(searchResultsController: nil)

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(cellView: CategoryTableViewCell.self)
        tableView.keyboardDismissMode = .onDrag

        searchController.hidesNavigationBarDuringPresentation = false
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        if #available(iOS 13.0, *) {
            searchController.searchBar.searchTextField.backgroundColor = KDriveAsset.backgroundCardViewColor.color
        }

        navigationItem.searchController = searchController
        definesPresentationContext = true

        // Select categories
        for category in file.categories {
            if let category = categories.first(where: { $0.id == category.id }) {
                category.isSelected = true
            }
        }
    }

    static func instantiate(file: File, driveFileManager: DriveFileManager) -> ManageCategoriesViewController {
        let viewController = Storyboard.files.instantiateViewController(withIdentifier: "ManageCategoriesViewController") as! ManageCategoriesViewController
        viewController.file = file
        viewController.driveFileManager = driveFileManager
        return viewController
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isFiltering ? filteredCategories.count : categories.count
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let category = isFiltering ? filteredCategories[indexPath.row] : categories[indexPath.row]
        if category.isSelected {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: CategoryTableViewCell.self, for: indexPath)

        let category = isFiltering ? filteredCategories[indexPath.row] : categories[indexPath.row]
        let count = isFiltering ? filteredCategories.count : categories.count

        cell.initWithPositionAndShadow(isFirst: indexPath.row == 0, isLast: indexPath.row == count - 1)
        cell.configure(with: category)

        return cell
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let category = isFiltering ? filteredCategories[indexPath.row] : categories[indexPath.row]
        category.isSelected = true
        driveFileManager.apiFetcher.addCategory(file: file, category: category) { response, _ in
            if response?.data == nil {
                // Error
                category.isSelected = false
                tableView.deselectRow(at: indexPath, animated: true)
                UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorGeneric)
            }
        }
    }

    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let category = isFiltering ? filteredCategories[indexPath.row] : categories[indexPath.row]
        category.isSelected = false
        driveFileManager.apiFetcher.removeCategory(file: file, category: category) { response, _ in
            if response?.data == nil {
                // Error
                category.isSelected = true
                tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
                UIConstants.showSnackBar(message: KDriveStrings.Localizable.errorGeneric)
            }
        }
    }
}

extension ManageCategoriesViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        if let searchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespaces).lowercased() {
            filteredCategories = Array(categories).filter { $0.localizedName.lowercased().contains(searchText) }
            tableView.reloadData()
        }
    }
}
