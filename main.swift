import Foundation
import Vision
import AVFoundation

// Command line arguments handling
guard CommandLine.arguments.count > 1 else {
    print("Usage: \(CommandLine.arguments[0]) <video_file_path> [interval_in_seconds] [output_file_path]")
    print("Example: \(CommandLine.arguments[0]) movie.mp4 1.0 subtitles.srt")
    exit(1)
}

let videoPath = CommandLine.arguments[1]
let intervalInSeconds = CommandLine.arguments.count > 2 ? Double(CommandLine.arguments[2]) ?? 1.0 : 1.0
// TODO: it doesn't seem to work? I tried setting it, but it used the fallback
let outputPath = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "\(URL(fileURLWithPath: videoPath).deletingPathExtension().lastPathComponent).srt"

// MARK: - Subtitle Extractor

class SubtitleExtractor {
    private let videoURL: URL
    private let asset: AVURLAsset
    private let intervalInSeconds: Double
    private let outputPath: String
    
    private var subtitles: [Subtitle] = []
    private var currentFrameTime: CMTime = .zero
    private var videoDuration: CMTime = .zero
    
    init(videoPath: String, intervalInSeconds: Double, outputPath: String) {
        self.videoURL = URL(fileURLWithPath: videoPath)
        self.asset = AVURLAsset(url: videoURL)
        self.intervalInSeconds = intervalInSeconds
        self.outputPath = outputPath
        
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
        while CMTimeCompare(currentFrameTime, videoDuration) < 0 {
            // Generate image from the current time
            if let image = try? await generateImageFromVideo(at: currentFrameTime) {
                // Perform OCR on the image
                let recognizedText = await performOCR(on: image)
                
                if !recognizedText.isEmpty {
                    let startTime = currentFrameTime
                    let endTime = CMTimeAdd(startTime, CMTimeMakeWithSeconds(intervalInSeconds, preferredTimescale: 600))
                    
                    let subtitle = Subtitle(
                        index: subtitles.count + 1,
                        startTime: startTime,
                        endTime: endTime,
                        text: recognizedText
                    )
                    
                    subtitles.append(subtitle)
                    print("Frame at \(formatTime(startTime)): \(recognizedText)")
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
            
            try requestHandler.perform([request])
            
            if let observations = request.results as? [VNRecognizedTextObservation] {
                // Extract the recognized text
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                // Join the recognized text into a single string
                return recognizedStrings.joined(separator: " ")
            }
            
            return ""
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
        
        var srtContent = ""
        
        for subtitle in subtitles {
            srtContent += "\(subtitle.index)\n"
            srtContent += "\(formatSRTTime(subtitle.startTime)) --> \(formatSRTTime(subtitle.endTime))\n"
            srtContent += "\(subtitle.text)\n\n"
        }
        
        do {
            try srtContent.write(toFile: outputPath, atomically: true, encoding: .utf8)
            print("Successfully wrote \(subtitles.count) subtitles to \(outputPath)")
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

// MARK: - Main Execution

// Use Task to run async code from synchronous entry point
print("Starting subtitle extraction process...")
print("Video: \(videoPath)")
print("Interval: \(intervalInSeconds) seconds")
print("Output: \(outputPath)")

Task {
    do {
        let extractor = SubtitleExtractor(
            videoPath: videoPath,
            intervalInSeconds: intervalInSeconds,
            outputPath: outputPath
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
    }
    
    // Exit after completion
    exit(0)
}

// Keep the main thread running until the task completes
dispatchMain()
