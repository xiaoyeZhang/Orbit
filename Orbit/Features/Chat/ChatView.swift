import SwiftUI
import MapKit
import UIKit
import OrbitCore
import OrbitUI
import OrbitServices

// MARK: - 聊天主视图

struct ChatView: View {
    @StateObject private var vm: ChatViewModel
    @EnvironmentObject private var location: LocationManager
    @State private var showLocationShare = false

    @State private var showBurstBar = false
    @State private var burstEffect: BurstEffect?
    @State private var lastSeenMessageId: String?
    @State private var didLoadInitial = false
    private let burstEmojis = ["❤️", "😂", "🎉", "🔥", "😭", "💣"]

    init(conversation: Conversation) {
        _vm = StateObject(wrappedValue: ChatViewModel(
            conversation: conversation,
            backend: SharedBackend.current))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Theme.Palette.groupedBackground,
                         Theme.Palette.primary.opacity(0.05)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                messageList
                if showBurstBar { burstBar }
                inputBar
            }

            if let effect = burstEffect {
                EmojiBurstOverlay(effect: effect) { burstEffect = nil }
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .navigationTitle(vm.conversation.friendName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
        .onChange(of: vm.messages.count) { _ in
            guard let last = vm.messages.last, last.id != lastSeenMessageId else { return }
            lastSeenMessageId = last.id
            guard didLoadInitial else { didLoadInitial = true; return }
            if case .burst(let emoji) = last.kind {
                Haptics.medium()
                burstEffect = BurstEffect(emoji: emoji)
            }
        }
    }

    // MARK: - 消息列表

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    ForEach(vm.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                            .messageAppear(isMine: message.isMine)
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.lg)
            }
            .onChange(of: vm.messages.count) { _ in
                if let last = vm.messages.last {
                    withAnimation(.smoothSpring) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - emoji 轰炸快捷条

    private var burstBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(burstEmojis, id: \.self) { emoji in
                Button {
                    vm.sendBurst(emoji)
                    withAnimation(.snap) { showBurstBar = false }
                } label: {
                    Text(emoji)
                        .font(Theme.Typography.title2(.heavy))
                        .frame(width: 44, height: 44)
                        .background(Theme.Palette.surface, in: Circle())
                        .shadowCard()
                }
                .buttonStyle(.pressable(scale: 0.82))
            }

            Button {
                vm.sendPing()
                withAnimation(.snap) { showBurstBar = false }
            } label: {
                    Text("👋")
                        .font(Theme.Typography.title2(.heavy))
                        .frame(width: 44, height: 44)
                    .background(Theme.Palette.sunshine.opacity(0.18), in: Circle())
                    .overlay(Circle().strokeBorder(Theme.Palette.sunshine.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.pressable(scale: 0.82))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.ultraThinMaterial)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - 输入栏

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Button {
                vm.shareLocation(location.effectiveCoordinate, name: "我的当前位置")
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.oceanGradient)
                        .frame(width: 36, height: 36)
                    Image(systemName: "location.fill")
                        .font(Theme.Typography.callout(.bold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
            }
            .buttonStyle(.pressable(scale: 0.88))
            .accessibilityLabel("分享位置")

            Button {
                Haptics.light()
                withAnimation(.snap) { showBurstBar.toggle() }
            } label: {
                ZStack {
                    Circle()
                        .fill(showBurstBar
                              ? AnyShapeStyle(Theme.brandGradient)
                              : AnyShapeStyle(Theme.Palette.surface))
                        .frame(width: 36, height: 36)
                        .shadowCard()
                    Image(systemName: "face.smiling.inverse")
                        .font(Theme.Typography.body(.bold))
                        .foregroundStyle(showBurstBar ? Theme.Palette.textPrimary : Theme.Palette.subtle)
                }
            }
            .buttonStyle(.pressable(scale: 0.88))
            .accessibilityLabel("表情轰炸")

            TextField("", text: $vm.draft, prompt:
                Text("发条消息…").foregroundColor(Theme.Palette.subtle),
                axis: .vertical)
                .lineLimit(1...4)
                .font(Theme.Typography.body())
                .foregroundStyle(Theme.Palette.ink)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                        .fill(Theme.Palette.surface)
                        .shadowCard()
                )

            let canSend = !vm.draft.trimmingCharacters(in: .whitespaces).isEmpty
            Button(action: vm.send) {
                ZStack {
                    Circle()
                        .fill(canSend ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.Palette.subtle.opacity(0.2)))
                        .frame(width: 36, height: 36)
                        .shadow(color: canSend ? Theme.Palette.primary.opacity(0.4) : .clear, radius: 6, y: 3)
                    Image(systemName: "arrow.up")
                        .font(Theme.Typography.callout(.heavy))
                        .foregroundStyle(canSend ? Theme.Palette.textPrimary : Theme.Palette.subtle)
                }
            }
            .buttonStyle(.pressable(scale: 0.88))
            .disabled(!canSend)
            .animation(.snap, value: canSend)
            .accessibilityLabel("发送消息")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider().opacity(0.4)
        }
    }
}

// MARK: - 消息气泡

