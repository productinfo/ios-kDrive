/*
 Infomaniak kDrive - iOS App
 Copyright (C) 2023 Infomaniak Network SA

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
import InfomaniakConcurrency
import InfomaniakCore
import PDFKit
import Photos
import QuickLookThumbnailing
import RealmSwift
import VisionKit

public extension FileImportHelper {
    func saveForUpload(_ files: [ImportedFile], in directory: File, drive: Drive, addToQueue: Bool) async throws {
        guard directory.capabilities.canUpload else {
            throw ImportError.accessDenied
        }

        let expiringActivity = ExpiringActivity()
        expiringActivity.start()

        let parentDirectoryId = directory.id
        let userId = drive.userId
        let driveId = drive.id

        await files.concurrentForEach { file in
            let uploadFile = UploadFile(
                parentDirectoryId: parentDirectoryId,
                userId: userId,
                driveId: driveId,
                url: file.path,
                name: file.name
            )

            self.uploadQueue.saveToRealm(uploadFile, addToQueue: addToQueue)
        }

        expiringActivity.endAll()
    }

    func upload(
        scan: VNDocumentCameraScan,
        name: String,
        scanType: ScanFileFormat,
        in directory: File,
        drive: Drive
    ) async throws {
        if !directory.capabilities.canUpload {
            throw ImportError.accessDenied
        }

        let data: Data?
        let name = name.addingExtension(scanType.extension)
        switch scanType {
        case .pdf:
            let pdfDocument = PDFDocument()

            // TODO: parallel task mapper
            for i in 0 ..< scan.pageCount {
                let pageImage = scan.imageOfPage(at: i)
                // Compress page image before adding it to the PDF
                guard let pageData = pageImage.jpegData(compressionQuality: imageCompression),
                      let compressedPageImage = UIImage(data: pageData) else {
                    continue
                }

                let pdfPage: PDFPage?
                pdfPage = PDFPage(image: compressedPageImage)

                guard let pdfPage else {
                    continue
                }

                // Set page size to something printable
                pdfPage.setBounds(pdfPageRect, for: .mediaBox)

                pdfDocument.insert(pdfPage, at: i)
            }

            data = pdfDocument.dataRepresentation()
        case .image:
            let image = scan.imageOfPage(at: 0)
            data = image.jpegData(compressionQuality: imageCompression)
        }
        guard let data else {
            throw ImportError.emptyImageData
        }
        try upload(data: data, name: name, uti: scanType.uti, drive: drive, directory: directory)
    }

    /// Get a standard printable page size
    private var pdfPageRect: CGRect {
        let locale = NSLocale.current
        let isMetric = locale.usesMetricSystem

        // Size is expressed in PostScript points
        let pageSize: CGSize
        if isMetric {
            // Using A4
            let metricPageSize = CGSize(width: 595.28, height: 841.89)
            pageSize = metricPageSize
        } else {
            // Using LETTER
            let freedomPageSize = CGSize(width: 612.00, height: 792.00)
            pageSize = freedomPageSize
        }

        let pageRect = CGRect(origin: CGPoint(x: 0, y: 0), size: pageSize)
        return pageRect
    }

    func upload(photo: UIImage, name: String, format: PhotoFileFormat, in directory: File, drive: Drive) throws {
        guard directory.capabilities.canUpload else {
            throw ImportError.accessDenied
        }

        let name = name.addingExtension(format.extension)
        let data: Data?
        switch format {
        case .jpg:
            data = photo.jpegData(compressionQuality: imageCompression)
        case .heic:
            data = photo.heicData(compressionQuality: imageCompression)
        case .png:
            var photo = photo
            if photo.imageOrientation != .up {
                let format = photo.imageRendererFormat
                photo = UIGraphicsImageRenderer(size: photo.size, format: format).image { _ in
                    photo.draw(at: .zero)
                }
            }
            data = photo.pngData()
        }
        guard let data else {
            throw ImportError.emptyImageData
        }
        try upload(data: data, name: name, uti: format.uti, drive: drive, directory: directory)
    }

    func upload(videoUrl: URL, name: String, in directory: File, drive: Drive) throws {
        guard directory.capabilities.canUpload else {
            throw ImportError.accessDenied
        }

        let uti = UTI.quickTimeMovie
        let name = name.addingExtension(uti.preferredFilenameExtension ?? "mov")
        let data = try Data(contentsOf: videoUrl)
        try upload(data: data, name: name, uti: uti, drive: drive, directory: directory)
    }

    /// Common upload method
    internal func upload(data: Data, name: String, uti: UTI, drive: Drive, directory: File) throws {
        let targetURL = generateImportURL(for: uti)
        try data.write(to: targetURL)
        let newFile = UploadFile(
            parentDirectoryId: directory.id,
            userId: drive.userId,
            driveId: drive.id,
            url: targetURL,
            name: name
        )
        uploadQueue.saveToRealm(newFile)
    }
}

public extension FileImportHelper {
    func generateImportURL(for contentType: UTI?) -> URL {
        var url = pathProvider.importDirectoryURL.appendingPathComponent(UUID().uuidString, isDirectory: false)
        if let uti = contentType {
            url.appendPathExtension(for: uti)
        }
        return url
    }

    static func getDefaultFileName(date: Date = Date()) -> String {
        return URL.defaultFileName(date: date)
    }
}
