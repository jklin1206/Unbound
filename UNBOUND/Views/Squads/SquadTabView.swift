// UNBOUND/Views/Squads/SquadTabView.swift
//
// The Squad tab root: routes empty vs detail state and refreshes on
// .squadStateChanged. The universal-link join path (https://unboundbtr.com/
// squad/<code>) is NOT owned here — the tapped code is parsed + persisted by
// SquadInviteLink / PendingSquadInvite (see UnboundApp.onContinueUserActivity)
// and consumed centrally by HomeTabView, which switches to this tab and
// presents JoinSquadSheet. That survives cold-launch through onboarding/auth,
// which a view that only exists once this tab is alive could not.
//
// AASA (apple-app-site-association) deployment is a marketing-site concern:
// served at https://unboundbtr.com/.well-known/apple-app-site-association with
// components [{ "/": "/squad/*" }] for the app's appID.

import SwiftUI

struct SquadTabView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var state: SquadState = .empty
    @State private var loadedUserId: String?

    var body: some View {
        let userId = services.auth.currentUserId ?? "anonymous"

        Group {
            if state.currentSquad != nil {
                SquadDetailView()
            } else {
                SquadEmptyView {
                    Task { await reloadState(for: userId) }
                }
            }
        }
        .id(loadedUserId ?? userId)
        .linkedSessionToast()
        .friendChallengeOutcomeToast()
        .task(id: userId) {
            await reloadState(for: userId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .squadStateChanged)) { _ in
            refreshFromCache(userId: userId)
        }
    }

    private func reloadState(for userId: String) async {
        await services.squads.loadCurrentSquad(userId: userId)
        refreshFromCache(userId: userId)
    }

    private func refreshFromCache(userId: String) {
        state = services.squads.state(userId: userId)
        loadedUserId = userId
    }
}
