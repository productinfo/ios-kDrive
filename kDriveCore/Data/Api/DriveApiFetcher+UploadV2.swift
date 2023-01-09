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

import Alamofire
import Foundation
import InfomaniakCore

public extension DriveApiFetcher {
    // MARK: Upload V2
    
    /// Conflict resolution options
    enum ConflictResolution: String {
        /// An error is thrown without creating the file/session.
        case throwError = "error"
        /// Rename the new file with an available name (ex. file.txt to file(3).txt).
        case rename
        /// Replace the content of the existing file (create a new version of the file).
        case version
    }
    
    /// The maximun number of chunks supported
    static let APIMaxChunks = 10000
    
    /// You should send at least one chunk
    static let APIMinChunks = 1
    
    enum APIParameters: String {
        case driveID = "drive_id"
        case conflict
        case createdAt = "created_at"
        case directoryID = "directory_id"
        case directoryPath = "directory_path"
        case fileID = "file_id"
        case fileName = "file_name"
        case lastModifiedAt = "last_modified_at"
        case totalChunks = "total_chunks"
        case totalSize = "total_size"
    }
    
    /// Starts a session to upload a file in multiple parts
    ///
    /// https://developer.infomaniak.com/docs/api/post/2/drive/%7Bdrive_id%7D/upload/session/start
    ///
    /// - Parameters:
    ///   - drive: the abstract drive, REQUIRED
    ///   - totalSize: the total size of the file, in Bytes REQUIRED
    ///   - fileName: name of the file
    ///   - conflictResolution: conflict resolution selection
    ///   - totalChunks: the count of chunks the backend should expect
    ///   - lastModifiedAt: override last modified date
    ///   - createdAt: override created at
    ///   - directoryID: The directory destination root of the new file. Must be a directory.
    /// If the identifier is unknown you can use only directory_path.
    /// The identifier 1 is the user root folder.
    /// Required without directory_path
    ///   - directoryPath: The destination path of the new file. If the directory_id is provided the directory path is used as a relative path, otherwise it will be used as an absolute path. The destination should be a directory.
    /// If the directory path does not exist, folders are created automatically.
    /// The path is a destination path, the file name should not be provided at the end.
    /// Required without directory_id.
    ///   - fileID: File identifier of uploaded file.
    ///
    /// - Returns: Void, the method will return without error in a success
    func startSession(drive: AbstractDrive,
                      totalSize: UInt64,
                      fileName: String,
                      totalChunks: UInt64,
                      conflictResolution: ConflictResolution? = nil,
                      lastModifiedAt: Date? = nil,
                      createdAt: Date? = nil,
                      directoryID: Int? = nil,
                      directoryPath: String? = nil,
                      fileID: Int? = nil) async throws -> UploadSessionData
    {
        // Parameter validation
        guard directoryID != nil || directoryPath != nil else {
            throw DriveError.UploadSessionError.invalidDirectoryParameters
        }
        
        guard !fileName.isEmpty else {
            throw DriveError.UploadSessionError.fileNameIsEmpty
        }
        
        guard totalChunks < Self.APIMaxChunks && totalChunks >= Self.APIMinChunks else {
            throw DriveError.UploadSessionError.chunksNumberOutOfBounds
        }
        
        // Build parameters
        var parameters: Parameters = [APIParameters.driveID.rawValue: drive.id,
                                      APIParameters.totalSize.rawValue: totalSize,
                                      APIParameters.fileName.rawValue: fileName,
                                      APIParameters.totalChunks.rawValue: totalChunks]
        
        if let conflictResolution {
            parameters[APIParameters.conflict.rawValue] = conflictResolution.rawValue
        }
        
        // TODO: ask if expecting ts, doc does not say
        if let lastModifiedAt {
            parameters[APIParameters.lastModifiedAt.rawValue] = "\(lastModifiedAt.timeIntervalSince1970)"
        }
        
        // TODO: ask if expecting ts, doc does not say
        if let createdAt {
            parameters[APIParameters.createdAt.rawValue] = "\(createdAt.timeIntervalSince1970)"
        }
        
        if let directoryID {
            parameters[APIParameters.directoryID.rawValue] = directoryID
        }
        
        if let directoryPath {
            parameters[APIParameters.directoryPath.rawValue] = directoryPath
        }
        
        if let fileID {
            parameters[APIParameters.fileID.rawValue] = fileID
        }
        
        let request = authenticatedRequest(.startSession(drive: drive), method: .post, parameters: parameters)

        let result: UploadSessionData = try await perform(request: request).data
        return result
    }
    
    func getSession(drive: AbstractDrive) async throws -> [Int] {
        return []
    }
    
    func cancelSession(drive: AbstractDrive) async throws -> [Int] {
        return []
    }
    
    func closeSession(drive: AbstractDrive) async throws -> [Int] {
        return []
    }
    
    func appendChunk(drive: AbstractDrive, Session: String) async throws -> [Int] {
        return []
    }
}
