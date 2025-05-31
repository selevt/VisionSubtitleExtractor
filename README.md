# SubtitleExtractor

A macOS command-line application that extracts subtitles from videos using the Vision API.

## Features

- Extracts frames from videos at specified intervals
- Uses OCR (Optical Character Recognition) to detect text in the frames
- Generates SRT subtitle files from the detected text
- Works with various video formats supported by AVFoundation

## Requirements

- macOS 11 (Big Sur) or later
- Swift 5.5 or later
- Xcode 13 or later (for development)

## Installation

1. Clone or download this repository
2. Navigate to the project directory in Terminal
3. Build the project using Swift Package Manager:

```bash
swift build -c release
```

4. The executable will be located in `.build/release/SubtitleExtractor`

## Usage

```bash
SubtitleExtractor <video_file_path> [interval_in_seconds] [output_file_path]
```

### Arguments

- `video_file_path` (required): Path to the video file
- `interval_in_seconds` (optional): How often to extract frames, in seconds (default: 1.0)
- `output_file_path` (optional): Path to save the SRT file (default: video_name.srt)

### Examples

Extract subtitles from a video with default settings (1 second interval):
```bash
SubtitleExtractor /path/to/movie.mp4
```

Extract subtitles every 2.5 seconds:
```bash
SubtitleExtractor /path/to/movie.mp4 2.5
```

Specify custom output path:
```bash
SubtitleExtractor /path/to/movie.mp4 1.0 /path/to/custom_subtitles.srt
```

## How It Works

1. The program loads the video using AVFoundation
2. Frames are extracted at the specified time intervals
3. Vision framework's text recognition (OCR) is applied to each frame
4. Detected text is recorded with its corresponding timestamp
5. An SRT subtitle file is generated from the collected text and timestamps

## Limitations

- OCR accuracy depends on the quality of the video and the clarity of the text
- Best results are achieved with high-resolution videos and clear subtitles
- Processing time depends on video length and the extraction interval

## License

This project is available under the MIT License.
