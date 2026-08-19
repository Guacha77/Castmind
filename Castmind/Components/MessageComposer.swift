import SwiftUI

struct MessageComposer: View {
    @Binding var text: String
    let placeholder: String
    let accessibilityPrefix: String
    let isGenerating: Bool
    let isListening: Bool
    let listeningText: String?
    let canSend: Bool
    let onSend: () -> Void
    let onStop: () -> Void
    let onMicrophone: () -> Void

    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if isListening {
                HStack(spacing: 8) {
                    Circle().fill(CM.red).frame(width: 7, height: 7)
                    Text((listeningText?.isEmpty == false ? listeningText : "ESCUCHANDO...") ?? "ESCUCHANDO...")
                        .lineLimit(1)
                    Spacer(minLength: 8)
                }
                .font(.caption.monospaced())
                .foregroundStyle(CM.textSecondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button(action: onMicrophone) {
                    Image(systemName: isListening ? "stop.fill" : "mic.fill")
                        .frame(width: 44, height: 44)
                        .foregroundStyle(isListening ? CM.red : CM.concrete)
                        .background(CM.elevated2)
                        .overlay(Rectangle().stroke(isListening ? CM.red : CM.strongBorder, lineWidth: 1))
                }
                .accessibilityIdentifier("\(accessibilityPrefix).microphone")

                TextField(placeholder, text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body.monospaced())
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        if canSend { onSend() }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 44)
                    .background(CM.elevated)
                    .overlay(Rectangle().stroke(CM.strongBorder, lineWidth: 1))
                    .accessibilityIdentifier("\(accessibilityPrefix).textfield")

                Button {
                    if isGenerating {
                        onStop()
                    } else if canSend {
                        inputFocused = false
                        onSend()
                    }
                } label: {
                    Image(systemName: isGenerating ? "stop.fill" : "arrow.up")
                        .frame(width: 44, height: 44)
                        .foregroundStyle(isGenerating ? .white : .black)
                        .background(isGenerating ? CM.red : (canSend ? CM.orange : CM.textTertiary))
                        .overlay(Rectangle().stroke(CM.strongBorder, lineWidth: 1))
                }
                .disabled(!isGenerating && !canSend)
                .accessibilityIdentifier("\(accessibilityPrefix).send")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 58)
        .background(CM.elevated2)
        .overlay(Rectangle().stroke(CM.strongBorder, lineWidth: 1))
        .layoutPriority(100)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Message composer")
        .accessibilityIdentifier("\(accessibilityPrefix).composer")
    }
}
