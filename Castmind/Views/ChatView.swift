import Foundation
import SwiftUI
import UIKit

struct ChatView: View {
    @EnvironmentObject private var app: AppState
    @FocusState private var focused: Bool
    @State private var showEditor = false
    @State private var showMemory = false
    @State private var showConversations = false
    @State private var showStream = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CastmindBackground(accent: CM.orange)
                VStack(spacing: 0) {
                    header
                    if app.settings.showPerformanceHUD { performanceHUD }
                    Rectangle().fill(CM.border).frame(height: 1)
                    messages
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    composer
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(100)
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            }
        }
        .navigationBarHidden(true)
        .toolbar { KeyboardDoneToolbar { focused = false } }
        .sheet(isPresented: $showEditor) { NavigationStack { CharacterEditorView(characterID: app.activeCharacter.id) } }
        .sheet(isPresented: $showMemory) { NavigationStack { MemoryView(characterID: app.activeCharacter.id) } }
        .sheet(isPresented: $showConversations) { NavigationStack { ConversationListView(characterID: app.activeCharacter.id) } }
        .fullScreenCover(isPresented: $showStream) { StreamModeView() }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                CharacterAvatarView(character: app.activeCharacter, size: 48, speaking: app.speaker.isSpeaking, listening: app.recognizer.isListening, speechPulse: app.speaker.speechPulse, audioLevel: app.recognizer.audioLevel)
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.activeCharacter.name.uppercased()).font(.system(.headline, design: .monospaced).weight(.black))
                    ModelStatusBadge()
                }
                Spacer()
                Button { showConversations = true } label: { Image(systemName: "clock.arrow.circlepath") }
                Button { showMemory = true } label: { Image(systemName: "brain") }
                Button { showEditor = true } label: { Image(systemName: "slider.horizontal.3") }
                Button { showStream = true } label: { Image(systemName: "rectangle.inset.filled") }
            }
            .foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 10)
            HStack {
                Text("CHAT / \(app.activeModelChoice.title.uppercased())").font(.caption2.monospaced().bold()).foregroundStyle(CM.textSecondary)
                Spacer()
                if app.speaker.isSpeaking { Text("VOICE_OUT").foregroundStyle(CM.green) }
                if app.isChatListening { Text("MIC_IN").foregroundStyle(CM.orange) }
            }.font(.caption2.monospaced().bold()).padding(.horizontal, 12).padding(.bottom, 8)
        }
    }

    private var performanceHUD: some View {
        HStack {
            Text("THERM_\(app.performance.thermalLabel.uppercased())")
            if let m = app.ai.lastMetrics { Text("TTFT_\(m.firstTokenMS)MS"); Text(String(format: "%.1fTOK/S", m.approximateTokensPerSecond)) }
            Spacer()
        }.font(.caption2.monospaced()).foregroundStyle(CM.textSecondary).padding(.horizontal, 12).padding(.vertical, 5).background(CM.elevated)
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(app.activeMessages) { message in
                        IndustrialMessage(message: message, character: app.activeCharacter, insightLoading: app.insightLoadingIDs.contains(message.id), onInsight: { Task { await app.loadInsight(for: message.id) } }, onReplay: { app.speaker.speak(message.text, settings: app.activeCharacter.voice, locale: app.settings.speechLocale) }, onRegenerate: { app.regenerateAssistantMessage(message.id) }, onDelete: { app.deleteMessage(message.id) }).id(message.id)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }.padding(12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { focused = false }
            .onChange(of: app.activeMessages.count) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: app.activeMessages.last?.text) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }

    private var composer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(CM.border).frame(height: 1)
            if app.isChatListening {
                HStack { Circle().fill(CM.red).frame(width: 7, height: 7); Text(app.recognizer.transcript.isEmpty ? "LISTENING…" : app.recognizer.transcript).lineLimit(1); Spacer() }
                    .font(.caption.monospaced()).foregroundStyle(CM.textSecondary).padding(.horizontal, 12).padding(.top, 8)
            }
            HStack(alignment: .bottom, spacing: 8) {
                Button { focused = false; Task { await app.toggleMicrophone() } } label: {
                    Image(systemName: app.isChatListening ? "stop.fill" : "mic.fill").frame(width: 44, height: 44).overlay(Rectangle().stroke(app.isChatListening ? CM.red : CM.border))
                }
                TextField("MESSAGE_\(app.activeCharacter.name.uppercased())", text: $app.composerText, axis: .vertical)
                    .accessibilityIdentifier("chat.composer.textfield")
                    .font(.body.monospaced()).lineLimit(1...4).focused($focused).submitLabel(.send)
                    .onSubmit { if !app.composerText.isEmpty { app.sendComposer() } }
                    .padding(10).frame(minHeight: 44).background(CM.elevated).overlay(Rectangle().stroke(CM.border))
                Button {
                    if app.ai.isGenerating { app.cancelCurrentResponse() } else { focused = false; app.sendComposer() }
                } label: {
                    Image(systemName: app.ai.isGenerating ? "stop.fill" : "arrow.up").frame(width: 42, height: 42).background(app.ai.isGenerating ? CM.red : CM.orange).foregroundStyle(.black)
                }
                .disabled(!app.ai.isGenerating && app.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding(10)
        }
        .frame(maxWidth: .infinity)
        .background(CM.background)
        .zIndex(50)
        .accessibilityIdentifier("chat.composer")
    }
}

private struct IndustrialMessage: View {
    let message: ChatMessage
    let character: CharacterProfile
    let insightLoading: Bool
    let onInsight: () -> Void
    let onReplay: () -> Void
    let onRegenerate: () -> Void
    let onDelete: () -> Void
    @State private var showInsight = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(message.role == .user ? "YOU" : character.name.uppercased()).font(.caption2.monospaced().bold()).foregroundStyle(message.role == .user ? CM.orange : CM.textSecondary)
                    if message.isStreaming { Text("LIVE").font(.caption2.monospaced().bold()).foregroundStyle(CM.green) }
                }
                Text(message.text.isEmpty && message.isStreaming ? "▍" : message.text)
                    .font(.body).foregroundStyle(.white).textSelection(.enabled)
                    .padding(11).frame(maxWidth: .infinity, alignment: .leading)
                    .background(message.role == .user ? CM.elevated2 : CM.elevated)
                    .overlay(Rectangle().stroke(message.role == .user ? CM.orange.opacity(0.55) : CM.border))
                    .gesture(DragGesture(minimumDistance: 18).onEnded { v in if message.role == .assistant && v.translation.width < -50 { showInsight = true; onInsight() } })
                    .contextMenu {
                        Button("Copiar") { UIPasteboard.general.string = message.text }
                        if message.role == .assistant { Button("Reproducir") { onReplay() }; Button("Explicación") { showInsight = true; onInsight() }; Button("Regenerar") { onRegenerate() } }
                        Button("Eliminar", role: .destructive) { onDelete() }
                    }
                if message.role == .assistant, let latency = message.latencyMS { Text("TTFT_\(latency)MS").font(.caption2.monospaced()).foregroundStyle(CM.textTertiary) }
                if showInsight && message.role == .assistant {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("RESPONSE_CONTEXT").font(.caption2.monospaced().bold()).foregroundStyle(CM.orange)
                        if let insight = message.insight { Text(insight).font(.caption).foregroundStyle(CM.textSecondary) }
                        else if insightLoading { ProgressView().controlSize(.small) }
                    }.padding(9).overlay(Rectangle().stroke(CM.border))
                }
            }
            if message.role != .user { Spacer(minLength: 34) }
        }
    }
}
