import SwiftUI
import UIKit

// MARK: - PhotoCalendarView
//
// Monthly calendar grid of the user's captured photos. Each day cell that
// has one or more photos shows a thumbnail; today's cell is highlighted
// violet regardless. Tap a photo cell → full-screen preview with
// delete. Chevrons navigate prev/next month.
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
        VStack(alignment: .leading, spacing: 14) {
            header
            weekdayLabels
            calendarGrid
            captureButton
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.unbound.surface)
        )
        .task { await loadPhotos() }
        .sheet(item: $selectedPhoto) { photo in
            PhotoPreviewSheet(photo: photo) {
                Task { await deletePhoto(photo) }
                selectedPhoto = nil
            }
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
        HStack(spacing: 10) {
            Button {
                UnboundHaptics.soft()
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthLabel)
                .font(Font.unbound.titleS)
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textPrimary)

            Spacer()

            Button {
                UnboundHaptics.soft()
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.unbound.textSecondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(isCurrentMonth)
            .opacity(isCurrentMonth ? 0.3 : 1.0)
        }
    }

    // MARK: - Weekday labels

    private var weekdayLabels: some View {
        HStack(spacing: 0) {
            ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { l in
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
            ForEach(days, id: \.self) { day in
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

    // MARK: - Capture button (swaps by eligibility)

    private var captureButton: some View {
        let isScanDue = isScanEligible
        return Button {
            UnboundHaptics.medium()
            captureMode = isScanDue ? .scan : .photo
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isScanDue ? "sparkle.magnifyingglass" : "plus")
                    .font(.system(size: 12, weight: .bold))
                Text(isScanDue ? "SCAN · +25 SP" : "NEW PHOTO · +5 SP")
                    .font(Font.unbound.captionS.weight(.bold))
                    .tracking(1.4)
            }
            .foregroundStyle(Color.unbound.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.unbound.accent)
            )
            .shadow(color: Color.unbound.accent.opacity(0.35), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var isScanEligible: Bool {
        guard lastScanTimestamp > 0 else { return true }
        return Date().timeIntervalSince1970 - lastScanTimestamp >= 14 * 24 * 3600
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
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirm = false

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
