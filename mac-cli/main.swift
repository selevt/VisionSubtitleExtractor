import Foundation
import Vision
import AVFoundation
import ArgumentParser


struct SubtitleExtractorCLI: ParsableCommand {
    @Argument(help: "Path to the video file.")
    var videoPath: String

    @Option(name: .shortAndLong, help: "Frame extraction interval in seconds.")
    var interval: Double = 1.0

    @Option(name: .shortAndLong, help: "Output SRT file path. Defaults to <video>.srt")
    var output: String?

    @Option(name: .long, parsing: .upToNextOption, help: "Region of interest as x y width height (normalized 0.0-1.0)")
    var roi: [Double] = []

    func run() throws {
        let outputPath = output ?? "\(URL(fileURLWithPath: videoPath).deletingPathExtension().lastPathComponent).srt"
        var regionOfInterest: CGRect? = nil
        if roi.count == 4 {
            regionOfInterest = CGRect(x: roi[0], y: roi[1], width: roi[2], height: roi[3])
        } else if !roi.isEmpty {
            throw ValidationError("ROI must be four numbers: x y width height (all normalized 0.0-1.0)")
        }

        print("Starting subtitle extraction process...")
        print("Video: \(videoPath)")
        print("Interval: \(interval) seconds")
        print("Output: \(outputPath)")
        if let roi = regionOfInterest {
            print("Region of interest: x=\(roi.origin.x), y=\(roi.origin.y), width=\(roi.size.width), height=\(roi.size.height)")
            print("Note: Coordinates use (0,0) as BOTTOM-LEFT corner and (1,1) as TOP-RIGHT corner")
        } else {
            print("Region of interest: Full frame")
        }

        Task {
            do {
                let extractor = SubtitleExtractor(
                    videoPath: videoPath,
                    intervalInSeconds: interval,
                    outputPath: outputPath,
                    regionOfInterest: regionOfInterest
                )
                try await extractor.prepare()
                let success = try await extractor.extractSubtitles()
                if success {
                    print("Subtitle extraction completed successfully")
                } else {
                    print("Subtitle extraction failed")
                }
            } catch {
                print("Error during subtitle extraction: \(error.localizedDescription)")
                print("Error type: \(type(of: error))")
                print("Error debug: \(error)")
                if let nsError = error as NSError? {
                    print("NSError domain: \(nsError.domain)")
                    print("NSError code: \(nsError.code)")
                    print("NSError userInfo: \(nsError.userInfo)")
                }
            }
            Foundation.exit(0)
        }
        dispatchMain()
    }
}

SubtitleExtractorCLI.main()

// MARK: - Subtitle Extractor

class SubtitleExtractor {
    private let videoURL: URL
    private let asset: AVURLAsset
    private let intervalInSeconds: Double
    private let outputPath: String
    private let regionOfInterest: CGRect?
    
    private var subtitles: [Subtitle] = []
    private var currentFrameTime: CMTime = .zero
    private var videoDuration: CMTime = .zero
    
    init(videoPath: String, intervalInSeconds: Double, outputPath: String, regionOfInterest: CGRect? = nil) {
        self.videoURL = URL(fileURLWithPath: videoPath)
        self.asset = AVURLAsset(url: videoURL)
        self.intervalInSeconds = intervalInSeconds
        self.outputPath = outputPath
        self.regionOfInterest = regionOfInterest
        
        // Get video duration - this is now handled in prepare()
    }
    
    // Prepare the extractor by loading video metadata
    func prepare() async throws {
        // Get video duration
        self.videoDuration = try await asset.load(.duration)
    }
    
    // MARK: - Extract Subtitles
    
    func extractSubtitles() async throws -> Bool {
        print("Starting subtitle extraction from \(videoURL.lastPathComponent)")
        print("Video duration: \(CMTimeGetSeconds(videoDuration)) seconds")
        print("Extracting frames every \(intervalInSeconds) seconds")
        
        // Reset state
        subtitles.removeAll()
        currentFrameTime = .zero
        
        // Process frames at regular intervals
        await processFrames()
        writeSubtitlesToFile()
        return true
    }
    
    private func processFrames() async {
        // Start at a small offset from zero to avoid "Cannot Open" error with exact zero time
        currentFrameTime = CMTimeMakeWithSeconds(0.1, preferredTimescale: 600)
        
        while CMTimeCompare(currentFrameTime, videoDuration) < 0 {
            // Generate image from the current time
            if let image = try? await generateImageFromVideo(at: currentFrameTime) {
                // Perform OCR on the image
                let recognizedText = await performOCR(on: image)
                
                if !recognizedText.isEmpty {
                    let startTime = currentFrameTime
                    var endTime = CMTimeAdd(startTime, CMTimeMakeWithSeconds(intervalInSeconds, preferredTimescale: 600))
                    
                    // Ensure endTime doesn't exceed video duration
                    if CMTimeCompare(endTime, videoDuration) > 0 {
                        endTime = videoDuration
                    }
                    
                    let subtitle = Subtitle(
                        index: subtitles.count + 1,
                        startTime: startTime,
                        endTime: endTime,
                        text: recognizedText
                    )
                    
                    subtitles.append(subtitle)
                    print("Frame at \(formatTime(startTime)): \(recognizedText)")
                    fflush(__stdoutp)
                }
            }
            
            // Move to the next time interval
            currentFrameTime = CMTimeAdd(currentFrameTime, CMTimeMakeWithSeconds(intervalInSeconds, preferredTimescale: 600))
        }
    }
    
