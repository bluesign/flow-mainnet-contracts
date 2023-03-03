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

pub contract interface OracleInterface {
    /*
        ************************************
                Reader interfaces
        ************************************
    */
    /// Oracle price reader, users need to save this resource in their local storage
    ///
    /// Only readers in the addr whitelist have permission to read prices
    /// Please do not share your PriceReader capability with others and take the responsibility of community governance.
    pub resource PriceReader {
        /// Get the median price of all current feeds.
        ///
        /// @Return Median price, returns 0.0 if the current price is invalid
        ///
        pub fun getMedianPrice(): UFix64
    }

    /// Reader related public interfaces opened on PriceOracle smart contract
    ///
    pub resource interface OraclePublicInterface_Reader {
        /// Users who need to read the oracle price should mint this resource and save locally.
        ///
        pub fun mintPriceReader(): @PriceReader

        /// Recommended path for PriceReader, users can manage resources by themselves
        ///
        pub fun getPriceReaderStoragePath(): StoragePath
    }


    /*
        ************************************
                Feeder interfaces
        ************************************
    */
    /// Panel for publishing price. Every feeder needs to mint this resource locally.
    ///
    pub resource PriceFeeder: PriceFeederPublic {
        /// The feeder uses this function to offer price at the price panel
        ///
        /// Param price - price from off-chain
        ///
        pub fun publishPrice(price: UFix64)

        /// Set valid duration of price. If there is no update within the duration, the price will be expired.
        ///
        /// Param blockheightDuration by the block numbers
        ///
        pub fun setExpiredDuration(blockheightDuration: UInt64)
    }
    pub resource interface PriceFeederPublic {
        /// Get the current feed price, this function can only be called by the PriceOracle contract
        ///
        pub fun fetchPrice(certificate: &OracleCertificate): UFix64
    }


    /// Feeder related public interfaces opened on PriceOracle smart contract
    ///
    pub resource interface OraclePublicInterface_Feeder {
        /// Feeders need to mint their own price panels and expose the exact public path to oracle contract
        ///
        /// @Return Resource of price panel
        ///
        pub fun mintPriceFeeder(): @PriceFeeder

        /// The oracle contract will get the PriceFeeder resource based on this path
        ///
        /// Feeders need to expose the capabilities at this public path
        ///
        pub fun getPriceFeederPublicPath(): PublicPath
        pub fun getPriceFeederStoragePath(): StoragePath
    }
    
    /// IdentityCertificate resource which is used to identify account address or perform caller authentication
    ///
    pub resource interface IdentityCertificate {}

    /// Each oracle contract will hold its own certificate to identify itself.
    ///
    /// Only the oracle contract can mint the certificate.
    ///
    pub resource OracleCertificate: IdentityCertificate {}



    /*
        ************************************
                Governace interfaces
        ************************************
    */
    /// Community administrator, Increment Labs will then collect community feedback and initiate voting for governance.
    ///
    pub resource interface Admin {
        pub fun configOracle(priceIdentifier: String, minFeederNumber: Int, feederStoragePath: StoragePath, feederPublicPath: PublicPath, readerStoragePath: StoragePath)
        pub fun addFeederWhiteList(feederAddr: Address)
        pub fun addReaderWhiteList(readerAddr: Address)
        pub fun delFeederWhiteList(feederAddr: Address)
        pub fun delReaderWhiteList(readerAddr: Address)
        pub fun getFeederWhiteListPrice(): [UFix64]   
    }
}
