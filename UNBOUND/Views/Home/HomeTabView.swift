import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var selectedTab: Int
    #if DEBUG
    @State private var debugPresentedSkillNode: SkillNode?
    @State private var debugShowCardioLogger = false
    #endif

    init() {
        _selectedTab = State(initialValue: Self.initialTabFromLaunchArguments())
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                UnboundHomeView()
            }
            .tabItem {
                Image(systemName: "house.fill")
                Text("Home")
            }
            .accessibilityIdentifier("tab.home")
            .tag(0)

            NavigationStack {
                ProgramOverviewView()
            }
            .tabItem {
                Image(systemName: "dumbbell.fill")
                Text("Program")
            }
            .accessibilityIdentifier("tab.program")
            .tag(1)

            NavigationStack {
                UnboundSkillTreeTabView()
            }
            .tabItem {
                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                Text("Skills")
            }
            .accessibilityIdentifier("tab.skills")
            .tag(2)

            NavigationStack {
                SquadTabView()
            }
            .tabItem {
                Image(systemName: "flag.2.crossed.fill")
                Text("Squad")
            }
            .accessibilityIdentifier("tab.squad")
            .tag(3)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Image(systemName: "person.crop.circle")
                Text("Profile")
            }
            .accessibilityIdentifier("tab.profile")
            .tag(4)
        }
        .tint(Color.unbound.accent)
        .rankUpCinematicOverlay()
        .skinUnlockToast()
        .badgeUnlockToast()
        .onReceive(NotificationCenter.default.publisher(for: .requestNavigateToProfileTab)) { _ in
            selectedTab = 4
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestNavigateToProfileRankGate)) { _ in
            selectedTab = 4
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                NotificationCenter.default.post(name: .requestOpenProfileRankInfo, object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestNavigateToProgramTab)) { _ in
            selectedTab = 1
        }
        #if DEBUG
        .fullScreenCover(isPresented: $debugShowCardioLogger) {
            LogCardioView()
                .environmentObject(services)
        }
        .fullScreenCover(item: $debugPresentedSkillNode) { node in
            SkillDetailView(
                node: node,
                graph: SkillGraph.shared,
                nodeStates: SkillProgressService.shared.nodeStates
            )
        }
        .onAppear {
            guard let skillId = Self.launchArgumentValue(for: "--unbound-open-skill"),
                  let node = SkillGraph.shared.node(id: skillId),
                  debugPresentedSkillNode == nil
            else { return }

            selectedTab = 2
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                debugPresentedSkillNode = node
            }
        }
        .onAppear {
            guard ProcessInfo.processInfo.arguments.contains("--unbound-open-cardio-log"),
                  !debugShowCardioLogger
            else { return }

            selectedTab = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                debugShowCardioLogger = true
            }
        }
        #endif
    }

    private static func initialTabFromLaunchArguments() -> Int {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--unbound-open-program") { return 1 }
        if arguments.contains("--unbound-open-routine") { return 1 }
        if arguments.contains("--unbound-open-skills") { return 2 }
        if arguments.contains("--unbound-open-squad") { return 3 }
        if arguments.contains("--unbound-open-profile") { return 4 }
        #endif
        return 0
    }

    #if DEBUG
    private static func launchArgumentValue(for key: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        for (index, argument) in arguments.enumerated() {
            if argument == key, arguments.indices.contains(index + 1) {
                return arguments[index + 1]
            }
            if argument.hasPrefix("\(key)=") {
                return String(argument.dropFirst(key.count + 1))
            }
        }
        return nil
    }
    #endif
}
