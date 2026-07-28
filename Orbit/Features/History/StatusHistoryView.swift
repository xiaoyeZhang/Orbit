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
    let stickerIcon: String   // SF Symbol used as sticker stand-in

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

// MARK: - Quick feature items
private struct QuickFeature: Identifiable {
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

    // AI 轨迹日记
    @State private var diaries: [TrajectoryDiary] = [.sample]
    @State private var generating = false
    @State private var selectedDiary: TrajectoryDiary?

    private let features: [QuickFeature] = [
        .init(icon: "shield.checkered",     label: "安全守护", color: Color(hex: 0x5352ED),
              detail: "实时守护你与家人的安全，遇到异常停留或长时间失联时主动提醒紧急联系人。"),
        .init(icon: "battery.100.bolt",     label: "健康用机", color: Color(hex: 0x2BCB96),
              detail: "统计每日屏幕使用时长与活动量，帮助你养成更健康的用机习惯。"),
        .init(icon: "bell.and.waveform",    label: "地点提醒", color: Color(hex: 0xFF6B81),
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
                    // ── AI 轨迹日记 hero ──
                    diaryHero
                        .padding(.top, 8)

                    // ── Quick features row ──
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(features) { f in
                            featureCell(f)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                    // ── Divider ──
                    Rectangle()
                        .fill(Theme.Palette.separator)
                        .frame(height: 0.5)

                    // Subheader
                    HStack {
                        Text("我的历史状态")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        HStack(spacing: 16) {
                            Button { showSettings = true } label: {
                                Image(systemName: "gearshape").font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                            Button { Toast.show("筛选功能即将上线") } label: {
                                Image(systemName: "line.3.horizontal.decrease").font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                    // ── Timeline ──
                    VStack(spacing: 0) {
                        ForEach(grouped, id: \.0) { (dateLabel, entries) in
                            sectionBlock(dateLabel: dateLabel, entries: entries)
                        }
                    }
                    .padding(.horizontal, 16)

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
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(f.color.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: f.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(f.color)
                }
                Text(f.label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 0.88))
    }

    // MARK: - Section block
    private func sectionBlock(dateLabel: String, entries: [StatusEntry]) -> some View {
        let isCollapsed = collapsed.contains(dateLabel)
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    if isCollapsed { collapsed.remove(dateLabel) }
                    else { collapsed.insert(dateLabel) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(dateLabel)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .rotationEffect(isCollapsed ? .degrees(-90) : .zero)
                }
            }
            .padding(.top, 20)

            if !isCollapsed {
                ForEach(entries) { entry in
                    entryCard(entry)
                }
            }
        }
    }

    // MARK: - Entry card
    @ViewBuilder
    private func entryCard(_ entry: StatusEntry) -> some View {
        let isNow = Calendar.current.isDateInToday(entry.date) && entry.locationName.isEmpty

        HStack(alignment: .top, spacing: 14) {
            // Timeline dot + line
            VStack(spacing: 0) {
                Circle()
                    .fill(isNow ? Theme.Palette.primary : Theme.Palette.textSecondary.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .padding(.top, 16)
            }
            .frame(width: 8)

            if isNow {
                // "此刻" simple pill
                HStack(spacing: 6) {
                    Image(systemName: entry.activityIcon)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Palette.primary)
                    Text(entry.activityLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Theme.Palette.card2, in: Capsule())
                .padding(.bottom, 8)
            } else {
                // Full card
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(timeString(entry.date))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.Palette.textSecondary)

                            HStack(spacing: 6) {
                                Image(systemName: entry.activityIcon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.Palette.primary)
                                Text(entry.activityLabel)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Theme.Palette.card2, in: Capsule())

                            if !entry.locationName.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.Palette.textSecondary)
                                    Text(entry.locationName)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.Palette.textSecondary)
                                }
                            }
                            if entry.systemTag {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.system(size: 10))
                                    Text("系统识别，仅供参考")
                                        .font(.system(size: 11))
                                }
                                .foregroundStyle(Theme.Palette.danger.opacity(0.85))
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text(entry.duration)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(Theme.Palette.textSecondary)
                        }

                        Spacer()

