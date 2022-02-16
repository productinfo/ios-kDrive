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
import InfomaniakCore
import InfomaniakLogin
import kDriveCore
import XCTest

@testable import kDrive

class FakeTokenDelegate: RefreshTokenDelegate {
    func didUpdateToken(newToken: ApiToken, oldToken: ApiToken) {}

    func didFailRefreshToken(_ token: ApiToken) {}
}

final class DriveApiTests: XCTestCase {
    static let defaultTimeout = 30.0

    var currentApiFetcher: DriveApiFetcher = {
        let token = ApiToken(accessToken: Env.token,
                             expiresIn: Int.max,
                             refreshToken: "",
                             scope: "",
                             tokenType: "",
                             userId: Env.userId,
                             expirationDate: Date(timeIntervalSinceNow: TimeInterval(Int.max)))
        return DriveApiFetcher(token: token, delegate: FakeTokenDelegate())
    }()

    private let proxyDrive = ProxyDrive(id: Env.driveId)

    // MARK: - Tests setup

    func setUpTest(testName: String) async throws -> File {
        let rootDirectory = try await getRootDirectory()
        return try await createTestDirectory(name: "UnitTest - \(testName)", parentDirectory: rootDirectory)
    }

    func setUpTest(testName: String, completion: @escaping (File) -> Void) {
        Task {
            try await completion(setUpTest(testName: testName))
        }
    }

    func tearDownTest(directory: File) {
        Task {
            _ = try await currentApiFetcher.delete(file: directory)
        }
    }

    // MARK: - Helping methods

    func getRootDirectory() async throws -> File {
        try await currentApiFetcher.fileInfo(ProxyFile(driveId: Env.driveId, id: DriveFileManager.constants.rootID)).data
    }

    func createTestDirectory(name: String, parentDirectory: File) async throws -> File {
        try await currentApiFetcher.createDirectory(in: parentDirectory, name: "\(name) - \(Date())", onlyForMe: true)
    }

    func createTestDirectory(name: String, parentDirectory: File, completion: @escaping (File) -> Void) {
        Task {
            try await completion(createTestDirectory(name: name, parentDirectory: parentDirectory))
        }
    }

    func initDropbox(testName: String) async throws -> (File, File) {
        let testDirectory = try await setUpTest(testName: testName)
        let directory = try await createTestDirectory(name: "dropbox-\(Date())", parentDirectory: testDirectory)
        let settings = DropBoxSettings(alias: nil, emailWhenFinished: false, limitFileSize: nil, password: nil, validUntil: nil)
        _ = try await currentApiFetcher.createDropBox(directory: directory, settings: settings)
        return (testDirectory, directory)
    }

    func initDropbox(testName: String, completion: @escaping (File, File) -> Void) {
        Task {
            let (testDirectory, directory) = try await initDropbox(testName: testName)
            completion(testDirectory, directory)
        }
    }

    func initOfficeFile(testName: String) async throws -> (File, File) {
        let testDirectory = try await setUpTest(testName: testName)
        let file = try await currentApiFetcher.createFile(in: testDirectory, name: "officeFile-\(Date())", type: "docx")
        return (testDirectory, file)
    }

    func initOfficeFile(testName: String, completion: @escaping (File, File) -> Void) {
        Task {
            let (testDirectory, file) = try await initOfficeFile(testName: testName)
            completion(testDirectory, file)
        }
    }

    func checkIfFileIsInDestination(file: File, directory: File) async throws {
        let (files, _) = try await currentApiFetcher.files(in: directory)
        let movedFile = files.contains { $0.id == file.id }
        XCTAssertTrue(movedFile, "File should be in destination")
    }

    func checkIfFileIsInDestination(file: File, directory: File, completion: @escaping () -> Void) {
        Task {
            try await checkIfFileIsInDestination(file: file, directory: directory)
            completion()
        }
    }

    // MARK: - Test methods

    func testGetRootFile() async throws {
        let (file, _) = try await currentApiFetcher.fileInfo(ProxyFile(driveId: Env.driveId, id: DriveFileManager.constants.rootID))
        _ = try await currentApiFetcher.files(in: file)
    }

