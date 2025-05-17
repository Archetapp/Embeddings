import Foundation
import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import AVFoundation
import Vision
import ImageIO
import AVKit

// Add AVMetadataIdentifier extensions for iTunes metadata
extension AVMetadataIdentifier {
    static let iTunesMetadataTrackSubTitle = AVMetadataIdentifier("com.apple.itunes.subtitle")
    static let iTunesMetadataReleaseDate = AVMetadataIdentifier("com.apple.itunes.release-date")
    static let iTunesMetadataTrackNumber = AVMetadataIdentifier("com.apple.itunes.track-number")
}

extension Document {
    class Handler {
        enum DocumentError: Error {
            case failedToReadData
            case unsupportedFileType
            case textExtractionFailed
            case imageAnalysisFailed
            case videoAnalysisFailed
            case audioAnalysisFailed
            case mlModelLoadFailed
        }
        
        enum FileType: String, Codable {
            case text
            case image
            case video
            case audio
            case pdf
            case unknown
        }
        
        static let supportedTypes: [UTType] = [
            // Text files
            .plainText,
            .pdf,
            .rtf,
            .html,
            .xml,
            .propertyList,
            .json,
            UTType(filenameExtension: "yaml")!,
            UTType(filenameExtension: "md")!,
            UTType(filenameExtension: "markdown")!,
            UTType(filenameExtension: "csv")!,
            .text,
            
            // Images
            .image,
            .jpeg,
            .png,
            .tiff,
            .heic,
            .gif,
            
            // Videos
            .movie,
            .video,
            .mpeg4Movie,
            .quickTimeMovie,
            
            // Audio
            .audio,
            .mp3,
            .wav,
            .aiff,
            UTType(filenameExtension: "m4a")!
        ]
        
        static func getFileType(for url: URL) -> FileType {
            guard let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
                return .unknown
            }
            
            if contentType.conforms(to: .text) || 
               contentType.conforms(to: .plainText) || 
               contentType.conforms(to: .html) || 
               contentType.conforms(to: .xml) || 
               contentType.conforms(to: .propertyList) || 
               contentType.conforms(to: .json) || 
               contentType.identifier.contains("yaml") || 
               contentType.identifier.contains("md") || 
               contentType.identifier.contains("csv") || 
               contentType.conforms(to: .rtf) {
                return .text
            } else if contentType.conforms(to: .pdf) {
                return .pdf
            } else if contentType.conforms(to: .image) {
                return .image
            } else if contentType.conforms(to: .video) || contentType.conforms(to: .movie) {
                return .video
            } else if contentType.conforms(to: .audio) {
                return .audio
            }
            
            return .unknown
        }
        
        static func extractMetadata(from url: URL) async throws -> [String: String] {
            var metadata: [String: String] = [:]
            
            // Basic file attributes
            do {
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
                
                // Creation and modification dates
                if let creationDate = fileAttributes[.creationDate] as? Date {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .medium
                    metadata["Created"] = formatter.string(from: creationDate)
                }
                
                if let modificationDate = fileAttributes[.modificationDate] as? Date {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .medium
                    metadata["Modified"] = formatter.string(from: modificationDate)
                }
                
                // File size
                if let fileSize = fileAttributes[.size] as? NSNumber {
                    let byteCountFormatter = ByteCountFormatter()
                    byteCountFormatter.allowedUnits = [.useKB, .useMB, .useGB]
                    byteCountFormatter.countStyle = .file
                    metadata["Size"] = byteCountFormatter.string(fromByteCount: fileSize.int64Value)
                }
                
                // Owner
                if let owner = fileAttributes[.ownerAccountName] as? String {
                    metadata["Owner"] = owner
                }
            } catch {
                print("Error getting file attributes: \(error)")
            }
            
            // File path and name info
            metadata["Filename"] = url.lastPathComponent
            metadata["Extension"] = url.pathExtension
            
            // UTType information
            if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
                metadata["ContentType"] = contentType.identifier
                
                if let typeDescription = contentType.localizedDescription {
                    metadata["FileType"] = typeDescription
                }
            }
            
