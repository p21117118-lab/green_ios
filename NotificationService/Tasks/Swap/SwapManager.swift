import core

actor SwapManager {
    static let shared = SwapManager()
    private var activeTasks: Set<String> = []
    private var sessions: [String: LwkSessionManager] = [:]

    func shouldStartTask(for id: String) -> Bool {
        if activeTasks.contains(id) { return false }
        activeTasks.insert(id)
        return true
    }

    func finishTask(for id: String) {
        activeTasks.remove(id)
    }

    // Shared session logic to save memory
    func getSession(for xpubHash: String) -> LwkSessionManager {
        if let existing = sessions[xpubHash] { return existing }
        let new = LwkSessionManager(newNotificationDelegate: nil)
        sessions[xpubHash] = new
        return new
    }
}
