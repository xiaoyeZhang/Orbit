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
    let systemTag: Bool       // 系统识别，仅供参考
    let emojiDecoration: String

    enum Preset {
        static let samples: [StatusEntry] = [
            .init(date: .now,
                  activityLabel: "在留宿地", activityIcon: "house.fill",
                  locationName: "", duration: "刚刚",
                  systemTag: false, emojiDecoration: "🏠"),
            .init(date: calendar.date(byAdding: .day, value: -17, to: .now)!
                    .addingTimeInterval(-12 * 3600 + 11 * 60),
                  activityLabel: "在夜间地点", activityIcon: "moon.fill",
                  locationName: "留宿地", duration: "3天 38分钟",
                  systemTag: true, emojiDecoration: "🌙"),
            .init(date: calendar.date(byAdding: .day, value: -18, to: .now)!
                    .addingTimeInterval(-23 * 3600 + 14 * 60),
                  activityLabel: "在夜间地点", activityIcon: "moon.fill",
                  locationName: "留宿地", duration: "12小时 56分钟",
                  systemTag: true, emojiDecoration: "📍"),
            .init(date: calendar.date(byAdding: .day, value: -24, to: .now)!
                    .addingTimeInterval(-12 * 3600 + 8 * 60),
                  activityLabel: "在夜间地点", activityIcon: "moon.fill",
                  locationName: "留宿地", duration: "3天 16分钟",
                  systemTag: true, emojiDecoration: "🌙"),
        ]
        private static let calendar = Calendar.current
    }
}

// MARK: - View
struct StatusHistoryView: View {
    private let grouped: [(String, [StatusEntry])] = {
        let entries = StatusEntry.Preset.samples
        var dict: [(String, [StatusEntry])] = []
        var seen: [String: Int] = [:]
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "MM-dd"

        for entry in entries {
            let key: String
            if Calendar.current.isDateInToday(entry.date) { key = "今天" }
            else { key = fmt.string(from: entry.date) }

            if let idx = seen[key] {
                dict[idx].1.append(entry)
            } else {
                seen[key] = dict.count
                dict.append((key, [entry]))
            }
        }
        return dict
    }()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(grouped, id: \.0) { (dateLabel, entries) in
                        sectionBlock(dateLabel: dateLabel, entries: entries)
                    }
                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Theme.Palette.bg.ignoresSafeArea())
            .navigationTitle("我的历史状态")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button { } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                        Button { } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Section
    private func sectionBlock(dateLabel: String, entries: [StatusEntry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date header
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

            // Entries
            VStack(spacing: 8) {
                ForEach(entries) { entry in
                    entryCard(entry)
                }
            }
        }
    }

    // MARK: - Entry card
    private func entryCard(_ entry: StatusEntry) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Timeline dot
            VStack(spacing: 0) {
                Circle()
                    .fill(Theme.Palette.primary)
                    .frame(width: 8, height: 8)
                    .padding(.top, 18)
            }
            .frame(width: 8)

            // Card
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    // Time
                    if !Calendar.current.isDateInToday(entry.date) {
                        Text(timeString(entry.date))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }

                    // Activity
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

                    // Location + system tag
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
                        .foregroundStyle(Theme.Palette.danger.opacity(0.8))
                    }

                    // Duration
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(entry.duration)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Theme.Palette.textSecondary)
                }

                Spacer()

                // Decoration emoji
                Text(entry.emojiDecoration)
                    .font(.system(size: 44))
                    .opacity(0.85)
            }
            .padding(16)
            .background(Theme.Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.Palette.separator, lineWidth: 0.5)
            )
        }
    }

    private func timeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }
}
