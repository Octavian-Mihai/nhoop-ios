import Foundation
import XCTest
@testable import StrandAnalytics

final class StepsDetailDensityTests: XCTestCase {
    private let projector: ([StepsDetailReading], StepsDetailRange, String?) -> [StepsDetailBucket] =
        StepsDetailDensity.project

    func testInvalidExplicitAnchorProducesNoBuckets() {
        let readings = [StepsDetailReading(day: "2024-02-29", value: 100)]
        XCTAssertEqual(projector(readings, .week, "2023-02-29"), [])
    }

    func testLatestValidReadingIsTheDefaultAnchor() {
        let readings = [
            StepsDetailReading(day: "2024-01-01", value: 1),
            StepsDetailReading(day: "2024-01-20", value: 2),
            StepsDetailReading(day: "invalid", value: 999),
        ]
        XCTAssertEqual(projector(readings, .week, nil), [
            StepsDetailBucket(key: "2024-01-20", displayDay: "2024-01-20",
                              sum: 2, observedDayCount: 1, mean: 2),
        ])
    }
}
