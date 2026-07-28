import SwiftUI
import MapKit
import UIKit
import OrbitCore
import OrbitUI
import OrbitServices

// MARK: - ViewModel
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var draft = ""

    let conversation: Conversation
    private let backend: BackendService
    private var streamTask: Task<Void, Never>?

    init(conversation: Conversation, backend: BackendService) {
        self.conversation = conversation
        self.backend = backend
    }

    func start() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            for await msgs in self.backend.messagesStream(conversationId: self.conversation.id) {
                self.messages = msgs
            }
        }
        Task { try? await backend.markRead(conversationId: conversation.id) }
    }

    func stop() { streamTask?.cancel(); streamTask = nil }

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        Haptics.light()
        draft = ""
        Task { _ = try? await backend.sendMessage(.text(text), to: conversation.id) }
    }

    func shareLocation(_ coordinate: Coordinate, name: String) {
        Haptics.medium()
        Task { _ = try? await backend.sendMessage(.location(coordinate, name: name), to: conversation.id) }
    }

    func sendBurst(_ emoji: String) {
        Haptics.medium()
        Task { _ = try? await backend.sendMessage(.burst(emoji), to: conversation.id) }
    }

    func sendPing() {
        Haptics.medium()
        Task { _ = try? await backend.sendMessage(.ping, to: conversation.id) }
    }
}

// MARK: - 聊天主视图
struct ChatView: View {
    @StateObject private var vm: ChatViewModel
    @EnvironmentObject private var location: LocationManager
    @State private var showLocationShare = false

    // emoji 轰炸
    @State private var showBurstBar = false
    @State private var burstEffect: BurstEffect?     // 当前播放的全屏轰炸动效
    @State private var lastSeenMessageId: String?    // 用于识别新到的消息
    @State private var didLoadInitial = false        // 首次加载历史消息不播动效
    private let burstEmojis = ["❤️", "😂", "🎉", "🔥", "😭", "💣"]

    init(conversation: Conversation) {
        _vm = StateObject(wrappedValue: ChatViewModel(
            conversation: conversation,
            backend: SharedBackend.current))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // 聊天背景：浅紫微渐变
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

            // ── 全屏 emoji 轰炸动效（最顶层，不挡交互）──
            if let effect = burstEffect {
                EmojiBurstOverlay(effect: effect) {
                    burstEffect = nil
                }
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
            // 新到消息若是轰炸，播放全屏动效（自己发的和对方发的都播）
            guard let last = vm.messages.last, last.id != lastSeenMessageId else { return }
            lastSeenMessageId = last.id
            // 首次加载的是历史消息，不播动效
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
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 16)
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
        HStack(spacing: 8) {
            ForEach(burstEmojis, id: \.self) { emoji in
                Button {
                    vm.sendBurst(emoji)
                    withAnimation(.snap) { showBurstBar = false }
                } label: {
                    Text(emoji)
                        .font(.system(size: 26))
                        .frame(width: 44, height: 44)
                        .background(Theme.Palette.surface, in: Circle())
                        .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
                }
                .buttonStyle(.pressable(scale: 0.82))
            }

            // 戳一下
            Button {
                vm.sendPing()
                withAnimation(.snap) { showBurstBar = false }
            } label: {
                Text("👋")
                    .font(.system(size: 26))
                    .frame(width: 44, height: 44)
                    .background(Theme.Palette.sunshine.opacity(0.18), in: Circle())
                    .overlay(Circle().strokeBorder(Theme.Palette.sunshine.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.pressable(scale: 0.82))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - 输入栏
    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // 位置分享按钮
            Button {
                vm.shareLocation(location.effectiveCoordinate, name: "我的当前位置")
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.oceanGradient)
                        .frame(width: 36, height: 36)
                    Image(systemName: "location.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.pressable(scale: 0.88))

            // emoji 轰炸开关
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
                        .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
                    Image(systemName: "face.smiling.inverse")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(showBurstBar ? .white : Theme.Palette.subtle)
                }
            }
            .buttonStyle(.pressable(scale: 0.88))

            // 文本输入
            TextField("", text: $vm.draft, prompt:
                Text("发条消息…").foregroundColor(Theme.Palette.subtle),
                axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.Palette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.Palette.surface)
                        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                )

            // 发送按钮
            let canSend = !vm.draft.trimmingCharacters(in: .whitespaces).isEmpty
            Button(action: vm.send) {
                ZStack {
                    Circle()
                        .fill(canSend ? AnyShapeStyle(Theme.brandGradient) : AnyShapeStyle(Theme.Palette.subtle.opacity(0.2)))
                        .frame(width: 36, height: 36)
                        .shadow(color: canSend ? Theme.Palette.primary.opacity(0.4) : .clear, radius: 6, y: 3)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(canSend ? .white : Theme.Palette.subtle)
                }
            }
            .buttonStyle(.pressable(scale: 0.88))
            .disabled(!canSend)
            .animation(.snap, value: canSend)
        }
        .padding(.horizontal, 14)
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

    private func sosBubble(coord: Coordinate, note: String) -> some View {
        Button { mapTarget = LocationTarget(coordinate: coord, name: note) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("紧急求助")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                Text(note)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                    Text("查看实时位置")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.white.opacity(0.2), in: Capsule())
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(width: 230, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.Palette.danger)
                    .shadow(color: Theme.Palette.danger.opacity(0.4), radius: 8, y: 3)
            )
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isMine { Spacer(minLength: 60) }
            bubbleContent
                .contentShape(Rectangle())
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
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(message.isMine ? .white : Theme.Palette.ink)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background {
                    if message.isMine {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Theme.brandGradient)
                            .shadow(color: Theme.Palette.primary.opacity(0.35), radius: 8, y: 3)
                    } else {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Theme.Palette.surface)
                            .shadow(color: .black.opacity(0.07), radius: 6, y: 2)
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
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.Palette.ink)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .frame(width: 210, alignment: .leading)
                    .background(Theme.Palette.surface)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
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
}

