import SwiftUI
import MapKit

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
}

// MARK: - 聊天主视图
struct ChatView: View {
    @StateObject private var vm: ChatViewModel
    @EnvironmentObject private var location: LocationManager
    @State private var showLocationShare = false

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
                inputBar
            }
        }
        .navigationTitle(vm.conversation.friendName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
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
            .animation(.snappy, value: canSend)
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

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isMine { Spacer(minLength: 60) }
            bubbleContent
                .contentShape(Rectangle())
            if !message.isMine { Spacer(minLength: 60) }
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

        case .ping:
            PingBubble()
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
