import SwiftUI

struct MemoryView: View {
    @EnvironmentObject private var app: AppState
    let characterID: UUID
    @State private var search = ""
    @State private var category: MemoryCategory? = nil
    @State private var showAdd = false

    private var character: CharacterProfile {
        app.library.characters.first(where: { $0.id == characterID }) ?? app.activeCharacter
    }

    private var memories: [MemoryItem] {
        app.library.memories
            .filter { $0.characterID == characterID }
            .filter { category == nil || $0.category == category }
            .filter { search.isEmpty || $0.text.localizedCaseInsensitiveContains(search) }
            .sorted { a, b in
                if a.isPinned != b.isPinned { return a.isPinned && !b.isPinned }
                return a.createdAt > b.createdAt
            }
    }

    var body: some View {
        ZStack {
            CastmindBackground(accent: Color(hex: character.accentHex))
            VStack(spacing: 0) {
                filters
                if memories.isEmpty {
                    ContentUnavailableView(
                        search.isEmpty ? "Sin recuerdos" : "No hay resultados",
                        systemImage: "brain.head.profile",
                        description: Text(search.isEmpty ? "Cuando la memoria está activa, Castmind guarda hechos útiles de forma local." : "Prueba otra búsqueda.")
                    )
                } else {
                    List {
                        ForEach(memories) { memory in
                            MemoryRow(memory: memory)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { app.deleteMemory(memory.id) } label: { Label("Eliminar", systemImage: "trash") }
                                }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Memoria · \(character.name)")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Buscar recuerdos")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
                Menu {
                    Button("Todos") { category = nil }
                    ForEach(MemoryCategory.allCases) { value in Button(value.title) { category = value } }
                } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
            }
        }
        .sheet(isPresented: $showAdd) { AddMemorySheet(characterID: characterID) }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                CMChip(text: "\(app.library.memories.filter { $0.characterID == characterID }.count) recuerdos", icon: "brain")
                if let category { CMChip(text: category.title, icon: category.icon, accent: CM.cyan) }
                if !character.memory.enabled { CMChip(text: "MEMORIA DESACTIVADA", icon: "pause.fill", accent: CM.orange) }
            }.padding(.horizontal, 16).padding(.vertical, 10)
        }
    }
}

private struct MemoryRow: View {
    @EnvironmentObject private var app: AppState
    @State var memory: MemoryItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: memory.category.icon)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.06), in: Circle())
                .foregroundStyle(memory.isPinned ? CM.purple : CM.textSecondary)
            VStack(alignment: .leading, spacing: 6) {
                Text(memory.text).font(.subheadline)
                HStack(spacing: 8) {
                    Text(memory.category.title).font(.caption2.weight(.semibold)).foregroundStyle(CM.textSecondary)
                    Text("importancia \(Int(memory.importance * 100))%").font(.caption2).foregroundStyle(CM.textTertiary)
                    if memory.source == "auto" { Text("AUTO").font(.caption2.weight(.black)).foregroundStyle(CM.green) }
                }
            }
            Spacer()
            Button {
                memory.isPinned.toggle()
                memory.importance = memory.isPinned ? max(memory.importance, 0.95) : memory.importance
                app.updateMemory(memory)
            } label: {
                Image(systemName: memory.isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(memory.isPinned ? CM.purple : CM.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 5)
    }
}

private struct AddMemorySheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    let characterID: UUID
    @State private var text = ""
    @State private var category: MemoryCategory = .event
    @State private var pinned = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Recuerdo") {
                    TextEditor(text: $text).frame(minHeight: 120)
                    Picker("Tipo", selection: $category) { ForEach(MemoryCategory.allCases) { Text($0.title).tag($0) } }
                    Toggle("Fijar siempre", isOn: $pinned)
                }
            }
            .navigationTitle("Nuevo recuerdo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        app.addMemory(text, characterID: characterID, category: category, pinned: pinned)
                        dismiss()
                    }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
