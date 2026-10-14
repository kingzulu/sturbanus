import SwiftData
import SwiftUI

/// Plätze verwalten: anlegen, Name, 9/18 Löcher, Par pro Loch, löschen.
struct CoursesView: View {
    @Query(sort: \Course.createdAt) private var courses: [Course]
    @State private var showNewCourse = false

    var body: some View {
        NavigationStack {
            List {
                if courses.isEmpty {
                    ContentUnavailableView("Noch kein Platz", systemImage: "map",
                                           description: Text("Lege deinen Heimatplatz mit + an."))
                }
                ForEach(courses) { course in
                    NavigationLink {
                        CourseEditView(course: course)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(course.name.isEmpty ? "Ohne Namen" : course.name)
                                .font(.headline)
                            Text("\(course.holes.count) Löcher · Par \(course.totalPar)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Plätze")
            .toolbar {
                Button("Platz anlegen", systemImage: "plus") { showNewCourse = true }
            }
            .sheet(isPresented: $showNewCourse) {
                NewCourseSheet()
            }
        }
    }
}

private struct NewCourseSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var holeCount = 18

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name des Platzes", text: $name)
                    Picker("Löcher", selection: $holeCount) {
                        Text("9 Löcher").tag(9)
                        Text("18 Löcher").tag(18)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("Alle Löcher starten mit Par 4. Die Pars passt du danach beim Platz an.")
                }
            }
            .navigationTitle("Neuer Platz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Anlegen") {
                        CourseService.createCourse(name: name, holeCount: holeCount, in: context)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct CourseEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var course: Course
    @State private var confirmDelete = false
    @State private var blockingRounds: Int?

    var body: some View {
        Form {
            Section("Platz") {
                TextField("Name", text: $course.name)
                Picker("Löcher", selection: Binding(
                    get: { course.holes.count },
                    set: { CourseService.setHoleCount($0, for: course, in: context) }
                )) {
                    Text("9 Löcher").tag(9)
                    Text("18 Löcher").tag(18)
                }
                .pickerStyle(.segmented)
                LabeledContent("Par gesamt", value: "\(course.totalPar)")
            }

            Section {
                ForEach(course.sortedHoles) { hole in
                    HoleParRow(hole: hole)
                }
            } header: {
                Text("Par pro Loch")
            } footer: {
                Text("Änderungen gelten für neue Runden. Gespielte Runden behalten ihre Pars.")
            }

            Section {
                Button("Platz löschen", role: .destructive) {
                    let rounds = CourseService.roundCount(for: course, in: context)
                    if rounds > 0 {
                        blockingRounds = rounds
                    } else {
                        confirmDelete = true
                    }
                }
            }
        }
        .navigationTitle(course.name.isEmpty ? "Platz" : course.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { try? context.save() }
        .confirmationDialog("Platz löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Platz löschen", role: .destructive) {
                // Erst zurück, dann löschen, damit keine Ansicht mehr auf den Platz zeigt.
                let course = course
                dismiss()
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    CourseService.deleteCourse(course, in: context)
                }
            }
        } message: {
            Text("Der Platz „\(course.name)“ wird gelöscht. Das lässt sich nicht rückgängig machen.")
        }
        .alert("Platz kann nicht gelöscht werden", isPresented: Binding(
            get: { blockingRounds != nil },
            set: { if !$0 { blockingRounds = nil } }
        )) {
            Button("OK") {}
        } message: {
            let count = blockingRounds ?? 0
            Text("Auf diesem Platz \(count == 1 ? "gibt es noch 1 Runde" : "gibt es noch \(count) Runden"). Lösche zuerst die Runden unter „Runden“.")
        }
    }
}

private struct HoleParRow: View {
    @Bindable var hole: Hole

    /// Par 3/4/5; ein älteres Par 6 bleibt wählbar, falls es schon gesetzt ist.
    private var options: [Int] { Array(Set([3, 4, 5, hole.par])).sorted() }

    var body: some View {
        HStack {
            Text("Loch \(hole.number)")
                .frame(width: 72, alignment: .leading)
            Picker("Par", selection: $hole.par) {
                ForEach(options, id: \.self) { Text("Par \($0)").tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }
}
