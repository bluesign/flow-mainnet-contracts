import StarlyCard from 0x5b82f21c0edf76e3
import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import StarlyCardStaking from 0x29fcd0b5e444242a
import StakedStarlyCard from 0x29fcd0b5e444242a
import StarlyCardMarket from 0x5b82f21c0edf76e3

pub contract StarlyCardBid {
    
    pub var totalCount: UInt64

    pub event StarlyCardBidCreated(
        bidID: UInt64,
        nftID: UInt64,
        starlyID: String,
        bidPrice: UFix64,
        bidVaultType: String,
        bidderAddress: Address)
    
    pub event StarlyCardBidAccepted(
        bidID: UInt64,
        nftID: UInt64,
        starlyID: String)

    // Declined by the card owner
    pub event StarlyCardBidDeclined(
        bidID: UInt64,
        nftID: UInt64,
        starlyID: String)

    // Bid cancelled by the bidder
    pub event StarlyCardBidCancelled(
        bidID: UInt64,
        nftID: UInt64,
        starlyID: String)

    // Bid invalidated due to changed conditions, i.e. remaining resource
    pub event StarlyCardBidInvalidated(
        bidID: UInt64,
        nftID: UInt64,
        starlyID: String)

    // Paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    pub resource interface BidPublicView {
        pub let id: UInt64
        pub let nftID: UInt64
        pub let starlyID: String
        pub let remainingResource: UFix64
        pub let bidPrice: UFix64
        pub let bidVaultType: Type
    }

    pub resource Bid: BidPublicView {
        pub let id: UInt64

        pub let nftID: UInt64
        pub let starlyID: String

        // card's remainig resource
        pub let remainingResource: UFix64

        // The price offered by the bidder
        pub let bidPrice: UFix64
        // The Type of the FungibleToken that payments must be made in
        pub let bidVaultType: Type
        access(self) let bidVault: @FungibleToken.Vault

        pub let bidderAddress: Address
        access(self) let bidderFungibleReceiver: Capability<&{FungibleToken.Receiver}>

        pub fun accept(
            bidderCardCollection: &StarlyCard.Collection{StarlyCard.StarlyCardCollectionPublic},
            sellerFungibleReceiver: Capability<&{FungibleToken.Receiver}>,
            sellerCardCollection: Capability<&StarlyCard.Collection{NonFungibleToken.Provider}>,
            sellerStakedCardCollection: &StakedStarlyCard.Collection,
            sellerMarketCollection: &StarlyCardMarket.Collection
        ) {
            pre {
                self.bidVault.balance == self.bidPrice: "The amount of locked funds is incorrect"
            }

            let currentRemainingResource = StarlyCardStaking.getRemainingResourceWithDefault(starlyID: self.starlyID)
            if currentRemainingResource != self.remainingResource {
                emit StarlyCardBidInvalidated(bidID: self.id, nftID: self.nftID, starlyID: self.starlyID)
                return
            }

            self.unstakeCardIfStaked(sellerStakedCardCollection: sellerStakedCardCollection)
            self.removeMarketSaleOfferIfExists(sellerMarketCollection: sellerMarketCollection)

            // transfer card
            let nft <- sellerCardCollection.borrow()!.withdraw(withdrawID: self.nftID)
            bidderCardCollection.deposit(token: <- nft)

            sellerFungibleReceiver.borrow()!.deposit(from: <- self.bidVault.withdraw(amount: self.bidPrice))

            emit StarlyCardBidAccepted(bidID: self.id, nftID: self.nftID, starlyID: self.starlyID)
        }

        access(self) fun removeMarketSaleOfferIfExists(sellerMarketCollection: &StarlyCardMarket.Collection) {
            let marketOfferIds = sellerMarketCollection.getSaleOfferIDs()
            if marketOfferIds.contains(self.nftID) {
                let offer <- sellerMarketCollection.remove(itemID: self.nftID)
                destroy offer
            }       
        }

        access(self) fun unstakeCardIfStaked(sellerStakedCardCollection: &StakedStarlyCard.Collection) {
            let stakeIds = sellerStakedCardCollection.getIDs()
            for stakeId in stakeIds {
                let cardStake = sellerStakedCardCollection.borrowStakePrivate(id: stakeId)
                if cardStake.getStarlyID() == self.starlyID {
                    sellerStakedCardCollection.unstake(id: stakeId)
                    return
                }
            }
        }

        init(
            nftID: UInt64,
            starlyID: String,
            bidPrice: UFix64,
            bidVaultType: Type,
            bidderAddress: Address,
            bidderFungibleReceiver: Capability<&{FungibleToken.Receiver}>,
            bidderFungibleProvider: &AnyResource{FungibleToken.Provider}
        ) {
            pre {
                bidPrice > 0.0: "The bid price must be non zero"
                bidderFungibleProvider.isInstance(bidVaultType): "Wrong Bid fungible provider type"
            }

            self.id = StarlyCardBid.totalCount
            self.nftID = nftID
            self.starlyID = starlyID
            self.bidPrice = bidPrice
            self.bidVaultType = bidVaultType
            self.bidderAddress = bidderAddress
            self.bidderFungibleReceiver = bidderFungibleReceiver

            self.remainingResource = StarlyCardStaking.getRemainingResourceWithDefault(starlyID: starlyID)

            self.bidVault <- bidderFungibleProvider.withdraw(amount: bidPrice)

            StarlyCardBid.totalCount = StarlyCardBid.totalCount + (1 as UInt64)

            emit StarlyCardBidCreated(
                bidID: self.id,
                nftID: self.nftID,
                starlyID: self.starlyID,
                bidPrice: self.bidPrice,
                bidVaultType: self.bidVaultType.identifier,
                bidderAddress: self.bidderAddress
            )
        }

        destroy () {
            if self.bidVault.balance > 0.0 {
                // return back to the bidder
                self.bidderFungibleReceiver.borrow()!.deposit(from: <- self.bidVault)
            } else {
                destroy self.bidVault
            }
        }        
    }

    pub resource interface CollectionManager {
        pub fun insert(bid: @StarlyCardBid.Bid)
        pub fun remove(bidID: UInt64): @Bid
        pub fun cancel(bidID: UInt64)
    }

    pub resource interface CollectionPublic {
        pub fun getBidIDs(): [UInt64]
        
        pub fun borrowBid(bidID: UInt64): &Bid{BidPublicView}?

        pub fun accept(
            bidID: UInt64,
            bidderCardCollection: &StarlyCard.Collection{StarlyCard.StarlyCardCollectionPublic},
            sellerFungibleReceiver: Capability<&{FungibleToken.Receiver}>,
            sellerCardCollection: Capability<&StarlyCard.Collection{NonFungibleToken.Provider}>,
            sellerStakedCardCollection: &StakedStarlyCard.Collection,
            sellerMarketCollection: &StarlyCardMarket.Collection)

        pub fun decline(bidID: UInt64)    
    }

    pub resource Collection : CollectionManager, CollectionPublic {
        pub var bids: @{UInt64: Bid}
        
        pub fun getBidIDs(): [UInt64] {
            return self.bids.keys
        }

        pub fun borrowBid(bidID: UInt64): &Bid{BidPublicView}? {
            if self.bids[bidID] == nil {
                return nil
            }

            return &self.bids[bidID] as &Bid{BidPublicView}?
        }

        pub fun insert(bid: @StarlyCardBid.Bid) {
            let oldBid <- self.bids[bid.id] <- bid
            destroy oldBid
        }

        pub fun remove(bidID: UInt64): @Bid {
            return <- (self.bids.remove(key: bidID) ?? panic("missing bid"))
        }

        pub fun accept(
            bidID: UInt64,
            bidderCardCollection: &StarlyCard.Collection{StarlyCard.StarlyCardCollectionPublic},
            sellerFungibleReceiver: Capability<&{FungibleToken.Receiver}>,
            sellerCardCollection: Capability<&StarlyCard.Collection{NonFungibleToken.Provider}>,
            sellerStakedCardCollection: &StakedStarlyCard.Collection,
            sellerMarketCollection: &StarlyCardMarket.Collection
        ) {
            let bid <- self.remove(bidID: bidID)
            bid.accept(
                bidderCardCollection: bidderCardCollection,
                sellerFungibleReceiver: sellerFungibleReceiver,
                sellerCardCollection: sellerCardCollection,
                sellerStakedCardCollection: sellerStakedCardCollection,
                sellerMarketCollection: sellerMarketCollection
            )
            destroy bid
        }

        pub fun decline(bidID: UInt64) {
            let bid <- self.remove(bidID: bidID)
            emit StarlyCardBidDeclined(bidID: bidID, nftID: bid.nftID, starlyID: bid.starlyID)
            destroy bid
        }

        pub fun cancel(bidID: UInt64) {
            let bid <- self.remove(bidID: bidID)
            emit StarlyCardBidCancelled(bidID: bidID, nftID: bid.nftID, starlyID: bid.starlyID)
            destroy bid
        }

        destroy () {
            destroy self.bids
        }

        init () {
            self.bids <- {}
        }
    }

    pub fun createBid(
        nftID: UInt64,
        starlyID: String,
        bidPrice: UFix64,
        bidVaultType: Type,
        bidderAddress: Address,
        bidderFungibleReceiver: Capability<&{FungibleToken.Receiver}>,
        bidderFungibleProvider: &AnyResource{FungibleToken.Provider}
    ): @Bid {
        return <- create Bid(
            nftID: nftID,
            starlyID: starlyID,
            bidPrice: bidPrice,
            bidVaultType: bidVaultType,
            bidderAddress: bidderAddress,
            bidderFungibleReceiver: bidderFungibleReceiver,
            bidderFungibleProvider: bidderFungibleProvider
        )
    }

    pub fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    init() {
        self.totalCount = 0
        self.CollectionStoragePath = /storage/starlyCardBidCollection
        self.CollectionPublicPath = /public/starlyCardBidCollection
    }       
}