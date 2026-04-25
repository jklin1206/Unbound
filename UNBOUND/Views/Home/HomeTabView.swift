import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                UnboundHomeView()
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .tag(0)

            NavigationStack {
                ProgramOverviewView()
            }
            .tabItem {
                Image(systemName: "dumbbell.fill")
                Text("Program")
            }
            .tag(1)

            NavigationStack {
                UnboundSkillTreeTabView()
            }
            .tabItem {
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                Text("Skills")
            }
            .tag(2)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Image(systemName: "person.crop.circle")
                Text("Profile")
            }
            .tag(3)
        }
        .tint(Color.unbound.accent)
        .rankUpCinematicOverlay()
        .skinUnlockToast()
        .badgeUnlockToast()
    }
}