                        // Sticker area (SF Symbol as 3D stand-in)
                        if !entry.stickerIcon.isEmpty {
                            Image(systemName: entry.stickerIcon)
                                .font(.system(size: 44, weight: .light))
                                .foregroundStyle(Theme.Palette.textSecondary.opacity(0.45))
                                .frame(width: 64, height: 64)
                        }
                    }
                    .padding([.horizontal, .top], 14)

                    // Action buttons row
                    Rectangle()
                        .fill(Theme.Palette.separator)
                        .frame(height: 0.5)
                        .padding(.top, 12)

                    HStack(spacing: 16) {
                        actionBtn(icon: "eye", label: "查看") { selectedEntry = entry }
                        Divider()
                            .frame(height: 14)
                            .background(Theme.Palette.separator)
                        actionBtn(icon: "arrow.clockwise", label: "重置") {
                            Toast.show("已重置（演示）")
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                }
                .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.Palette.separator, lineWidth: 0.5)
                )
                .padding(.bottom, 8)
            }
        }
    }

    private func actionBtn(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.Palette.primary)
                Text("AI 轨迹日记")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    generateDiary()
                } label: {
                    HStack(spacing: 5) {
                        if generating {
                            ProgressView().controlSize(.small)
                                .tint(Theme.Palette.primary)
                        } else {
                            Image(systemName: "pencil.and.outline").font(.system(size: 13, weight: .semibold))
                        }
                        Text(generating ? "撰写中" : "写今天")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Theme.Palette.primary)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Theme.Palette.primary.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.pressable(scale: 0.92))
                .disabled(generating)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    if generating {
                        diaryLoadingCard
                    }
                    ForEach(diaries) { diary in
                        diaryCard(diary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
        }
        .padding(.bottom, 16)
    }

    private func diaryCard(_ diary: TrajectoryDiary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(diary.coverEmoji).font(.system(size: 34))
                VStack(alignment: .leading, spacing: 3) {
                    Text(diary.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text(dateText(diary.date))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
                Spacer(minLength: 0)
            }

            Text(diary.story)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineLimit(4)
                .lineSpacing(4)

            // 统计胶囊
            HStack(spacing: 8) {
                statPill("📍", "\(diary.placesVisited) 个地方")
                statPill("🚶", String(format: "%.1f km", diary.distanceKm))
                statPill("💡", diary.mood)
            }

            HStack(spacing: 10) {
                Button {
                    selectedDiary = diary
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("查看")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pressable(scale: 0.94))

                ShareLink(item: diary.shareText) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("分享")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Palette.primary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.pressable(scale: 0.94))
            }
        }
        .padding(14)
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
                RoundedRectangle(cornerRadius: 8).fill(Theme.Palette.card2)
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.Palette.card2).frame(width: 120, height: 12)
                    RoundedRectangle(cornerRadius: 4).fill(Theme.Palette.card2).frame(width: 70, height: 9)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(Theme.Palette.card2).frame(height: 9)
                RoundedRectangle(cornerRadius: 4).fill(Theme.Palette.card2).frame(height: 9)
                RoundedRectangle(cornerRadius: 4).fill(Theme.Palette.card2).frame(width: 180, height: 9)
            }
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8).fill(Theme.Palette.card2).frame(width: 64, height: 22)
                RoundedRectangle(cornerRadius: 8).fill(Theme.Palette.card2).frame(width: 64, height: 22)
            }
        }
        .padding(14)
        .frame(width: 280, height: 168, alignment: .leading)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.Palette.separator, lineWidth: 0.5)
        )
    }

    private func statPill(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Text(icon).font(.system(size: 11))
            Text(text).font(.system(size: 11, weight: .medium))
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

// MARK: - Feature detail sheet
private struct QuickFeatureDetailSheet: View {
    let feature: QuickFeature
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    ZStack {
                        Circle().fill(feature.color.opacity(0.15)).frame(width: 88, height: 88)
                        Image(systemName: feature.icon)
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(feature.color)
                    }
                    Text(feature.label)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text(feature.detail)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .lineSpacing(5)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
            .navigationTitle("功能详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(Theme.Palette.primary)
                }
            }
            .background(Theme.Palette.bg)
        }
    }
}

// MARK: - Entry detail sheet
private struct EntryDetailSheet: View {
    let entry: StatusEntry
    @Environment(\.dismiss) private var dismiss

    private var dateText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        return fmt.string(from: entry.date)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: entry.activityIcon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Theme.Palette.primary)
                        Text(entry.activityLabel)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    detailRow("时间", dateText)
                    if !entry.locationName.isEmpty {
                        detailRow("地点", entry.locationName)
                    }
                    detailRow("停留时长", entry.duration)
                    if entry.systemTag {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(Theme.Palette.danger)
                            Text("系统识别，仅供参考")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("状态详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(Theme.Palette.primary)
                }
            }
            .background(Theme.Palette.bg)
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Palette.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - 轨迹日记详情 sheet
private struct DiaryDetailSheet: View {
    let diary: TrajectoryDiary
    @Environment(\.dismiss) private var dismiss

    private var dateText: String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy 年 M 月 d 日"
        return fmt.string(from: diary.date)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    // 封面
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Theme.Palette.primary.opacity(0.14))
                                .frame(width: 72, height: 72)
                            Text(diary.coverEmoji).font(.system(size: 38))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(diary.title)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                            Text(dateText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.Palette.textSecondary)
                            HStack(spacing: 6) {
                                Image(systemName: "face.smiling").font(.system(size: 12))
                                Text("今日心情 · \(diary.mood)")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(Theme.Palette.primary)
                        }
                    }

                    // 故事正文
                    Text(diary.story)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .lineSpacing(6)

                    // 统计
                    HStack(spacing: 12) {
                        statBlock("📍", "\(diary.placesVisited)", "途经地方")
                        statBlock("🚶", String(format: "%.1f", diary.distanceKm), "漫游 km")
                        statBlock("⏱️", diary.durationLabel.replacingOccurrences(of: "活跃 ", with: ""), "活跃")
                    }

                    // 途经点
                    Text("途经的点")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    VStack(spacing: 10) {
                        ForEach(diary.highlights) { h in
                            HStack(alignment: .top, spacing: 12) {
                                Text(h.emoji).font(.system(size: 26))
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(h.placeName)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Text(h.time)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Theme.Palette.textSecondary)
                                    }
                                    Text(h.note)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.Palette.textSecondary)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }

                    ShareLink(item: diary.shareText) {
                        Label("分享这段日记", systemImage: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Theme.Palette.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.pressable(scale: 0.96))
                }
                .padding(20)
            }
            .navigationTitle("轨迹日记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(Theme.Palette.primary)
                }
            }
            .background(Theme.Palette.bg)
        }
    }

    private func statBlock(_ icon: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(icon).font(.system(size: 13))
                Text(value).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
            }
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
