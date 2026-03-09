public struct LwkEvent: Codable {
    enum CodingKeys: String, CodingKey {
        case type
        case event
        case walletHashedId = "wallet_hashed_id"
        case data
    }
    let type: String
    let event: String
    let walletHashedId: String
    let data: String
}

public struct LwkEventData: Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case status
    }
    let id: String
    let status: String
}