            // Media-specific metadata based on file type
            let fileType = getFileType(for: url)
            
            switch fileType {
            case .image:
                try await extractImageMetadata(from: url, into: &metadata)
            case .video:
                try await extractVideoMetadata(from: url, into: &metadata)
            case .audio:
                try await extractAudioMetadata(from: url, into: &metadata)
            case .pdf:
                extractPDFMetadata(from: url, into: &metadata)
            default:
                break
            }
            
            return metadata
        }
        
        private static func extractImageMetadata(from url: URL, into metadata: inout [String: String]) async throws {
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                return
            }
            
            // Get image dimensions
            if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
                if let width = properties[kCGImagePropertyPixelWidth as String] as? NSNumber,
                   let height = properties[kCGImagePropertyPixelHeight as String] as? NSNumber {
                    metadata["Dimensions"] = "\(width.intValue) × \(height.intValue)"
                }
                
                // Extract EXIF data
                if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                    if let dateTime = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                        metadata["DateTaken"] = dateTime
                    }
                    
                    if let make = exif["Make" as String] as? String {
                        metadata["CameraMake"] = make
                    }
                    
                    if let model = exif["Model" as String] as? String {
                        metadata["CameraModel"] = model
                    }
                    
                    if let exposureTime = exif[kCGImagePropertyExifExposureTime as String] as? NSNumber {
                        metadata["ExposureTime"] = "\(exposureTime) sec"
                    }
                    
                    if let fNumber = exif[kCGImagePropertyExifFNumber as String] as? NSNumber {
                        metadata["Aperture"] = "f/\(fNumber)"
                    }
                    
                    if let iso = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [NSNumber], let isoValue = iso.first {
                        metadata["ISO"] = "\(isoValue)"
                    }
                }
                
                // GPS data
                if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
                    if let latitude = gps[kCGImagePropertyGPSLatitude as String] as? NSNumber, 
                       let longitude = gps[kCGImagePropertyGPSLongitude as String] as? NSNumber {
                        metadata["Location"] = "Lat: \(latitude), Long: \(longitude)"
                    }
                }
            }
        }
        
        private static func extractVideoMetadata(from url: URL, into metadata: inout [String: String]) async throws {
            let asset = AVAsset(url: url)
            
            // Get video duration
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .positional
            formatter.zeroFormattingBehavior = .pad
            if let formattedDuration = formatter.string(from: seconds) {
                metadata["Duration"] = formattedDuration
            }
            
            // Get video dimensions
            if let videoTrack = try await asset.loadTracks(withMediaType: .video).first {
                let size = try await videoTrack.load(.naturalSize)
                metadata["Dimensions"] = "\(Int(size.width)) × \(Int(size.height))"
                
                let frameRate = try await videoTrack.load(.nominalFrameRate)
                metadata["FrameRate"] = "\(Int(frameRate)) fps"
            }
            
            // Get audio details
            if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                // Audio format
                metadata["HasAudio"] = "Yes"
                
                // Try to get sample rate
                let formatDescriptions = try await audioTrack.load(.formatDescriptions)
                if let formatDescription = formatDescriptions.first {
                    let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription as! CMAudioFormatDescription)
                    if let asbd = asbd {
                        metadata["AudioSampleRate"] = "\(Int(asbd.pointee.mSampleRate)) Hz"
                        metadata["AudioChannels"] = "\(Int(asbd.pointee.mChannelsPerFrame))"
                    }
                }
            } else {
                metadata["HasAudio"] = "No"
            }
            
            // Creation date if available using traditional method for metadata access
            let commonMetadata = asset.commonMetadata
            for item in commonMetadata {
                if item.commonKey?.rawValue == "creationDate", let dateString = item.stringValue {
                    metadata["CreationDate"] = dateString
                }
            }
        }
        
        private static func extractAudioMetadata(from url: URL, into metadata: inout [String: String]) async throws {
            let asset = AVAsset(url: url)
            
            // Get audio duration
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .positional
            formatter.zeroFormattingBehavior = .pad
            if let formattedDuration = formatter.string(from: seconds) {
                metadata["Duration"] = formattedDuration
            }
            
            // Get audio details
            if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                // Try to get sample rate and channels
                let formatDescriptions = try await audioTrack.load(.formatDescriptions)
                if let formatDescription = formatDescriptions.first {
                    let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription as! CMAudioFormatDescription)
                    if let asbd = asbd {
                        metadata["SampleRate"] = "\(Int(asbd.pointee.mSampleRate)) Hz"
                        metadata["Channels"] = "\(Int(asbd.pointee.mChannelsPerFrame))"
                        
                        // Get bits per channel if available
                        if asbd.pointee.mBitsPerChannel > 0 {
                            metadata["BitDepth"] = "\(asbd.pointee.mBitsPerChannel) bits"
                        }
                    }
                }
            }
            
            // Metadata from the file using traditional method for metadata access
            let commonMetadata = asset.commonMetadata
            for item in commonMetadata {
                if let key = item.commonKey?.rawValue, 
                   let stringValue = item.stringValue {
                    switch key {
                    case "title":
                        metadata["Title"] = stringValue
                    case "artist", "author":
                        metadata["Artist"] = stringValue
                    case "albumName":
                        metadata["Album"] = stringValue
                    case "description":
                        metadata["Description"] = stringValue
                    case "creationDate":
                        metadata["ReleaseDate"] = stringValue
                    default:
                        break
                    }
                }
            }
            
            // Try to get additional metadata using AVMetadataItem's standard identifier method
            let metadataList = asset.metadata
            for item in metadataList {
                if let value = item.value as? String, 
                   let key = item.key as? String {
                    metadata[key] = value
                }
            }
        }
        
        private static func extractPDFMetadata(from url: URL, into metadata: inout [String: String]) {
            guard let pdfDocument = PDFDocument(url: url) else {
                return
            }
            
            // Get page count
            metadata["PageCount"] = "\(pdfDocument.pageCount)"
            
            // Get document attributes
            if let docAttributes = pdfDocument.documentAttributes {
                if let title = docAttributes[PDFDocumentAttribute.titleAttribute] as? String {
                    metadata["Title"] = title
                }
                
                if let author = docAttributes[PDFDocumentAttribute.authorAttribute] as? String {
                    metadata["Author"] = author
                }
                
                if let subject = docAttributes[PDFDocumentAttribute.subjectAttribute] as? String {
                    metadata["Subject"] = subject
                }
                
                if let creator = docAttributes[PDFDocumentAttribute.creatorAttribute] as? String {
                    metadata["Creator"] = creator
                }
                
                if let creationDate = docAttributes[PDFDocumentAttribute.creationDateAttribute] as? Date {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .medium
                    metadata["CreationDate"] = formatter.string(from: creationDate)
                }
                
                if let modDate = docAttributes[PDFDocumentAttribute.modificationDateAttribute] as? Date {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .medium
                    metadata["ModificationDate"] = formatter.string(from: modDate)
                }
                
                if let keywords = docAttributes[PDFDocumentAttribute.keywordsAttribute] as? [String] {
                    metadata["Keywords"] = keywords.joined(separator: ", ")
                }
            }
        }
        
        static func extractText(from url: URL) async throws -> String {
            let fileType = getFileType(for: url)
            
            switch fileType {
            case .text:
                return try extractTextFromTextFile(url: url)
            case .pdf:
                return try extractTextFromPDF(url: url)
            case .image:
                return try await extractTextFromImage(url: url)
            case .video:
                return try await extractTextFromVideo(url: url)
            case .audio:
                return try await extractTextFromAudio(url: url)
            case .unknown:
                throw DocumentError.unsupportedFileType
            }
        }
        
        private static func extractTextFromPDF(url: URL) throws -> String {
            guard let pdfDocument = PDFDocument(url: url) else {
                throw DocumentError.failedToReadData
            }
            
            var text = ""
            for i in 0..<pdfDocument.pageCount {
                if let page = pdfDocument.page(at: i) {
                    if let pageText = page.string {
                        text += pageText + "\n"
                    }
                }
            }
            
            if text.isEmpty {
                throw DocumentError.textExtractionFailed
            }
            
            return text
        }
        
        private static func extractTextFromTextFile(url: URL) throws -> String {
            do {
                return try String(contentsOf: url, encoding: .utf8)
            } catch {
                // Try another encoding if UTF-8 fails
                do {
                    return try String(contentsOf: url, encoding: .ascii)
                } catch {
                    throw DocumentError.textExtractionFailed
                }
            }
        }
        
        private static func extractTextFromRTF(url: URL) throws -> String {
            guard let data = try? Data(contentsOf: url) else {
                throw DocumentError.failedToReadData
            }
            
            guard let attributedString = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) else {
                throw DocumentError.textExtractionFailed
            }
            
            return attributedString.string
        }
        
        private static func extractTextFromHTML(url: URL) throws -> String {
            guard let data = try? Data(contentsOf: url) else {
                throw DocumentError.failedToReadData
            }
            
            guard let attributedString = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) else {
                throw DocumentError.textExtractionFailed
            }
            
            return attributedString.string
        }
        
        private static func extractTextFromImage(url: URL) async throws -> String {
            // First try to use Vision API to recognize text in the image
            let textFromOCR = try await performOCR(on: url)
            
            // If we have OCR text, use it along with image description
            let imageDescription = try await analyzeImage(url: url)
            
            if !textFromOCR.isEmpty {
                return "Image contains text: \(textFromOCR)\n\nImage description: \(imageDescription)"
            }
            
            return "Image description: \(imageDescription)"
        }
        
        private static func performOCR(on url: URL) async throws -> String {
            guard let cgImage = loadCGImage(from: url) else {
                return ""
            }
            
            let requestHandler = VNImageRequestHandler(cgImage: cgImage)
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            
            do {
                try requestHandler.perform([request])
                guard let observations = request.results else { return "" }
                
                return observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
            } catch {
                print("OCR failed: \(error)")
                return ""
            }
        }
        
        private static func loadCGImage(from url: URL) -> CGImage? {
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                return nil
            }
            return cgImage
        }
        
        private static func analyzeImage(url: URL) async throws -> String {
            // Using MultimodalService for image analysis
            return try await Multimodal.Service.shared.analyzeImage(url: url)
        }
        
        private static func extractTextFromVideo(url: URL) async throws -> String {
            // Use the new video analysis function that handles both image and audio in one call
            let result = try await Multimodal.Service.shared.analyzeVideo(url: url)
            
            return "Video visual content: \(result.imageDescription)\n\nAudio transcription: \(result.audioTranscription)"
        }
        
        static func extractVideoThumbnail(url: URL) async throws -> NSImage {
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            // Try to get a thumbnail from the middle of the video
            let duration = try await asset.load(.duration)
            let middleTime = CMTime(seconds: duration.seconds / 2, preferredTimescale: 600)
            
            do {
                let cgImage = try imageGenerator.copyCGImage(at: middleTime, actualTime: nil)
                let thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                return thumbnail
            } catch {
                throw DocumentError.videoAnalysisFailed
            }
        }
        
        private static func extractAudioFromVideo(url: URL) async throws -> String {
            // Use the audio extraction and transcription from Multimodal service
            return try await Multimodal.Service.shared.analyzeAudio(url: url)
        }
        
        private static func extractTextFromAudio(url: URL) async throws -> String {
            // Using MultimodalService for audio analysis/transcription
            return try await Multimodal.Service.shared.analyzeAudio(url: url)
        }
    }
} 
