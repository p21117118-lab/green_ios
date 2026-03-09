import Foundation
import UserNotifications
import os.log
import core

// MARK: - Meld Transaction Status
public enum MeldTransactionStatus: String {
    case pending = "PENDING"
    case processing = "PROCESSING"
    case settling = "SETTLING"
    case completed = "COMPLETED"
    case failed = "FAILED"
    case cancelled = "CANCELLED"

    var notificationTitle: String {
        switch self {
        case .pending: return "Transaction Pending"
        case .processing: return "Transaction Processing"
        case .settling: return "Transaction Settling"
        case .completed: return "Transaction Completed"
        case .failed: return "Transaction Failed"
        case .cancelled: return "Transaction Cancelled"
        }
    }

    var notificationBody: String {
        switch self {
        case .pending: return "Your transaction is pending confirmation"
        case .processing: return "Your transaction is being processed"
        case .settling: return "Your transaction is being settled"
        case .completed: return "Your transaction has been completed successfully"
        case .failed: return "Your transaction could not be completed"
        case .cancelled: return "Your transaction was cancelled"
        }
    }
}

// MARK: - Meld Transaction Task
public class MeldTransactionTask {
    public func start(event: MeldEvent) async throws -> [AnyHashable: Any] {
        logger.info("MeldTransactionTask: Starting Meld transaction task")
        // Verify we have the externalCustomerId
        guard let externalCustomerId = event.payload.externalCustomerId else {
            logger.error("MeldTransactionTask: Missing externalCustomerId in Meld transaction payload")
            throw NotificationError.InvalidNotification
        }
        // setup refresh flag
        let defaults = UserDefaults(suiteName: Bundle.main.appGroup)
        defaults?.setValue(true, forKey: "MELD_FETCH_REQUEST_TRANSACTIONS_FOR_\(externalCustomerId)")
        
        // Parse the transaction status
        let status = MeldTransactionStatus(rawValue: event.payload.paymentTransactionStatus.uppercased()) ?? .processing
        // Set notification title and body based on status
        var info: [AnyHashable: Any] = [
            "title": status.notificationTitle,
            "body": status.notificationBody
        ]
        // Add transaction data to userInfo
        info["eventId"] = event.eventId
        info["eventType"] = event.eventType
        info["timestamp"] = event.timestamp
        info["transactionId"] = event.payload.paymentTransactionId
        info["customerId"] = event.payload.customerId
        info["externalCustomerId"] = externalCustomerId
        info["status"] = event.payload.paymentTransactionStatus
        info["accountId"] = event.payload.accountId
        info["externalSessionId"] = event.payload.externalSessionId
        // Add a thread identifier based on the externalCustomerId
        logger.info("MeldTransactionTask: Notification content updated with transaction data for user \(externalCustomerId, privacy: .public)")
        return info
    }
}