    func testGetCommonDocuments() async throws {
        let (file, _) = try await currentApiFetcher.fileInfo(ProxyFile(driveId: Env.driveId, id: Env.commonDocumentsId))
        _ = try await currentApiFetcher.files(in: file)
    }

    func testCreateDirectory() async throws {
        let testDirectory = try await setUpTest(testName: "Create directory")
        _ = try await currentApiFetcher.createDirectory(in: testDirectory, name: "Test directory", onlyForMe: true)
        tearDownTest(directory: testDirectory)
    }

    func testCreateCommonDirectory() async throws {
        let testDirectory = try await currentApiFetcher.createCommonDirectory(drive: proxyDrive, name: "Create common directory-\(Date())", forAllUser: true)
        tearDownTest(directory: testDirectory)
    }

    func testCreateFile() async throws {
        let testDirectory = try await setUpTest(testName: "Create file")
        _ = try await currentApiFetcher.createFile(in: testDirectory, name: "Test file", type: "docx")
        tearDownTest(directory: testDirectory)
    }

    func testCreateDropBox() async throws {
        let settings = DropBoxSettings(alias: nil, emailWhenFinished: false, limitFileSize: nil, password: "password", validUntil: nil)
        let testDirectory = try await setUpTest(testName: "Create dropbox")
        let dir = try await createTestDirectory(name: "Create dropbox", parentDirectory: testDirectory)
        let dropBox = try await currentApiFetcher.createDropBox(directory: dir, settings: settings)
        XCTAssertTrue(dropBox.capabilities.hasPassword, "Dropbox should have a password")
        tearDownTest(directory: testDirectory)
    }

    func testGetDropBox() async throws {
        let settings = DropBoxSettings(alias: nil, emailWhenFinished: false, limitFileSize: .gigabytes(5), password: "newPassword", validUntil: Date())
        let (testDirectory, dropBoxDir) = try await initDropbox(testName: "Dropbox settings")
        let response = try await currentApiFetcher.updateDropBox(directory: dropBoxDir, settings: settings)
        XCTAssertTrue(response, TestsMessages.shouldReturnTrue)
        let dropBox = try await currentApiFetcher.getDropBox(directory: dropBoxDir)
        XCTAssertTrue(dropBox.capabilities.hasPassword, "Dropxbox should have a password")
        XCTAssertTrue(dropBox.capabilities.hasValidity, "Dropbox should have a validity")
        XCTAssertNotNil(dropBox.capabilities.validity.date, "Validity shouldn't be nil")
        XCTAssertTrue(dropBox.capabilities.hasSizeLimit, "Dropbox should have a size limit")
        XCTAssertNotNil(dropBox.capabilities.size.limit, "Size limit shouldn't be nil")
        tearDownTest(directory: testDirectory)
    }

    func testDeleteDropBox() async throws {
        let (testDirectory, dropBoxDir) = try await initDropbox(testName: "Delete dropbox")
        _ = try await currentApiFetcher.getDropBox(directory: dropBoxDir)
        let response = try await currentApiFetcher.deleteDropBox(directory: dropBoxDir)
        XCTAssertTrue(response, TestsMessages.shouldReturnTrue)
        tearDownTest(directory: testDirectory)
    }

    func testGetFavoriteFiles() async throws {
        _ = try await currentApiFetcher.favorites(drive: proxyDrive)
    }

    func testGetMyShared() async throws {
        _ = try await currentApiFetcher.mySharedFiles(drive: proxyDrive)
    }

    func testGetLastModifiedFiles() async throws {
        _ = try await currentApiFetcher.lastModifiedFiles(drive: proxyDrive)
    }

    func testCreateShareLink() async throws {
        let testDirectory = try await setUpTest(testName: "Create share link")
        let shareLink1 = try await currentApiFetcher.createShareLink(for: testDirectory)
        let shareLink2 = try await currentApiFetcher.shareLink(for: testDirectory)
        XCTAssertEqual(shareLink1.url, shareLink2.url, "Share link url should match")
        tearDownTest(directory: testDirectory)
    }

