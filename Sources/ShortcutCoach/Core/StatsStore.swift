import Foundation
import Combine

/// Main-thread store of hint statistics, persisted as JSON in Application Support.
final class StatsStore: ObservableObject {
    static let shared = StatsStore()

    @Published private(set) var records: [String: HintRecord] = [:]
    private var noShortcutCounts: [String: Int] = [:]
    /// How often each shortcut was typed (per app, and "*" across apps) — used to spot shortcuts
    /// you already knew before the first hint.
    private var typedCounts: [String: Int] = [:]
    private var comboIndex: [String: Set<String>] = [:]
    private var saveWork: DispatchWorkItem?

    private struct Snapshot: Codable {
        var records: [String: HintRecord]
        var noShortcutCounts: [String: Int]
        var typedCounts: [String: Int]?
    }

    private let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ShortcutCoach", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("stats.json")
    }()

    private init() {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: url),
           let snap = try? dec.decode(Snapshot.self, from: data) {
            records = snap.records
            noShortcutCounts = snap.noShortcutCounts
            typedCounts = snap.typedCounts ?? [:]
        }
        rebuildIndex()
    }

    // MARK: Recording

    @discardableResult
    func recordShown(_ hint: Hint) -> HintRecord {
        let keys = Array(Set(hint.matchCombos.flatMap(\.matchKeys))).sorted()
        var r: HintRecord
        if let existing = records[hint.id] {
            r = existing
        } else {
            r = HintRecord(id: hint.id, kind: hint.kind, bundleID: hint.bundleID, appName: hint.appName,
                           title: hint.title, keycapGroups: hint.keycapGroups, matchKeys: keys)
            let scope = hint.bundleID ?? "*"
            r.alreadyKnown = keys.contains { (typedCounts["\(scope)|\($0)"] ?? 0) >= HintRecord.knownBeforeThreshold }
        }
        let rebound = r.matchKeys.sorted() != keys
        r.title = hint.title
        r.appName = hint.appName
        r.keycapGroups = hint.keycapGroups
        r.matchKeys = keys
        r.shown += 1
        r.mouseStreak += 1
        r.lastShown = Date()
        records[hint.id] = r
        // A changed shortcut (e.g. rebound in App Shortcuts) must stop crediting the old keys.
        if rebound { rebuildIndex() } else { index(r) }
        scheduleSave()
        return r
    }

    /// Called after a reminder for a known shortcut is shown, so the next one needs a fresh streak.
    func resetStreak(_ id: String) {
        guard var r = records[id] else { return }
        r.mouseStreak = 0
        records[id] = r
        scheduleSave()
    }

    /// Credits every previously-shown hint that this keystroke satisfies. Returns the updated records.
    func recordUsed(_ combo: KeyCombo, bundleID: String?) -> [HintRecord] {
        if let key = combo.matchKeys.first, typedCounts.count < 5000 {
            typedCounts["\(bundleID ?? "?")|\(key)", default: 0] += 1
            typedCounts["*|\(key)", default: 0] += 1
        }
        var ids = Set<String>()
        for key in combo.matchKeys { ids.formUnion(comboIndex[key] ?? []) }
        guard !ids.isEmpty else { return [] }
        var updated: [HintRecord] = []
        for id in ids {
            guard var r = records[id], r.shown > 0 else { continue }
            if let b = r.bundleID, b != bundleID { continue }
            r.used += 1
            r.mouseStreak = 0
            r.lastUsed = Date()
            records[id] = r
            updated.append(r)
        }
        scheduleSave()
        return updated
    }

    func bumpNoShortcut(_ id: String) -> Int {
        let n = (noShortcutCounts[id] ?? 0) + 1
        noShortcutCounts[id] = n
        scheduleSave()
        return n
    }

    func setMuted(_ id: String, _ muted: Bool) {
        guard var r = records[id] else { return }
        r.muted = muted
        records[id] = r
        scheduleSave()
    }

    func remove(_ id: String) {
        records[id] = nil
        rebuildIndex()
        scheduleSave()
    }

    func reset() {
        records = [:]
        noShortcutCounts = [:]
        typedCounts = [:]
        comboIndex = [:]
        scheduleSave()
    }

    // MARK: Aggregates

    var totalShown: Int { records.values.reduce(0) { $0 + $1.shown } }
    var totalUsed: Int { records.values.reduce(0) { $0 + $1.used } }
    var learnedCount: Int { records.values.filter(\.isLearned).count }
    var alreadyKnownCount: Int { records.values.filter(\.alreadyKnown).count }

    // MARK: Internals

    private func index(_ r: HintRecord) {
        for key in r.matchKeys { comboIndex[key, default: []].insert(r.id) }
    }

    private func rebuildIndex() {
        comboIndex = [:]
        records.values.forEach(index)
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let snap = Snapshot(records: records, noShortcutCounts: noShortcutCounts, typedCounts: typedCounts)
        let url = self.url
        let work = DispatchWorkItem {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            enc.dateEncodingStrategy = .iso8601
            if let data = try? enc.encode(snap) { try? data.write(to: url, options: .atomic) }
        }
        saveWork = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5, execute: work)
    }
}
