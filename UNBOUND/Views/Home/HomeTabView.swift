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
                Image(systemName: "hexagon.fill")
                Text("Skills")
            }
            .tag(2)

            NavigationStack {
                CoachTabView()
            }
            .tabItem {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                Text("Coach")
            }
            .tag(3)

            NavigationStack {
                SettingsView(services: services)
            }
            .tabItem {
                Image(systemName: "person.crop.circle")
                Text("Profile")
            }
            .tag(4)
        }
        .tint(Color.unbound.accent)
        .rankUpCinematicOverlay()
        .skinUnlockToast()
        .badgeUnlockToast()
    }
}
