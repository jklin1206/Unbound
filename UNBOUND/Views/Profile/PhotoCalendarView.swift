import SwiftUI
import UIKit

// MARK: - PhotoCalendarView
//
// Identity log for the user's captured photos. The calendar owns the capture
// action, promoting the same compact button into a scan when the milestone
// window is open so profile does not need a separate scan row.
//
// Lives inside `ProfileView` as the "come back and see change" surface —
// long-horizon comparison is user's own eyes scrolling back, not invented
// percentages.

struct PhotoCalendarView: View {
    @EnvironmentObject var services: ServiceContainer

    @State private var photos: [ProgressPhoto] = []
    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: Date())
    @State private var selectedPhoto: ProgressPhoto?
    @State private var captureMode: PhotoCaptureFlow.Mode?

    @AppStorage("unbound.lastScanTimestamp") private var lastScanTimestamp: Double = 0

    var body: some View {
        // Slim timeline log: month strip + calendar grid + one adaptive capture CTA.
        // Drops the 3-stat boxes (redundant with profile header) and the
        // horizontal recent strip (redundant with the calendar). Cells
        // remain tappable — that's the way to revisit a day's photo.
        VStack(alignment: .leading, spacing: 14) {
            header
            VStack(alignment: .leading, spacing: 8) {
                weekdayLabels
                calendarGrid
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
        .task { await loadPhotos() }
        .sheet(item: $selectedPhoto) { photo in
            PhotoPreviewSheet(
                photo: photo,
                onSetProfilePhoto: { setProfilePhoto(photo) },
                onDelete: {
                    Task { await deletePhoto(photo) }
                    selectedPhoto = nil
                }
            )
        }
        .fullScreenCover(item: $captureMode) { mode in
            PhotoCaptureFlow(mode: mode) { _ in
                captureMode = nil
                Task { await loadPhotos() }
            }
            .environmentObject(services)
        }
        .onReceive(NotificationCenter.default.publisher(for: .photoCaptured)) { _ in
            Task { await loadPhotos() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .scanCompleted)) { _ in
            Task { await loadPhotos() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PHOTO TIMELINE")
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.8)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Text(monthLabel)
                        .font(Font.unbound.titleS)
                        .tracking(0.9)
                        .foregroundStyle(Color.unbound.textPrimary)
                }
                Spacer()
                HStack(spacing: 6) {
                    captureButton
                    monthButton(systemName: "chevron.left") {
                        shiftMonth(by: -1)
                    }
                    monthButton(systemName: "chevron.right") {
                        shiftMonth(by: 1)
                    }
                    .disabled(isCurrentMonth)
                    .opacity(isCurrentMonth ? 0.35 : 1)
                }
            }
        }
    }

    private func monthButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button {
            UnboundHaptics.soft()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.unbound.textSecondary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.unbound.bg.opacity(0.8)))
                .overlay(Circle().strokeBorder(Color.unbound.borderSubtle, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var archiveStats: some View {
        HStack(spacing: 8) {
            archiveStat("TOTAL", "\(photos.count)")
            archiveStat("SCANS", "\(photos.filter { $0.source == .scan }.count)")
            archiveStat("CHECK-INS", "\(photos.filter { $0.source == .manual }.count)")
        }
    }

    private func archiveStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(Color.unbound.textTertiary)
                .lineLimit(1)
            Text(value)
                .font(Font.unbound.monoM.weight(.bold))
                .foregroundStyle(Color.unbound.textPrimary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private var recentStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if photos.isEmpty {
                    archiveEmptyTile
                } else {
                    ForEach(Array(photos.prefix(10))) { photo in
                        recentPhotoButton(photo)
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var archiveEmptyTile: some View {
        HStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.unbound.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text("NO PHOTOS YET")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.1)
                    .foregroundStyle(Color.unbound.textSecondary)
                Text("Start with a photo check-in or scan.")
                    .font(Font.unbound.captionS)
                    .foregroundStyle(Color.unbound.textTertiary)
            }
        }
        .frame(width: 230, height: 92, alignment: .leading)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.bg.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
        )
    }

    private func recentPhotoButton(_ photo: ProgressPhoto) -> some View {
        Button {
            UnboundHaptics.soft()
            selectedPhoto = photo
        } label: {
            ZStack(alignment: .bottomLeading) {
                if let img = loadThumbnail(for: photo) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.unbound.bg
                    Image(systemName: "photo")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.unbound.textTertiary.opacity(0.6))
                }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.68)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(spacing: 5) {
                    Image(systemName: photo.source == .scan ? "sparkle.magnifyingglass" : "camera.fill")
                        .font(.system(size: 8, weight: .bold))
                    Text(dayLabel(for: photo.capturedAt))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
            }
            .frame(width: 74, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        photo.source == .scan ? Color.unbound.accent.opacity(0.65) : Color.unbound.borderSubtle,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekday labels

    private var weekdayLabels: some View {
        HStack(spacing: 0) {
            ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, l in
                Text(l)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.unbound.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Grid

    private var calendarGrid: some View {
        let days = daysForMonth()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    cell(for: day)
                } else {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    @ViewBuilder
    private func cell(for date: Date) -> some View {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(date)
        let dayPhotos = photosOn(date)
        let firstPhoto = dayPhotos.first

        Button {
            UnboundHaptics.soft()
            if let photo = firstPhoto {
                selectedPhoto = photo
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.unbound.bg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                isToday ? Color.unbound.accent : Color.unbound.borderSubtle,
                                lineWidth: isToday ? 1.5 : 0.75
                            )
                    )

                if let photo = firstPhoto, let img = loadThumbnail(for: photo) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.45)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                VStack {
                    HStack {
                        Spacer()
                        if firstPhoto?.source == .scan {
                            Image(systemName: "sparkle.magnifyingglass")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color.unbound.accent)
                                .padding(3)
                                .background(Circle().fill(Color.black.opacity(0.55)))
                                .padding(3)
                        }
                    }
                    Spacer()
                    HStack {
                        Text("\(cal.component(.day, from: date))")
                            .font(Font.unbound.monoS.weight(.bold))
                            .foregroundStyle(
                                firstPhoto != nil
                                    ? Color.unbound.textPrimary
                                    : (isToday ? Color.unbound.accent : Color.unbound.textSecondary)
                            )
                            .monospacedDigit()
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                firstPhoto != nil
                                    ? Capsule().fill(Color.black.opacity(0.55))
                                    : Capsule().fill(Color.clear)
                            )
                        Spacer()
                    }
                    .padding(4)
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .disabled(firstPhoto == nil)
    }

    // MARK: - Capture action

    private var captureButton: some View {
        Button {
            UnboundHaptics.medium()
            captureMode = isScanEligible ? .scan : .photo
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isScanEligible ? "sparkle.magnifyingglass" : "camera.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(isScanEligible ? "MONTHLY" : "CHECK IN")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(0.9)
            }
            .foregroundStyle(isScanEligible ? Color.unbound.textPrimary : Color.unbound.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(isScanEligible ? Color.unbound.accent : Color.unbound.bg.opacity(0.8))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isScanEligible ? Color.unbound.accent.opacity(0.65) : Color.unbound.borderSubtle, lineWidth: 1)
            )
            .shadow(color: isScanEligible ? Color.unbound.accent.opacity(0.2) : .clear, radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var isScanEligible: Bool {
        guard lastScanTimestamp > 0 else { return true }
        return Date().timeIntervalSince1970 - lastScanTimestamp >= 28 * 24 * 3600
    }

    // MARK: - Data

    @MainActor
    private func loadPhotos() async {
        let userId = services.auth.currentUserId ?? "anonymous"
        let fetched: [ProgressPhoto] = (try? await services.database.query(
            collection: "progressPhotos",
            field: "userId",
            isEqualTo: userId,
            orderBy: "capturedAt",
            descending: true,
            limit: 120
        )) ?? []
        photos = fetched
    }

    private func photosOn(_ date: Date) -> [ProgressPhoto] {
        let cal = Calendar.current
        return photos.filter { cal.isDate($0.capturedAt, inSameDayAs: date) }
    }

    private func loadThumbnail(for photo: ProgressPhoto) -> UIImage? {
        // For now local path; cloud URLs would go through an async image
        // loader. Gracefully nil if file is gone (reinstall, etc.).
        let url = URL(fileURLWithPath: photo.storageUrl)
        return UIImage(contentsOfFile: url.path)
    }

    @MainActor
    private func setProfilePhoto(_ photo: ProgressPhoto) {
        let userId = services.auth.currentUserId ?? "anonymous"
        guard let image = UIImage(contentsOfFile: photo.storageUrl) else { return }
        ProfilePhotoStore.shared.set(image, userId: userId)
        UnboundHaptics.medium()
    }

    @MainActor
    private func deletePhoto(_ photo: ProgressPhoto) async {
        try? await services.database.delete(collection: "progressPhotos", documentId: photo.id)
        // Best-effort local file cleanup
        try? FileManager.default.removeItem(atPath: photo.storageUrl)
        await loadPhotos()
    }

    // MARK: - Month navigation

    private func shiftMonth(by delta: Int) {
        var cal = Calendar.current
        cal.firstWeekday = 2
        if let newMonth = cal.date(byAdding: .month, value: delta, to: displayedMonth) {
            // Don't allow going past current month.
            let currentMonthStart = cal.startOfMonth(for: Date())
            if newMonth > currentMonthStart { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                displayedMonth = newMonth
            }
        }
    }

    private var isCurrentMonth: Bool {
        let cal = Calendar.current
        return cal.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth).uppercased()
    }

    private func dayLabel(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date).uppercased()
    }

    /// Returns 42 slots (6 weeks × 7 days) representing the displayed month.
    /// Slots outside the month are nil (rendered empty).
    private func daysForMonth() -> [Date?] {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let firstOfMonth = cal.startOfMonth(for: displayedMonth)
        let weekdayOfFirst = cal.component(.weekday, from: firstOfMonth)
        let leadingEmpty = ((weekdayOfFirst + 5) % 7)   // Mon=0, Sun=6
        let range = cal.range(of: .day, in: .month, for: firstOfMonth) ?? 1..<32
        let daysInMonth = range.count

        var slots: [Date?] = Array(repeating: nil, count: leadingEmpty)
        for d in 0..<daysInMonth {
            if let date = cal.date(byAdding: .day, value: d, to: firstOfMonth) {
                slots.append(date)
            }
        }
        while slots.count < 42 { slots.append(nil) }
        return slots
    }
}

// MARK: - PhotoPreviewSheet

private struct PhotoPreviewSheet: View {
    let photo: ProgressPhoto
    let onSetProfilePhoto: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirm = false
    @State private var didSetProfilePhoto = false

    var body: some View {
        ZStack {
            Color.unbound.bg.ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.unbound.textSecondary)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(dateLabel.uppercased())
                        .font(Font.unbound.captionS.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(Color.unbound.textTertiary)
                    Spacer()
                    Button {
                        showingDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.unbound.alert)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                if let img = UIImage(contentsOfFile: photo.storageUrl) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal, 16)

                    Button {
                        onSetProfilePhoto()
                        didSetProfilePhoto = true
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: didSetProfilePhoto ? "checkmark.circle.fill" : "person.crop.circle.badge.checkmark")
                                .font(.system(size: 14, weight: .bold))
                            Text(didSetProfilePhoto ? "PROFILE PHOTO SET" : "SET AS PROFILE PHOTO")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .tracking(1.0)
                        }
                        .foregroundStyle(Color.unbound.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(didSetProfilePhoto ? Color.unbound.rankGreen : Color.unbound.accent)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                } else {
                    Rectangle()
                        .fill(Color.unbound.surface)
                        .overlay(
                            Text("PHOTO UNAVAILABLE")
                                .font(Font.unbound.captionS)
                                .foregroundStyle(Color.unbound.textTertiary)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal, 16)
                }

                Spacer()
            }
        }
        .confirmationDialog("Delete photo?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d · h:mm a"
        return f.string(from: photo.capturedAt)
    }
}

// MARK: - Calendar helper

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}