    func testUpdateShareLink() async throws {
        let testDirectory = try await setUpTest(testName: "Update share link")
        _ = try await currentApiFetcher.createShareLink(for: testDirectory)
        let updatedSettings = ShareLinkSettings(canComment: true, canDownload: false, canEdit: true, canSeeInfo: true, canSeeStats: true, password: "password", right: .password, validUntil: nil)
        let response = try await currentApiFetcher.updateShareLink(for: testDirectory, settings: updatedSettings)
        XCTAssertTrue(response, TestsMessages.shouldReturnTrue)
        let updatedShareLink = try await currentApiFetcher.shareLink(for: testDirectory)
        XCTAssertTrue(updatedShareLink.capabilities.canComment, "canComment should be true")
        XCTAssertFalse(updatedShareLink.capabilities.canDownload, "canDownload should be false")
        XCTAssertTrue(updatedShareLink.capabilities.canEdit, "canEdit should be true")
        XCTAssertTrue(updatedShareLink.capabilities.canSeeInfo, "canSeeInfo should be true")
        XCTAssertTrue(updatedShareLink.capabilities.canSeeStats, "canSeeStats should be true")
        XCTAssertTrue(updatedShareLink.right == ShareLinkPermission.password.rawValue, "Right should be equal to 'password'")
        XCTAssertNil(updatedShareLink.validUntil, "validUntil should be nil")
        tearDownTest(directory: testDirectory)
    }

    func testRemoveShareLink() async throws {
        let testDirectory = try await setUpTest(testName: "Remove share link")
        _ = try await currentApiFetcher.createShareLink(for: testDirectory)
        let response = try await currentApiFetcher.removeShareLink(for: testDirectory)
        XCTAssertTrue(response, TestsMessages.shouldReturnTrue)
        tearDownTest(directory: testDirectory)
    }

    func testGetFileAccess() async throws {
        let testDirectory = try await setUpTest(testName: "Get file access")
        _ = try await currentApiFetcher.access(for: testDirectory)
        tearDownTest(directory: testDirectory)
    }

    func testCheckAccessChange() async throws {
        let testDirectory = try await setUpTest(testName: "Check access")
        let settings = FileAccessSettings(right: .write, emails: [Env.inviteMail], userIds: [Env.inviteUserId])
        _ = try await currentApiFetcher.checkAccessChange(to: testDirectory, settings: settings)
        tearDownTest(directory: testDirectory)
    }

    func testAddAccess() async throws {
        let testDirectory = try await setUpTest(testName: "Add access")
        let settings = FileAccessSettings(message: "Test access", right: .write, emails: [Env.inviteMail], userIds: [Env.inviteUserId])
        _ = try await currentApiFetcher.addAccess(to: testDirectory, settings: settings)
        let fileAccess = try await currentApiFetcher.access(for: testDirectory)
        let userAdded = fileAccess.users.first { $0.id == Env.inviteUserId }
        XCTAssertNotNil(userAdded, "Added user should be in share list")
        XCTAssertEqual(userAdded?.right, .write, "Added user right should be equal to 'write'")
        let invitation = fileAccess.invitations.first { $0.email == Env.inviteMail }
        XCTAssertNotNil(invitation, "Invitation should be in share list")
        XCTAssertEqual(invitation?.right, .write, "Invitation right should be equal to 'write'")
        XCTAssertTrue(fileAccess.teams.isEmpty, "There should be no team in share list")
        tearDownTest(directory: testDirectory)
    }

    func testUpdateUserAccess() async throws {
        let testDirectory = try await setUpTest(testName: "Update user access")
        let settings = FileAccessSettings(message: "Test update user access", right: .read, userIds: [Env.inviteUserId])
        let response = try await currentApiFetcher.addAccess(to: testDirectory, settings: settings)
        let user = response.users.first { $0.id == Env.inviteUserId }?.access
        XCTAssertNotNil(user, "User shouldn't be nil")
        if let user = user {
            let response = try await currentApiFetcher.updateUserAccess(to: testDirectory, user: user, right: .manage)
            XCTAssertTrue(response, TestsMessages.shouldReturnTrue)
            let fileAccess = try await currentApiFetcher.access(for: testDirectory)
            let updatedUser = fileAccess.users.first { $0.id == Env.inviteUserId }
            XCTAssertNotNil(updatedUser, "User shouldn't be nil")
            XCTAssertEqual(updatedUser?.right, .manage, "User permission should be equal to 'manage'")
        }
        tearDownTest(directory: testDirectory)
    }

