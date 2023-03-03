/**

# Desc This contract is the interface description of PriceOracle.
  The oracle includes an medianizer, which obtains prices from multiple feeds and calculate the median as the final price.
 
# Author Increment Labs

  This contract will accept price offers from multiple feeders.
  Feeders are anonymous for now to protect the providers from extortion.
  We welcome more price-feeding institutions and partners to join in and build a more decentralized oracle on flow.

  Currently, the use of this oracle is limited to addresses in the whitelist, and applications can be submitted to Increment Labs.

# Structure 
  Feeder1(off-chain) --> PriceFeeder(resource) 3.4$                                               PriceReader1(resource)
  Feeder2(off-chain) --> PriceFeeder(resource) 3.2$ --> PriceOracle(contract) cal median 3.4$ --> PriceReader2(resource)
  Feeder3(off-chain) --> PriceFeeder(resource) 3.6$                                               PriceReader3(resource)

  To apply for the whitelists of Feeders and Readers, pleas follow: https://increment.gitbook.io/public-documentation-1/protocols/decentralized-money-market/oracle

# Robustness
  1. Median value is the current referee decision strategy.
  2. _MinFeederNumber determines the minimum number of feeds required to provide a valid price
  3. The feeder needs to set the price expiration time. If the expiration block height is exceeded, the price will be invalid.
  4. The oracle will set the price to 0.0 When a valid price cannot be provided. Contract side needs to be able to detect and deal with this abnormal price, such as terminating the transactions.
*/

import OracleInterface from 0xcec15c814971c1dc
import OracleConfig from 0xcec15c814971c1dc

