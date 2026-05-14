// UNBOUND/Views/Squads/SquadTabView.swift
//
// Universal Links: https://unboundapp.com/squad/<code>
//
// AASA file deployment is a marketing-site concern (not in this PR). Required content:
// {
//   "applinks": {
//     "details": [
//       { "appIDs": ["TEAMID.com.unboundapp.ios"], "components": [{ "/": "/squad/*" }] }
//     ]
//   }
// }
// AASA must be served at https://unboundapp.com/.well-known/apple-app-site-association

import SwiftUI

struct SquadTabView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var pendingInviteCode: String?

    var body: some View {
        let userId = services.auth.currentUserId ?? "anonymous"
        let state = services.squads.state(userId: userId)

        Group {
            if state.currentSquad != nil {
                SquadDetailView()
            } else {
                SquadEmptyView()
            }
        }
        .linkedSessionToast()
        .task {
            await services.squads.loadCurrentSquad(userId: userId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .squadStateChanged)) { _ in
            Task { await services.squads.loadCurrentSquad(userId: userId) }
        }
        .sheet(item: Binding<InviteCode?>(
            get: { pendingInviteCode.map(InviteCode.init) },
            set: { pendingInviteCode = $0?.value }
        )) { ic in
            JoinSquadSheet(prefilledCode: ic.value)
        }
        .onReceive(NotificationCenter.default.publisher(for: .squadInviteCodeReceived)) { note in
            if let code = note.object as? String {
                pendingInviteCode = code
            }
        }
    }

    private struct InviteCode: Identifiable {
        let value: String
        var id: String { value }
        init(_ v: String) { self.value = v }
    }
}
