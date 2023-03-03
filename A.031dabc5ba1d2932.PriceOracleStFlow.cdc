import OracleInterface from 0xcec15c814971c1dc
import OracleConfig from 0xcec15c814971c1dc
import DelegatorManager from 0xd6f80565193ad727
import LiquidStakingConfig from 0xd6f80565193ad727

/// On-chain PriceOracle for stFlowToken/USD, which leverages on-chain PriceOracle for FlowToken/USD.
/// It needs to be a whitelisted reader of Flow/USD PriceOracle.
/// But no feeder is needed in this PriceOracle as stFlow/USD = Flow/USD x stFlow/Flow.
pub contract PriceOracleStFlow: OracleInterface {
    /// The identifier of the token type, eg: stFlow/USD
    pub var _PriceIdentifier: String?

    /// Recommended path for PriceReader, users can manage resources by themselves
    pub var _PriceReaderStoragePath: StoragePath?

    /// Storage path of public interface resource
    pub let _OraclePublicStoragePath: StoragePath

    /// Storage path to store the PriceReader resource of the Flow/USD price feed
    pub let _FlowPriceReaderPath: StoragePath

    /// Address whitelist of readers
    access(self) let _ReaderWhiteList: {Address: Bool}

    /// Reserved parameter fields: {ParamName: Value}
    access(self) let _reservedFields: {String: AnyStruct}

    /// Events
    pub event MintPriceReader()
    pub event ConfigOracle(oldType: String?, newType: String, oldReaderStoragePath: StoragePath?, newReaderStoragePath: StoragePath)
    pub event AddReaderWhiteList(addr: Address)
    pub event DelReaderWhiteList(addr: Address)

    /// Oracle price reader, users need to save this resource in their local storage
    ///
    /// Only readers in the addr whitelist have permission to read prices
    /// Please do not share your PriceReader capability with others and take the responsibility of community governance.
    pub resource PriceReader {
        pub let _PriceIdentifier: String

        /// @Return the median price of stFlow/USD price feed, return 0.0 if there's no valid price data to provide
        pub fun getMedianPrice(): UFix64 {
            // If no this feed's PriceReader resource, or the reader is not in stFlow/USD feed's whitelist
            if self.owner == nil || PriceOracleStFlow._ReaderWhiteList.containsKey(self.owner!.address) != true {
                return 0.0
            }

            let flowPriceReaderRef = PriceOracleStFlow.account.borrow<&OracleInterface.PriceReader>(from: PriceOracleStFlow._FlowPriceReaderPath)
            // If no Flow/USD feed's PriceReader resource
            if flowPriceReaderRef == nil {
                return 0.0
            }

            let flowToUsd = flowPriceReaderRef!.getMedianPrice()
            let scaledStFlowToFlow = DelegatorManager.borrowCurrentQuoteEpochSnapshot().scaledQuoteStFlowFlow
            return LiquidStakingConfig.ScaledUInt256ToUFix64(scaledStFlowToFlow) * flowToUsd
        }

        init() {
            self._PriceIdentifier = PriceOracleStFlow._PriceIdentifier!
        }
    }

    /// PriceFeeder is *unused* for PriceOracle_stFlowToken, put here simply for implementing the OracleInterface.
    pub resource PriceFeeder: OracleInterface.PriceFeederPublic {
        pub fun publishPrice(price: UFix64) { /* Do nothing */ }
        pub fun setExpiredDuration(blockheightDuration: UInt64) { /* Do nothing */ }
        pub fun fetchPrice(certificate: &OracleInterface.OracleCertificate): UFix64 { /* Do nothing */ return 0.0 }
    }

    /// OracleCertificate is also *unused* as there's no feeder
    pub resource OracleCertificate: OracleInterface.IdentityCertificate {}

    /// All external interfaces of this contract
    pub resource OraclePublic: OracleInterface.OraclePublicInterface_Reader {
        /// Users who need to read the oracle price should mint this resource and save locally.
        pub fun mintPriceReader(): @PriceReader {
            emit MintPriceReader()
            return <- create PriceReader()
        }

        /// Recommended path for PriceReader, users can manage resources by themselves
        pub fun getPriceReaderStoragePath(): StoragePath {
            return PriceOracleStFlow._PriceReaderStoragePath!
        }
    }

    /// Get reader whitelist of stFlow/USD price feed
    pub fun getReaderWhiteList(from: UInt64, to: UInt64): [Address] {
        let readerAddrs = PriceOracleStFlow._ReaderWhiteList.keys
        let readerLen = UInt64(readerAddrs.length)
        assert(from <= to && from < readerLen, message: "Index out of range")
        var _to = to
        if _to == 0 || _to == UInt64.max || _to >= readerLen {
            _to = readerLen-1
        }
        let list: [Address] = []
        var cur = from
        while cur <= _to && cur < readerLen {
            list.append(readerAddrs[cur])
            cur = cur + 1
        }
        return list
    }

    pub resource Admin: OracleInterface.Admin {
        pub fun configOracle(
            priceIdentifier: String,
            minFeederNumber: Int,
            feederStoragePath: StoragePath,
            feederPublicPath: PublicPath,
            readerStoragePath: StoragePath
        ) {
            emit ConfigOracle(
                oldType: PriceOracleStFlow._PriceIdentifier, newType: priceIdentifier,
                oldReaderStoragePath: PriceOracleStFlow._PriceReaderStoragePath, newReaderStoragePath: readerStoragePath
            )
            if (PriceOracleStFlow._PriceIdentifier != priceIdentifier) {
                PriceOracleStFlow._PriceIdentifier = priceIdentifier
            }
            if (PriceOracleStFlow._PriceReaderStoragePath != readerStoragePath) {
                PriceOracleStFlow._PriceReaderStoragePath = readerStoragePath
            }
        }

        pub fun addReaderWhiteList(readerAddr: Address) {
            PriceOracleStFlow._ReaderWhiteList[readerAddr] = true
            emit AddReaderWhiteList(addr: readerAddr)
        }

        pub fun delReaderWhiteList(readerAddr: Address) {
            PriceOracleStFlow._ReaderWhiteList.remove(key: readerAddr)
            emit DelReaderWhiteList(addr: readerAddr)
        }

        // Feeder-related are *unused*.
        pub fun addFeederWhiteList(feederAddr: Address) {}
        pub fun delFeederWhiteList(feederAddr: Address) {}
        pub fun getFeederWhiteListPrice(): [UFix64] { return [] }
    }

    init(flowPriceOracle: Address) {
        self._PriceIdentifier = "stFlow/USD"

        self._PriceReaderStoragePath = /storage/increment_oracle_reader_stFlowToken
        self._OraclePublicStoragePath = /storage/oracle_public

        self._ReaderWhiteList = {}
        self._reservedFields = {}

        // Initialize & save flowPriceReader
        let flowPriceOraclePublicInterfaceReaderRef = getAccount(flowPriceOracle)
            .getCapability<&{OracleInterface.OraclePublicInterface_Reader}>(OracleConfig.OraclePublicInterface_ReaderPath).borrow()
            ?? panic("cannot borrow reference to Flow/USD PriceOracle Reader")
        let flowPriceReaderPath = flowPriceOraclePublicInterfaceReaderRef.getPriceReaderStoragePath()
        destroy <- self.account.load<@AnyResource>(from: flowPriceReaderPath)
        let flowPriceReader <- flowPriceOraclePublicInterfaceReaderRef.mintPriceReader()
        self.account.save(<- flowPriceReader, to: flowPriceReaderPath)
        self._FlowPriceReaderPath = flowPriceReaderPath

        // Local admin resource
        destroy <- self.account.load<@AnyResource>(from: OracleConfig.OracleAdminPath)
        self.account.save(<-create Admin(), to: OracleConfig.OracleAdminPath)

        // Public interface
        destroy <- self.account.load<@AnyResource>(from: self._OraclePublicStoragePath)
        self.account.save(<-create OraclePublic(), to: self._OraclePublicStoragePath)
        self.account.link<&{OracleInterface.OraclePublicInterface_Reader}>(OracleConfig.OraclePublicInterface_ReaderPath, target: self._OraclePublicStoragePath)
    }
}