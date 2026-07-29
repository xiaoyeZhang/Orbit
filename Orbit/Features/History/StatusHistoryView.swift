import SwiftUI
import OrbitCore
import OrbitServices
import OrbitUI

// MARK: - Model

struct StatusEntry: Identifiable {
    let id = UUID()
    let date: Date
    let activityLabel: String
    let activityIcon: String
    let locationName: String
    let duration: String
    let systemTag: Bool
    let stickerIcon: String

    enum Preset {
        static let samples: [StatusEntry] = [
            .init(date: .now,
                  activityLabel: "在留宿地", activityIcon: "house.fill",
                  locationName: "", duration: "此刻",
                  systemTag: false, stickerIcon: ""),
            .init(date: cal.date(byAdding: .day, value: -17, to: .now)!
                    .addingTimeInterval(-12 * 3600 + 11 * 60),
                  activityLabel: "在夜间地点", activityIcon: "moon.fill",
                  locationName: "留宿地", duration: "3天 38分钟",
                  systemTag: true, stickerIcon: "cart.fill"),
            .init(date: cal.date(byAdding: .day, value: -18, to: .now)!
                    .addingTimeInterval(-23 * 3600 + 14 * 60),
                  activityLabel: "在夜间地点", activityIcon: "moon.fill",
                  locationName: "留宿地", duration: "12小时 56分钟",
                  systemTag: true, stickerIcon: "mappin.circle.fill"),
            .init(date: cal.date(byAdding: .day, value: -24, to: .now)!
                    .addingTimeInterval(-12 * 3600 + 8 * 60),
                  activityLabel: "在夜间地点", activityIcon: "moon.fill",
                  locationName: "留宿地", duration: "3天 16分钟",
                  systemTag: true, stickerIcon: "fork.knife"),
        ]
        private static let cal = Calendar.current
    }
}

// MARK: - Quick feature

struct QuickFeature: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let color: Color
    let detail: String
}

// MARK: - View

