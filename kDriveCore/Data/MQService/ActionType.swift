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

import Foundation

public enum BulkActionType: String, Codable {
    case trash
    case move
    case copy
}

enum SimpleAction: String, Codable {
    case create
    case update
    case delete
}

enum Action: String, Codable {
    case fileCreate = "file_create"
    case fileRename = "file_rename"
    case fileMove = "file_move"
    case fileRestore = "file_restore"
    case fileTrash = "file_trash"
    case fileUpdate = "file_update"
    case reload
}

enum ExternalImportAction: String, Codable {
    case importStarted = "import_started"
    case createFile = "create_file"
    case importFinish = "import_finish"
    case cancel
}
