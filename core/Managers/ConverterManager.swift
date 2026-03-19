import Foundation
import UIKit
import gdk

public protocol ConverterProvider {
    func convertBitcoinAmount(params: Balance) throws -> Balance?
    func convertLiquidAmount(params: Balance) throws -> Balance?
}

public class ConverterManager {

    private let provider: ConverterProvider
    private let testnet: Bool

    private lazy var fiatFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = .current
        return formatter
    }()

    private lazy var btcFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        formatter.locale = .current
        return formatter
    }()

    private func assetFormatter(precision: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = precision
        formatter.locale = .current
        return formatter
    }

    public init(provider: ConverterProvider, testnet: Bool) {
        self.provider = provider
        self.testnet = testnet
    }

    public func convertAmount(balance: Balance) throws -> Balance? {
        let start = CFAbsoluteTimeGetCurrent()
        if AssetInfo.baseIds.contains(balance.assetId ?? AssetInfo.btcId) {
            let res = try? provider.convertBitcoinAmount(params: balance)
            let end = CFAbsoluteTimeGetCurrent()
            print("Convert amount btc time: \(end - start) seconds")
            return res
        } else {
            let res = try? provider.convertLiquidAmount(params: balance)
            let end = CFAbsoluteTimeGetCurrent()
            print("Convert amount \(balance.assetId ?? "") time: \(end - start) seconds")
            return res
        }
    }

    func getBtcFromBalance(_ b: Balance, _ denomination: DenominationType) -> String? {
        switch denomination {
        case .BTC:
            return b.btc
        case .MilliBTC:
            return b.mbtc
        case .MicroBTC:
            return b.ubtc
        case .Bits:
            return b.bits
        case .Sats:
            return b.sats
        }
    }
 
    // Result as "value currency"
    public func formatFiat(_ b: Balance, withCurrency: Bool = true, withGroupSeparator: Bool = true) -> String? {
        guard let fiat = b.fiat, let val = Double(fiat) else {
            return nil
        }
        let formatter = btcFormatter
        if !withGroupSeparator {
            formatter.groupingSeparator = ""
        }
        if withCurrency {
            return "\(formatter.string(from: NSNumber(value: val)) ?? "") \(b.fiatCurrency ?? "")"
        } else {
            return "\(formatter.string(from: NSNumber(value: val)) ?? "")"
        }
    }
    public func formatBTC(_ b: Balance, denomination: DenominationType, withDenomination: Bool = true, withGroupSeparator: Bool = true) -> String? {
        guard let rawValue = getBtcFromBalance(b, denomination), let val = Double(rawValue) else {
            return nil
        }
        let formatter = btcFormatter
        if !withGroupSeparator {
            formatter.groupingSeparator = ""
        }
        if withDenomination {
            var network = testnet ? NetworkSecurityCase.testnetSS : NetworkSecurityCase.bitcoinSS
            if b.assetId == AssetInfo.lbtcId || b.assetId == AssetInfo.ltestId {
                network = testnet ? NetworkSecurityCase.testnetLiquidSS : NetworkSecurityCase.liquidSS
            }
            let denominations = DenominationType.denominations(for: network.gdkNetwork)
            let denominationText = denominations[denomination]
            return "\(formatter.string(from: NSNumber(value: val)) ?? "") \(denominationText ?? "")"
        } else {
            return "\(formatter.string(from: NSNumber(value: val)) ?? "")"
        }
    }
    public func formatAsset(_ b: Balance, withTicker: Bool = true, withGroupSeparator: Bool = true) -> String? {
        guard let assetValue = b.assetValue, let value = Double(assetValue) else {
            return nil
        }
        let formatter = assetFormatter(precision: Int(b.assetInfo?.precision ?? 8))
        if !withGroupSeparator {
            formatter.groupingSeparator = ""
        }
        if withTicker {
            return "\(formatter.string(from: NSNumber(value: value)) ?? "") \(b.assetInfo?.ticker ?? "")"
        } else {
            return "\(formatter.string(from: NSNumber(value: value)) ?? "")"
        }
    }
}