struct MessageBubble: View {
    let message: Message
    @State private var mapTarget: LocationTarget?

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
            if message.isMine { Spacer(minLength: 60) }
            bubbleContent.contentShape(Rectangle())
            if !message.isMine { Spacer(minLength: 60) }
        }
        .sheet(item: $mapTarget) { target in
            LocationPreviewSheet(coordinate: target.coordinate, name: target.name)
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        switch message.kind {
        case .text(let text):
            Text(text)
                .font(Theme.Typography.body())
                .foregroundStyle(message.isMine ? Theme.Palette.textPrimary : Theme.Palette.ink)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 10)
                .background {
                    if message.isMine {
                        RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                            .fill(Theme.brandGradient)
                            .themedShadow(.glow(Theme.Palette.primary))
                    } else {
                        RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                            .fill(Theme.Palette.surface)
                            .shadowCard()
                    }
                }

        case .location(let coord, let name):
            Button { mapTarget = LocationTarget(coordinate: coord, name: name) } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Map(coordinateRegion: .constant(MKCoordinateRegion(
                        center: coord.clLocationCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))))
                        .frame(width: 210, height: 126)
                        .allowsHitTesting(false)

                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(Theme.Palette.accent)
                        Text(name)
                            .font(Theme.Typography.caption(.semibold))
                            .foregroundStyle(Theme.Palette.ink)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, 9)
                    .frame(width: 210, alignment: .leading)
                    .background(Theme.Palette.surface)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadowElevated()
            }
            .buttonStyle(.plain)

        case .ping:
            PingBubble()

        case .sos(let coord, let note):
            sosBubble(coord: coord, note: note)

        case .burst(let emoji):
            BurstBubble(emoji: emoji, isMine: message.isMine)
        }
    }

    private func sosBubble(coord: Coordinate, note: String) -> some View {
        Button { mapTarget = LocationTarget(coordinate: coord, name: note) } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(Theme.Typography.symbol(16, .bold))
                    Text("紧急求助")
                        .font(Theme.Typography.callout(.bold))
                }
                .foregroundStyle(Theme.Palette.textPrimary)
                Text(note)
                    .font(Theme.Typography.subheadline(.medium))
                    .foregroundStyle(Theme.Palette.textPrimary.opacity(0.92))
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                    Text("查看实时位置")
                        .font(Theme.Typography.caption(.semibold))
                }
                .foregroundStyle(Theme.Palette.textPrimary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.white.opacity(0.2), in: Capsule())
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
            .frame(width: 230, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.Palette.danger)
                    .themedShadow(.glow(Theme.Palette.danger))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - emoji 轰炸气泡

struct BurstBubble: View {
    let emoji: String
    let isMine: Bool
    @State private var pop = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(emoji)
                .font(Theme.Typography.title2())
                .scaleEffect(pop ? 1.25 : 0.8)
                .onAppear {
                    withAnimation(.jelly.repeatCount(2, autoreverses: true)) { pop = true }
                }
            Text(isMine ? "发起了轰炸" : "轰炸了你")
                .font(Theme.Typography.callout(.bold))
                .foregroundStyle(Theme.Palette.primary)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Palette.primary.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.Palette.primary.opacity(0.35), lineWidth: 1.2)
                }
        )
    }
}

// MARK: - 全屏 emoji 轰炸动效

struct BurstEffect: Identifiable, Equatable {
    let id = UUID()
    let emoji: String
}

// MARK: - 戳一下气泡

struct PingBubble: View {
    @State private var bounce = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text("👋")
                .font(Theme.Typography.title3())
                .scaleEffect(bounce ? 1.3 : 1.0)
                .rotationEffect(.degrees(bounce ? 20 : -5))
                .onAppear {
                    withAnimation(.jelly.repeatCount(3, autoreverses: true)) { bounce = true }
                }
            Text("戳了你一下")
                .font(Theme.Typography.callout(.bold))
                .foregroundStyle(Theme.Palette.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Palette.sunshine.opacity(0.15))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.Palette.sunshine.opacity(0.4), lineWidth: 1.2)
                }
        )
    }
}

// MARK: - Location preview sheet

private struct LocationTarget: Identifiable {
    let id = UUID()
    let coordinate: Coordinate
    let name: String
}

private struct LocationPreviewSheet: View {
    let coordinate: Coordinate
    let name: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: coordinate.clLocationCoordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))))
                .frame(maxWidth: .infinity)
                .frame(height: 360)
                .ignoresSafeArea(edges: .top)

                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(Theme.Palette.accent)
                    Text(name)
                        .font(Theme.Typography.body(.semibold))
                        .foregroundStyle(Theme.Palette.ink)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(Theme.Spacing.lg)

                Button {
                    openInMaps()
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "map")
                        Text("在地图中打开")
                    }
                    .font(Theme.Typography.body(.bold))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .buttonStyle(.pressable(scale: 0.96))
                .padding(.horizontal, Theme.Spacing.lg)

                Spacer()
            }
            .navigationTitle("位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(Theme.Palette.primary)
                }
            }
            .background(Theme.Palette.groupedBackground)
        }
    }

    private func openInMaps() {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        let q = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "位置"
        if let url = URL(string: "maps://?q=\(q)&ll=\(lat),\(lon)") {
            UIApplication.shared.open(url)
        }
    }
}
