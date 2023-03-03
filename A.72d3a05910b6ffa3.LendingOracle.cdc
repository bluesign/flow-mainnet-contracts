/**

# Handle lending's oracle price readers. Prices come from a multi-node oracle.

# Author: Increment Labs

*/
import LendingInterfaces from 0x2df970b6cdee5735
import OracleInterface from 0xcec15c814971c1dc
import OracleConfig from 0xcec15c814971c1dc


pub contract LendingOracle {
    /// The storage path for the Admin resource
    pub let OracleAdminStoragePath: StoragePath
    /// The storage path for the Oracle resource
    pub let OracleStoragePath: StoragePath
    /// The public path for the capability to restricted to &{LendingInterfaces.OraclePublic}
    pub let OraclePublicPath: PublicPath
    /// Reserved parameter fields: {ParamName: Value}
    access(self) let _reservedFields: {String: AnyStruct}


    pub event PriceFeedAdded(for pool: Address, oracleAddr: Address)
    pub event PriceFeedRemoved(from pool: Address)
    

    pub resource OracleReaders: LendingInterfaces.OraclePublic {
        access(self) let feeds: [Address]
        access(self) let oracleAddrDict: {Address: Address}
        /// Reserved parameter fields: {ParamName: Value}
        access(self) let _reservedFields: {String: AnyStruct}


        /// Return underlying asset price of the pool, denominated in USD.
        /// Return 0.0 means price feed for the given pool is not available.  
        pub fun getUnderlyingPrice(pool: Address): UFix64 {
            if (!self.feeds.contains(pool)) {
                return 0.0
            }
            return self.latestResult(pool: pool)[1]
        }

        /// Return pool's latest data point in form of (timestamp, data)
        pub fun latestResult(pool: Address): [UFix64; 2] {
            var oracleAddr = self.oracleAddrDict[pool]!
            let oraclePublicInterface_ReaderRef = getAccount(oracleAddr).getCapability<&{OracleInterface.OraclePublicInterface_Reader}>(OracleConfig.OraclePublicInterface_ReaderPath).borrow()
                                                      ?? panic("Lost oracle public capability at ".concat(oracleAddr.toString()))
            let priceReaderSuggestedPath = oraclePublicInterface_ReaderRef.getPriceReaderStoragePath()
            let priceReaderRef = LendingOracle.account.borrow<&OracleInterface.PriceReader>(from: priceReaderSuggestedPath)
                                 ?? panic("Lost local price reader resource.")
            let price = priceReaderRef.getMedianPrice()

            return [
                getCurrentBlock().timestamp,
                price
            ]
        }

        pub fun getSupportedFeeds(): [Address] {
            return self.feeds
        }


        access(contract) fun addPriceFeed(for pool: Address, oracleAddr: Address) {
            if (!self.feeds.contains(pool)) {
                /// 1. Append new feed
                self.feeds.append(pool)
                /// 2. Record oracle address for this feed
                self.oracleAddrDict[pool] = oracleAddr
                /// 3. Mint oracle reader
                let oraclePublicInterface_ReaderRef = getAccount(oracleAddr).getCapability<&{OracleInterface.OraclePublicInterface_Reader}>(OracleConfig.OraclePublicInterface_ReaderPath).borrow()
                                                      ?? panic("Lost oracle public capability at ".concat(oracleAddr.toString()))
                let priceReaderSuggestedPath = oraclePublicInterface_ReaderRef.getPriceReaderStoragePath()
                if (LendingOracle.account.borrow<&OracleInterface.PriceReader>(from: priceReaderSuggestedPath) == nil) {
                    let priceReader <- oraclePublicInterface_ReaderRef.mintPriceReader()

                    destroy <- LendingOracle.account.load<@AnyResource>(from: priceReaderSuggestedPath)
                    LendingOracle.account.save(<- priceReader, to: priceReaderSuggestedPath)
                }

                emit PriceFeedAdded(for: pool, oracleAddr: oracleAddr)
            }

        }

        access(contract) fun removePriceFeed(pool: Address) {
            if (self.feeds.contains(pool)) {
                /// 1. Remove pool from data feeds
                var idx = 0
                while idx < self.feeds.length {
                    if (self.feeds[idx] == pool) {
                        break
                    }
                    idx = idx + 1
                }
                let lastToken = self.feeds.removeLast()
                if (lastToken != pool) {
                    self.feeds[idx] = lastToken
                }
                /// 2. Remove pool's associated data
                var oracleAddr = self.oracleAddrDict[pool]!
                self.oracleAddrDict.remove(key: pool)
                /// 3. Remove local oracle reader resource
                let oraclePublicInterface_ReaderRef = getAccount(oracleAddr).getCapability<&{OracleInterface.OraclePublicInterface_Reader}>(OracleConfig.OraclePublicInterface_ReaderPath).borrow()
                                                      ?? panic("Lost oracle public capability at ".concat(oracleAddr.toString()))
                let priceReaderSuggestedPath = oraclePublicInterface_ReaderRef.getPriceReaderStoragePath()
                destroy <- LendingOracle.account.load<@AnyResource>(from: priceReaderSuggestedPath)
                
                emit PriceFeedRemoved(from: pool)
            }
        }

        init () {
            self.feeds = []
            self.oracleAddrDict = {}
            self._reservedFields = {}
        }

        destroy() {
        }
    }

    pub resource Admin {
        /// Creating an Oracle resource which holds @maxCapacity data points at most.
        pub fun createOracleResource(): @OracleReaders {
            return <- create OracleReaders()
        }
        
        pub fun addPriceFeed(oracleRef: &OracleReaders, pool: Address, oracleAddr: Address) {
            oracleRef.addPriceFeed(for: pool, oracleAddr: oracleAddr)
        }

        pub fun removePriceFeed(oracleRef: &OracleReaders, pool: Address) {
            oracleRef.removePriceFeed(pool: pool)
        }
    }

    init() {
        self.OracleAdminStoragePath = /storage/oracleAdmin

        self.OracleStoragePath = /storage/oracleModule
        self.OraclePublicPath = /public/oracleModule
        
        destroy <-self.account.load<@AnyResource>(from: self.OracleAdminStoragePath)
        self.account.save(<-create Admin(), to: self.OracleAdminStoragePath)

        var adminRef = self.account.borrow<&LendingOracle.Admin>(from: self.OracleAdminStoragePath)!

        destroy <-self.account.load<@AnyResource>(from: self.OracleStoragePath)
        // Create and store a new Oracle resource
        self.account.save(<-adminRef.createOracleResource(), to: self.OracleStoragePath)
        // Create a public capability to Oracle resource that only exposes {OraclePublic} interface to public.
        self.account.unlink(self.OraclePublicPath)
        self.account.link<&{LendingInterfaces.OraclePublic}>(self.OraclePublicPath, target: self.OracleStoragePath)
        self._reservedFields = {}
    }
}