    // MARK: - Image Generation
    
    private func generateImageFromVideo(at time: CMTime) async throws -> CGImage? {
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceBefore = CMTime.zero
        imageGenerator.requestedTimeToleranceAfter = CMTime.zero
        
        do {
            let (cgImage, _) = try await imageGenerator.image(at: time)
            return cgImage
        } catch {
            print("Error generating image: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - OCR Processing
    
    private func performOCR(on cgImage: CGImage) async -> String {
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // TODO: Make this configurable
            request.recognitionLanguages = ["ko"]
            
            // Apply region of interest if specified
            if let roi = regionOfInterest {
                request.regionOfInterest = roi
            }
            
            try requestHandler.perform([request])
            
            // Get observations from request results
            guard let observations = request.results else { return "" }
            
            // Extract the recognized text
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }
            
            // Join the recognized text into a single string
            return recognizedStrings.joined(separator: " ")
        } catch {
            print("Failed to perform OCR: \(error.localizedDescription)")
            return ""
        }
    }
    
    // MARK: - SRT File Generation
    
    private func writeSubtitlesToFile() {
        guard !subtitles.isEmpty else {
            print("No subtitles were detected in the video")
            return
        }

        var mergedSubtitles: [Subtitle] = []
        var currentSubtitle: Subtitle? = nil

        for subtitle in subtitles {
            if let curr = currentSubtitle {
                // Merge if text is the same, or if the new text starts with the previous text
                if curr.text == subtitle.text || subtitle.text.hasPrefix(curr.text) {
                    // Extend the endTime and use the longer text
                    let mergedText = subtitle.text.count > curr.text.count ? subtitle.text : curr.text
                    var endTime = subtitle.endTime
                    
                    // Ensure endTime doesn't exceed video duration
                    if CMTimeCompare(endTime, videoDuration) > 0 {
                        endTime = videoDuration
                    }
                    
                    currentSubtitle = Subtitle(
                        index: curr.index,
                        startTime: curr.startTime,
                        endTime: endTime,
                        text: mergedText
                    )
                } else {
                    mergedSubtitles.append(curr)
                    currentSubtitle = Subtitle(
                        index: curr.index + 1,
                        startTime: subtitle.startTime,
                        endTime: subtitle.endTime,
                        text: subtitle.text
                    )
                }
            } else {
                currentSubtitle = Subtitle(
                    index: 1,
                    startTime: subtitle.startTime,
                    endTime: subtitle.endTime,
                    text: subtitle.text
                )
            }
        }
        if let curr = currentSubtitle {
            mergedSubtitles.append(curr)
        }

        // Re-index merged subtitles
        var srtContent = ""
        let ms10 = CMTimeMake(value: 10, timescale: 1000) // 10 milliseconds
        for (i, subtitle) in mergedSubtitles.enumerated() {
            var endTime = subtitle.endTime
            // If this is the last subtitle and its endTime is at or after videoDuration, subtract 10ms
            if i == mergedSubtitles.count - 1 && CMTimeCompare(endTime, videoDuration) >= 0 {
                endTime = CMTimeSubtract(videoDuration, ms10)
                if CMTimeCompare(endTime, subtitle.startTime) <= 0 {
                    // If subtracting 10ms would make endTime before startTime, set endTime = subtitle.startTime
                    endTime = subtitle.startTime
                }
            }
            srtContent += "\(i+1)\n"
            srtContent += "\(formatSRTTime(subtitle.startTime)) --> \(formatSRTTime(endTime))\n"
            srtContent += "\(subtitle.text)\n\n"
        }

        do {
            try srtContent.write(toFile: outputPath, atomically: true, encoding: .utf8)
            print("Successfully wrote \(mergedSubtitles.count) subtitles to \(outputPath)")
        } catch {
            print("Error writing SRT file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Utility Functions
    
    private func formatTime(_ time: CMTime) -> String {
        let seconds = CMTimeGetSeconds(time)
        return String(format: "%.2f", seconds)
    }
    
    private func formatSRTTime(_ time: CMTime) -> String {
        let totalSeconds = Int(CMTimeGetSeconds(time))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let milliseconds = Int((CMTimeGetSeconds(time).truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }
}

// MARK: - Subtitle Model

struct Subtitle {
    let index: Int
    let startTime: CMTime
    let endTime: CMTime
    let text: String
}

// Main execution is now handled by SubtitleExtractorCLI
