import SwiftUI

struct PhotoReviewView: View {
    @ObservedObject var viewModel: BodyScanViewModel
    @EnvironmentObject var services: ServiceContainer
    @Environment(\.dismiss) private var dismiss

    @State private var showLoading = false

    private var canAnalyze: Bool {
        viewModel.allPhotosCaptured
    }

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 4) {
                        Text("Review Your Photos")
                            .font(.headline(24))
                            .foregroundColor(.theme.textPrimary)
                        Text("Tap a photo to retake it")
                            .font(.caption())
                            .foregroundColor(.theme.textSecondary)
                    }
                    .padding(.top, 8)

                    // Photo thumbnails
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(ScanAngle.allCases, id: \.self) { angle in
                                PhotoThumbnail(
                                    angle: angle,
                                    image: viewModel.capturedPhotos[angle],
                                    onRetake: {
                                        viewModel.retakePhoto(for: angle)
                                        dismiss()
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Archetype picker
                    ArchetypePickerView(selectedArchetype: $viewModel.selectedArchetype)
                        .padding(.horizontal, 20)

                    Spacer(minLength: 16)

                    // Analyze button
                    GradientButton(
                        title: "Analyze My Body",
                        action: {
                            showLoading = true
                        },
                        isDisabled: !canAnalyze
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    dismiss()
                }
                .foregroundColor(.theme.primary)
            }
        }
        .fullScreenCover(isPresented: $showLoading) {
            NavigationStack {
                AnalysisLoadingView(viewModel: viewModel)
                    .environmentObject(services)
            }
        }
    }
}

private struct PhotoThumbnail: View {
    let angle: ScanAngle
    let image: UIImage?
    let onRetake: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.theme.surface)
                    .frame(width: 110, height: 160)

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 110, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundColor(.theme.textMuted)
                        Text("Missing")
                            .font(.caption(12))
                            .foregroundColor(.theme.textMuted)
                    }
                }

                // Retake overlay
                if image != nil {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 110, height: 160)
                        .overlay(
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title3)
                                .foregroundColor(.white)
                        )
                }
            }
            .onTapGesture {
                HapticManager.selection()
                onRetake()
            }

            Text(angle.rawValue.capitalized)
                .font(.caption(13))
                .foregroundColor(.theme.textSecondary)

            // Status indicator
            Image(systemName: image != nil ? "checkmark.circle.fill" : "circle")
                .foregroundColor(image != nil ? .theme.secondary : .theme.textMuted)
                .font(.caption())
        }
    }
}
