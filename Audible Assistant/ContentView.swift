import SwiftUI
import SiriWaveView

struct ContentView: View {
    @StateObject var vm = ViewModel() // Only one instance of ViewModel
    @State var isSymbolAnimating = false
    
    var body: some View {
        VStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Audible Assistant")
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center) // Remove maxHeight: .infinity
                    .padding(.vertical, 10) // Add vertical padding
                
                Text("Click the microphone button to begin your conversation with AI!")
                    .font(.title2)
                    .frame(maxWidth: .infinity, alignment: .center) // Align this text as well
            }
            .padding(10)
            .background(Color.blue.opacity(0.2))
            .cornerRadius(10)
            
            SiriWaveView()
                .power(power: vm.audioPower) // Accessing from viewModel
                .opacity(vm.siriWaveFormOpacity)
                .frame(height: 300)
                .overlay { overlayView }
            
            Spacer()
            
            // Messages view - displays the list of messages
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(zip(vm.prompts.indices, vm.prompts)), id: \.0) { index, prompt in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(prompt)
                                .padding()
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            if index < vm.messages.count {
                                Text(vm.messages[index])
                                    .padding()
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(10)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                }
                .padding(15)
            }
            

            // Switch statement to handle different states of the app
            Group {
                switch vm.state {
                case .recordingSpeech:
                    cancelRecordingButton // Show cancel recording button
                    
                case .processingSpeech, .playingSpeech:
                    cancelButton // Show cancel button
                    
                default:
                    EmptyView() // Default empty view
                }
            }
            
            Picker("Select Voice", selection: $vm.selectedVoice) { // Picker to select voice type
                ForEach(VoiceType.allCases, id: \.self) {
                    Text($0.rawValue).id($0) // Looping over all voice types
                }
            }
            .pickerStyle(.segmented) // Style for the picker
            .disabled(!vm.isIdle) // Disabled when not idle
            
            // Display error message if there's an error state
            if case let .error(error) = vm.state {
                Text(error.localizedDescription)
                    .foregroundStyle(.red) // Red text for errors
                    .font(.caption) // Smaller font for error message
                    .lineLimit(2) // Limit to two lines
            }
        }
        .padding(15) // Padding around the VStack
    }
    
    // ViewBuilder for creating the overlay view
    @ViewBuilder
    var overlayView: some View {
        switch vm.state {
        case .idle, .error: // In idle or error state
            startCaptureButton // Show start capture button
        case .processingSpeech: // In processing state
            Image(systemName: "brain") // Display a brain icon
                .symbolEffect(.bounce.up.byLayer, options: .repeating, value: isSymbolAnimating) // Animated effect
                .font(.system(size: 128)) // Large icon size
                .onAppear { isSymbolAnimating = true } // Start animation on appear
                .onDisappear { isSymbolAnimating = false } // Stop animation on disappear
        default: EmptyView() // Default empty view
        }
    }
    
    // View for the start capture button
    var startCaptureButton: some View {
        Button {
            vm.startCaptureAudio() // Action to start audio capture
        } label: {
            Image(systemName: "mic.circle") // Microphone icon
                .symbolRenderingMode(.multicolor) // Multicolor rendering
                .font(.system(size: 50)) // Large icon size
        }.buttonStyle(.borderless) // Borderless button style
    }
    
    // View for the cancel recording button
    var cancelRecordingButton: some View {
        Button(role: .destructive) {
            vm.cancelRecording() // Action to cancel recording
        } label: {
            Image(systemName: "xmark.circle.fill") // X-mark icon
                .symbolRenderingMode(.multicolor) // Multicolor rendering
                .font(.system(size: 44)) // Icon size
        }.buttonStyle(.borderless) // Borderless button style

    }
    
    // View for the cancel button
    var cancelButton: some View {
        Button(role: .destructive) {
            vm.cancelProcessingTask() // Action to cancel processing
        } label: {
            Image(systemName: "stop.circle.fill") // Stop icon
                .symbolRenderingMode(.monochrome) // Monochrome rendering
                .foregroundStyle(.red) // Red color
                .font(.system(size: 44)) // Icon size
        }.buttonStyle(.borderless) // Borderless button style
    }
}


#Preview("Idle") {
    ContentView()
}

#Preview("Recording Speech") {
    let vm = ViewModel()
    vm.state = .recordingSpeech
    vm.audioPower = 0.2
    return ContentView(vm: vm)
}

#Preview("Processing Speech") {
    let vm = ViewModel()
    vm.state = .processingSpeech
    return ContentView(vm: vm)
}

#Preview("Playing Speech") {
    let vm = ViewModel()
    vm.state = .playingSpeech
    vm.audioPower = 0.3
    return ContentView(vm: vm)
}

#Preview("Error") {
    let vm = ViewModel()
    vm.state = .error("An error has occured")
    return ContentView(vm: vm)
}

 