struct StatusHistoryView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var selectedFeature: QuickFeature?
    @State private var selectedEntry: StatusEntry?
    @State private var showSettings = false
    @State private var collapsed = Set<String>()

    @State private var diaries: [TrajectoryDiary] = [.sample]
    @State private var generating = false
    @State private var selectedDiary: TrajectoryDiary?

    private let features: [QuickFeature] = [
        .init(icon: "shield.checkered", label: "安全守护", color: Theme.Palette.indigo,
              detail: "实时守护你与家人的安全，遇到异常停留或长时间失联时主动提醒紧急联系人。"),
        .init(icon: "battery.100.bolt", label: "健康用机", color: Theme.Palette.emerald,
              detail: "统计每日屏幕使用时长与活动量，帮助你养成更健康的用机习惯。"),
        .init(icon: "bell.and.waveform", label: "地点提醒", color: Theme.Palette.pinkRed,
              detail: "为常用地点设置到访/离开提醒，重要的人进出这些地点时你会第一时间收到通知。"),
        .init(icon: "chart.bar.doc.horizontal", label: "每日报告", color: Theme.Palette.gold,
              detail: "每日清晨生成专属行动报告，汇总昨日足迹、常去地点与互动概况。"),
    ]

    private let grouped: [(String, [StatusEntry])] = {
        let entries = StatusEntry.Preset.samples
        var dict: [(String, [StatusEntry])] = []
        var seen: [String: Int] = [:]
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "MM-dd"
        for entry in entries {
            let key: String = Calendar.current.isDateInToday(entry.date) ? "今天" : fmt.string(from: entry.date)
            if let idx = seen[key] { dict[idx].1.append(entry) }
            else { seen[key] = dict.count; dict.append((key, [entry])) }
        }
        return dict
    }()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    diaryHero
                        .padding(.top, Theme.Spacing.sm)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.md), count: 4),
                              spacing: Theme.Spacing.md) {
                        ForEach(features) { f in featureCell(f) }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.sm)
                    .padding(.bottom, Theme.Spacing.xl)

                    Rectangle()
                        .fill(Theme.Palette.separator)
                        .frame(height: 0.5)

                    HStack {
                        Text("我的历史状态")
                            .font(Theme.Typography.body(.bold))
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Spacer()
                        HStack(spacing: Theme.Spacing.lg) {
                            Button { showSettings = true } label: {
                                Image(systemName: "gearshape")
                                    .font(Theme.Typography.symbol(16, .semibold))
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                            Button { Toast.show("筛选功能即将上线") } label: {
                                Image(systemName: "line.3.horizontal.decrease")
                                    .font(Theme.Typography.symbol(16, .semibold))
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.sm)

                    VStack(spacing: 0) {
                        ForEach(grouped, id: \.0) { (dateLabel, entries) in
                            sectionBlock(dateLabel: dateLabel, entries: entries)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)

                    Color.clear.frame(height: 100)
                }
            }
            .background(Theme.Palette.bg.ignoresSafeArea())
            .navigationTitle("现在在做什么呢?")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedFeature) { f in QuickFeatureDetailSheet(feature: f) }
            .sheet(item: $selectedEntry) { e in EntryDetailSheet(entry: e) }
            .sheet(item: $selectedDiary) { d in DiaryDetailSheet(diary: d) }
            .sheet(isPresented: $showSettings) {
                ReportingSettingsView().presentationDetents([.large])
            }
        }
    }

    // MARK: - Feature cell

    private func featureCell(_ f: QuickFeature) -> some View {
        Button {
            selectedFeature = f
        } label: {
            VStack(spacing: Theme.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(f.color.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: f.icon)
                        .font(Theme.Typography.symbol(22, .semibold))
                        .foregroundStyle(f.color)
                }
                Text(f.label)
                    .font(Theme.Typography.caption2(.medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 0.88))
        .accessibilityLabel(f.label)
    }

    // MARK: - Section block

    private func sectionBlock(dateLabel: String, entries: [StatusEntry]) -> some View {
        let isCollapsed = collapsed.contains(dateLabel)
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    if isCollapsed { collapsed.remove(dateLabel) } else { collapsed.insert(dateLabel) }
                }
            } label: {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(dateLabel)
                        .font(Theme.Typography.body(.bold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(Theme.Typography.symbol(11, .semibold))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .rotationEffect(isCollapsed ? .degrees(-90) : .zero)
                }
            }
            .padding(.top, Theme.Spacing.xl)
            .accessibilityLabel(isCollapsed ? "展开 \(dateLabel)" : "收起 \(dateLabel)")

            if !isCollapsed {
                ForEach(entries) { entry in entryCard(entry) }
            }
        }
    }

    // MARK: - Entry card

    @ViewBuilder
    private func entryCard(_ entry: StatusEntry) -> some View {
        let isNow = Calendar.current.isDateInToday(entry.date) && entry.locationName.isEmpty

        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            VStack(spacing: 0) {
                Circle()
                    .fill(isNow ? Theme.Palette.primary : Theme.Palette.textSecondary.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .padding(.top, Theme.Spacing.lg)
            }
            .frame(width: 8)

            if isNow {
                HStack(spacing: 6) {
                    Image(systemName: entry.activityIcon)
                        .font(Theme.Typography.callout())
                        .foregroundStyle(Theme.Palette.primary)
                    Text(entry.activityLabel)
                        .font(Theme.Typography.body(.semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, 10)
                .background(Theme.Palette.card2, in: Capsule())
                .padding(.bottom, Theme.Spacing.sm)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: Theme.Spacing.md) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(timeString(entry.date))
                                .font(Theme.Typography.caption(.medium))
                                .foregroundStyle(Theme.Palette.textSecondary)

                            HStack(spacing: 6) {
                                Image(systemName: entry.activityIcon)
                                    .font(Theme.Typography.subheadline())
                                    .foregroundStyle(Theme.Palette.primary)
                                Text(entry.activityLabel)
                                    .font(Theme.Typography.body(.semibold))
                                    .foregroundStyle(Theme.Palette.textPrimary)
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, 7)
                            .background(Theme.Palette.card2, in: Capsule())

                            if !entry.locationName.isEmpty {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(Theme.Typography.symbol(11))
                                        .foregroundStyle(Theme.Palette.textSecondary)
                                    Text(entry.locationName)
                                        .font(Theme.Typography.caption())
                                        .foregroundStyle(Theme.Palette.textSecondary)
                                }
                            }
                            if entry.systemTag {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(Theme.Typography.symbol(10))
                                    Text("系统识别，仅供参考")
                                        .font(Theme.Typography.caption2())
                                }
                                .foregroundStyle(Theme.Palette.danger.opacity(0.85))
                            }
                            HStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: "clock").font(Theme.Typography.symbol(10))
                                Text(entry.duration)
                                    .font(Theme.Typography.caption2(.medium))
                            }
                            .foregroundStyle(Theme.Palette.textSecondary)
                        }

                        Spacer()

                        if !entry.stickerIcon.isEmpty {
                            Image(systemName: entry.stickerIcon)
                                .font(Theme.Typography.display())
                                .foregroundStyle(Theme.Palette.textSecondary.opacity(0.45))
                                .frame(width: 64, height: 64)
                        }
                    }
                    .padding([.horizontal, .top], Theme.Spacing.md)

                    Rectangle()
                        .fill(Theme.Palette.separator)
                        .frame(height: 0.5)
                        .padding(.top, Theme.Spacing.md)

                    HStack(spacing: Theme.Spacing.lg) {
                        actionBtn(icon: "eye", label: "查看") { selectedEntry = entry }
                        Divider().frame(height: 14).background(Theme.Palette.separator)
                        actionBtn(icon: "arrow.clockwise", label: "重置") { Toast.show("已重置（演示）") }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, 10)
                }
                .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                        .strokeBorder(Theme.Palette.separator, lineWidth: 0.5)
                )
                .padding(.bottom, Theme.Spacing.sm)
            }
        }
    }

    private func actionBtn(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(Theme.Typography.subheadline(.semibold))
                Text(label)
                    .font(Theme.Typography.subheadline(.medium))
            }
            .foregroundStyle(Theme.Palette.textSecondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 0.94))
    }

    private func timeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }

    // MARK: - AI 轨迹日记

    private var diaryHero: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(Theme.Typography.symbol(16, .bold))
                    .foregroundStyle(Theme.Palette.primary)
                Text("AI 轨迹日记")
                    .font(Theme.Typography.headline(.bold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Button {
                    generateDiary()
                } label: {
                    HStack(spacing: 5) {
                        if generating {
                            ProgressView().controlSize(.small)
                                .tint(Theme.Palette.primary)
                        } else {
                            Image(systemName: "pencil.and.outline")
                                .font(Theme.Typography.subheadline(.semibold))
                        }
                        Text(generating ? "撰写中" : "写今天")
                            .font(Theme.Typography.subheadline(.semibold))
                    }
                    .foregroundStyle(Theme.Palette.primary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, 7)
                    .background(Theme.Palette.primary.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.pressable(scale: 0.92))
                .disabled(generating)
                .accessibilityLabel(generating ? "AI正在撰写" : "让AI写今天的轨迹日记")
            }
            .padding(.horizontal, Theme.Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    if generating { diaryLoadingCard }
                    ForEach(diaries) { diary in diaryCard(diary) }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xs)
            }
        }
        .padding(.bottom, Theme.Spacing.lg)
    }

    private func diaryCard(_ diary: TrajectoryDiary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(diary.coverEmoji).font(Theme.Typography.titleLarge())
                VStack(alignment: .leading, spacing: 3) {
                    Text(diary.title)
                        .font(Theme.Typography.body(.bold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(dateText(diary.date))
                        .font(Theme.Typography.caption2(.medium))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer(minLength: 0)
            }

            Text(diary.story)
                .font(Theme.Typography.subheadline())
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineLimit(4)
                .lineSpacing(4)

            HStack(spacing: Theme.Spacing.sm) {
                statPill("📍", "\(diary.placesVisited) 个地方")
                statPill("🚶", String(format: "%.1f km", diary.distanceKm))
                statPill("💡", diary.mood)
            }

            HStack(spacing: 10) {
                Button {
                    selectedDiary = diary
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("查看")
                    }
                    .font(Theme.Typography.caption(.medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pressable(scale: 0.94))

                ShareLink(item: diary.shareText) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "square.and.arrow.up")
                        Text("分享")
                    }
                    .font(Theme.Typography.caption(.medium))
                    .foregroundStyle(Theme.Palette.primary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pressable(scale: 0.94))
            }
        }
        .padding(Theme.Spacing.md)
        .frame(width: 280, alignment: .leading)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.Palette.separator, lineWidth: 0.5)
        )
    }

    private var diaryLoadingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SkeletonBlock(height: 34, shape: .roundedRect)
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonBlock(width: 120, height: 12, shape: .line(height: 12))
                    SkeletonBlock(width: 70, height: 9, shape: .line(height: 9))
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(height: 9, shape: .line(height: 9))
                SkeletonBlock(height: 9, shape: .line(height: 9))
                SkeletonBlock(width: 180, height: 9, shape: .line(height: 9))
            }
            HStack(spacing: Theme.Spacing.sm) {
                SkeletonBlock(width: 64, height: 22, shape: .roundedRect)
                SkeletonBlock(width: 64, height: 22, shape: .roundedRect)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(width: 280, height: 168, alignment: .leading)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.Palette.separator, lineWidth: 0.5)
        )
    }

    private func statPill(_ icon: String, _ text: String) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(icon).font(Theme.Typography.caption2())
            Text(text).font(Theme.Typography.caption2(.medium))
        }
        .foregroundStyle(Theme.Palette.textSecondary)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Theme.Palette.card2, in: Capsule())
    }

    private func dateText(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M月d日"
        return fmt.string(from: date)
    }

    private func generateDiary() {
        guard !generating else { return }
        generating = true
        Haptics.light()
        Task { @MainActor in
            if let diary = await session.generateTrajectoryDiary() {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    diaries.insert(diary, at: 0)
                }
                Haptics.success()
                Toast.show("AI 已为你写下一段日记 ✨")
            } else if let err = session.errorMessage {
                Toast.show(err)
            }
            generating = false
        }
    }
}
