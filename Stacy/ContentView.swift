import SwiftUI
import Speech
import AVFoundation

class SimpleSpeechRecognizer: ObservableObject {
    @Published var transcript = ""
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer()
    
    func startRecording() {
        let request = SFSpeechAudioBufferRecognitionRequest()
        let inputNode = audioEngine.inputNode
        
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                }
            }
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputNode.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }
        
        try? audioEngine.start()
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
    }
}

struct ContentView: View {
    @StateObject private var speechRecognizer = SimpleSpeechRecognizer()
    @State private var isListening = false
    @State private var statusText = "Ready to help"
    @State private var pulseAnimation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.02, green: 0.06, blue: 0.23)
                    .ignoresSafeArea()
                VStack(spacing: 30) {
                    Spacer()
                    
                    Button(action: toggleListening) {
                        ZStack {
                            Circle()
                                .fill(isListening ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                                .frame(width: 220, height: 220)
                                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                                .opacity(pulseAnimation ? 0.5 : 1.0)
                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
                            
                            Circle()
                                .fill(isListening ? Color.red : Color.blue)
                                .frame(width: 180, height: 180)
                                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                            
                            VStack(spacing: 8) {
                                Image(systemName: isListening ? "waveform" : "mic.fill")
                                    .font(.system(size: 40, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text(isListening ? "LISTENING" : "TAP TO SPEAK")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    Text(statusText)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    if !speechRecognizer.transcript.isEmpty {
                        Text("You said: \(speechRecognizer.transcript)")
                            .foregroundColor(.white.opacity(0.8))
                            .padding()
                    }
                    
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private func toggleListening() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isListening.toggle()
        }
        
        if isListening {
            pulseAnimation = true
            statusText = "Listening..."
            speechRecognizer.startRecording()
        } else {
            pulseAnimation = false
            statusText = "Processing..."
            speechRecognizer.stopRecording()
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

#Preview {
    ContentView()
}
