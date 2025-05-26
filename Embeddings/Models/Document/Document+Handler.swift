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
            .text,
            
            // Programming and markup files
            UTType(filenameExtension: "swift")!,
            UTType(filenameExtension: "js")!,
            UTType(filenameExtension: "ts")!,
            UTType(filenameExtension: "py")!,
            UTType(filenameExtension: "java")!,
            UTType(filenameExtension: "cpp")!,
            UTType(filenameExtension: "c")!,
            UTType(filenameExtension: "h")!,
            UTType(filenameExtension: "hpp")!,
            UTType(filenameExtension: "cs")!,
            UTType(filenameExtension: "php")!,
            UTType(filenameExtension: "rb")!,
            UTType(filenameExtension: "go")!,
            UTType(filenameExtension: "rs")!,
            UTType(filenameExtension: "kt")!,
            UTType(filenameExtension: "scala")!,
            UTType(filenameExtension: "sql")!,
            UTType(filenameExtension: "r")!,
            UTType(filenameExtension: "m")!,
            UTType(filenameExtension: "pl")!,
            UTType(filenameExtension: "lua")!,
            UTType(filenameExtension: "vim")!,
            UTType(filenameExtension: "el")!,
            
            // Markup and config files
            UTType(filenameExtension: "yaml")!,
            UTType(filenameExtension: "yml")!,
            UTType(filenameExtension: "md")!,
            UTType(filenameExtension: "markdown")!,
            UTType(filenameExtension: "csv")!,
            UTType(filenameExtension: "toml")!,
            UTType(filenameExtension: "ini")!,
            UTType(filenameExtension: "conf")!,
            UTType(filenameExtension: "config")!,
            UTType(filenameExtension: "dockerfile")!,
            UTType(filenameExtension: "gitignore")!,
            UTType(filenameExtension: "sh")!,
            UTType(filenameExtension: "bash")!,
            UTType(filenameExtension: "zsh")!,
            UTType(filenameExtension: "fish")!,
            UTType(filenameExtension: "ps1")!,
            UTType(filenameExtension: "bat")!,
            UTType(filenameExtension: "cmd")!,
            
            // Xcode and Apple specific files
            UTType(filenameExtension: "entitlements")!,
            UTType(filenameExtension: "plist")!,
            UTType(filenameExtension: "xcstrings")!,
            UTType(filenameExtension: "xctestplan")!,
            UTType(filenameExtension: "xcprivacy")!,
            
            // Web and Node.js files
            UTType(filenameExtension: "mjs")!,
            UTType(filenameExtension: "jsx")!,
            UTType(filenameExtension: "tsx")!,
            UTType(filenameExtension: "vue")!,
            UTType(filenameExtension: "svelte")!,
            
            // Container and deployment files
            UTType(filenameExtension: "podfile")!,
            UTType(filenameExtension: "gemfile")!,
            UTType(filenameExtension: "rakefile")!,
            UTType(filenameExtension: "makefile")!,
            UTType(filenameExtension: "cmake")!,
            UTType(filenameExtension: "gradle")!,
            UTType(filenameExtension: "pom")!,
            UTType(filenameExtension: "sbt")!,
            
            // Data and log files
            UTType(filenameExtension: "log")!,
            UTType(filenameExtension: "tsv")!,
            UTType(filenameExtension: "ndjson")!,
            UTType(filenameExtension: "jsonl")!,
            
            // License and documentation files (no extension)
            UTType(filenameExtension: "license")!,
            UTType(filenameExtension: "readme")!,
            UTType(filenameExtension: "changelog")!,
            UTType(filenameExtension: "authors")!,
            UTType(filenameExtension: "contributors")!,
            UTType(filenameExtension: "copying")!,
            UTType(filenameExtension: "install")!,
            UTType(filenameExtension: "news")!,
            UTType(filenameExtension: "todo")!,
            UTType(filenameExtension: "version")!,
            UTType(filenameExtension: "history")!,
            UTType(filenameExtension: "notice")!,
            
            // Images
            .image,
            .jpeg,
            .png,
            .tiff,
            .heic,
            .gif,
            .webP,
            UTType(filenameExtension: "svg")!,
            
            // Videos
            .movie,
            .video,
            .mpeg4Movie,
            .quickTimeMovie,
            UTType(filenameExtension: "webm")!,
            UTType(filenameExtension: "mkv")!,
            UTType(filenameExtension: "avi")!,
            UTType(filenameExtension: "wmv")!,
            UTType(filenameExtension: "flv")!,
            
            // Audio
            .audio,
            .mp3,
            .wav,
            .aiff,
            UTType(filenameExtension: "m4a")!,
            UTType(filenameExtension: "flac")!,
            UTType(filenameExtension: "ogg")!,
            UTType(filenameExtension: "wma")!
        ]
        
        // Common text file extensions and names
        static let textFileExtensions: Set<String> = [
            "txt", "text", "md", "markdown", "yaml", "yml", "json", "xml", "html", "htm", "css", "js", "ts", "mjs", "jsx", "tsx",
            "swift", "py", "java", "cpp", "c", "h", "hpp", "cs", "php", "rb", "go", "rs", "kt", "scala", "sql", "r", "m", "pl", "lua", "vim", "el",
            "csv", "tsv", "log", "conf", "config", "ini", "toml", "dockerfile", "gitignore", "readme", "license", 
            "sh", "bash", "zsh", "fish", "ps1", "bat", "cmd", "plist", "entitlements", "xcstrings", "xctestplan", "xcprivacy",
            "vue", "svelte", "podfile", "gemfile", "rakefile", "makefile", "cmake", "gradle", "pom", "sbt",
            "ndjson", "jsonl", "changelog", "authors", "contributors", "copying", "install", "news", "todo", "version", "history", "notice",
            "rules", "command"
        ]
        
        static func getFileType(for url: URL) -> FileType {
            let fileName = url.lastPathComponent.lowercased()
            let fileExtension = url.pathExtension.lowercased()
            
            // Check if it's a known text file by name or extension
            if textFileExtensions.contains(fileName) || textFileExtensions.contains(fileExtension) {
                return .text
            }
            
            // Check by content type
            if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
                if contentType.conforms(to: .text) || 
                   contentType.conforms(to: .plainText) || 
                   contentType.conforms(to: .html) || 
                   contentType.conforms(to: .xml) || 
                   contentType.conforms(to: .propertyList) || 
                   contentType.conforms(to: .json) ||
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
            }
            
            // Fallback: if we think it might be text, try to read it
            if couldBeTextFile(url: url) {
                return .text
            }
            
            return .unknown
        }
        
        // Helper to detect if a file might be text-based
        private static func couldBeTextFile(url: URL) -> Bool {
            // Check if file is small enough to potentially be text
            guard let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  fileSize < 50_000_000 else { // 50MB limit
                return false
            }
            
            // Try to read first few bytes to check for text content
            guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
                return false
            }
            defer { fileHandle.closeFile() }
            
            let sampleData = fileHandle.readData(ofLength: 512)
            guard !sampleData.isEmpty else { return false }
            
            // Check if sample contains mostly printable ASCII characters
            let printableCount = sampleData.filter { byte in
                (byte >= 32 && byte <= 126) || byte == 9 || byte == 10 || byte == 13 // printable ASCII, tab, LF, CR
            }.count
            
            let printableRatio = Double(printableCount) / Double(sampleData.count)
            return printableRatio > 0.7 // If 70%+ is printable, likely text
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
            // Start accessing security scoped resource
            let shouldStopAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
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
            // Start accessing security scoped resource
            let shouldStopAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            let asset = AVURLAsset(url: url)
            
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
            // Start accessing security scoped resource
            let shouldStopAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
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
            // Start accessing security scoped resource
            let shouldStopAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
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
                // Try to process as text first if it might be a text file
                if couldBeTextFile(url: url) {
                    do {
                        return try extractTextFromTextFile(url: url)
                    } catch {
                        // If text extraction fails, throw the original error
                        throw DocumentError.unsupportedFileType
                    }
                }
                throw DocumentError.unsupportedFileType
            }
        }
        
        private static func extractTextFromTextFile(url: URL) throws -> String {
            // Try multiple encodings in order of preference
            let encodings: [String.Encoding] = [.utf8, .utf16, .ascii, .isoLatin1, .macOSRoman, .windowsCP1252]
            
            for encoding in encodings {
                do {
                    let text = try String(contentsOf: url, encoding: encoding)
                    // Basic validation: ensure it's not empty and has reasonable content
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return text
                    }
                } catch {
                    // Continue to next encoding
                    continue
                }
            }
            
            // If all encodings fail, try reading as raw data and converting
            do {
                let data = try Data(contentsOf: url)
                
                // If it's a small file, try to detect encoding
                if data.count < 1_000_000 { // 1MB limit for encoding detection
                    if let detectedString = String(data: data, encoding: .utf8) {
                        return detectedString
                    }
                    
                    // Try other common encodings
                    for encoding in encodings.dropFirst() {
                        if let detectedString = String(data: data, encoding: encoding) {
                            return detectedString
                        }
                    }
                }
                
                // Last resort: convert non-UTF8 bytes to readable representation
                let utf8String = data.compactMap { byte in
                    if byte >= 32 && byte <= 126 || byte == 9 || byte == 10 || byte == 13 {
                        let scalar = UnicodeScalar(byte)
                        return String(Character(scalar))
                    }
                    return nil
                }.joined()
                
                if !utf8String.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                    return utf8String
                }
                
            } catch {
                throw DocumentError.failedToReadData
            }
            
            throw DocumentError.textExtractionFailed
        }
        
        private static func extractTextFromPDF(url: URL) throws -> String {
            // Start accessing security scoped resource
            let shouldStopAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
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
        
        private static func extractTextFromImage(url: URL) async throws -> String {
            // Start accessing security scoped resource
            let shouldStopAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
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
            // Start accessing security scoped resource
            let shouldStopAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
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
            // Start accessing security scoped resource
            let shouldStopAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
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
            // Start accessing security scoped resource
            let shouldStopAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            // Use the new video analysis function that handles both image and audio in one call
            let result = try await Multimodal.Service.shared.analyzeVideo(url: url)
            
            return "Video visual content: \(result.imageDescription)\n\nAudio transcription: \(result.audioTranscription)"
        }
        
        private static func extractTextFromAudio(url: URL) async throws -> String {
            // Start accessing security scoped resource
            let shouldStopAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            // Using MultimodalService for audio analysis/transcription
            return try await Multimodal.Service.shared.analyzeAudio(url: url)
        }
        
        static func extractVideoThumbnail(url: URL) async throws -> NSImage {
            // Start accessing security scoped resource
            let shouldStopAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
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
            // Start accessing security scoped resource
            let shouldStopAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            // Use the audio extraction and transcription from Multimodal service
            return try await Multimodal.Service.shared.analyzeAudio(url: url)
        }
    }
}