    func testRemoveUserAccess() async throws {
        let testDirectory = try await setUpTest(testName: "Remove user access")
        let settings = FileAccessSettings(message: "Test remove user access", right: .read, userIds: [Env.inviteUserId])
        let response = try await currentApiFetcher.addAccess(to: testDirectory, settings: settings)
        let user = response.users.first { $0.id == Env.inviteUserId }?.access
        XCTAssertNotNil(user, "User shouldn't be nil")
        if let user = user {
            let response = try await currentApiFetcher.removeUserAccess(to: testDirectory, user: user)
            XCTAssertTrue(response, TestsMessages.shouldReturnTrue)
            let fileAccess = try await currentApiFetcher.access(for: testDirectory)
            let deletedUser = fileAccess.users.first { $0.id == Env.inviteUserId }
            XCTAssertNil(deletedUser, "Deleted user should be nil")
        }
        tearDownTest(directory: testDirectory)
    }

    func testUpdateInvitationAccess() async throws {
        let testDirectory = try await setUpTest(testName: "Update invitation access")
        let settings = FileAccessSettings(message: "Test update invitation access", right: .read, emails: [Env.inviteMail])
        let response = try await currentApiFetcher.addAccess(to: testDirectory, settings: settings)
        let invitation = response.emails.first { $0.id == Env.inviteMail }?.access
        XCTAssertNotNil(invitation, "Invitation shouldn't be nil")
        if let invitation = invitation {
            let response = try await currentApiFetcher.updateInvitationAccess(drive: proxyDrive, invitation: invitation, right: .write)
            XCTAssertTrue(response, TestsMessages.shouldReturnTrue)
            let fileAccess = try await currentApiFetcher.access(for: testDirectory)
            let updatedInvitation = fileAccess.invitations.first { $0.email == Env.inviteMail }
            XCTAssertNotNil(updatedInvitation, "Invitation shouldn't be nil")
            XCTAssertEqual(updatedInvitation?.right, .write, "Invitation right should be equal to 'write'")
        }
        tearDownTest(directory: testDirectory)
    }

    func testDeleteInvitation() async throws {
        let testDirectory = try await setUpTest(testName: "Delete invitation")
        let settings = FileAccessSettings(message: "Test delete invitation", right: .read, emails: [Env.inviteMail])
        let response = try await currentApiFetcher.addAccess(to: testDirectory, settings: settings)
        let invitation = response.emails.first { $0.id == Env.inviteMail }?.access
        XCTAssertNotNil(invitation, "Invitation shouldn't be nil")
        if let invitation = invitation {
            let response = try await currentApiFetcher.deleteInvitation(drive: proxyDrive, invitation: invitation)
            XCTAssertTrue(response, TestsMessages.shouldReturnTrue)
            let fileAccess = try await currentApiFetcher.access(for: testDirectory)
            let deletedInvitation = fileAccess.invitations.first { $0.email == Env.inviteMail }
            XCTAssertNil(deletedInvitation, "Deleted invitation should be nil")
        }
        tearDownTest(directory: testDirectory)
    }

    func createCommonDirectory(testName: String) async throws -> File {
        try await currentApiFetcher.createCommonDirectory(drive: proxyDrive, name: "UnitTest-\(testName)-\(Date())", forAllUser: false)
    }

    func testUpdateTeamAccess() async throws {
        let testDirectory = try await createCommonDirectory(testName: "Update team access")
        let settings = FileAccessSettings(message: "Test update team access", right: .read, teamIds: [Env.inviteTeam])
        let response = try await currentApiFetcher.addAccess(to: testDirectory, settings: settings)
        let team = response.teams.first { $0.id == Env.inviteTeam }?.access
        XCTAssertNotNil(team, "Team shouldn't be nil")
        if let team = team {
            let response = try await currentApiFetcher.updateTeamAccess(to: testDirectory, team: team, right: .write)
            XCTAssertTrue(response, TestsMessages.shouldReturnTrue)
            let fileAccess = try await currentApiFetcher.access(for: testDirectory)
            let updatedTeam = fileAccess.teams.first { $0.id == Env.inviteTeam }
            XCTAssertNotNil(updatedTeam, "Team shouldn't be nil")
            XCTAssertEqual(updatedTeam?.right, .write, "Team right should be equal to 'write'")
        }
        tearDownTest(directory: testDirectory)
    }

