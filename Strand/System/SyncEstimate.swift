import Foundation

/// A rough "how long will the next strap sync take?" figure, learned from this strap's own past syncs.
///
/// The strap never says how much history it holds (see `SyncChipState`), so this does not pretend to
/// know the backlog. It assumes the strap has been recording since the last sync, which is the normal
/// case when it was worn, and scales by how fast past syncs moved: seconds of recorded time pulled per
/// second of syncing. Nothing is shown until at least one real sync has been timed, and the copy always
/// says "about".
///
/// Pure + platform-neutral so it is covered by StrandTests. Android has no twin yet.
enum SyncEstimate {
    /// Gaps shorter than this are not worth estimating (the sync is near-instant) or timing (too noisy).
    static let minGapSeconds: TimeInterval = 10 * 60
    /// Sessions shorter than this give a throughput dominated by link setup rather than transfer.
    static let minSessionSeconds: TimeInterval = 5
    /// Weight of the newest sample in the running average.
    static let smoothing = 0.4
    /// Plausible bounds on the learned rate (recorded seconds per sync second), against a corrupt value.
    static let rateRange: ClosedRange<Double> = 5...20_000

    static let rateKey = "sync.estimate.rate"

    /// Fold one completed, productive sync into the running rate. `gap` is how much recorded time it
    /// covered (previous sync to now); `duration` is how long the offload took. Returns the new rate, or
    /// the old one untouched when this sample is too small or too short to trust.
    static func updatedRate(previous: Double?, gap: TimeInterval, duration: TimeInterval) -> Double? {
        guard gap >= minGapSeconds, duration >= minSessionSeconds else { return previous }
        let sample = min(max(gap / duration, rateRange.lowerBound), rateRange.upperBound)
        guard let previous else { return sample }
        return previous * (1 - smoothing) + sample * smoothing
    }

    /// Estimated seconds to sync `gap` seconds of recording at `rate`, or nil when there is nothing
    /// honest to say (no learned rate yet, or too small a gap to matter).
    static func estimatedSeconds(gap: TimeInterval, rate: Double?) -> TimeInterval? {
        guard let rate, rate > 0, gap >= minGapSeconds else { return nil }
        return max(gap / rate, 1)
    }

    /// Persisted rate, if any sync has been timed yet.
    static var storedRate: Double? {
        let v = UserDefaults.standard.double(forKey: rateKey)
        return v > 0 ? v : nil
    }

    /// Record a finished productive sync. Called from the offload-complete path.
    static func record(previousSyncAt: TimeInterval?, startedAt: Date?, now: Date = Date()) {
        guard let previousSyncAt, let startedAt else { return }
        let gap = startedAt.timeIntervalSince1970 - previousSyncAt
        let duration = now.timeIntervalSince(startedAt)
        guard let rate = updatedRate(previous: storedRate, gap: gap, duration: duration) else { return }
        UserDefaults.standard.set(rate, forKey: rateKey)
    }

    /// "about 40 seconds" / "about 3 minutes", or nil. `lastSyncAt` is the last completed sync.
    static func copy(lastSyncAt: TimeInterval?, now: Date = Date(), rate: Double? = storedRate) -> String? {
        guard let lastSyncAt else { return nil }
        let gap = now.timeIntervalSince1970 - lastSyncAt
        guard let secs = estimatedSeconds(gap: gap, rate: rate) else { return nil }
        let f = DateComponentsFormatter()
        f.calendar = { var c = Calendar.current; c.locale = AppLanguage.activeLocale; return c }()
        f.unitsStyle = .full
        f.maximumUnitCount = 1
        f.allowedUnits = secs < 90 ? [.second] : [.minute, .hour]
        // Round to something that doesn't pretend to precision: 5 s steps under 90 s, whole minutes above.
        let rounded = secs < 90 ? max(5, (secs / 5).rounded() * 5) : (secs / 60).rounded() * 60
        guard let span = f.string(from: rounded) else { return nil }
        let gapText = DateComponentsFormatter()
        gapText.calendar = f.calendar
        gapText.unitsStyle = .full
        gapText.maximumUnitCount = 1
        gapText.allowedUnits = gap < 3600 * 2 ? [.minute] : (gap < 86_400 * 2 ? [.hour] : [.day])
        guard let since = gapText.string(from: gap) else { return nil }
        return String(localized: "About \(since) of new data should be waiting, so the next sync should take about \(span).")
    }
}
