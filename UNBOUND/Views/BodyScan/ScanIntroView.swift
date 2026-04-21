import SwiftUI

struct ScanIntroView: View {
    @EnvironmentObject var services: ServiceContainer
    @State private var viewModel: BodyScanViewModel?
    @State private var showCamera = false

    private var canStart: Bool {
        guard let vm = viewModel else { return false }
        return !vm.heightCm.trimmingCharacters(in: .whitespaces).isEmpty &&
               !vm.weightKg.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Color.theme.background.ignoresSafeArea()

            if let vm = viewModel {
                ScrollView {
                    VStack(spacing: 24) {
                        // Instructions banner
                        Text("We'll take 3 photos (front, side, back). Stand 6 feet from camera. Good lighting. Fitted clothing.")
                            .font(.bodyText(15))
                            .foregroundColor(.theme.textSecondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color.theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.top, 8)

                        // Form fields
                        VStack(spacing: 12) {
                            // Height
                            HStack {
                                Text("Height (cm)")
                                    .font(.bodyMedium(15))
                                    .foregroundColor(.theme.textPrimary)
                                Spacer()
                                TextField("e.g. 178", text: Binding(
                                    get: { vm.heightCm },
                                    set: { vm.heightCm = $0 }
                                ))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(.bodyText(15))
                                .foregroundColor(.theme.textPrimary)
                                .frame(width: 100)
                            }
                            .padding(16)
                            .background(Color.theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            // Weight
                            HStack {
                                Text("Weight (kg)")
                                    .font(.bodyMedium(15))
                                    .foregroundColor(.theme.textPrimary)
                                Spacer()
                                TextField("e.g. 80", text: Binding(
                                    get: { vm.weightKg },
                                    set: { vm.weightKg = $0 }
                                ))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(.bodyText(15))
                                .foregroundColor(.theme.textPrimary)
                                .frame(width: 100)
                            }
                            .padding(16)
                            .background(Color.theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            // Training Experience Picker
                            HStack {
                                Text("Training Experience")
                                    .font(.bodyMedium(15))
                                    .foregroundColor(.theme.textPrimary)
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { vm.trainingExperience },
                                    set: { vm.trainingExperience = $0 }
                                )) {
                                    ForEach([TrainingExperience.beginner, .intermediate, .advanced], id: \.self) { level in
                                        Text(level.rawValue.capitalized).tag(level)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.theme.primary)
                            }
                            .padding(16)
                            .background(Color.theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Spacer(minLength: 16)

                        GradientButton(title: "Start Scan", action: {
                            showCamera = true
                        }, isDisabled: !canStart)
                        .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 20)
                }
                .fullScreenCover(isPresented: $showCamera) {
                    NavigationStack {
                        CameraView(viewModel: vm)
                            .environmentObject(services)
                    }
                }
            }
        }
        .navigationTitle("Body Scan")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if viewModel == nil {
                viewModel = BodyScanViewModel(services: services)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ScanIntroView()
            .environmentObject(ServiceContainer.mock)
    }
}
