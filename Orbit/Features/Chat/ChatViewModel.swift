import OrbitCore
import OrbitUI
import OrbitServices
import SwiftUI

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
