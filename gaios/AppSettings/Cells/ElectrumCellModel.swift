class ElectrumCellModel {
    var testnetIsEnabled: Bool
    var switchTls: Bool
    var serverBTC: String
    var serverLiquid: String
    var serverTestnet: String
    var serverLiquidtestnet: String
    init(testnetIsEnabled: Bool,
         switchTls: Bool,
         serverBTC: String,
         serverLiquid: String,
         serverTestnet: String,
         serverLiquidtestnet: String
    ) {
        self.testnetIsEnabled = testnetIsEnabled
        self.switchTls = switchTls
        self.serverBTC = serverBTC
        self.serverLiquid = serverLiquid
        self.serverTestnet = serverTestnet
        self.serverLiquidtestnet = serverLiquidtestnet
    }
}
