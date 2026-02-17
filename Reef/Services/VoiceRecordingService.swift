//
//  VoiceRecordingService.swift
//  Reef
//

import AVFoundation

/// Manages microphone recording for push-to-talk voice messages.
class VoiceRecordingService: NSObject, AVAudioRecorderDelegate {
    static let shared = VoiceRecordingService()

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?

    /// Whether currently recording.
    private(set) var isRecording: Bool = false

    private override init() {
        super.init()
    }

    /// Start recording audio. Requests microphone permission if needed.
    /// - Returns: `true` if recording started successfully.
    @discardableResult
    func startRecording() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
        } catch {
            print("[VoiceRecording] Failed to set up audio session: \(error)")
            return false
        }

        // Request permission
        var permissionGranted = false
        let semaphore = DispatchSemaphore(value: 0)
        AVAudioApplication.requestRecordPermission { granted in
            permissionGranted = granted
            semaphore.signal()
        }
        semaphore.wait()

        guard permissionGranted else {
            print("[VoiceRecording] Microphone permission denied")
            return false
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.record()
            audioRecorder = recorder
            recordingURL = url
            isRecording = true
            print("[VoiceRecording] Started recording to \(url.lastPathComponent)")
            return true
        } catch {
            print("[VoiceRecording] Failed to start recording: \(error)")
            return false
        }
    }

    /// Stop recording and return the audio data.
    /// - Returns: WAV audio data, or `nil` if not recording.
    func stopRecording() -> Data? {
        guard let recorder = audioRecorder, isRecording else { return nil }

        recorder.stop()
        isRecording = false

        // Reset audio session so TTS playback can configure it fresh
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("[VoiceRecording] Failed to deactivate audio session: \(error)")
        }

        defer {
            // Clean up temp file
            if let url = recordingURL {
                try? FileManager.default.removeItem(at: url)
            }
            audioRecorder = nil
            recordingURL = nil
        }

        guard let url = recordingURL else { return nil }
        let data = try? Data(contentsOf: url)
        print("[VoiceRecording] Stopped recording, \(data?.count ?? 0) bytes")
        return data
    }
}
