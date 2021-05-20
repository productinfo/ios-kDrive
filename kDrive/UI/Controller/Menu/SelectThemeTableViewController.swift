//
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

@available(iOS 13.0, *)
class SelectThemeTableViewController: UITableViewController {

    private enum Theme: String {
        case dark
        case light
        case system
    }

    private var tableContent: [Theme] = [.light, .dark, .system]
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var selectedTheme: Theme!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Sélection du thème"

        tableView.register(cellView: ThemeSelectionTableViewCell.self)
        tableView.separatorColor = .clear
        tableView.allowsMultipleSelection = false

        let defaults = UserDefaults.standard
        let theme = defaults.object(forKey: "Theme") as! String
        selectedTheme = Theme(rawValue: theme)!
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableContent.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(type: ThemeSelectionTableViewCell.self, for: indexPath)
        let currentTheme = tableContent[indexPath.row]
        if currentTheme == selectedTheme {
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        }
        switch currentTheme {
        case .dark:
            cell.themeLabel.text = "sombre"
        case .light:
            cell.themeLabel.text = "clair"
        case .system:
            cell.themeLabel.text = "système"
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch tableContent[indexPath.row] {
        case .light:
            appDelegate.window?.overrideUserInterfaceStyle = .light
        case .dark:
            appDelegate.window?.overrideUserInterfaceStyle = .dark
        case .system:
            appDelegate.window?.overrideUserInterfaceStyle = .unspecified
        }

        let defaults = UserDefaults.standard
        defaults.setValue(tableContent[indexPath.row].rawValue, forKey: "Theme")
    }

}
