import SwiftUI

extension SkillDetailView {
    @ViewBuilder
    var skillGuideSection: some View {
        if let guide = SkillGuideLibrary.guide(for: node.id) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        sectionHeader("Skill Guide")
                        Text("Open one layer at a time")
                            .font(Font.unbound.captionS)
                            .foregroundStyle(Color.unbound.textTertiary)
                    }
                    Spacer()
                    Text(selectedGuideTab.label.uppercased())
                        .font(Font.unbound.captionS.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(Color.unbound.textTertiary)
                }

                guideTabs

                Group {
                    switch selectedGuideTab {
                    case .form:
                        formSection(showHeader: false)
                    case .assist:
                        guideAssistanceSection(guide.assistance)
                    case .tips:
                        guideTipsSection(guide.tips)
                    case .fixes:
                        guideMistakeSection(guide.mistakes)
                    }
                }
                .animation(.easeOut(duration: 0.18), value: selectedGuideTab)
            }
        }
    }

    var guideTabs: some View {
        HStack(spacing: 6) {
            ForEach(SkillGuideTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        selectedGuideTab = tab
                    }
                    UnboundHaptics.soft()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .bold))
                        Text(tab.label)
                            .font(Font.unbound.captionS.weight(.heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(selectedGuideTab == tab ? Color.unbound.bg : Color.unbound.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selectedGuideTab == tab ? Color.unbound.accent : Color.unbound.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(selectedGuideTab == tab ? Color.clear : Color.unbound.borderSubtle, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.unbound.surfaceElevated.opacity(0.9))
        )
    }

    func guideAssistanceSection(_ options: [SkillGuideAssistance]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Regressions & Assistance")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)

            VStack(spacing: 8) {
                ForEach(options, id: \.name) { option in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: option.icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.unbound.accent)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.unbound.accent.opacity(0.14)))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(option.name)
                                .font(Font.unbound.bodyS.weight(.heavy))
                                .foregroundStyle(Color.unbound.textPrimary)
                            Text(option.detail)
                                .font(Font.unbound.bodyS)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.unbound.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
                }
            }
        }
    }

    func guideTipsSection(_ tips: [SkillGuideTip]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Technique Notes")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)

            VStack(spacing: 8) {
                ForEach(tips, id: \.title) { tip in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Image(systemName: tip.icon)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.unbound.accent)
                                .frame(width: 22)
                            Text(tip.title)
                                .font(Font.unbound.bodyS.weight(.heavy))
                                .foregroundStyle(Color.unbound.textPrimary)
                        }

                        Text(tip.detail)
                            .font(Font.unbound.bodyS)
                            .foregroundStyle(Color.unbound.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.unbound.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
                }
            }
        }
    }

    func guideMistakeSection(_ mistakes: [SkillGuideMistake]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Watch For")
                .font(Font.unbound.captionS.weight(.heavy))
                .tracking(1.2)
                .foregroundStyle(Color.unbound.textTertiary)

            VStack(spacing: 8) {
                ForEach(mistakes, id: \.mistake) { item in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.unbound.alert)
                                .frame(width: 20)
                            Text(item.mistake)
                                .font(Font.unbound.bodyS.weight(.semibold))
                                .foregroundStyle(Color.unbound.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.unbound.accent)
                                .frame(width: 20)
                            Text(item.fix)
                                .font(Font.unbound.bodyS)
                                .foregroundStyle(Color.unbound.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.unbound.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.unbound.borderSubtle, lineWidth: 1)
                    )
                }
            }
        }
    }
}