pub contract PriceOracle: OracleInterface {

    /// The identifier of the token type, eg: BTC/USD
    pub var _PriceIdentifier: String?

    /// Storage path of local oracle certificate
    pub let _CertificateStoragePath: StoragePath
    /// Storage path of public interface resource
    pub let _OraclePublicStoragePath: StoragePath

    /// The contract will fetch the price according to this path on the feed node
    pub var _PriceFeederPublicPath: PublicPath?
    pub var _PriceFeederStoragePath: StoragePath?
    /// Recommended path for PriceReader, users can manage resources by themselves
    pub var _PriceReaderStoragePath: StoragePath?

    /// Address white list of feeders and readers
    access(self) let _FeederWhiteList: {Address: Bool}
    access(self) let _ReaderWhiteList: {Address: Bool}

    /// The minimum number of feeders to provide a valid price.
    pub var _MinFeederNumber: Int

    /// Reserved parameter fields: {ParamName: Value}
    access(self) let _reservedFields: {String: AnyStruct}

    /// events
    pub event PublishOraclePrice(price: UFix64, tokenType: String, feederAddr: Address)
    pub event MintPriceReader()
    pub event MintPriceFeeder()
    pub event ConfigOracle(oldType: String?, newType: String?, oldMinFeederNumber: Int, newMinFeederNumber: Int)
    pub event AddFeederWhiteList(addr: Address)
    pub event DelFeederWhiteList(addr: Address)
    pub event AddReaderWhiteList(addr: Address)
    pub event DelReaderWhiteList(addr: Address)


    /// Oracle price reader, users need to save this resource in their local storage
    ///
    /// Only readers in the addr whitelist have permission to read prices
    /// Please do not share your PriceReader capability with others and take the responsibility of community governance.
    ///
    pub resource PriceReader {
        pub let _PriceIdentifier: String

        /// Get the median price of all current feeds.
        ///
        /// @Return Median price, returns 0.0 if the current price is invalid
        ///
        pub fun getMedianPrice(): UFix64 {
            pre {
                self.owner != nil: "PriceReader resource must be stored in local storage."
                PriceOracle._ReaderWhiteList.containsKey(self.owner!.address): "Reader addr is not on the whitelist."
            }

            let priceMedian = PriceOracle.takeMedianPrice()

            return priceMedian
        }

        init() {
            self._PriceIdentifier = PriceOracle._PriceIdentifier!
        }
    }

    /// Panel for publishing price. Every feeder needs to mint this resource locally.
    ///
    pub resource PriceFeeder: OracleInterface.PriceFeederPublic {
        access(self) var _Price: UFix64
        access(self) var _LastPublishBlockHeight: UInt64
        /// seconds
        access(self) var _ExpiredDuration: UInt64

        pub let _PriceIdentifier: String

        /// The feeder uses this function to offer price at the price panel
        ///
        /// @Param price - price from off-chain
        ///
        pub fun publishPrice(price: UFix64) {
            self._Price = price
            
            self._LastPublishBlockHeight = getCurrentBlock().height
            emit PublishOraclePrice(price: price, tokenType: PriceOracle._PriceIdentifier!, feederAddr: self.owner!.address)
        }

        /// Set valid duration of price. If there is no update within the duration, the price will expire.
        ///
        /// @Param blockheightDuration by the block numbers
        ///
        pub fun setExpiredDuration(blockheightDuration: UInt64) {
            self._ExpiredDuration = blockheightDuration
        }

        /// Get the current feed price, this function can only be called by the PriceOracle contract
        ///
        pub fun fetchPrice(certificate: &OracleInterface.OracleCertificate): UFix64 {
            pre {
                certificate.getType() == Type<@OracleCertificate>(): "PriceOracle certificate does not match."
            }
            if (getCurrentBlock().height - self._LastPublishBlockHeight > self._ExpiredDuration) {
                return 0.0
            }
            return self._Price
        }

        init() {
            self._Price = 0.0
            self._PriceIdentifier = PriceOracle._PriceIdentifier!
            self._LastPublishBlockHeight = 0
            self._ExpiredDuration = 60 * 40
        }
    }

    /// All external interfaces of this contract
    ///
    pub resource OraclePublic: OracleInterface.OraclePublicInterface_Reader, OracleInterface.OraclePublicInterface_Feeder {
        /// Users who need to read the oracle price should mint this resource and save locally.
        ///
        pub fun mintPriceReader(): @PriceReader {
            emit MintPriceReader()

            return <- create PriceReader()
        }

        /// Feeders need to mint their own price panels and expose the exact public path to oracle contract
        ///
        /// @Return Resource of price panel
        ///
        pub fun mintPriceFeeder(): @PriceFeeder {
            emit MintPriceFeeder()

            return <- create PriceFeeder()
        }

        /// Recommended path for PriceReader, users can manage resources by themselves
        ///
        pub fun getPriceReaderStoragePath(): StoragePath { return PriceOracle._PriceReaderStoragePath! }

        /// The oracle contract will get the feeding-price based on this path
        /// Feeders need to expose their price panel capabilities at this public path
        pub fun getPriceFeederStoragePath(): StoragePath { return PriceOracle._PriceFeederStoragePath! }
        pub fun getPriceFeederPublicPath(): PublicPath { return PriceOracle._PriceFeederPublicPath! }
    }

    /// Each oracle contract will hold its own certificate to identify itself.
    ///
    /// Only the oracle contract can mint the certificate.
    ///
    pub resource OracleCertificate: OracleInterface.IdentityCertificate {}

    /// Reader certificate is used to provide proof of its address.In fact, anyone can mint their reader certificate.
    ///
    /// Readers only need to apply for a certificate to any oracle contract once.
    /// The contract will control the read permission of the readers according to the address whitelist.
    /// Please do not share your certificate capability with others and take the responsibility of community governance.
    ///
    pub resource ReaderCertificate: OracleInterface.IdentityCertificate {}

    /// Calculate the median price
    ///
    /// Return median price
    ///
    access(contract) fun takeMedianPrice(): UFix64 {
        let oraclePrices: [UFix64] = []
        let certificateRef = self.account.borrow<&OracleCertificate>(from: self._CertificateStoragePath)
                             ?? panic("Lost PriceOracle certificate resource.")

        var priceList: [UFix64] = []
        var sortList: [UFix64] = []

        for oracleAddr in self._FeederWhiteList.keys {
            let pricePanelCap = getAccount(oracleAddr).getCapability<&{OracleInterface.PriceFeederPublic}>(PriceOracle._PriceFeederPublicPath!)
            // Get valid feeding-price
            if (pricePanelCap.check()) {
                let price = pricePanelCap.borrow()!.fetchPrice(certificate: certificateRef)
                if(price > 0.0) {
                    priceList.append(price)
                    sortList.append(0.0)
                }
            }
        }

        let len = priceList.length
        // If the number of valid prices is insufficient
        if (len < self._MinFeederNumber) {
            return 0.0
        }
        // sort
        var curIndex = 0
        while(curIndex < len) {
            let curPrice = priceList[curIndex]
            if (curIndex == 0 || curPrice >= sortList[curIndex-1]) {
                sortList[curIndex] = curPrice
            } else {
                var insertIndex = 0
                while (curPrice >= sortList[insertIndex]) {
                    insertIndex = insertIndex + 1
                }
                var swapIndex = curIndex
                while(swapIndex > insertIndex) {
                    sortList[swapIndex] = sortList[swapIndex-1]
                    swapIndex = swapIndex - 1
                }
                sortList[insertIndex] = curPrice
            }
            
            curIndex = curIndex + 1
        }
        // find median
        var mid = 0.0
        if (len % 2 == 0) {
            let v1 = sortList[len/2-1]
            let v2 = sortList[len/2]
            mid = UFix64(v1+v2)/2.0
        } else {
            mid = sortList[(len-1)/2]
        }
        return mid
    }

    access(contract) fun getFeederWhiteListPrice(): [UFix64] {
        let certificateRef = self.account.borrow<&OracleCertificate>(from: self._CertificateStoragePath)
            ?? panic("Lost PriceOracle certificate resource.")
        var priceList: [UFix64] = []

        for oracleAddr in PriceOracle._FeederWhiteList.keys {
            let pricePanelCap = getAccount(oracleAddr).getCapability<&{OracleInterface.PriceFeederPublic}>(PriceOracle._PriceFeederPublicPath!)
            if (pricePanelCap.check()) {
                let price = pricePanelCap.borrow()!.fetchPrice(certificate: certificateRef)
                if(price > 0.0) {
                    priceList.append(price)
                } else {
                    priceList.append(0.0)
                }
            } else {
                priceList.append(0.0)
            }
        }
        return priceList
    }

    access(contract) fun configOracle(
        priceIdentifier: String,
        minFeederNumber: Int,
        feederStoragePath: StoragePath,
        feederPublicPath: PublicPath,
        readerStoragePath: StoragePath
    ) {
        emit ConfigOracle(
            oldType: self._PriceIdentifier,
            newType: priceIdentifier,
            oldMinFeederNumber: self._MinFeederNumber,
            newMinFeederNumber: minFeederNumber
        )

        self._PriceIdentifier = priceIdentifier
        self._MinFeederNumber = minFeederNumber
        self._PriceFeederStoragePath = feederStoragePath
        self._PriceFeederPublicPath = feederPublicPath
        self._PriceReaderStoragePath = readerStoragePath
    }

    pub fun getFeederWhiteList(): [Address] {
        return PriceOracle._FeederWhiteList.keys
    }

    pub fun getReaderWhiteList(from: UInt64, to: UInt64): [Address] {
        let readerAddrs = PriceOracle._ReaderWhiteList.keys
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

    /// Community administrator, Increment Labs will then collect community feedback and initiate voting for governance.
    ///
    pub resource Admin: OracleInterface.Admin {
        /// 
        pub fun configOracle(
            priceIdentifier: String,
            minFeederNumber: Int,
            feederStoragePath: StoragePath,
            feederPublicPath: PublicPath,
            readerStoragePath: StoragePath
        ) {
            PriceOracle.configOracle(
                priceIdentifier: priceIdentifier,
                minFeederNumber: minFeederNumber,
                feederStoragePath: feederStoragePath,
                feederPublicPath: feederPublicPath,
                readerStoragePath: readerStoragePath
            )
        }

        pub fun addFeederWhiteList(feederAddr: Address) {
            // Check if feeder prepared price panel first
            let PriceFeederCap = getAccount(feederAddr).getCapability<&{OracleInterface.PriceFeederPublic}>(PriceOracle._PriceFeederPublicPath!)
            assert(PriceFeederCap.check(), message: "Need to prepare data feeder resource capability first.")

            PriceOracle._FeederWhiteList[feederAddr] = true

            emit AddFeederWhiteList(addr: feederAddr)
        }

        pub fun addReaderWhiteList(readerAddr: Address) {
            
            PriceOracle._ReaderWhiteList[readerAddr] = true

            emit AddReaderWhiteList(addr: readerAddr)
        }

        pub fun delFeederWhiteList(feederAddr: Address) {

            PriceOracle._FeederWhiteList.remove(key: feederAddr)

            emit DelFeederWhiteList(addr: feederAddr)
        }

        pub fun delReaderWhiteList(readerAddr: Address) {

            PriceOracle._ReaderWhiteList.remove(key: readerAddr)

            emit DelReaderWhiteList(addr: readerAddr)
        }

        pub fun getFeederWhiteListPrice(): [UFix64] {
            return PriceOracle.getFeederWhiteListPrice()
        }
    }


    init() {
        self._FeederWhiteList = {}
        self._ReaderWhiteList = {}
        self._MinFeederNumber = 1
        self._PriceIdentifier = nil

        self._CertificateStoragePath = /storage/oracle_certificate
        self._OraclePublicStoragePath = /storage/oracle_public
        
        self._PriceFeederStoragePath = nil
        self._PriceFeederPublicPath = nil

        self._PriceReaderStoragePath = nil

        self._reservedFields = {}

        
        // Local admin resource
        destroy <- self.account.load<@AnyResource>(from: OracleConfig.OracleAdminPath)
        self.account.save(<-create Admin(), to: OracleConfig.OracleAdminPath)
        // Create oracle ceritifcate
        destroy <- self.account.load<@AnyResource>(from: self._CertificateStoragePath)
        self.account.save(<-create OracleCertificate(), to: self._CertificateStoragePath)
        // Public interface
        destroy <- self.account.load<@AnyResource>(from: self._OraclePublicStoragePath)
        self.account.save(<-create OraclePublic(), to: self._OraclePublicStoragePath)
        self.account.link<&{OracleInterface.OraclePublicInterface_Reader}>(OracleConfig.OraclePublicInterface_ReaderPath, target: self._OraclePublicStoragePath)
        self.account.link<&{OracleInterface.OraclePublicInterface_Feeder}>(OracleConfig.OraclePublicInterface_FeederPath, target: self._OraclePublicStoragePath)
    }
}
