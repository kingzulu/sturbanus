import Foundation
import SwiftData

/// Plätze anlegen, bearbeiten und löschen. Runden halten ihre Pars selbst (HoleScore.par),
/// Änderungen am Platz gelten daher nur für neue Runden.
@MainActor
enum CourseService {
    static let allowedHoleCounts = [9, 18]

    /// Plätze in der Reihenfolge für die Auswahl beim Rundenstart: zuletzt gespielt zuerst.
    static func coursesForSelection(in context: ModelContext) -> [Course] {
        let courses = (try? context.fetch(FetchDescriptor<Course>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        return courses.sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
    }

    @discardableResult
    static func createCourse(name: String, holeCount: Int, in context: ModelContext) -> Course {
        let course = Course(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(course)
        setHoleCount(holeCount, for: course, in: context)
        return course
    }

    /// 9 oder 18 Löcher; neue Löcher bekommen Par 4, überzählige werden entfernt.
    static func setHoleCount(_ count: Int, for course: Course, in context: ModelContext) {
        let target = allowedHoleCounts.contains(count) ? count : 18
        let current = course.holes.count
        if current < target {
            for number in (current + 1)...target {
                course.holes.append(Hole(number: number, par: 4))
            }
        } else if current > target {
            for hole in course.holes where hole.number > target {
                course.holes.removeAll { $0 === hole }
                context.delete(hole)
            }
        }
        try? context.save()
    }

    /// Anzahl der Runden, die auf diesem Platz gespielt wurden.
    static func roundCount(for course: Course, in context: ModelContext) -> Int {
        let rounds = (try? context.fetch(FetchDescriptor<Round>())) ?? []
        return rounds.filter { $0.course === course }.count
    }

    /// Löscht den Platz, aber nur, wenn keine Runden darauf existieren.
    /// - Returns: `false`, wenn noch Runden darauf gespielt wurden.
    @discardableResult
    static func deleteCourse(_ course: Course, in context: ModelContext) -> Bool {
        guard roundCount(for: course, in: context) == 0 else { return false }
        context.delete(course)
        try? context.save()
        return true
    }
}