// MARK: - emoji 轰炸气泡
struct BurstBubble: View {
    let emoji: String
    let isMine: Bool
    @State private var pop = false

    var body: some View {
        HStack(spacing: 8) {
            Text(emoji)
                .font(.system(size: 30))
                .scaleEffect(pop ? 1.25 : 0.8)
                .onAppear {
                    withAnimation(.jelly.repeatCount(2, autoreverses: true)) { pop = true }
                }
            Text(isMine ? "发起了轰炸" : "轰炸了你")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.Palette.primary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
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

struct EmojiBurstOverlay: View {
    let effect: BurstEffect
    var onFinished: () -> Void

    private struct Particle: Identifiable {
        let id = UUID()
        let x: CGFloat          // 水平位置（0~1 相对宽度）
        let size: CGFloat
        let delay: Double
        let duration: Double
        let rotation: Double
    }

    @State private var particles: [Particle] = []
    @State private var falling = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Text(effect.emoji)
                        .font(.system(size: p.size))
                        .rotationEffect(.degrees(falling ? p.rotation : 0))
                        .position(x: p.x * geo.size.width,
                                  y: falling ? geo.size.height + 60 : -60)
                        .animation(.easeIn(duration: p.duration).delay(p.delay), value: falling)
                }
            }
        }
        .onAppear {
            particles = (0..<24).map { _ in
                Particle(x: .random(in: 0.05...0.95),
                         size: .random(in: 26...44),
                         delay: .random(in: 0...0.5),
                         duration: .random(in: 1.2...2.0),
                         rotation: .random(in: -180...180))
            }
            // 下一帧开始下落，确保初始位置先布局
            DispatchQueue.main.async { falling = true }
            // 最长 delay+duration ≈ 2.5s 后收尾
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { onFinished() }
        }
    }
}

// MARK: - 戳一下气泡（动效特效）
struct PingBubble: View {
    @State private var bounce = false

    var body: some View {
        HStack(spacing: 8) {
            Text("👋")
                .font(.system(size: 24))
                .scaleEffect(bounce ? 1.3 : 1.0)
                .rotationEffect(.degrees(bounce ? 20 : -5))
                .onAppear {
                    withAnimation(.jelly.repeatCount(3, autoreverses: true)) {
                        bounce = true
                    }
                }
            Text("戳了你一下")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.Palette.sunshine)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
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

                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(Theme.Palette.accent)
                    Text(name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Palette.ink)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(16)

                Button {
                    openInMaps()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "map")
                        Text("在地图中打开")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Theme.brandGradient, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.pressable(scale: 0.96))
                .padding(.horizontal, 16)

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
