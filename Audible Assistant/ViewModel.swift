import AVFoundation
import Foundation
import Observation
import XCAOpenAIClient

@Observable
class ViewModel: NSObject, ObservableObject ,AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    // Arrays to store Messages from OpenAI and Prompts dictated by the User
    var messages: [String] = []
    var prompts: [String] = []
    
    // OpenAI clinet for handling requests
    let client = OpenAIClient(apiKey: "placeholder")

    // Properties for audio player and recorder.
    var audioPlayer: AVAudioPlayer!
    var audioRecorder: AVAudioRecorder!

    // Audio session for managing audio behaviors. Excluded in macOS environment.
    #if !os(macOS)
    var recordingSession = AVAudioSession.sharedInstance()
    #endif

    // Timers for updating UI and managing recording states.
    var animationTimer: Timer?
    var recordingTimer: Timer?

    // Variables for tracking audio power levels.
    var audioPower = 0.0
    var prevAudioPower: Double?

    // A Task for processing speech.
    var processingSpeechTask: Task<Void, Never>?

    // The selected voice type for speech synthesis.
    var selectedVoice = VoiceType.alloy

    // Computed property to define the URL where audio recordings are saved.
    var captureURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("recording.m4a")
    }

    // State of the voice chat, with observer to print state changes.
    var state = VoiceChatState.idle {
        didSet { print(state) }
    }

    // Computed property to check if the current state is idle.
    var isIdle: Bool {
        if case .idle = state {
            return true
        }
        return false
    }

    // Computed property to determine the opacity of the waveform based on state.
    var siriWaveFormOpacity: CGFloat {
        switch state {
        case .recordingSpeech, .playingSpeech: return 1
        default: return 0
        }
    }

    // Text response to be displayed in the UI
    
    // Initializer for the ViewModel. Sets up the audio session, particularly with IOS devices
    override init() {
        super.init()
        #if !os(macOS)
        do {
            // Set the audio session category. Different implementation for iOS.
            #if os(iOS)
            try recordingSession.setCategory(.playAndRecord, options: .defaultToSpeaker)
            #else
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            #endif
            try recordingSession.setActive(true)

            // Request permission to record audio.
            AVAudioApplication.requestRecordPermission { [unowned self] allowed in
                if !allowed {
                    self.state = .error("Recording not allowed by the user")
                }
            }
        } catch {
            state = .error(error)
        }
        #endif
    }
    // Function to start capturing audio, initialize recorders, and set up timers.
    func startCaptureAudio() {
        resetValues()
        state = .recordingSpeech
        do {
            // Initialize the audio recorder with settings.
            audioRecorder = try AVAudioRecorder(url: captureURL,
                                                settings: [
                                                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                                                    AVSampleRateKey: 12000,
                                                    AVNumberOfChannelsKey: 1,
                                                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                                                ])
            audioRecorder.isMeteringEnabled = true
            audioRecorder.delegate = self
            audioRecorder.record()

            // Timer to update UI based on audio input, e.g. for visualizing audio levels
            animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { [unowned self]_ in
                guard self.audioRecorder != nil else { return }
                self.audioRecorder.updateMeters()
                let power = min(1, max(0, 1 - abs(Double(self.audioRecorder.averagePower(forChannel: 0)) / 50) ))
                self.audioPower = power
            })

            // Timer to determine if recording should be stopped based on audio levels.
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: true, block: { [unowned self]_ in
                guard self.audioRecorder != nil else { return }
                self.audioRecorder.updateMeters()
                let power = min(1, max(0, 1 - abs(Double(self.audioRecorder.averagePower(forChannel: 0)) / 50) ))
                if self.prevAudioPower == nil {
                    self.prevAudioPower = power
                    return
                }
                if let prevAudioPower = self.prevAudioPower, prevAudioPower < 0.25 && power < 0.175 {
                    self.finishCaptureAudio()
                    return
                }
                self.prevAudioPower = power
            })
            
        } catch {
            resetValues()
            state = .error(error)
        }
    }
    // Function to finish capturing audio and start processing it.
    func finishCaptureAudio() {
        resetValues()
        do {
            let data = try Data(contentsOf: captureURL)
            processingSpeechTask = processSpeechTask(audioData: data)
        } catch {
            state = .error(error)
            resetValues()
        }
    }

    // Function to process the captured speech data.
    func processSpeechTask(audioData: Data) -> Task<Void, Never> {
        Task { @MainActor [unowned self] in
            do {
                self.state = .processingSpeech
                let userTranscription = try await client.generateAudioTransciptions(audioData: audioData)

                // Append user prompt
                DispatchQueue.main.async {
                    self.prompts.append(userTranscription)
                }

                let responseText = try await client.promptChatGPT(prompt: userTranscription)

                // Append AI response
                DispatchQueue.main.async {
                    self.messages.append(responseText)
                }

                let data = try await client.generateSpeechFrom(input: responseText, voice:
                        .init(rawValue: selectedVoice.rawValue) ?? .alloy)
                try self.playAudio(data: data)
            } catch {
                if Task.isCancelled { return }
                state = .error(error)
                resetValues()
            }
        }
    }

    // Function to play audio from data.
    func playAudio(data: Data) throws {
        self.state = .playingSpeech
        audioPlayer = try AVAudioPlayer(data: data)
        audioPlayer.isMeteringEnabled = true
        audioPlayer.delegate = self
        audioPlayer.play()

        // Timer to update UI based on audio output.
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { [unowned self]_ in
            guard self.audioPlayer != nil else { return }
            self.audioPlayer.updateMeters()
            let power = min(1, max(0, 1 - abs(Double(self.audioPlayer.averagePower(forChannel: 0)) / 160) ))
            self.audioPower = power
        })
    }

    // Functions to handle cancellation of recording and processing tasks.
    func cancelRecording() {
        resetValues()
        state = .idle
    }

    func cancelProcessingTask() {
        processingSpeechTask?.cancel()
        processingSpeechTask = nil
        resetValues()
        state = .idle
    }

    // Delegate methods for AVAudioRecorder and AVAudioPlayer to handle finish events.
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            resetValues()
            state = .idle
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        resetValues()
        state = .idle
    }

    // Function to reset all values and states to default.
    func resetValues() {
        audioPower = 0
        prevAudioPower = nil
        audioRecorder?.stop()
        audioRecorder = nil
        audioPlayer?.stop()
        audioPlayer = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
}
