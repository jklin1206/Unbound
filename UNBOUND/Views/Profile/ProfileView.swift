import SwiftUI
import PhotosUI

// MARK: - ProfileView
//
// The ARCHIVE counterpart to Home. Home is LIVE (what's happening today);
// Profile is identity, lifetime state, collection, and settings. Per the
// `project_unbound_home_vs_profile_boundary` memory:
//
//   Home  — today's mission, live rank, live streak, today's stats
//   Profile — who you've become: avatar, rank journey, badges grid,
//             photo library, stats history, settings
//
// This first-pass profile surfaces what we already compute on home at
// rest (rank, stats, badges) and nests the existing
// SettingsView as a push destination for account/preferences.
//
// Split across focused files:
//   ProfileView+Header.swift   — trophy header, top bar, layout metrics
//   ProfileView+Identity.swift — identity stack + handle/title strings
//   ProfileView+Archive.swift  — archive bands (build, badges, photos)
//   ProfileView+Showcase.swift — showcase option resolution
//   ProfileView+Data.swift     — load/refresh + identity save
//
// Deferred to future passes:
//   - Real scan photo library (grid of ProgressPhoto)
//   - Stats history charts (weekly/monthly trend)
//   - Rank journey timeline (when you crossed D → C → B)
//   - Titles collection (separate from badges, per rank memory)

struct ProfileView: View {
    @EnvironmentObject var services: ServiceContainer

    @State var profile: UserProfile?
    @State var aggregateTier: SkillTier = .initiate
    @State var attributeProfile: AttributeProfile = AttributeProfile.empty(userId: "", at: .now)
    @State var unlockedBadges: [Badge] = []
    @State var totalBadgeCount: Int = 0
    @State var totalWorkouts: Int = 0
    @State var showcaseSkillId: String?
    @State var showcaseSkillName: String = "None yet"
    @State var showcaseSkillTier: SkillTier = .initiate
    @State var showcaseLiftId: String?
    @State var showcaseLiftName: String = "None yet"
    @State var showcaseLiftTier: SkillTier = .initiate
    @State var showcaseSkillOptions: [ProfileShowcaseOption] = []
    @State var showcaseLiftOptions: [ProfileShowcaseOption] = []
    @State var equippedFrameTier: RankTitle = .initiate
    @State var equippedBackgroundTier: RankTitle = .initiate
    @State var equippedShopProfileBorder: ShopProfileBorderID?
    @State var equippedProfileBackdrop: ShopItem?
    @State var sessionXP: SessionXPRecord?
    @State var manualPhotoCount: Int = 0
    @State var scanPhotoCount: Int = 0
    @State var beforePhoto: ProgressPhoto?
    @State var afterPhoto: ProgressPhoto?
    @State var isLoading = true
    @State var trialsState: TrialsState = .empty
    @State var profileHeaderWidth: CGFloat = ScreenMetrics.bounds.width

    @ObservedObject var photoStore = ProfilePhotoStore.shared
    @State var showPhotoOptions = false
    @State var showProfileCosmetics = false
    #if DEBUG
    @State private var didAutoOpenCosmetics = false
    #endif
    @State private var showShop = false
    @State private var shopInitialCategory: ShopCategory = .backdrop
    @State private var showCamera = false
    @State private var pickedItem: PhotosPickerItem?
    var photoUserId: String { services.auth.currentUserId ?? "" }

    @State var overallLevel: OverallLevelProgress?

    var body: some View {
        GeometryReader { rootProxy in
            ZStack(alignment: .top) {
                Color.unbound.bg.ignoresSafeArea()
                profileBaseWash

                if isLoading {
                    ProgressView().tint(Color.unbound.accent)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            trophyHeader(topSafeInset: rootProxy.safeAreaInsets.top)
                            profileArchiveStack
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .ignoresSafeArea(edges: .top)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: services.auth.currentUserId ?? "anonymous") {
            await load()
            #if DEBUG
            // Screenshot harness: `--unbound-open-cosmetics` (with
            // `--unbound-open-profile`) lands on the Profile Kit sheet.
            // Runs AFTER load() so the identity form captures real
            // handle/title state instead of the empty pre-load values.
            if !didAutoOpenCosmetics,
               ProcessInfo.processInfo.arguments.contains("--unbound-open-cosmetics") {
                didAutoOpenCosmetics = true
                showProfileCosmetics = true
            }
            #endif
        }
        .confirmationDialog("Profile picture",
                            isPresented: $showPhotoOptions,
                            titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showCamera = true }
            }
            PhotosPicker("Choose from Library",
                         selection: $pickedItem, matching: .images)
            if photoStore.image(userId: photoUserId) != nil {
                Button("Remove Photo", role: .destructive) {
                    photoStore.remove(userId: photoUserId)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showProfileCosmetics, onDismiss: {
            // Guarantee the header avatar reflects any frame/border the user
            // equipped while the picker was open, even if a change notification
            // was missed.
            refreshEquippedCosmetics()
        }) {
            NavigationStack {
                ProfileCosmeticsView(
                    identity: ProfileIdentityEditorContext(
                        displayHandle: profile?.displayHandle ?? "",
                        unlockedTitles: trialsState.unlockedTitles,
                        equippedTitle: trialsState.equippedTitle,
                        showcaseSkillOptions: showcaseSkillOptions,
                        selectedShowcaseSkillId: showcaseSkillId,
                        showcaseLiftOptions: showcaseLiftOptions,
                        selectedShowcaseLiftId: showcaseLiftId,
                        save: saveProfileIdentity
                    )
                ) { category in
                    shopInitialCategory = category
                    showProfileCosmetics = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                        showShop = true
                    }
                }
                .environmentObject(services)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showShop) {
            NavigationStack {
                ShopView(initialCategory: shopInitialCategory)
                    .environmentObject(services)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                photoStore.set(image, userId: photoUserId)
            }
            .ignoresSafeArea()
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    photoStore.set(img, userId: photoUserId)
                }
                pickedItem = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .attributeRankUp)) { _ in
            if let userId = services.auth.currentUserId {
                Task {
                    attributeProfile = services.attribute.profile(userId: userId)
                    await refreshRewardReadouts(userId: userId)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .overallLevelProgressUpdated)) { note in
            guard let userId = services.auth.currentUserId else { return }
            if let progress = note.userInfo?["progress"] as? OverallLevelProgress,
               progress.userId == userId {
                overallLevel = progress
            }
            Task { await refreshRewardReadouts(userId: userId) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionXPUpdated)) { _ in
            guard let userId = services.auth.currentUserId else { return }
            Task { await refreshRewardReadouts(userId: userId) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .shopInventoryChanged)) { _ in
            refreshShopCosmetics()
        }
        .onReceive(NotificationCenter.default.publisher(for: .profileCosmeticsChanged)) { note in
            guard profileCosmeticChangeAppliesToCurrentUser(note) else { return }
            refreshEquippedCosmetics()
        }
        .attributeRankUpToast()
    }
}
