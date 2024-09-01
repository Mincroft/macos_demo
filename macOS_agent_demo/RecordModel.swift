//
//  RecordModel.swift
//  macOS_agent_demo
//
//  Created by 殷瑜 on 2024/8/20.
//

import Foundation
import AVFoundation
import CoreGraphics
import CoreMedia
import VideoToolbox
import AppKit

class RecordModel: ObservableObject {
    private var recorder: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var displayLink: CVDisplayLink?
    private var startTime: CMTime?
    private var fileURL: URL?

    @Published var isRecording = false

    func startRecording() {
        guard !isRecording else { return }

        do {
            try setupRecorder()
            isRecording = true
            startDisplayLink()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard isRecording else {
            completion(nil)
            return
        }

        isRecording = false
        stopDisplayLink()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.input?.markAsFinished()
            self?.recorder?.finishWriting {
                DispatchQueue.main.async {
                    self?.saveRecordingWithCustomLocation(completion: completion)
                }
            }
        }
    }

    private func setupRecorder() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        fileURL = tempDirectory.appendingPathComponent("temp_recording_\(dateString).mp4")

        guard let fileURL = fileURL else {
            throw NSError(domain: "RecordModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create temporary file URL"])
        }

        recorder = try AVAssetWriter(url: fileURL, fileType: .mp4)

        let displayID = CGMainDisplayID()
        let width = CGDisplayPixelsWide(displayID)
        let height = CGDisplayPixelsHigh(displayID)

        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_H264_High_AutoLevel,
                kVTCompressionPropertyKey_MaxKeyFrameInterval: 60,
                kVTCompressionPropertyKey_AverageBitRate: 10_000_000
            ]
        ]

        input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        input?.expectsMediaDataInRealTime = true

        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input!, sourcePixelBufferAttributes: sourcePixelBufferAttributes)

        if recorder?.canAdd(input!) ?? false {
            recorder?.add(input!)
        } else {
            throw NSError(domain: "RecordModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to add input to recorder"])
        }

        recorder?.startWriting()
        recorder?.startSession(atSourceTime: CMTime.zero)
        startTime = CMClockGetTime(CMClockGetHostTimeClock())
    }

    private func startDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        CVDisplayLinkSetOutputCallback(displayLink!, { (displayLink, inNow, inOutputTime, flagsIn, flagsOut, displayLinkContext) -> CVReturn in
            let context = unsafeBitCast(displayLinkContext, to: RecordModel.self)
            context.captureFrame()
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(displayLink!)
    }

    private func stopDisplayLink() {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
    }

    private func captureFrame() {
        guard let input = input, input.isReadyForMoreMediaData else { return }

        let displayID = CGMainDisplayID()

        autoreleasepool {
            if let pixelBuffer = createPixelBuffer(for: displayID) {
                let currentTime = CMClockGetTime(CMClockGetHostTimeClock())
                let duration = CMTimeSubtract(currentTime, startTime!)
                adaptor?.append(pixelBuffer, withPresentationTime: duration)
            }
        }
    }

    private func createPixelBuffer(for displayID: CGDirectDisplayID) -> CVPixelBuffer? {
        let width = CGDisplayPixelsWide(displayID)
        let height = CGDisplayPixelsHigh(displayID)

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)

        guard status == kCVReturnSuccess, let unwrappedPixelBuffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(unwrappedPixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(unwrappedPixelBuffer, []) }

        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(unwrappedPixelBuffer),
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(unwrappedPixelBuffer),
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            return nil
        }

        guard let image = CGDisplayCreateImage(displayID) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return unwrappedPixelBuffer
    }

    private func saveRecordingWithCustomLocation(completion: @escaping (URL?) -> Void) {
        guard let tempFileURL = fileURL else {
            completion(nil)
            return
        }
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        fileURL = tempDirectory.appendingPathComponent("temp_recording_\(dateString).mp4")

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.mpeg4Movie]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "Screen_Recording_\(dateString).mp4"

        savePanel.begin { result in
            if result == .OK, let url = savePanel.url {
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try FileManager.default.moveItem(at: tempFileURL, to: url)
                        DispatchQueue.main.async {
                            completion(url)
                        }
                    } catch {
                        print("Failed to save recording: \(error)")
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                    }
                }
            } else {
                completion(nil)
            }
        }
    }
}
