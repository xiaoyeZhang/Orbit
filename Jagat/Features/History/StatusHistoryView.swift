import SwiftUI
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
}

// MARK: - View
struct StatusHistoryView: View {
    private let features: [QuickFeature] = [
        .init(icon: "shield.checkered",     label: "安全守护", color: Color(hex: 0x5352ED)),
        .init(icon: "battery.100.bolt",     label: "健康用机", color: Color(hex: 0x2BCB96)),
        .init(icon: "bell.and.waveform",    label: "地点提醒", color: Color(hex: 0xFF6B81)),
        .init(icon: "chart.bar.doc.horizontal", label: "每日报告", color: Color(hex: 0xFFC312)),
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
                            Button { } label: {
                                Image(systemName: "gearshape").font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Theme.Palette.textSecondary)
                            }
                            Button { } label: {
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
        }
    }

    // MARK: - Feature cell
    private func featureCell(_ f: QuickFeature) -> some View {
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
    }

    // MARK: - Section block
    private func sectionBlock(dateLabel: String, entries: [StatusEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { } label: {
                HStack(spacing: 4) {
                    Text(dateLabel)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .padding(.top, 20)

            ForEach(entries) { entry in
                entryCard(entry)
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
                        actionBtn(icon: "eye", label: "查看")
                        Divider()
                            .frame(height: 14)
                            .background(Theme.Palette.separator)
                        actionBtn(icon: "arrow.clockwise", label: "重置")
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

    private func actionBtn(icon: String, label: String) -> some View {
        Button { } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func timeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }
}
