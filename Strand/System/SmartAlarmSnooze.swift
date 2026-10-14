import Foundation

/// Snooze for the strap wake-alarm. Pure + platform-neutral so the rules are unit-testable (StrandTests).
///
/// The strap holds ONE absolute alarm instant, so a snooze is a re-arm: when the strap reports it fired
/// (STRAP_DRIVEN_ALARM_EXECUTED) and snooze is on, the alarm is re-armed `delay` minutes later instead of
/// for tomorrow. This needs the strap connected to the phone at the moment it fires, because that event is
/// how NOOP learns the buzz happened. A strap out of range simply buzzes once, as it did before.
///
/// The chain ends on its own after `maxRepeats` re-arms, and early when the wearer double-taps the strap
/// or opens the app (both mean "I'm awake").
enum SmartAlarmSnooze {
    /// Delays offered in the picker, in minutes.
    static let delayOptions = [3, 4, 5, 10]
    static let defaultDelayMinutes = 4
    /// Re-arms after the first buzz, so the strap buzzes at most `maxRepeats + 1` times in a morning.
    static let maxRepeats = 3

    /// Defaults keys for the chain in flight. Process-independent so a relaunch mid-chain keeps it.
    static let countKey = "alarm.snoozeCount"
    static let fireAtKey = "alarm.snoozeFireAt"

    /// A chain older than this is dead (the strap never reported back), so its count no longer applies.
    static let chainStaleSeconds: TimeInterval = 15 * 60

    /// Re-arms already used in the chain in flight, or 0 when there is none or it has gone stale.
    static func repeatsSoFar(count: Int, lastFireAt: TimeInterval, now: Date) -> Int {
        guard count > 0, lastFireAt > 0,
              abs(now.timeIntervalSince1970 - lastFireAt) <= chainStaleSeconds else { return 0 }
        return count
    }

    /// Clamp a stored delay to an offered value.
    static func clampedDelay(_ minutes: Int) -> Int {
        delayOptions.contains(minutes) ? minutes : defaultDelayMinutes
    }

    /// Whether another snooze may be armed after a buzz.
    static func shouldSnooze(enabled: Bool, repeatsSoFar: Int) -> Bool {
        enabled && repeatsSoFar < maxRepeats
    }

    /// The instant of the next snooze buzz: `delayMinutes` after `now`, rounded UP to a whole minute,
    /// because the strap alarm is minute-granular and rounding down could land in the past.
    static func fireDate(after now: Date, delayMinutes: Int) -> Date {
        let target = now.timeIntervalSince1970 + Double(clampedDelay(delayMinutes) * 60)
        return Date(timeIntervalSince1970: (target / 60).rounded(.up) * 60)
    }
}