    func testRemoveTeamAccess() async throws {
        let testDirectory = try await createCommonDirectory(testName: "Update team access")
        let settings = FileAccessSettings(message: "Test remove team access", right: .read, teamIds: [Env.inviteTeam])
        let response = try await currentApiFetcher.addAccess(to: testDirectory, settings: settings)
        let team = response.teams.first { $0.id == Env.inviteTeam }?.access
        XCTAssertNotNil(team, "Invitation shouldn't be nil")
        if let team = team {
            let response = try await currentApiFetcher.removeTeamAccess(to: testDirectory, team: team)
            XCTAssertTrue(response, TestsMessages.shouldReturnTrue)
            let fileAccess = try await currentApiFetcher.access(for: testDirectory)
            let deletedTeam = fileAccess.teams.first { $0.id == Env.inviteTeam }
            XCTAssertNil(deletedTeam, "Deleted team should be nil")
        }
        tearDownTest(directory: testDirectory)
    }

    func testFileInfo() async throws {
        let testDirectory = try await setUpTest(testName: "Get file detail")
        _ = try await currentApiFetcher.fileInfo(testDirectory)
        tearDownTest(directory: testDirectory)
    }

    func testGetComments() async throws {
        let testDirectory = try await setUpTest(testName: "Get comments")
        _ = try await currentApiFetcher.comments(file: testDirectory, page: 1)
        tearDownTest(directory: testDirectory)
    }

    func testAddComment() async throws {
        let (testDirectory, file) = try await initOfficeFile(testName: "Add comment")
        let comment = try await currentApiFetcher.addComment(to: file, body: "Testing comment")
        XCTAssertEqual(comment.body, "Testing comment", "Comment body should be equal to 'Testing comment'")
        let comments = try await currentApiFetcher.comments(file: file, page: 1)
        XCTAssertNotNil(comments.first { $0.id == comment.id }, "Comment should exist")
        tearDownTest(directory: testDirectory)
    }

    func testLikeComment() async throws {
        let (testDirectory, file) = try await initOfficeFile(testName: "Like comment")
        let comment = try await currentApiFetcher.addComment(to: file, body: "Testing comment")
        let response = try await currentApiFetcher.likeComment(file: file, liked: false, comment: comment)
        XCTAssertTrue(response, TestsMessages.shouldReturnTrue)
        let comments = try await currentApiFetcher.comments(file: file, page: 1)
        guard let fetchedComment = comments.first(where: { $0.id == comment.id }) else {
            XCTFail("Comment should exist")
            tearDownTest(directory: testDirectory)
            return
        }
        XCTAssertTrue(fetchedComment.liked, "Comment should be liked")
        tearDownTest(directory: testDirectory)
    }

    func testDeleteComment() async throws {
        let (testDirectory, file) = try await initOfficeFile(testName: "Delete comment")
        let comment = try await currentApiFetcher.addComment(to: file, body: "Testing comment")
        let response = try await currentApiFetcher.deleteComment(file: file, comment: comment)
        XCTAssertTrue(response, TestsMessages.shouldReturnTrue)
        let comments = try await currentApiFetcher.comments(file: file, page: 1)
        XCTAssertNil(comments.first { $0.id == comment.id }, "Comment should be deleted")
        tearDownTest(directory: testDirectory)
    }

    func testEditComment() async throws {
        let (testDirectory, file) = try await initOfficeFile(testName: "Edit comment")
        let comment = try await currentApiFetcher.addComment(to: file, body: "Testing comment")
        let editedBody = "Edited comment"
        let response = try await currentApiFetcher.editComment(file: file, body: editedBody, comment: comment)
        XCTAssertTrue(response, TestsMessages.shouldReturnTrue)
        let comments = try await currentApiFetcher.comments(file: file, page: 1)
        guard let editedComment = comments.first(where: { $0.id == comment.id }) else {
            XCTFail("Edited comment should exist")
            tearDownTest(directory: testDirectory)
            return
        }
        XCTAssertEqual(editedComment.body, editedBody, "Edited comment body is wrong")
        tearDownTest(directory: testDirectory)
    }

