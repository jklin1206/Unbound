import AVFoundation
import Foundation

/// Reward / celebration sound effects. Companion to `UnboundHaptics`.
///
/// SFX are synthesized WAVs bundled under Resources/Sounds. Players are pooled
/// so rapid-fire effects (the XP tick during the count-up) can overlap, and the
/// tick supports a playback `rate` so its pitch rises as the bar fills.
///
/// Uses the `.ambient` audio session (respects the hardware mute switch and
/// mixes with other audio), gated behind a user-facing `isEnabled` toggle.
enum SoundEffect: String, CaseIterable {
    case xpTick = "xp_tick"
    case levelUp = "level_up"
    case rankReveal = "rank_reveal"
    case sessionComplete = "session_complete"
    case finish = "finish"

    var poolSize: Int { self == .xpTick ? 8 : 2 }
}

@MainActor
final class UnboundSound {
    static let shared = UnboundSound()

    private var pools: [SoundEffect: [AVAudioPlayer]] = [:]
    private var cursor: [SoundEffect: Int] = [:]
    private var sessionConfigured = false

    /// In-app toggle (Settings). Defaults on; respects the hardware mute switch
    /// regardless via the `.ambient` category.
    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "rewardSoundEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "rewardSoundEnabled") }
    }

    private init() {}

    /// Warm the players for the upcoming reward sequence (avoids first-play hitch).
    func preloadRewardKit() {
        for effect in SoundEffect.allCases { _ = pool(for: effect) }
    }

    /// Play an effect. `rate` (0.5–2.0) shifts pitch+speed — used to ramp the XP tick.
    func play(_ effect: SoundEffect, volume: Float = 1.0, rate: Float = 1.0) {
        guard isEnabled else { return }
        configureSessionIfNeeded()
        guard let player = nextPlayer(for: effect) else { return }
        player.currentTime = 0
        player.volume = volume
        player.rate = rate
        player.play()
    }

    // MARK: - Internals

    private func configureSessionIfNeeded() {
        guard !sessionConfigured else { return }
        sessionConfigured = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func pool(for effect: SoundEffect) -> [AVAudioPlayer] {
        if let existing = pools[effect] { return existing }
        guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav") else {
            pools[effect] = []
            return []
        }
        let players: [AVAudioPlayer] = (0..<effect.poolSize).compactMap { _ in
            guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
            player.enableRate = true
            player.prepareToPlay()
            return player
        }
        pools[effect] = players
        cursor[effect] = 0
        return players
    }

    private func nextPlayer(for effect: SoundEffect) -> AVAudioPlayer? {
        let players = pool(for: effect)
        guard !players.isEmpty else { return nil }
        let index = (cursor[effect] ?? 0) % players.count
        cursor[effect] = index + 1
        return players[index]
    }
}
