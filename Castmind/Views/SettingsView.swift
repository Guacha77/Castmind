import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @State private var showBackupImporter = false
    @State private var showDeleteModel: LocalModelChoice?
    @State private var editingScenario: WorldScenario?

    var body: some View {
        ZStack {
            CastmindBackground(accent: CM.purple)
            ScrollView {
                VStack(spacing: 16) {
                    modelSection
                    performanceSection
                    speechSection
                    scenarioSection
                    bridgeSection
                    dataSection
                    statsSection
                    aboutSection
                }
                .padding(16)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Ajustes")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showBackupImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { app.importBackup(from: url) }
        }
        .sheet(item: $editingScenario) { scenario in
            ScenarioEditorSheet(scenario: scenario) { updated in
                if let index = app.settings.scenarios.firstIndex(where: { $0.id == updated.id }) {
                    app.settings.scenarios[index] = updated
                } else {
                    app.settings.scenarios.append(updated)
                }
                app.settings.selectedScenarioID = updated.id
                app.saveSettings()
            }
        }
        .confirmationDialog("Borrar modelo descargado", isPresented: Binding(
            get: { showDeleteModel != nil },
            set: { if !$0 { showDeleteModel = nil } }
        ), titleVisibility: .visible) {
            if let choice = showDeleteModel {
                Button("Borrar \(choice.title)", role: .destructive) { Task { await app.deleteModel(choice) }; showDeleteModel = nil }
            }
            Button("Cancelar", role: .cancel) { showDeleteModel = nil }
        }
    }

    private var modelSection: some View {
        CMCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack { CMSectionTitle(title: "Cerebro local", subtitle: "Un modelo compartido por todos los personajes"); Spacer(); ModelStatusBadge() }
                ForEach(LocalModelChoice.allCases) { choice in
                    VStack(spacing: 8) {
                        Button {
                            Task { await app.switchGlobalModel(to: choice) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: choice == .fast ? "bolt.fill" : choice == .balanced ? "sparkles" : "brain.head.profile")
                                    .foregroundStyle(choice == app.settings.modelChoice ? CM.purple : CM.textSecondary).frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack { Text(choice.title).font(.headline); if choice == .balanced { Text("RECOMENDADO").font(.caption2.weight(.black)).foregroundStyle(CM.purple) } }
                                    Text(choice.subtitle).font(.caption).foregroundStyle(CM.textSecondary)
                                }
                                Spacer()
                                Image(systemName: choice == app.settings.modelChoice ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(choice == app.settings.modelChoice ? CM.purple : CM.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        if app.ai.cachedModelDirectoryExists(for: choice) {
                            HStack {
                                CMChip(text: "DESCARGADO", icon: "checkmark", accent: CM.green)
                                Spacer()
                                Button("Borrar archivo") { showDeleteModel = choice }.font(.caption).foregroundStyle(CM.red)
                            }
                        }
                    }
                    if choice != LocalModelChoice.allCases.last { Divider().overlay(CM.border) }
                }
                Toggle("Cargar automáticamente al abrir", isOn: $app.settings.autoLoadModel).onChange(of: app.settings.autoLoadModel) { _, _ in app.saveSettings() }
                Toggle("Precalentar tras cargar", isOn: $app.settings.warmupModel).onChange(of: app.settings.warmupModel) { _, _ in app.saveSettings() }
                HStack(spacing: 10) {
                    Button { Task { await app.preloadModel() } } label: { Label("Cargar", systemImage: "play.fill") }.buttonStyle(.borderedProminent).tint(CM.purple)
                    Button { Task { await app.unloadModel() } } label: { Label("Liberar RAM", systemImage: "memorychip") }.buttonStyle(.bordered)
                }
            }
        }
    }

    private var performanceSection: some View {
        CMCard {
            VStack(alignment: .leading, spacing: 13) {
                CMSectionTitle(title: "Rendimiento", subtitle: "Castmind puede reducir contexto cuando el iPhone se calienta")
                Picker("Perfil", selection: $app.settings.performanceMode) {
                    ForEach(PerformanceMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
                .onChange(of: app.settings.performanceMode) { _, _ in app.saveSettings() }
                HStack {
                    Label("Temperatura", systemImage: "thermometer.medium").foregroundStyle(CM.textSecondary)
                    Spacer()
                    Text(app.performance.thermalLabel).font(.subheadline.weight(.semibold))
                }
                Toggle("Mostrar HUD técnico", isOn: $app.settings.showPerformanceHUD).onChange(of: app.settings.showPerformanceHUD) { _, _ in app.saveSettings() }
                if let benchmark = app.settings.benchmark {
                    HStack {
                        metric("Primer token", "\(benchmark.firstTokenMS) ms")
                        metric("Velocidad", String(format: "%.1f tok/s", benchmark.approximateTokensPerSecond))
                        metric("Carga", String(format: "%.1f s", benchmark.loadSeconds))
                    }
                }
                Button { Task { await app.runBenchmarkIfNeeded(force: true) } } label: { Label("Ejecutar benchmark", systemImage: "gauge.with.dots.needle.50percent") }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var speechSection: some View {
        CMCard {
            VStack(alignment: .leading, spacing: 13) {
                CMSectionTitle(title: "Voz y micrófono", subtitle: "Reconocimiento on-device y TTS nativo")
                Picker("Modo de micrófono", selection: $app.settings.voiceMode) {
                    ForEach(VoiceMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: app.settings.voiceMode) { _, _ in app.saveSettings() }
                Toggle("Wake words", isOn: $app.settings.wakeWordsEnabled)
                    .onChange(of: app.settings.wakeWordsEnabled) { _, _ in app.saveSettings() }
                Text("Con wake words, decir «Gregorio, …» puede cambiar automáticamente al personaje correspondiente.")
                    .font(.caption).foregroundStyle(CM.textSecondary)
                TextField("Locale", text: $app.settings.speechLocale)
                    .textInputAutocapitalization(.never)
                    .padding(10).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    .onSubmit { app.saveSettings() }
            }
        }
    }

    private var scenarioSection: some View {
        CMCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    CMSectionTitle(title: "Escenario", subtitle: "Contexto temporal que reciben todos los personajes")
                    Spacer()
                    Button { editingScenario = WorldScenario(title: "Nuevo escenario", context: "Describe lo que está ocurriendo para orientar a los personajes.", icon: "sparkles") } label: { Image(systemName: "plus.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(CM.purple)
                }
                ForEach(app.settings.scenarios) { scenario in
                    Button {
                        app.settings.selectedScenarioID = scenario.id
                        app.saveSettings()
                    } label: {
                        HStack {
                            Image(systemName: scenario.icon).frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(scenario.title).font(.subheadline.weight(.semibold))
                                Text(scenario.context).font(.caption).foregroundStyle(CM.textSecondary).lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: app.settings.selectedScenarioID == scenario.id ? "checkmark.circle.fill" : "circle")
                        }
                    }.buttonStyle(.plain)
                    .contextMenu {
                        Button("Editar", systemImage: "pencil") { editingScenario = scenario }
                        if app.settings.scenarios.count > 1 {
                            Button("Eliminar", systemImage: "trash", role: .destructive) {
                                app.settings.scenarios.removeAll { $0.id == scenario.id }
                                if app.settings.selectedScenarioID == scenario.id { app.settings.selectedScenarioID = app.settings.scenarios.first?.id }
                                app.saveSettings()
                            }
                        }
                    }
                    if scenario.id != app.settings.scenarios.last?.id { Divider().overlay(CM.border) }
                }
            }
        }
    }

    private var bridgeSection: some View {
        CMCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack { CMSectionTitle(title: "Stream Bridge V2", subtitle: "iPhone → PC → OBS por tu red local"); Spacer(); CMChip(text: app.bridge.statusText, icon: "dot.radiowaves.left.and.right", accent: bridgeAccent) }
                Toggle("Activar Stream Bridge", isOn: $app.settings.streamBridge.enabled)
                    .onChange(of: app.settings.streamBridge.enabled) { _, enabled in
                        app.saveSettings()
                        if enabled && app.settings.streamBridge.autoDiscover { app.bridgeDiscovery.start() }
                        if !enabled { app.bridge.disconnect() }
                    }
                Toggle("Descubrir PC automáticamente", isOn: $app.settings.streamBridge.autoDiscover)
                    .onChange(of: app.settings.streamBridge.autoDiscover) { _, enabled in
                        app.saveSettings()
                        if enabled { app.bridgeDiscovery.start() } else { app.bridgeDiscovery.stop() }
                    }
                if app.settings.streamBridge.autoDiscover {
                    if app.bridgeDiscovery.services.isEmpty {
                        HStack { ProgressView().controlSize(.small); Text("Buscando companion en la Wi‑Fi…").font(.caption).foregroundStyle(CM.textSecondary); Spacer(); Button("Buscar") { app.bridgeDiscovery.start() }.font(.caption) }
                    } else {
                        ForEach(app.bridgeDiscovery.services) { item in
                            Button {
                                app.useDiscoveredBridge(item)
                            } label: {
                                HStack { Image(systemName: "desktopcomputer"); VStack(alignment: .leading) { Text(item.name); Text("\(item.host):\(item.port)").font(.caption).foregroundStyle(CM.textSecondary) }; Spacer(); Image(systemName: "link") }
                            }.buttonStyle(.bordered)
                        }
                    }
                }
                DisclosureGroup("Configuración manual") {
                    VStack(spacing: 10) {
                        TextField("IP / host", text: $app.settings.streamBridge.host).textInputAutocapitalization(.never).keyboardType(.URL)
                        TextField("Puerto", value: $app.settings.streamBridge.port, format: .number).keyboardType(.numberPad)
                        SecureField("Clave compartida", text: $app.settings.streamBridge.secret)
                    }
                    .textFieldStyle(.roundedBorder)
                    .padding(.top, 8)
                }
                Button { app.saveSettings(); Task { await app.testBridge() } } label: { Label("Probar conexión", systemImage: "antenna.radiowaves.left.and.right") }.buttonStyle(.borderedProminent).tint(CM.cyan)
            }
        }
    }

    private var dataSection: some View {
        CMCard {
            VStack(alignment: .leading, spacing: 13) {
                CMSectionTitle(title: "Datos", subtitle: "Todo se guarda localmente")
                Button { app.exportBackup() } label: { Label("Exportar backup completo", systemImage: "square.and.arrow.up") }.buttonStyle(.bordered)
                Button { showBackupImporter = true } label: { Label("Restaurar backup", systemImage: "square.and.arrow.down") }.buttonStyle(.bordered)
            }
        }
    }

    private var statsSection: some View {
        CMCard {
            VStack(alignment: .leading, spacing: 13) {
                CMSectionTitle(title: "Actividad", subtitle: "Estadísticas locales; no salen del dispositivo")
                HStack {
                    metric("Mensajes", "\(app.library.stats.totalUserMessages)")
                    metric("Respuestas", "\(app.library.stats.totalAssistantMessages)")
                    metric("Lanzamientos", "\(app.library.stats.launches)")
                }
                if app.library.stats.averageFirstTokenMS > 0 {
                    Text("Tiempo medio hasta primer token: \(Int(app.library.stats.averageFirstTokenMS)) ms").font(.caption).foregroundStyle(CM.textSecondary)
                }
            }
        }
    }

    private var aboutSection: some View {
        CMCard {
            VStack(alignment: .leading, spacing: 7) {
                Text("CASTMIND V2").font(.caption.weight(.black)).tracking(2).foregroundStyle(CM.purple)
                Text("Personajes IA locales para iPhone y stream.").font(.headline)
                Text("Sin OpenAI, sin ElevenLabs, sin analytics y sin coste por conversación. MLX Swift LM + modelos MLX descargados bajo demanda.")
                    .font(.caption).foregroundStyle(CM.textSecondary)
            }
        }
    }

    private var bridgeAccent: Color {
        if case .connected = app.bridge.status { return CM.green }
        if case .failed = app.bridge.status { return CM.red }
        return CM.textSecondary
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) { Text(value).font(.headline.monospacedDigit()); Text(title).font(.caption2).foregroundStyle(CM.textSecondary) }.frame(maxWidth: .infinity)
    }
}


private struct ScenarioEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var scenario: WorldScenario
    let onSave: (WorldScenario) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Escenario") {
                    TextField("Nombre", text: $scenario.title)
                    TextField("Icono SF Symbol", text: $scenario.icon)
                }
                Section("Contexto") {
                    TextEditor(text: $scenario.context).frame(minHeight: 160)
                }
            }
            .navigationTitle("Editar escenario")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Guardar") { onSave(scenario); dismiss() }.disabled(scenario.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }
    }
}