    func testAnswerComment() async throws {
        let (testDirectory, file) = try await initOfficeFile(testName: "Answer comment")
        let comment = try await currentApiFetcher.addComment(to: file, body: "Testing comment")
        let answer = try await currentApiFetcher.answerComment(file: file, body: "Answer comment", comment: comment)
        let comments = try await currentApiFetcher.comments(file: file, page: 1)
        guard let fetchedComment = comments.first(where: { $0.id == comment.id }) else {
            XCTFail("Comment should exist")
            tearDownTest(directory: testDirectory)
            return
        }
        XCTAssertNotNil(fetchedComment.responses?.first { $0.id == answer.id }, "Answer should exist")
        tearDownTest(directory: testDirectory)
    }

    func testDeleteFile() async throws {
        let testDirectory = try await setUpTest(testName: "Delete file")
        let directory = try await createTestDirectory(name: "Delete file", parentDirectory: testDirectory)
        _ = try await currentApiFetcher.delete(file: directory)
        // Check that file has been deleted
        let (files, _) = try await currentApiFetcher.files(in: testDirectory)
        let deletedFile = files.first { $0.id == directory.id }
        XCTAssertNil(deletedFile, TestsMessages.notNil("trashed file"))
        // Check that file is in trash
        let trashedFiles = try await currentApiFetcher.trashedFiles(drive: proxyDrive, sortType: .newerDelete)
        let fileInTrash = trashedFiles.first { $0.id == directory.id }
        XCTAssertNotNil(fileInTrash, TestsMessages.notNil("trashed file"))
        if let file = fileInTrash {
            // Delete definitely
            let response = try await currentApiFetcher.deleteDefinitely(file: file)
            XCTAssertTrue(response, TestsMessages.shouldReturnTrue)
            // Check that file is not in trash anymore
            let trashedFiles = try await currentApiFetcher.trashedFiles(drive: proxyDrive, sortType: .newerDelete)
            let deletedDefinitelyFile = trashedFiles.first { $0.id == file.id }
            XCTAssertNil(deletedDefinitelyFile, TestsMessages.notNil("deleted file"))
        }
        tearDownTest(directory: testDirectory)
    }

    func testRenameFile() async throws {
        let (testDirectory, file) = try await initOfficeFile(testName: "Rename file")
        let newName = "renamed office file"
        _ = try await currentApiFetcher.rename(file: file, newName: newName)
        tearDownTest(directory: testDirectory)
    }

    func testDuplicateFile() async throws {
        let (testDirectory, file) = try await initOfficeFile(testName: "Duplicate file")
        _ = try await currentApiFetcher.duplicate(file: file, duplicateName: "duplicate-\(Date())")
        let (files, _) = try await currentApiFetcher.files(in: testDirectory)
        XCTAssertEqual(files.count, 2, "Root file should have 2 children")
        tearDownTest(directory: testDirectory)
    }

    func testCopyFile() async throws {
        let (testDirectory, file) = try await initOfficeFile(testName: "Copy file")
        let copiedFile = try await currentApiFetcher.copy(file: file, to: testDirectory)
        try await checkIfFileIsInDestination(file: copiedFile, directory: testDirectory)
        tearDownTest(directory: testDirectory)
    }

    func testMoveFile() async throws {
        let (testDirectory, file) = try await initOfficeFile(testName: "Move file")
        let destination = try await createTestDirectory(name: "destination-\(Date())", parentDirectory: testDirectory)
        _ = try await currentApiFetcher.move(file: file, to: destination)
        try await checkIfFileIsInDestination(file: file, directory: destination)
        tearDownTest(directory: testDirectory)
    }

    func testGetRecentActivity() async throws {
        _ = try await currentApiFetcher.recentActivity(drive: proxyDrive)
    }

