import XCTest
@testable import Strand

final class SmartAlarmSnoozeTests: XCTestCase {
    func testShouldSnoozeStopsAtMaxRepeats() {
        XCTAssertTrue(SmartAlarmSnooze.shouldSnooze(enabled: true, repeatsSoFar: 0))
        XCTAssertTrue(SmartAlarmSnooze.shouldSnooze(enabled: true, repeatsSoFar: SmartAlarmSnooze.maxRepeats - 1))
        XCTAssertFalse(SmartAlarmSnooze.shouldSnooze(enabled: true, repeatsSoFar: SmartAlarmSnooze.maxRepeats))
        XCTAssertFalse(SmartAlarmSnooze.shouldSnooze(enabled: false, repeatsSoFar: 0))
    }

    func testFireDateRoundsUpToWholeMinute() {
        let now = Date(timeIntervalSince1970: 1_000_000_030)   // 30 s past a minute boundary
        let at = SmartAlarmSnooze.fireDate(after: now, delayMinutes: 4)
        XCTAssertEqual(at.timeIntervalSince1970.truncatingRemainder(dividingBy: 60), 0)
        XCTAssertGreaterThanOrEqual(at.timeIntervalSince(now), 4 * 60)
        XCTAssertLessThan(at.timeIntervalSince(now), 5 * 60)
    }

    func testFireDateOnExactMinuteAddsExactlyTheDelay() {
        let now = Date(timeIntervalSince1970: 1_000_000_020)   // divisible by 60
        XCTAssertEqual(SmartAlarmSnooze.fireDate(after: now, delayMinutes: 3).timeIntervalSince(now), 180)
    }

    func testClampedDelayFallsBackToDefault() {
        XCTAssertEqual(SmartAlarmSnooze.clampedDelay(10), 10)
        XCTAssertEqual(SmartAlarmSnooze.clampedDelay(7), SmartAlarmSnooze.defaultDelayMinutes)
        XCTAssertEqual(SmartAlarmSnooze.clampedDelay(-1), SmartAlarmSnooze.defaultDelayMinutes)
    }

    func testStaleChainCountsAsZero() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        XCTAssertEqual(SmartAlarmSnooze.repeatsSoFar(count: 2, lastFireAt: now.timeIntervalSince1970 - 60, now: now), 2)
        XCTAssertEqual(SmartAlarmSnooze.repeatsSoFar(count: 2, lastFireAt: now.timeIntervalSince1970 - 3600, now: now), 0)
        XCTAssertEqual(SmartAlarmSnooze.repeatsSoFar(count: 0, lastFireAt: now.timeIntervalSince1970, now: now), 0)
        XCTAssertEqual(SmartAlarmSnooze.repeatsSoFar(count: 2, lastFireAt: 0, now: now), 0)
    }
}

final class SyncEstimateTests: XCTestCase {
    func testFirstSampleBecomesTheRate() {
        // 1 h of recording pulled in 30 s = 120 recorded seconds per sync second.
        XCTAssertEqual(SyncEstimate.updatedRate(previous: nil, gap: 3600, duration: 30)!, 120, accuracy: 0.001)
    }

    func testLaterSamplesAreSmoothed() {
        let r = SyncEstimate.updatedRate(previous: 100, gap: 3600, duration: 30)!   // sample 120
        XCTAssertEqual(r, 100 * 0.6 + 120 * 0.4, accuracy: 0.001)
    }

    func testTinyGapOrShortSessionIsIgnored() {
        XCTAssertEqual(SyncEstimate.updatedRate(previous: 100, gap: 60, duration: 30), 100)
        XCTAssertEqual(SyncEstimate.updatedRate(previous: 100, gap: 3600, duration: 1), 100)
        XCTAssertNil(SyncEstimate.updatedRate(previous: nil, gap: 60, duration: 30))
    }

    func testEstimateNeedsARateAndAMeaningfulGap() {
        XCTAssertNil(SyncEstimate.estimatedSeconds(gap: 7200, rate: nil))
        XCTAssertNil(SyncEstimate.estimatedSeconds(gap: 60, rate: 120))
        XCTAssertEqual(SyncEstimate.estimatedSeconds(gap: 7200, rate: 120)!, 60, accuracy: 0.001)
    }

    func testCopyIsNilWithoutHistory() {
        XCTAssertNil(SyncEstimate.copy(lastSyncAt: nil, rate: 120))
        XCTAssertNil(SyncEstimate.copy(lastSyncAt: Date().timeIntervalSince1970 - 7200, rate: nil))
        XCTAssertNotNil(SyncEstimate.copy(lastSyncAt: Date().timeIntervalSince1970 - 7200, rate: 120))
    }
}
