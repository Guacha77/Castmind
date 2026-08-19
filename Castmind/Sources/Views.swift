import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var store: CastmindStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(store.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: store.messages) { _, messages in
                        guard let last = messages.last else { return }
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }

                Divider()

                HStack(spacing: 10) {
                    Button {
                        store.toggleDictation()
                    } label: {
                        Image(systemName: store.isListening ? "mic.fill" : "mic")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Dictado")

                    TextField("Mensaje", text: $store.draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)

                    if store.modelStatus.lifecycle == .generating {
                        Button {
                            store.cancelGeneration()
                        } label: {
                            Image(systemName: "stop.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    } else {
                        Button {
                            store.sendDraft()
                        } label: {
                            Image(systemName: "paperplane.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle("Castmind")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    ShareLink(item: store.exportText) {
                        Image(systemName: "square.and.arrow.up")
                    }

                    Button {
                        store.clearChat()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .alert("Castmind", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) {
                Button("OK", role: .cancel) { store.lastError = nil }
            } message: {
                Text(store.lastError ?? "")
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 44) }

            VStack(alignment: .leading, spacing: 6) {
                Text(message.role == .user ? "Tu" : "Castmind")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(message.text.isEmpty ? "..." : message.text)
                    .font(.body)
                    .textSelection(.enabled)
            }
            .padding(12)
            .background(message.role == .user ? Color.accentColor.opacity(0.22) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if message.role != .user { Spacer(minLength: 44) }
        }
    }
}

struct ModelView: View {
    @EnvironmentObject private var store: CastmindStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Estado") {
                    LabeledContent("Modelo", value: "mlx-community/Qwen3-1.7B-4bit")
                    LabeledContent("Motor", value: "MLX Swift LM 3.31.4")
                    LabeledContent("Estado", value: store.modelStatus.lifecycle.rawValue)
                    if store.modelStatus.progress > 0 && store.modelStatus.progress < 1 {
                        ProgressView(value: store.modelStatus.progress)
                    }
                    Text(store.modelStatus.detail)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        store.downloadModel()
                    } label: {
                        Label("Descargar o cargar modelo", systemImage: "arrow.down.circle")
                    }

                    Button {
                        store.unloadModel()
                    } label: {
                        Label("Liberar memoria", systemImage: "memorychip")
                    }

                    Button(role: .destructive) {
                        store.deleteDownloadedModel()
                    } label: {
                        Label("Eliminar descarga local", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Modelo")
        }
    }
}

struct CharacterView: View {
    @EnvironmentObject private var store: CastmindStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Identidad") {
                    TextField("Nombre", text: $store.profile.name)
                    TextField("Estado emocional", text: $store.profile.emotionalState)
                }

                Section("Personalidad") {
                    TextEditor(text: $store.profile.personality)
                        .frame(minHeight: 110)
                }

                Section("Memoria") {
                    TextEditor(text: $store.profile.memory)
                        .frame(minHeight: 140)
                }

                Section {
                    Button {
                        store.saveProfile()
                    } label: {
                        Label("Guardar personaje", systemImage: "checkmark.circle")
                    }
                }
            }
            .navigationTitle("Personaje")
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: CastmindStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Generacion") {
                    VStack(alignment: .leading) {
                        LabeledContent("Temperatura", value: store.settings.temperature.formatted(.number.precision(.fractionLength(2))))
                        Slider(value: $store.settings.temperature, in: 0...1.4, step: 0.05)
                    }
                    VStack(alignment: .leading) {
                        LabeledContent("Top P", value: store.settings.topP.formatted(.number.precision(.fractionLength(2))))
                        Slider(value: $store.settings.topP, in: 0.1...1, step: 0.05)
                    }
                    Stepper("Max tokens: \(store.settings.maxTokens)", value: $store.settings.maxTokens, in: 64...2048, step: 64)
                }

                Section("Voz") {
                    Toggle("Leer respuestas", isOn: $store.settings.speakReplies)
                    Picker("Voz", selection: $store.profile.voiceIdentifier) {
                        Text("Sistema").tag(Optional<String>.none)
                        ForEach(store.availableVoices, id: \.identifier) { voice in
                            Text("\(voice.name) (\(voice.language))").tag(Optional(voice.identifier))
                        }
                    }
                    Button {
                        store.speak("Hola. Soy Castmind y estoy funcionando con la voz seleccionada.")
                    } label: {
                        Label("Probar voz", systemImage: "speaker.wave.2")
                    }
                    Button {
                        store.stopSpeaking()
                    } label: {
                        Label("Detener voz", systemImage: "speaker.slash")
                    }
                }

                Section("Stream Bridge") {
                    Toggle("Activar puente local", isOn: $store.profile.streamBridgeEnabled)
                    Stepper("Puerto: \(store.profile.streamBridgePort)", value: $store.profile.streamBridgePort, in: 1024...65535)
                    Text("http://iphone-local:\(store.profile.streamBridgePort)")
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        store.saveSettings()
                        store.saveProfile()
                    } label: {
                        Label("Guardar ajustes", systemImage: "checkmark.circle")
                    }
                }
            }
            .navigationTitle("Ajustes")
        }
    }
}