    func testGetFileActivities() async throws {
        let testDirectory = try await setUpTest(testName: "Get file detail activity")
        _ = try await currentApiFetcher.fileActivities(file: testDirectory, page: 1)
        tearDownTest(directory: testDirectory)
    }

    func testGetFileActivitiesFromDate() async throws {
        let earlyDate = Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
        let (testDirectory, file) = try await initOfficeFile(testName: "Get file activity from date")
        _ = try await currentApiFetcher.fileActivities(file: file, from: earlyDate, page: 1)
        tearDownTest(directory: testDirectory)
    }

    func testGetFilesActivities() async throws {
        let (testDirectory, file) = try await initOfficeFile(testName: "Get files activities")
        let secondFile = try await currentApiFetcher.createFile(in: testDirectory, name: "Get files activities-\(Date())", type: "docx")
        let (result, _) = try await currentApiFetcher.filesActivities(drive: proxyDrive, files: [file, secondFile], from: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(result.activities.count, 2, "Array should contain two activities")
        for activity in result.activities {
            XCTAssertNotNil(activity, TestsMessages.notNil("file activity"))
        }
        tearDownTest(directory: testDirectory)
    }

    func testFavoriteFile() async throws {
        let (testDirectory, file) = try await initOfficeFile(testName: "Favorite file")
        // Favorite
        let favoriteResponse = try await currentApiFetcher.favorite(file: file)
        XCTAssertTrue(favoriteResponse, TestsMessages.shouldReturnTrue)
        let files = try await currentApiFetcher.favorites(drive: proxyDrive, sortType: .newer)
        let favoriteFile = files.first { $0.id == file.id }
        XCTAssertNotNil(favoriteFile, "File should be in Favorite files")
        XCTAssertTrue(favoriteFile?.isFavorite == true, "File should be favorite")
        // Unfavorite
        let unfavoriteResponse = try await currentApiFetcher.unfavorite(file: file)
        XCTAssertTrue(unfavoriteResponse, TestsMessages.shouldReturnTrue)
        let files2 = try await currentApiFetcher.favorites(drive: proxyDrive, sortType: .newer)
        let unfavoriteFile = files2.first { $0.id == file.id }
        XCTAssertNil(unfavoriteFile, "File should be in Favorite files")
        // Check file
        let (finalFile, _) = try await currentApiFetcher.fileInfo(file)
        XCTAssertFalse(finalFile.isFavorite, "File shouldn't be favorite")
        tearDownTest(directory: testDirectory)
    }

    func testPerformAuthenticatedRequest() {
        let testName = "Perform authenticated request"
        let expectation = XCTestExpectation(description: testName)

        let token = currentApiFetcher.currentToken!
        currentApiFetcher.performAuthenticatedRequest(token: token) { apiToken, error in
            XCTAssertNil(error, TestsMessages.noError)
            XCTAssertNotNil(apiToken, TestsMessages.notNil("API Token"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
    }

    func testGetPublicUploadTokenWithToken() {
        let testName = "Get public upload token with token"
        let expectation = XCTestExpectation(description: testName)

        let token = currentApiFetcher.currentToken!
        currentApiFetcher.getPublicUploadTokenWithToken(token, driveId: Env.driveId) { apiResponse, error in
            XCTAssertNil(error, TestsMessages.noError)
            XCTAssertNotNil(apiResponse?.data, TestsMessages.notNil("API Response"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: DriveApiTests.defaultTimeout)
    }

    func testTrashedFiles() async throws {
        _ = try await currentApiFetcher.trashedFiles(drive: proxyDrive, sortType: .newerDelete)
    }

    func testTrashedFilesOf() async throws {
        let (testDirectory, _) = try await initOfficeFile(testName: "Get children trashed file")
        _ = try await currentApiFetcher.delete(file: testDirectory)
        let files = try await currentApiFetcher.trashedFiles(of: testDirectory)
        XCTAssertEqual(files.count, 1, "There should be one file in the trashed directory")
    }

    func testRestoreTrashedFile() async throws {
        let (testDirectory, file) = try await initOfficeFile(testName: "Restore trashed file")
        _ = try await currentApiFetcher.delete(file: file)
        _ = try await currentApiFetcher.restore(file: file)
        try await checkIfFileIsInDestination(file: file, directory: testDirectory)
        tearDownTest(directory: testDirectory)
    }

    func testRestoreTrashedFileInFolder() async throws {
        let (testDirectory, file) = try await initOfficeFile(testName: "Restore trashed file in folder")
        _ = try await currentApiFetcher.delete(file: file)
        let directory = try await createTestDirectory(name: "restore destination - \(Date())", parentDirectory: testDirectory)
        _ = try await currentApiFetcher.restore(file: file, in: directory)
        try await checkIfFileIsInDestination(file: file, directory: directory)
        tearDownTest(directory: testDirectory)
    }

    func testSearchFiles() async throws {
        let (testDirectory, file) = try await initOfficeFile(testName: "Search files")
        let files = try await currentApiFetcher.searchFiles(drive: proxyDrive, query: "officeFile", categories: [], belongToAllCategories: true)
        let fileFound = files.contains { $0.id == file.id }
        XCTAssertTrue(fileFound, "File created should be in response")
        tearDownTest(directory: testDirectory)
    }

    func testUndoAction() async throws {
        let (testDirectory, file) = try await initOfficeFile(testName: "Undo action")
        let directory = try await createTestDirectory(name: "test", parentDirectory: testDirectory)
        // Move & cancel
        let moveResponse = try await currentApiFetcher.move(file: file, to: directory)
        try await currentApiFetcher.undoAction(drive: proxyDrive, cancelId: moveResponse.id)
        try await checkIfFileIsInDestination(file: file, directory: testDirectory)
        // Delete & cancel
        let deleteResponse = try await currentApiFetcher.delete(file: file)
        try await currentApiFetcher.undoAction(drive: proxyDrive, cancelId: deleteResponse.id)
        try await checkIfFileIsInDestination(file: file, directory: testDirectory)
        tearDownTest(directory: testDirectory)
    }

    func testGetFileCount() async throws {
        let (testDirectory, _) = try await initOfficeFile(testName: "Get file count")
        _ = try await currentApiFetcher.createFile(in: testDirectory, name: "secondFile-\(Date())", type: "docx")
        _ = try await currentApiFetcher.createDirectory(in: testDirectory, name: "directory-\(Date())", onlyForMe: true)
        let count = try await currentApiFetcher.count(of: testDirectory)
        XCTAssertEqual(count.count, 3, "Root file should contain 3 elements")
        XCTAssertEqual(count.files, 2, "Root file should contain 2 files")
        XCTAssertEqual(count.directories, 1, "Root file should contain 1 folder")
        tearDownTest(directory: testDirectory)
    }

    func testBuildArchive() async throws {
        let (testDirectory, file) = try await initOfficeFile(testName: "Build archive")
        _ = try await currentApiFetcher.buildArchive(drive: proxyDrive, for: [file])
        tearDownTest(directory: testDirectory)
    }

    // MARK: - Complementary tests

    func testCategory() async throws {
        let testDirectory = try await setUpTest(testName: "Categories")
        // 1. Create category
        let category = try await currentApiFetcher.createCategory(drive: proxyDrive, name: "UnitTest-\(Date())", color: "#1abc9c")
        // 2. Add category to folder
        let addResponse = try await currentApiFetcher.add(category: category, to: testDirectory)
        XCTAssertTrue(addResponse, TestsMessages.shouldReturnTrue)
        // 3. Remove category from folder
        let removeResponse = try await currentApiFetcher.remove(category: category, from: testDirectory)
        XCTAssertTrue(removeResponse, TestsMessages.shouldReturnTrue)
        // 4. Delete category
        let deleteResponse = try await currentApiFetcher.deleteCategory(drive: proxyDrive, category: category)
        XCTAssertTrue(deleteResponse, TestsMessages.shouldReturnTrue)
        tearDownTest(directory: testDirectory)
    }

    func testDirectoryColor() async throws {
        let testDirectory = try await setUpTest(testName: "DirectoryColor")
        let result = try await currentApiFetcher.updateColor(directory: testDirectory, color: "#E91E63")
        XCTAssertTrue(result, TestsMessages.shouldReturnTrue)
        tearDownTest(directory: testDirectory)
    }
}
