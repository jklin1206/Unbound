import SwiftUI

// MARK: - Shared bottom-docked number-pad editor (Phase 2)
//
// ONE reusable keypad-editing module used by BOTH the in-workout logging grid
// (ActiveWorkoutContainerView) and the Plan/Edit Workout grid (SessionEditorView).
// Derived from active-logging's proven editing logic so behaviour is preserved by
// construction: the same buffer state machine (pristine until the first keystroke,
// no leading zeros, decimal seeding) and the same bottom-dock chrome.
//
// The model owns ONLY the editing state machine + key handling. It knows nothing
// about how a cell is read or written — the caller supplies that via a
// `NumberPadCellConfig` (per-target label/unit/kind + seed/live-write/commit
// closures). This keeps the two backing stores (ActiveWorkoutSession vs the
// draft's setPlans) entirely on the caller side.

/// How a target's value is entered: a numeric keypad or the RPE quick-pick.
enum NumberPadFieldKind: Equatable {
    /// Numeric keypad. `allowsDecimal` enables the "." key (weight) vs integer-only
    /// (reps / hold / time / distance / calories).
    case numeric(allowsDecimal: Bool)
    /// RPE quick-pick (its own control — never the numeric keypad).
    case rpe
}

/// Per-target presentation + read/write wiring the caller supplies when a cell is
/// opened. `seed`/`liveWrite`/`commitWrite` close over the caller's backing store.
struct NumberPadCellConfig {
    let kind: NumberPadFieldKind
    /// Numeric: the dock title (e.g. "Weight", "Reps"). RPE: unused.
    let label: String
    /// Numeric: optional unit suffix (kg / sec / m / cal). RPE: unused.
    let unit: String?
    /// Numeric: the dim placeholder shown when the buffer is empty (the suggested
    /// value). RPE: unused.
    let placeholder: String
    /// Numeric: the seed buffer string for the cell's current value. RPE: unused.
    let seed: String
    /// RPE only: the currently-selected RPE for the cell (nil = none).
    let rpeValue: Int?

    /// Numeric only — write the typed buffer into the backing store live (so the
    /// cell updates as you type). Mirrors active-logging's `writeLive`.
    let liveWrite: ((String) -> Void)?
    /// Numeric only — persist after a committed edit (e.g. save the draft).
    let commitWrite: (() -> Void)?
    /// RPE only — the user picked (or cleared, nil) an RPE value.
    let rpePick: ((Int?) -> Void)?

    init(
        kind: NumberPadFieldKind,
        label: String = "",
        unit: String? = nil,
        placeholder: String = "—",
        seed: String = "",
        rpeValue: Int? = nil,
        liveWrite: ((String) -> Void)? = nil,
        commitWrite: (() -> Void)? = nil,
        rpePick: ((Int?) -> Void)? = nil
    ) {
        self.kind = kind
        self.label = label
        self.unit = unit
        self.placeholder = placeholder
        self.seed = seed
        self.rpeValue = rpeValue
        self.liveWrite = liveWrite
        self.commitWrite = commitWrite
        self.rpePick = rpePick
    }
}

/// Owns the keypad editing state machine for a single screen. Generic over the
/// caller's cell target so each screen keeps its own addressing type.
///
/// Behaviour mirrors active-logging exactly:
/// - `pristine` is true until the first keystroke, so merely opening a cell never
///   overwrites the existing/suggested value.
/// - On the first digit the seeded buffer is cleared; "0" never gets a leading
///   zero; decimal seeds "0." when empty.
/// - Opening a new cell commits the previous one first (if it was edited).
@MainActor
final class NumberPadEditorModel<Target: Equatable & Identifiable>: ObservableObject {
    @Published private(set) var active: Target?
    @Published private(set) var buffer: String = ""
    private(set) var pristine: Bool = true

    /// The config for the currently-active target, captured at `begin`. The dock
    /// reads label/unit/kind from here so the view never re-derives per target.
    private(set) var config: NumberPadCellConfig?

    var isActive: Bool { active != nil }

    /// Open `target` for editing. Commits any previously-open cell first, seeds the
    /// buffer from `config.seed`, and marks the buffer pristine.
    func begin(_ target: Target, config: NumberPadCellConfig) {
        commitIfNeeded()
        self.config = config
        buffer = config.seed
        pristine = true
        active = target
    }

    /// Handle a keypad key for the active numeric cell, writing live as you type.
    func key(_ key: NumberPadKey) {
        guard active != nil, let config, case .numeric = config.kind else { return }
        switch key {
        case .digit(let digit):
            if pristine { buffer = ""; pristine = false }
            if buffer == "0" { buffer = "" }   // no leading zeros
            buffer.append("\(digit)")
        case .decimal:
            if pristine { buffer = "0"; pristine = false }
            if !buffer.contains(".") {
                buffer.append(buffer.isEmpty ? "0." : ".")
            }
        case .delete:
            pristine = false
            if !buffer.isEmpty { buffer.removeLast() }
        }
        config.liveWrite?(buffer)
    }

    /// Commit the active numeric cell (writing the final buffer + persisting) and
    /// close the dock. RPE closes via `cancel` after `rpePick`.
    func commit() {
        commitIfNeeded()
        active = nil
        config = nil
    }

    /// Close the dock without an explicit commit beat (the picker / next-cell flow).
    /// Still flushes a pending numeric edit first so nothing is lost.
    func cancel() {
        commitIfNeeded()
        active = nil
        config = nil
    }

    /// RPE pick for the active RPE cell, then close.
    func pickRPE(_ value: Int?) {
        guard let config, case .rpe = config.kind else { return }
        config.rpePick?(value)
        active = nil
        self.config = nil
    }

    /// Flush a pending (edited) numeric cell into the backing store + persist.
    /// No-op for a pristine cell or an RPE cell. Mirrors active-logging's
    /// `commitPendingEditIfNeeded` + numeric `commitEdit`.
    private func commitIfNeeded() {
        guard active != nil, let config, case .numeric = config.kind, !pristine else { return }
        config.liveWrite?(buffer)
        config.commitWrite?()
    }
}

// MARK: - Dock view modifier

private struct NumberPadDockModifier<Target: Equatable & Identifiable>: ViewModifier {
    @ObservedObject var model: NumberPadEditorModel<Target>

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                dock
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: model.active.map { "\($0.id)" })
    }

    @ViewBuilder
    private var dock: some View {
        if model.active != nil, let config = model.config {
            switch config.kind {
            case .numeric(let allowsDecimal):
                InlineNumberPad(
                    title: config.label,
                    unit: config.unit,
                    valueText: model.buffer,
                    placeholder: config.placeholder,
                    allowsDecimal: allowsDecimal,
                    onKey: { model.key($0) },
                    onDone: { model.commit() }
                )
                .zIndex(20)
            case .rpe:
                InlineRPEPicker(
                    current: config.rpeValue,
                    onPick: { model.pickRPE($0) },
                    onDone: { model.cancel() }
                )
                .zIndex(20)
            }
        }
    }
}

extension View {
    /// Attach the shared bottom-docked keypad / RPE picker driven by `model`.
    /// Renders via `.safeAreaInset(edge: .bottom)` (the same bottom-accessory
    /// mechanism both screens used), so it docks above the home indicator and
    /// slides in/out. Read `model.isActive` to hide a screen's own bottom bar.
    func numberPadDock<Target: Equatable & Identifiable>(
        model: NumberPadEditorModel<Target>
    ) -> some View {
        modifier(NumberPadDockModifier(model: model))
    }
}
