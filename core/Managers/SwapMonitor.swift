import Foundation
import CoreData
import LiquidWalletKit

public actor SwapMonitor {

    private let xpubHashId: String
    private let lwkSession: LwkSessionManager
    private var activeTasks: [NSManagedObjectID: Task<Void, Never>] = [:]

    public init(xpubHashId: String, lwkSession: LwkSessionManager) {
        self.xpubHashId = xpubHashId
        self.lwkSession = lwkSession
    }

    deinit {
        activeTasks.removeAll()
    }

    /// Called on wallet login to resume pending work
    public func start() async throws {
        try await BoltzController.shared.dump(xpubHashId: xpubHashId)
        let pendingIDs = try await getPendingSwaps()
        for swapId in pendingIDs {
            await monitorSwap(id: swapId)
        }
    }

    /// Called on restore wallet before wallet login to restore swaps, do before bootstrap()
    public func restoreSwaps(bitcoinAddress: String, liquidAddress: String) async throws {
        try await lwkSession.restoreSwaps(
            bitcoinAddress: bitcoinAddress,
            liquidAddress: liquidAddress,
            xpubHashId: xpubHashId)
    }

    public func monitorSwap(id: NSManagedObjectID) async {
        // Check if we are already monitoring this to avoid duplicates
        guard activeTasks[id] == nil else { return }
        // Create an isolated task for this specific transaction
        let task = Task {
            try? await handleSwap(id: id)
            // Cleanup: remove from dictionary once handleTransaction finishes
            await removeTask(for: id)
        }
        activeTasks[id] = task
    }

    private func removeTask(for id: NSManagedObjectID) {
        activeTasks.removeValue(forKey: id)
    }
    
    public func stop() async {
        for task in activeTasks {
            task.value.cancel()
        }
        // Give some time for tasks to cancel
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }

    private func getPendingSwaps() async throws -> [NSManagedObjectID] {
        try await BoltzController.shared.fetchPendingSwaps(xpubHashId: xpubHashId)
    }

    private func getPendingSwap(id: NSManagedObjectID) async throws -> BoltzSwap? {
        try await BoltzController.shared.get(with: id)
    }

    nonisolated private func handleSwap(id: NSManagedObjectID) async throws {
        let swap = try await getPendingSwap(id: id)
        guard let swap else { return }
        if swap.isPending == false { return }
        logger.info("LWK \(swap.id ?? "", privacy: .public): \(swap.data?.prefix(128) ?? "")")
        switch swap.type {
        case .some(BoltzSwapTypes.Submarine):
            if let pay = try await lwkSession.restorePreparePay(data: swap.data ?? "") {
                logger.info("LWK \(swap.id ?? "", privacy: .public) restored")
                let state = try await loopSwap(swap: SwapResponse.submarine(pay))
                logger.info("LWK \(swap.id ?? "", privacy: .public) \(state.localized, privacy: .public)")
            }
        case .some(BoltzSwapTypes.ReverseSubmarine):
            if let invoice = try await lwkSession.restoreInvoice(data: swap.data ?? "") {
                logger.info("LWK \(swap.id ?? "", privacy: .public) restored")
                let state = try await loopSwap(swap: SwapResponse.reverseSubmarine(invoice))
                logger.info("LWK \(swap.id ?? "", privacy: .public) \(state.localized, privacy: .public)")
            }
        case .some(.Chain):
            if let lockup = try await lwkSession.restoreLockup(data: swap.data ?? "") {
                logger.info("LWK \(swap.id ?? "", privacy: .public) restored")
                let state = try await loopSwap(swap: SwapResponse.chain(lockup))
                logger.info("LWK \(swap.id ?? "", privacy: .public) \(state.localized, privacy: .public)")
            }
        case .none:
            logger.info("LWK \(swap.id ?? "", privacy: .public) invalid")
        }
    }

    nonisolated public func handleSingleSwap(persistentId: NSManagedObjectID, swap: inout SwapResponse) async throws -> PaymentState {
        let swapId = try swap.swapId()
        do {
            let state = try swap.advance()
            switch state {
            case .continue:
                let data = try swap.serialize()
                logger.info("LWK \(swapId, privacy: .public) updated with \(data.prefix(64), privacy: .public)")
                _ = try await BoltzController.shared.update(with: persistentId, newData: data, newIsPending: true)
                try await Task.sleep(nanoseconds: 100_000_000)
            case .success:
                logger.info("LWK \(swapId, privacy: .public) completed successfully!")
                _ = try await BoltzController.shared.update(with: persistentId, newIsPending: false)
            case .failed:
                logger.info("LWK \(swapId, privacy: .public) failed!")
                _ = try await BoltzController.shared.update(with: persistentId, newIsPending: false)
                //_ = try await BoltzController.shared.delete(with: persistentId)
            }
            return state
        } catch LwkError.NoBoltzUpdate {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            logger.info("LWK \(swapId, privacy: .public) NoBoltzUpdate!")
            if let swap = try? await BoltzController.shared.get(with: persistentId) {
                return swap.isPending ? PaymentState.continue : PaymentState.success
            } else {
                return .failed
            }
        } catch LwkError.ObjectConsumed {
            logger.error("LWK \(swapId, privacy: .public) object consumed")
            //_ = try? await BoltzController.shared.delete(with: persistentId)
            //_ = try await BoltzController.shared.update(with: persistentId, newIsPending: false)
            return .failed
        } catch {
            logger.error("LWK \(swapId, privacy: .public) unrecoverable error: \(error.localizedDescription, privacy: .public)")
            //_ = try? await BoltzController.shared.delete(with: persistentId)
            //_ = try await BoltzController.shared.update(with: persistentId, newIsPending: false)
            return .failed
        }
    }

    nonisolated public func loopSwap(swap: SwapResponse) async throws -> PaymentState {
        let swapId = try swap.swapId()
        logger.error("LWK \(swapId, privacy: .public) loopSwap")
        let persistentId = try? await BoltzController.shared.fetchID(byId: swapId)
        guard let persistentId else {
            logger.error("LWK \(swapId, privacy: .public) not found")
            throw LwkError.Generic(msg: "Swap not found")
        }
        var state = PaymentState.continue
        var swap = swap
        repeat {
            try Task.checkCancellation()
            state = try await self.handleSingleSwap(persistentId: persistentId, swap: &swap)
        } while state == PaymentState.continue && !Task.isCancelled
        return state
    }
}
