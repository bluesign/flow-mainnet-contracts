import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448

/// AnchainNFTTrader
///
/// A general purpose contract for trading Flow NonFungibleTokens based
/// on the NFTStorefront smart contract.
/// 
/// Each account that wants to trade NFTs installs a Trader,
/// and lists individual trades within that Trader as Trades.
/// There is one Trader per account, it handles trades of all NFT types
/// for that account.
///
/// Unlike the NFTStorefront contract, there is no concept of a SaleCut.
/// Each NFT may be listed in one or more Trades, the validity of each
/// Trade can easily be checked.
/// 
/// Traders can watch for Trade events and check the NFT type and
/// ID to see if they wish to accept the trade of the listed item.
/// Marketplaces and other aggregators can watch for Trade events
/// and list items of interest.
///
/// Currently, this contract supports 1:1 trades only (i.e. each trade 
/// can only exchange exactly one NFT for another single NFT). There are 
/// two types of 1:1 trades this contract supports:
/// 
///   1. Random trades: traders can exchange an NFT they own with any other 
///      NFT from a diffferent collection. This can be accomplished by setting 
///      requestedNftID to nil when creating a trade.
///   
///   2. Specific trades: traders can exchange an NFT they own for another 
///      NFT from a different collection with a particular ID. This can be 
///      accomplished by specifying requestedNftID when creating a trade.
///
/// This contract is intended to have a very similar interface to the 
/// NFTStorefront contract so that there's less barrier to entry when 
/// appying it in code. Many of the fields and functionalities should 
/// feel very familiar to those who have worked with the NFTStorefront 
/// contract in the past.
///
pub contract AnchainNFTTrader {
  /// ContractInitialized
  /// This contract has been deployed.
  /// Event consumers can now expect events from this contract.
  ///
  pub event ContractInitialized()

  /// TraderInitialized
  /// A Trader resource has been created.
  /// Event consumers can now expect events from this Trader.
  /// Note that we do not specify an address: we cannot and should not.
  /// Created resources do not have an owner address, and may be moved
  /// after creation in ways we cannot check.
  /// TradeAvailable events can be used to determine the address
  /// of the owner of the Trader (...its location) at the time of
  /// the trade but only at that precise moment in that precise transaction.
  /// If the seller moves the Trader while the trade is valid, 
  /// that is on them.
  ///
  pub event TraderInitialized(traderResourceID: UInt64)

  /// TraderDestroyed
  /// A Trader has been destroyed.
  /// Event consumers can now stop processing events from this Trader.
  /// Note that we do not specify an address.
  ///
  pub event TraderDestroyed(traderResourceID: UInt64)

  /// TradeAvailable
  /// A trade has been created and added to a Trader resource.
  /// The Address values here are valid when the event is emitted, but
  /// the state of the accounts they refer to may be changed outside of the
  /// AnchainTrader workflow, so be careful to check when using them.
  ///
  pub event TradeAvailable(
    traderAddress: Address,
    tradeResourceID: UInt64,
    nftType: Type,
    nftID: UInt64,
    requestedNftType: Type,
    requestedNftID: UInt64?,
  )

  /// TradeCompleted
  /// The trade has been resolved. It has either been executed, or removed and destroyed.
  ///
  pub event TradeCompleted(
    tradeResourceID: UInt64, 
    traderResourceID: UInt64, 
    executed: Bool,
    nftType: Type,
    nftID: UInt64
  )

  /// TraderStoragePath
  /// The location in storage that a Trader resource should be located.
  pub let TraderStoragePath: StoragePath

  /// TraderPublicPath
  /// The public location for a Trader link.
  pub let TraderPublicPath: PublicPath

  /// TradeDetails
  /// A struct containing a Trade's data.
  ///
  pub struct TradeDetails {
    /// The Trader that the Trade is stored in.
    /// Note that this resource cannot be moved to a different Trader,
    /// so this is OK. If we ever make it so that it *can* be moved,
    /// this should be revisited.
    pub var traderID: UInt64
    /// Whether this trade has been executed or not.
    pub var executed: Bool
    /// The Type of the NonFungibleToken.NFT that is being traded.
    pub let nftType: Type
    /// The ID of the NFT within that type.
    pub let nftID: UInt64
    /// The Type of the NonFungibleToken that trades must be made in.
    pub let requestedNftType: Type
    /// An optional NFT ID that traders can use to request a trade involving a specific NFT.
    pub let requestedNftID: UInt64?
    /// Allows the trade owner to receive NFTs from trades
    pub let nftReceiverCapability: Capability<&{NonFungibleToken.Receiver}>

    /// setToExecuted
    /// Irreversibly set this trade as executed.
    ///
    access(contract) fun setToExecuted() {
      self.executed = true
    }

    /// initializer
    ///
    init (
      nftType: Type,
      nftID: UInt64,
      nftReceiverCapability: Capability<&{NonFungibleToken.Receiver}>,
      requestedNftType: Type,
      requestedNftID: UInt64?,
      traderID: UInt64
    ) {
      self.traderID = traderID
      self.executed = false
      self.nftType = nftType
      self.nftID = nftID
      self.nftReceiverCapability = nftReceiverCapability
      self.requestedNftType = requestedNftType
      self.requestedNftID = requestedNftID
  
      // Make sure we can borrow the receiver.
      // We will check this again when the token is traded.
      nftReceiverCapability.borrow() ?? panic("Cannot borrow receiver")
    }
  }


  /// TradePublic
  /// An interface providing a useful public interface to a Trade.
  ///
  pub resource interface TradePublic {
    /// borrowNFT
    /// This will assert in the same way as the NFT standard borrowNFT()
    /// if the NFT is absent, for example if it has been executed via another trade.
    ///
    pub fun borrowNFT(): &NonFungibleToken.NFT

    /// execute
    /// Executes the trade, swapping the NFTs.
    ///
    pub fun execute(payment: @NonFungibleToken.NFT): @NonFungibleToken.NFT

    /// getDetails
    ///
    pub fun getDetails(): TradeDetails
  }


  /// Trade
  /// A resource that allows an NFT to be traded for another NFT.
  /// 
  pub resource Trade: TradePublic {
    /// The simple (non-Capability, non-complex) details of the trade
    access(self) let details: TradeDetails

    /// A capability allowing this resource to withdraw the NFT with the given ID from its collection.
    /// This capability allows the resource to withdraw *any* NFT, so you should be careful when giving
    /// such a capability to a resource and always check its code to make sure it will use it in the
    /// way that it claims.
    access(contract) let nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>

    /// borrowNFT
    /// This will assert in the same way as the NFT standard borrowNFT()
    /// if the NFT is absent, for example if it has been sold via another trade.
    ///
    pub fun borrowNFT(): &NonFungibleToken.NFT {
      let ref = self.nftProviderCapability.borrow()!.borrowNFT(id: self.getDetails().nftID)
      //- CANNOT DO THIS IN PRECONDITION: "member of restricted type is not accessible: isInstance"
      //  result.isInstance(self.getDetails().nftType): "token has wrong type"
      assert(ref.isInstance(self.getDetails().nftType), message: "token has wrong type")
      assert(ref.id == self.getDetails().nftID, message: "token has wrong ID")
      return (ref as &NonFungibleToken.NFT?)!
    }

    /// getDetails
    /// Get the details of the current state of the trade as a struct.
    /// This avoids having more public variables and getter methods for them, and plays
    /// nicely with scripts (which cannot return resources). 
    ///
    pub fun getDetails(): TradeDetails {
      return self.details
    }
    
    /// execute
    /// Execute the trade, swapping the NFTs.
    ///
    pub fun execute(payment: @NonFungibleToken.NFT): @NonFungibleToken.NFT {
      pre {
          self.details.executed == false: "trade has already been executed"
          payment.isInstance(self.details.requestedNftType): "provided NFT does not have the same type as the requested NFT"
      }

      if self.details.requestedNftID != nil {
        assert(payment.id == self.details.requestedNftID, message: "provided NFT does not have an ID that matches the requested ID")
      }

      // Make sure the trade cannot be executed again.
      self.details.setToExecuted()

      // Fetch the token to return to the entity who accepted the trade.
      let nft <-self.nftProviderCapability.borrow()!.withdraw(withdrawID: self.details.nftID)
      // Neither receivers nor providers are trustworthy, they must implement the correct
      // interface but beyond complying with its pre/post conditions they are not gauranteed
      // to implement the functionality behind the interface in any given way.
      // Therefore we cannot trust the Collection resource behind the interface,
      // and we must check the NFT resource it gives us to make sure that it is the correct one.
      assert(nft.isInstance(self.details.nftType), message: "withdrawn NFT is not of specified type")
      assert(nft.id == self.details.nftID, message: "withdrawn NFT does not have specified ID")

      // Execute the trade
      if let receiver = self.details.nftReceiverCapability.borrow() {
        receiver.deposit(token: <- payment)
      } else {
        panic("could not borrow reference to receiver collection")
      }

      // If the trade is executed, we regard it as completed here.
      // Otherwise we regard it as completed in the destructor.        
      emit TradeCompleted(
        tradeResourceID: self.uuid,
        traderResourceID: self.details.traderID,
        executed: self.details.executed,
        nftType: self.details.nftType,
        nftID: self.details.nftID
      )

      return <-nft
    }

    /// destructor
    ///
    destroy () {
      // If the trade has not been executed, we regard it as completed here.
      // Otherwise we regard it as completed in execute().
      // This is because we destroy the trade in Trader.removeTrade()
      // or Trader.cleanup() .
      // If we change this destructor, revisit those functions.
      if !self.details.executed {
        emit TradeCompleted(
          tradeResourceID: self.uuid,
          traderResourceID: self.details.traderID,
          executed: self.details.executed,
          nftType: self.details.nftType,
          nftID: self.details.nftID
        )
      }
    }

    /// initializer
    ///
    init (
      nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
      nftType: Type,
      nftID: UInt64,
      nftReceiverCapability: Capability<&{NonFungibleToken.Receiver}>,
      requestedNftType: Type,
      requestedNftID: UInt64?,
      traderID: UInt64
    ) {
      // Store the trade information
      self.details = TradeDetails(
        nftType: nftType,
        nftID: nftID,
        nftReceiverCapability: nftReceiverCapability,
        requestedNftType: requestedNftType,
        requestedNftID: requestedNftID,
        traderID: traderID
      )

      // Store the NFT provider
      self.nftProviderCapability = nftProviderCapability

      // Check that the provider contains the NFT.
      // We will check it again when the token is sold.
      // We cannot move this into a function because initializers cannot call member functions.
      let provider = self.nftProviderCapability.borrow()
      assert(provider != nil, message: "cannot borrow nftProviderCapability")

      // This will precondition assert if the token is not available.
      let nft = provider!.borrowNFT(id: self.details.nftID)
      assert(nft.isInstance(self.details.nftType), message: "token is not of specified type")
      assert(nft.id == self.details.nftID, message: "token does not have specified ID")
    }
  }

  /// TradeManager
  /// An interface for adding and removing Trades within a Trader,
  /// intended for use by the Trader's owner
  ///
  pub resource interface TradeManager {
    /// createTrade
    /// Allows the Trader to create and insert Trades.
    ///
    pub fun createTrade(
      nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
      nftType: Type,
      nftID: UInt64,
      nftReceiverCapability: Capability<&{NonFungibleToken.Receiver}>,
      requestedNftType: Type,
      requestedNftID: UInt64?,
    ): UInt64
    /// removeTrade
    /// Allows the Trader to remove any trade, accepted or not.
    ///
    pub fun removeTrade(tradeResourceID: UInt64)
  }

  /// TraderPublic
  /// An interface to allow listing and borrowing Trades, and executing Trades
  /// in a Trader.
  ///
  pub resource interface TraderPublic {
    pub fun getTradeIDs(): [UInt64]
    pub fun borrowTrade(tradeResourceID: UInt64): &Trade{TradePublic}?
    pub fun cleanup(tradeResourceID: UInt64)
  }

  /// Trader
  /// A resource that allows its owner to manage a list of Trades, and anyone to interact with them
  /// in order to query their details and execute trades on the NFTs that they represent.
  ///
  pub resource Trader : TradeManager, TraderPublic {
    /// The dictionary of Trade uuids to Trade resources.
    access(self) var trades: @{UInt64: Trade}

    /// insert
    /// Create and publish a Trade for an NFT.
    ///
    pub fun createTrade(
      nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
      nftType: Type,
      nftID: UInt64,
      nftReceiverCapability: Capability<&{NonFungibleToken.Receiver}>,
      requestedNftType: Type,
      requestedNftID: UInt64?,
    ): UInt64 {
      let trade <- create Trade(
        nftProviderCapability: nftProviderCapability,
        nftType: nftType,
        nftID: nftID,
        nftReceiverCapability: nftReceiverCapability,
        requestedNftType: requestedNftType,
        requestedNftID: requestedNftID,
        traderID: self.uuid
      )

      let tradeResourceID = trade.uuid

      // Add the new trade to the dictionary.
      let oldTrade <- self.trades[tradeResourceID] <- trade
      // Note that oldTrade will always be nil, but we have to handle it.

      destroy oldTrade

      emit TradeAvailable(
        traderAddress: self.owner?.address!,
        tradeResourceID: tradeResourceID,
        nftType: nftType,
        nftID: nftID,
        requestedNftType: requestedNftType,
        requestedNftID: requestedNftID,
      )

      return tradeResourceID
    }
      

    /// removeTrade
    /// Remove a Trade that has not yet been executed from the collection and destroy it.
    ///
    pub fun removeTrade(tradeResourceID: UInt64) {
      let trade <- self.trades.remove(key: tradeResourceID)
        ?? panic("missing Trade")

      // This will emit a TradeCompleted event.
      destroy trade
    }

    /// getTradeIDs
    /// Returns an array of the Trade resource IDs that are in the collection
    ///
    pub fun getTradeIDs(): [UInt64] {
      return self.trades.keys
    }

    /// borrowTrade
    /// Returns a read-only view of the Trade for the given tradeID if it is contained by this collection.
    ///
    pub fun borrowTrade(tradeResourceID: UInt64): &Trade{TradePublic}? {
      if self.trades[tradeResourceID] != nil {
        return &self.trades[tradeResourceID] as! &Trade{TradePublic}?
      } else {
        return nil
      }
    }

    /// cleanup
    /// Remove an trade *if* it has been executed.
    /// Anyone can call, but at present it only benefits the account owner to do so.
    /// Kind traders can however call it if they like.
    ///
    pub fun cleanup(tradeResourceID: UInt64) {
      pre {
        self.trades[tradeResourceID] != nil: "could not find trade with given id"
      }

      let trade <- self.trades.remove(key: tradeResourceID)!
      assert(trade.getDetails().executed == true, message: "trade is not executed, only admin can remove")
      destroy trade
    }

    /// destructor
    ///
    destroy () {
      destroy self.trades

      // Let event consumers know that this trader will no longer exist
      emit TraderDestroyed(traderResourceID: self.uuid)
    }

    /// constructor
    ///
    init () {
      self.trades <- {}

      // Let event consumers know that this trader exists
      emit TraderInitialized(traderResourceID: self.uuid)
    }
  }

  /// createTrader
  /// Make creating a Trader publicly accessible.
  ///
  pub fun createTrader(): @Trader {
    return <- create Trader()
  }

  init () {
    self.TraderStoragePath = /storage/AnchainTrader
    self.TraderPublicPath = /public/AnchainTrader

    emit ContractInitialized()
  }
}