import SwiftUI
import Speech
import AVFoundation
import OpenAIRealtime

class HybridVoiceManager: ObservableObject {
    @Published var isListening = false
    @Published var statusText = "Ready to help"
    @Published var transcript = ""
    @Published var lastResponse = ""
    
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer()
    
    private var conversation: Conversation
    
    init() {
        self.conversation = Conversation(authToken: "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")
    }
    
    @MainActor
    func startListening() {
        startLocalSpeechRecognition()
        do {
            try conversation.startListening()
            self.isListening = true
            self.statusText = "Listening..."
            self.transcript = ""
        } catch {
            print("Failed to start OpenAI listening: \(error)")
            self.statusText = "Error starting conversation"
            stopLocalSpeechRecognition()
        }
    }
    
    @MainActor
    func stopListening() {
        stopLocalSpeechRecognition()
        conversation.stopHandlingVoice()
        self.isListening = false
        self.statusText = "Ready to help"
    }
    
    @MainActor
    func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }
    
    private func startLocalSpeechRecognition() {
        let request = SFSpeechAudioBufferRecognitionRequest()
        let inputNode = audioEngine.inputNode
        
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self?.transcript = result.bestTranscription.formattedString
                }
            }
            
            if let error = error {
                print("Speech recognition error: \(error)")
            }
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    private func stopLocalSpeechRecognition() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}

struct ContentView: View {
    @StateObject private var voiceManager = HybridVoiceManager()
    @State private var pulseAnimation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.02, green: 0.06, blue: 0.23)
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    Button(action: {
                        Task { @MainActor in
                            voiceManager.toggleListening()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                pulseAnimation = voiceManager.isListening
                            }
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(circleColor.opacity(0.2))
                                .frame(width: 220, height: 220)
                                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                                .opacity(pulseAnimation ? 0.5 : 1.0)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
                            
                            Circle()
                                .fill(circleColor)
                                .frame(width: 180, height: 180)
                                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                            
                            VStack(spacing: 8) {
                                Image(systemName: voiceManager.isListening ? "waveform" : "mic.fill")
                                    .font(.system(size: 40, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text(voiceManager.isListening ? "LISTENING" : "TAP TO SPEAK")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    Text(voiceManager.statusText)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    if !voiceManager.transcript.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("You're saying:")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(voiceManager.transcript)
                                .foregroundColor(.white.opacity(0.9))
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(10)
                                .animation(.easeInOut(duration: 0.2), value: voiceManager.transcript)
                        }
                        .padding(.horizontal)
                    }
                    
                    if !voiceManager.lastResponse.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("AI Response:")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(voiceManager.lastResponse)
                                .foregroundColor(.white.opacity(0.9))
                                .padding()
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private var circleColor: Color {
        voiceManager.isListening ? Color.red : Color.blue
    }
}

#Preview {
    ContentView()
}
