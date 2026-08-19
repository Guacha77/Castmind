import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @State private var showBackupImporter = false
    @State private var showDeleteModel: LocalModelChoice?

    var body: some View {
        ZStack {
            CastmindBackground()
            ScrollView {
                LazyVStack(spacing: 0) {
                    header
                    modelSection
                    performanceSection
                    speechSection
                    bridgeSection
                    dataSection
                    statsSection
                    aboutSection
                }
                .padding(12)
                .padding(.bottom, 20)
            }
        }
        .navigationBarHidden(true)
        .fileImporter(isPresented: $showBackupImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { app.importBackup(from: url) }
        }
        .confirmationDialog("Borrar modelo descargado", isPresented: Binding(
            get: { showDeleteModel != nil },
            set: { if !$0 { showDeleteModel = nil } }
        ), titleVisibility: .visible) {
            if let choice = showDeleteModel {
                Button("Borrar \(choice.title)", role: .destructive) {
                    Task { await app.deleteModel(choice) }
                    showDeleteModel = nil
                }
            }
            Button("Cancelar", role: .cancel) { showDeleteModel = nil }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SYSTEM_CFG").font(.system(.title2, design: .monospaced).weight(.black))
                Spacer(); ModelStatusBadge()
            }.padding(.vertical, 14)
            Rectangle().fill(CM.strongBorder).frame(height: 1)
        }
    }

    private var modelSection: some View {
        industrialSection("LOCAL_MODEL", subtitle: "Un único cerebro compartido. 1.7B es el perfil recomendado para estabilidad y latencia.") {
            ForEach(LocalModelChoice.allCases) { choice in
                Button {
                    Task { await app.switchGlobalModel(to: choice) }
                } label: {
                    HStack(spacing: 12) {
                        Text(choice == .fast ? "FST" : choice == .balanced ? "BAL" : "QLT")
                            .font(.caption2.monospaced().bold()).foregroundStyle(CM.orange).frame(width: 30)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(choice.title.uppercased()).font(.subheadline.monospaced().bold()).foregroundStyle(.white)
                                if choice == .balanced { Text("DEFAULT").font(.caption2.monospaced().bold()).foregroundStyle(CM.green) }
                            }
                            Text(choice.subtitle).font(.caption).foregroundStyle(CM.textSecondary)
                        }
                        Spacer()
                        Image(systemName: choice == app.settings.modelChoice ? "checkmark.square.fill" : "square")
                            .foregroundStyle(choice == app.settings.modelChoice ? CM.orange : CM.textTertiary)
                    }
                    .padding(.vertical, 10)
                }.buttonStyle(.plain)

                if app.ai.cachedModelDirectoryExists(for: choice) {
                    HStack {
                        Text("CACHED").font(.caption2.monospaced().bold()).foregroundStyle(CM.green)
                        Spacer()
                        Button("DELETE") { showDeleteModel = choice }
                            .font(.caption2.monospaced().bold()).foregroundStyle(CM.red)
                    }.padding(.bottom, 6)
                }
                if choice != LocalModelChoice.allCases.last { Rectangle().fill(CM.border).frame(height: 1) }
            }
            industrialToggle("AUTO_LOAD", isOn: $app.settings.autoLoadModel) { app.saveSettings() }
            industrialToggle("WARM_UP", isOn: $app.settings.warmupModel) { app.saveSettings() }
            HStack(spacing: 8) {
                Button("LOAD_MODEL") { Task { await app.preloadModel() } }.buttonStyle(CMPrimaryButtonStyle())
                Button("FREE_RAM") { Task { await app.unloadModel() } }
                    .font(.caption.monospaced().bold()).foregroundStyle(.white)
                    .padding(.horizontal, 12).frame(height: 46)
                    .overlay(Rectangle().stroke(CM.strongBorder))
            }.padding(.top, 8)
        }
    }

    private var performanceSection: some View {
        industrialSection("PERFORMANCE", subtitle: "Castmind reduce contexto y salida antes de forzar la memoria del iPhone.") {
            HStack {
                Text("PROFILE").font(.caption.monospaced().bold()).foregroundStyle(CM.textSecondary)
                Spacer()
                Picker("Perfil", selection: $app.settings.performanceMode) {
                    ForEach(PerformanceMode.allCases) { Text($0.title).tag($0) }
                }.labelsHidden().tint(CM.orange)
                    .onChange(of: app.settings.performanceMode) { _, _ in app.saveSettings() }
            }.padding(.vertical, 8)
            row("THERMAL", value: app.performance.thermalLabel.uppercased())
            industrialToggle("TECH_HUD", isOn: $app.settings.showPerformanceHUD) { app.saveSettings() }
            if let benchmark = app.settings.benchmark {
                row("TTFT", value: "\(benchmark.firstTokenMS) MS")
                row("SPEED", value: String(format: "%.1f TOK/S", benchmark.approximateTokensPerSecond))
            }
            Button("RUN_BENCHMARK") { Task { await app.runBenchmarkIfNeeded(force: true) } }
                .font(.caption.monospaced().bold()).foregroundStyle(CM.orange).padding(.top, 6)
        }
    }

    private var speechSection: some View {
        industrialSection("VOICE_IO", subtitle: "Reconocimiento on-device y voz nativa de iOS.") {
            HStack {
                Text("MIC_MODE").font(.caption.monospaced().bold()).foregroundStyle(CM.textSecondary)
                Spacer()
                Picker("Mic", selection: $app.settings.voiceMode) {
                    ForEach(VoiceMode.allCases) { Text($0.title).tag($0) }
                }.labelsHidden().tint(CM.orange)
                    .onChange(of: app.settings.voiceMode) { _, _ in app.saveSettings() }
            }.padding(.vertical, 8)
            industrialToggle("WAKE_WORDS", isOn: $app.settings.wakeWordsEnabled) { app.saveSettings() }
            TextField("es-ES", text: $app.settings.speechLocale)
                .textInputAutocapitalization(.never)
                .font(.body.monospaced())
                .padding(10).background(CM.background).overlay(Rectangle().stroke(CM.border))
                .onSubmit { app.saveSettings() }
        }
    }

    private var bridgeSection: some View {
        industrialSection("STREAM_BRIDGE", subtitle: "Opcional. iPhone → PC → OBS por red local.") {
            row("STATUS", value: app.bridge.statusText.uppercased(), color: bridgeAccent)
            industrialToggle("ENABLED", isOn: $app.settings.streamBridge.enabled) {
                app.saveSettings()
                if app.settings.streamBridge.enabled && app.settings.streamBridge.autoDiscover { app.bridgeDiscovery.start() }
                if !app.settings.streamBridge.enabled { app.bridge.disconnect() }
            }
            industrialToggle("AUTO_DISCOVERY", isOn: $app.settings.streamBridge.autoDiscover) {
                app.saveSettings()
                if app.settings.streamBridge.autoDiscover { app.bridgeDiscovery.start() } else { app.bridgeDiscovery.stop() }
            }
            if app.settings.streamBridge.autoDiscover {
                ForEach(app.bridgeDiscovery.services) { service in
                    Button {
                        app.useDiscoveredBridge(service)
                    } label: {
                        HStack {
                            Text(service.name.uppercased()).font(.caption.monospaced().bold()).foregroundStyle(.white)
                            Spacer(); Text("\(service.host):\(service.port)").font(.caption2.monospaced()).foregroundStyle(CM.textSecondary)
                        }.padding(.vertical, 7)
                    }.buttonStyle(.plain)
                }
            }
            DisclosureGroup("MANUAL") {
                VStack(spacing: 8) {
                    industrialField("HOST", text: $app.settings.streamBridge.host)
                    TextField("PORT", value: $app.settings.streamBridge.port, format: .number)
                        .keyboardType(.numberPad).font(.body.monospaced()).padding(10).background(CM.background).overlay(Rectangle().stroke(CM.border))
                    SecureField("SHARED_SECRET", text: $app.settings.streamBridge.secret)
                        .font(.body.monospaced()).padding(10).background(CM.background).overlay(Rectangle().stroke(CM.border))
                }.padding(.top, 8)
            }.font(.caption.monospaced().bold()).tint(CM.orange)
            Button("TEST_CONNECTION") { app.saveSettings(); Task { await app.testBridge() } }
                .font(.caption.monospaced().bold()).foregroundStyle(CM.orange).padding(.top, 6)
        }
    }

    private var dataSection: some View {
        industrialSection("LOCAL_DATA", subtitle: "Personajes, chats y memoria permanecen en este dispositivo.") {
            HStack {
                Button("EXPORT_BACKUP") { app.exportBackup() }
                Spacer()
                Button("RESTORE") { showBackupImporter = true }
            }.font(.caption.monospaced().bold()).foregroundStyle(CM.orange).padding(.vertical, 8)
        }
    }

    private var statsSection: some View {
        industrialSection("RUNTIME", subtitle: nil) {
            row("USER_MSG", value: "\(app.library.stats.totalUserMessages)")
            row("AI_MSG", value: "\(app.library.stats.totalAssistantMessages)")
            row("LAUNCHES", value: "\(app.library.stats.launches)")
            if app.library.stats.averageFirstTokenMS > 0 { row("AVG_TTFT", value: "\(Int(app.library.stats.averageFirstTokenMS)) MS") }
        }
    }

    private var aboutSection: some View {
        industrialSection("CASTMIND_V3", subtitle: "LOCAL CHARACTER RUNTIME / PRIVATE BUILD") {
            Text("Sin API de IA, sin analytics y sin coste por conversación. El campo COMPORTAMIENTO de cada personaje es la instrucción de máxima prioridad.")
                .font(.caption).foregroundStyle(CM.textSecondary).padding(.vertical, 8)
        }
    }

    private func industrialSection<Content: View>(_ title: String, subtitle: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.caption.monospaced().bold()).foregroundStyle(.white)
                Spacer(); Text("/").font(.caption.monospaced()).foregroundStyle(CM.orange)
            }.padding(.top, 14)
            if let subtitle { Text(subtitle).font(.caption).foregroundStyle(CM.textSecondary) }
            content()
            Rectangle().fill(CM.strongBorder).frame(height: 1).padding(.top, 8)
        }
    }

    private func industrialToggle(_ title: String, isOn: Binding<Bool>, changed: @escaping () -> Void) -> some View {
        Toggle(isOn: isOn) { Text(title).font(.caption.monospaced().bold()).foregroundStyle(CM.textSecondary) }
            .tint(CM.orange).padding(.vertical, 5).onChange(of: isOn.wrappedValue) { _, _ in changed() }
    }

    private func row(_ key: String, value: String, color: Color = .white) -> some View {
        HStack { Text(key).font(.caption.monospaced()).foregroundStyle(CM.textSecondary); Spacer(); Text(value).font(.caption.monospaced().bold()).foregroundStyle(color) }
            .padding(.vertical, 7).overlay(alignment: .bottom) { Rectangle().fill(CM.border).frame(height: 1) }
    }

    private func industrialField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text).textInputAutocapitalization(.never).font(.body.monospaced())
            .padding(10).background(CM.background).overlay(Rectangle().stroke(CM.border))
    }

    private var bridgeAccent: Color {
        if case .connected = app.bridge.status { return CM.green }
        if case .failed = app.bridge.status { return CM.red }
        return CM.textSecondary
    }
}
