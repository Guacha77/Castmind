import SwiftUI
import UIKit

struct ChatView: View {
    @EnvironmentObject private var app: AppState
    @FocusState private var composerFocused: Bool
    @State private var showEditor = false
    @State private var showMemory = false
    @State private var showConversations = false
    @State private var showStreamMode = false

    var body: some View {
        ZStack {
            CastmindBackground(accent: Color(hex: app.activeCharacter.accentHex))
            VStack(spacing: 0) {
                characterHeader
                if app.settings.showPerformanceHUD { performanceHUD }
                Divider().overlay(CM.border)
                messages
                composer
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showConversations = true } label: { Image(systemName: "clock.arrow.circlepath") }
            }
            ToolbarItem(placement: .principal) { ModelStatusBadge() }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showStreamMode = true } label: { Image(systemName: "rectangle.inset.filled.and.person.filled") }
                Menu {
                    Button("Memoria", systemImage: "brain.head.profile") { showMemory = true }
                    Button("Editar personaje", systemImage: "slider.horizontal.3") { showEditor = true }
                    Button("Nueva conversación", systemImage: "plus.bubble") { app.newConversation() }
                    Button("Exportar personaje", systemImage: "square.and.arrow.up") { app.exportActiveCharacter() }
                } label: { Image(systemName: "ellipsis.circle") }
            }
            KeyboardDoneToolbar { composerFocused = false }
        }
        .sheet(isPresented: $showEditor) { NavigationStack { CharacterEditorView(characterID: app.activeCharacter.id) } }
        .sheet(isPresented: $showMemory) { NavigationStack { MemoryView(characterID: app.activeCharacter.id) } }
        .sheet(isPresented: $showConversations) { NavigationStack { ConversationListView(characterID: app.activeCharacter.id) } }
        .fullScreenCover(isPresented: $showStreamMode) { StreamModeView() }
    }


    private var performanceHUD: some View {
        HStack(spacing: 10) {
            Label(app.performance.thermalLabel, systemImage: "thermometer.medium")
            if let metrics = app.ai.lastMetrics {
                Label("\(metrics.firstTokenMS) ms", systemImage: "bolt.fill")
                Label(String(format: "%.1f tok/s", metrics.approximateTokensPerSecond), systemImage: "speedometer")
            } else {
                Text("Sin métrica todavía")
            }
            Spacer(minLength: 4)
            Text(app.settings.performanceMode.title)
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(CM.textSecondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rendimiento del modelo")
    }

    private var characterHeader: some View {
        HStack(spacing: 14) {
            CharacterAvatarView(
                character: app.activeCharacter,
                size: 68,
                speaking: app.speaker.isSpeaking,
                listening: app.recognizer.isListening,
                speechPulse: app.speaker.speechPulse,
                audioLevel: app.recognizer.audioLevel
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(app.activeCharacter.name).font(.title3.bold())
                HStack(spacing: 8) {
                    Text(app.activeCharacter.subtitle).font(.caption).foregroundStyle(CM.textSecondary).lineLimit(1)
                    if app.speaker.isSpeaking { CMChip(text: "HABLANDO", icon: "waveform", accent: CM.green) }
                    else if app.recognizer.isListening { CMChip(text: "ESCUCHANDO", icon: "mic.fill", accent: CM.orange) }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(app.activeModelChoice.title).font(.caption.weight(.semibold))
                Text(app.selectedScenario.title).font(.caption2).foregroundStyle(CM.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if app.activeMessages.count <= 2 {
                        Text("Desliza una respuesta de \(app.activeCharacter.name) hacia la izquierda para ver un resumen de por qué respondió así.")
                            .font(.caption).foregroundStyle(CM.textTertiary).multilineTextAlignment(.center).padding(.horizontal, 34).padding(.top, 8)
                    }
                    ForEach(app.activeMessages) { message in
                        ChatMessageBubble(
                            message: message,
                            character: app.activeCharacter,
                            insightLoading: app.insightLoadingIDs.contains(message.id),
                            onRevealInsight: { Task { await app.loadInsight(for: message.id) } },
                            onReplay: {
                                if message.role == .assistant {
                                    app.speaker.speak(message.text, settings: app.activeCharacter.voice, locale: app.settings.speechLocale)
                                }
                            },
                            onRegenerate: { app.regenerateAssistantMessage(message.id) },
                            onDelete: { app.deleteMessage(message.id) }
                        )
                        .id(message.id)
                    }
                    Color.clear.frame(height: 2).id("bottom")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { composerFocused = false }
            .onChange(of: app.activeMessages.count) { _, _ in withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) } }
            .onChange(of: app.activeMessages.last?.text) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }

    private var composer: some View {
        VStack(spacing: 7) {
            if app.recognizer.isListening {
                HStack(spacing: 9) {
                    Circle().fill(CM.red).frame(width: 8, height: 8)
                    Text(app.recognizer.transcript.isEmpty ? "Te escucho…" : app.recognizer.transcript)
                        .font(.caption).foregroundStyle(CM.textSecondary).lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            HStack(alignment: .bottom, spacing: 9) {
                Button {
                    composerFocused = false
                    Task { await app.toggleMicrophone() }
                } label: {
                    Image(systemName: app.recognizer.isListening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(app.recognizer.isListening ? CM.red.opacity(0.18) : Color.white.opacity(0.07), in: Circle())
                        .foregroundStyle(app.recognizer.isListening ? CM.red : .white)
                }

                TextField("Habla con \(app.activeCharacter.name)…", text: $app.composerText, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($composerFocused)
                    .submitLabel(.send)
                    .onSubmit { if !app.composerText.isEmpty { app.sendComposer() } }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(CM.border))

                if app.ai.isGenerating {
                    Button { app.cancelCurrentResponse() } label: {
                        Image(systemName: "stop.fill")
                            .frame(width: 44, height: 44)
                            .background(CM.orange, in: Circle()).foregroundStyle(CM.background)
                    }
                } else {
                    Button {
                        composerFocused = false
                        app.sendComposer()
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .bold))
                            .frame(width: 44, height: 44)
                            .background(app.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.white.opacity(0.07) : Color(hex: app.activeCharacter.accentHex), in: Circle())
                            .foregroundStyle(app.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? CM.textTertiary : .white)
                    }
                    .disabled(app.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 9)
            .padding(.bottom, 7)
        }
        .background(.ultraThinMaterial)
    }
}

private struct ChatMessageBubble: View {
    let message: ChatMessage
    let character: CharacterProfile
    let insightLoading: Bool
    let onRevealInsight: () -> Void
    let onReplay: () -> Void
    let onRegenerate: () -> Void
    let onDelete: () -> Void

    @State private var showInsight = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user { Spacer(minLength: 46) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 7) {
                Text(message.text.isEmpty && message.isStreaming ? "▍" : message.text)
                    .font(.body)
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        if message.isStreaming { Circle().fill(CM.green).frame(width: 6, height: 6).offset(x: -7, y: -6) }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 18)
                            .onEnded { value in
                                guard message.role == .assistant, value.translation.width < -55 else { return }
                                withAnimation(.snappy) { showInsight = true }
                                onRevealInsight()
                            }
                    )
                    .contextMenu {
                        Button("Copiar", systemImage: "doc.on.doc") { UIPasteboard.general.string = message.text }
                        if message.role == .assistant {
                            Button("Reproducir voz", systemImage: "speaker.wave.2.fill") { onReplay() }
                            Button("Por qué respondió así", systemImage: "sparkles") {
                                showInsight = true
                                onRevealInsight()
                            }
                            Button("Regenerar respuesta", systemImage: "arrow.clockwise") { onRegenerate() }
                        }
                        Button("Eliminar mensaje", systemImage: "trash", role: .destructive) { onDelete() }
                    }

                if message.role == .assistant, let latency = message.latencyMS {
                    Text("primer token · \(latency) ms")
                        .font(.caption2.monospacedDigit()).foregroundStyle(CM.textTertiary).padding(.leading, 4)
                }

                if message.role == .assistant && showInsight {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("POR QUÉ RESPONDIÓ ASÍ").font(.caption2.weight(.black)).tracking(0.7)
                            Spacer()
                            Button { withAnimation { showInsight = false } } label: { Image(systemName: "xmark.circle.fill") }
                        }
                        .foregroundStyle(Color(hex: character.accentHex))
                        if let insight = message.insight {
                            Text(insight).font(.caption).foregroundStyle(CM.textSecondary)
                        } else if insightLoading {
                            HStack { ProgressView().controlSize(.small); Text("Resumiendo factores…").font(.caption).foregroundStyle(CM.textSecondary) }
                        } else {
                            Text("Desliza de nuevo para generar el resumen.").font(.caption).foregroundStyle(CM.textSecondary)
                        }
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 15))
                    .overlay(RoundedRectangle(cornerRadius: 15).stroke(CM.border))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            if message.role != .user { Spacer(minLength: 32) }
        }
    }

    private var bubbleBackground: AnyShapeStyle {
        if message.role == .user {
            return AnyShapeStyle(Color(hex: character.accentHex).opacity(0.88))
        }
        return AnyShapeStyle(CM.elevated2.opacity(0.94))
    }
}
