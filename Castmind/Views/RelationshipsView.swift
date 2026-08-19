import SwiftUI

struct RelationshipsView: View {
    @EnvironmentObject private var app: AppState
    let characterID: UUID
    @State private var draft: CharacterProfile?
    @State private var showAdd = false

    var body: some View {
        ZStack {
            CastmindBackground(accent: Color(hex: draft?.accentHex ?? "9C6BFF"))
            if let draft {
                if draft.relationships.isEmpty {
                    ContentUnavailableView("Sin relaciones", systemImage: "person.2", description: Text("Añade viewers, amigos u otros personajes para que esta opinión forme parte del contexto."))
                } else {
                    List {
                        ForEach(draft.relationships) { relation in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Text(relation.name).font(.headline); Spacer(); Text(relation.relationship).font(.caption).foregroundStyle(CM.textSecondary) }
                                HStack { Text("Confianza \(Int(relation.trust))"); Spacer(); Text("Afinidad \(Int(relation.affinity))") }.font(.caption2).foregroundStyle(CM.textTertiary)
                                if !relation.notes.isEmpty { Text(relation.notes).font(.caption).foregroundStyle(CM.textSecondary) }
                            }
                            .listRowBackground(Color.clear)
                            .swipeActions { Button(role: .destructive) { delete(relation.id) } label: { Label("Eliminar", systemImage: "trash") } }
                        }
                    }.scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Relaciones")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showAdd) { AddRelationshipSheet { add($0) } }
        .onAppear { draft = app.library.characters.first(where: { $0.id == characterID }) }
        .onDisappear { if let draft { app.updateCharacter(draft) } }
    }

    private func add(_ relation: RelationshipRecord) {
        draft?.relationships.append(relation)
        if let draft { app.updateCharacter(draft) }
    }

    private func delete(_ id: UUID) {
        draft?.relationships.removeAll { $0.id == id }
        if let draft { app.updateCharacter(draft) }
    }
}

private struct AddRelationshipSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (RelationshipRecord) -> Void
    @State private var name = ""
    @State private var kind = "Viewer"
    @State private var trust = 50.0
    @State private var affinity = 50.0
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Identidad") { TextField("Nombre", text: $name); TextField("Relación", text: $kind) }
                Section("Estado") {
                    VStack { HStack { Text("Confianza"); Spacer(); Text("\(Int(trust))") }; Slider(value: $trust, in: 0...100) }
                    VStack { HStack { Text("Afinidad"); Spacer(); Text("\(Int(affinity))") }; Slider(value: $affinity, in: 0...100) }
                }
                Section("Notas") { TextEditor(text: $notes).frame(minHeight: 90) }
            }
            .navigationTitle("Nueva relación")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onSave(RelationshipRecord(name: name.trimmingCharacters(in: .whitespacesAndNewlines), relationship: kind, trust: trust, affinity: affinity, notes: notes))
                        dismiss()
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
