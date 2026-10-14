import Foundation
import SwiftData
import Testing
@testable import StUrbanus

@MainActor
struct CourseServiceTests {
    let context: ModelContext

    init() throws {
        let container = try ModelContainer(
            for: Course.self, Hole.self, Round.self, HoleScore.self, Shot.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    @Test func createNineHoleCourse() {
        let course = CourseService.createCourse(name: "  GC Mein Club ", holeCount: 9, in: context)
        #expect(course.name == "GC Mein Club")
        #expect(course.sortedHoles.map(\.number) == Array(1...9))
        #expect(course.totalPar == 36)
    }

    @Test func changeHoleCount() {
        let course = CourseService.createCourse(name: "Club", holeCount: 9, in: context)
        course.sortedHoles[0].par = 5
        CourseService.setHoleCount(18, for: course, in: context)
        #expect(course.holes.count == 18)
        #expect(course.sortedHoles[0].par == 5)
        CourseService.setHoleCount(9, for: course, in: context)
        #expect(course.sortedHoles.map(\.number) == Array(1...9))
        #expect(course.sortedHoles[0].par == 5)
    }

    @Test func parChangeDoesNotAlterPlayedRound() {
        let course = CourseService.createCourse(name: "Club", holeCount: 18, in: context)
        let round = RoundService.startRound(on: course, in: context)
        course.sortedHoles[0].par = 3
        #expect(round.sortedScores[0].par == 4)
        let next = RoundService.startRound(on: course, in: context)
        #expect(next.sortedScores[0].par == 3)
    }

    @Test func deleteIsBlockedWhileRoundsExist() throws {
        let course = CourseService.createCourse(name: "Club", holeCount: 9, in: context)
        let round = RoundService.startRound(on: course, in: context)
        #expect(CourseService.roundCount(for: course, in: context) == 1)
        #expect(!CourseService.deleteCourse(course, in: context))
        #expect(try context.fetchCount(FetchDescriptor<Course>()) == 1)

        RoundService.deleteRound(round, in: context)
        #expect(CourseService.deleteCourse(course, in: context))
        #expect(try context.fetchCount(FetchDescriptor<Course>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Hole>()) == 0)
    }

    @Test func lastPlayedCourseComesFirst() {
        let home = CourseService.createCourse(name: "Heimat", holeCount: 18, in: context)
        let away = CourseService.createCourse(name: "Auswärts", holeCount: 9, in: context)
        _ = RoundService.startRound(on: away, in: context)
        #expect(CourseService.coursesForSelection(in: context).first === away)
        _ = RoundService.startRound(on: home, in: context)
        #expect(CourseService.coursesForSelection(in: context).first === home)
    }

    @Test func nineHoleRoundEndsAfterHoleNine() {
        let course = CourseService.createCourse(name: "Kurzplatz", holeCount: 9, in: context)
        let round = RoundService.startRound(on: course, in: context)
        round.currentHole = 9
        let reply = RoundService.apply(.nextHole, to: round, in: context)
        #expect(reply.hasPrefix("Das war das letzte Loch."))
    }

    @Test func statsFilterByCourse() throws {
        let home = CourseService.createCourse(name: "Heimat", holeCount: 9, in: context)
        let away = CourseService.createCourse(name: "Auswärts", holeCount: 9, in: context)
        let homeRound = RoundService.startRound(on: home, in: context)
        RoundService.logShot(.drive, .good, nil, in: homeRound, context: context)
        let awayRound = RoundService.startRound(on: away, in: context)
        RoundService.logShot(.putt, .short, nil, in: awayRound, context: context)

        let shots = try context.fetch(FetchDescriptor<Shot>())
        let homeID = home.persistentModelID
        #expect(shots.filter { StatsFilter.matches($0.holeScore?.round, nil) }.count == 2)
        #expect(shots.filter { StatsFilter.matches($0.holeScore?.round, homeID) }.map(\.shotType) == [.drive])
    }

    @Test func seedOnlyOnFirstLaunch() throws {
        let defaults = try #require(UserDefaults(suiteName: "CourseServiceTests-\(UUID().uuidString)"))
        SeedData.seedIfNeeded(context, defaults: defaults)
        let seeded = try context.fetch(FetchDescriptor<Course>())
        #expect(seeded.map(\.name) == [SeedData.stUrbanusName])
        #expect(seeded.first?.totalPar == 72)

        // Hat jemand alle Plätze gelöscht, kommt St. Urbanus nicht zurück.
        for course in seeded { CourseService.deleteCourse(course, in: context) }
        SeedData.seedIfNeeded(context, defaults: defaults)
        #expect(try context.fetchCount(FetchDescriptor<Course>()) == 0)
    }
}
