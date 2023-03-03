import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import StarlyIDParser from 0x5b82f21c0edf76e3
import StakedStarlyCard from 0x29fcd0b5e444242a
import StarlyCard from 0x5b82f21c0edf76e3
import StarlyCardMarket from 0x5b82f21c0edf76e3
import StarlyCardStaking from 0x29fcd0b5e444242a
import StarlyRoyalties from 0x5b82f21c0edf76e3

pub contract StarlyCardBidV3 {

    pub var totalCount: UInt64

    pub event StarlyCardBidCreated(
        bidID: UInt64,
        nftID: UInt64,
        starlyID: String,
        bidPrice: UFix64,
        bidVaultType: String,
        bidderAddress: Address,
        beneficiarySaleCut: StarlyCardMarket.SaleCut,
        creatorSaleCut: StarlyCardMarket.SaleCut,
        additionalSaleCuts: [StarlyCardMarket.SaleCut])

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

        access(self) let beneficiarySaleCutReceiver: StarlyCardMarket.SaleCutReceiverV2
        access(self) let creatorSaleCutReceiver: StarlyCardMarket.SaleCutReceiverV2
        access(self) let additionalSaleCutReceivers: [StarlyCardMarket.SaleCutReceiverV2]

        pub fun accept(
            bidderCardCollection: &StarlyCard.Collection{StarlyCard.StarlyCardCollectionPublic},
            sellerFungibleReceiver: Capability<&{FungibleToken.Receiver}>,
            sellerCardCollection: Capability<&StarlyCard.Collection{NonFungibleToken.Provider}>,
            sellerStakedCardCollection: &StakedStarlyCard.Collection,
            sellerMarketCollection: &StarlyCardMarket.Collection,
            cardStakeId: UInt64?
        ) {
            pre {
                self.bidVault.balance == self.bidPrice: "The amount of locked funds is incorrect"
            }

            let currentRemainingResource = StarlyCardStaking.getRemainingResourceWithDefault(starlyID: self.starlyID)
            if currentRemainingResource != self.remainingResource {
                emit StarlyCardBidInvalidated(bidID: self.id, nftID: self.nftID, starlyID: self.starlyID)
                return
            }

            if let stakeId = cardStakeId {
                self.unstakeCardIfStaked(sellerStakedCardCollection: sellerStakedCardCollection, stakeId: stakeId)
                self.removeMarketSaleOfferIfExists(sellerMarketCollection: sellerMarketCollection)
            }

            // sale cuts
            let beneficiaryCutAmount = self.bidPrice * self.beneficiarySaleCutReceiver.percent
            let beneficiaryCut <- self.bidVault.withdraw(amount: beneficiaryCutAmount)
            self.beneficiarySaleCutReceiver.receiver.borrow()!.deposit(from: <- beneficiaryCut)

            let creatorCutAmount = self.bidPrice * self.creatorSaleCutReceiver.percent
            let creatorCut <- self.bidVault.withdraw(amount: creatorCutAmount)
            self.creatorSaleCutReceiver.receiver.borrow()!.deposit(from: <- creatorCut)

            for additionalSaleCutReceiver in self.additionalSaleCutReceivers {
                let additionalCutAmount = self.bidPrice * additionalSaleCutReceiver.percent
                let additionalCut <- self.bidVault.withdraw(amount: additionalCutAmount)
                additionalSaleCutReceiver.receiver.borrow()!.deposit(from: <- additionalCut)
            }

            // The rest goes to the seller
            let sellerCutAmount = self.bidVault.balance
            sellerFungibleReceiver.borrow()!.deposit(from: <- self.bidVault.withdraw(amount: sellerCutAmount))

            // transfer card
            let nft <- sellerCardCollection.borrow()!.withdraw(withdrawID: self.nftID)
            bidderCardCollection.deposit(token: <- nft)

            emit StarlyCardBidAccepted(
                bidID: self.id,
                nftID: self.nftID,
                starlyID: self.starlyID)
        }

        access(self) fun removeMarketSaleOfferIfExists(sellerMarketCollection: &StarlyCardMarket.Collection) {
            let marketOfferIds = sellerMarketCollection.getSaleOfferIDs()
            if marketOfferIds.contains(self.nftID) {
                let offer <- sellerMarketCollection.remove(itemID: self.nftID)
                destroy offer
            }
        }

        access(self) fun unstakeCardIfStaked(sellerStakedCardCollection: &StakedStarlyCard.Collection, stakeId: UInt64) {
            let cardStake = sellerStakedCardCollection.borrowStakePrivate(id: stakeId)
            if cardStake.getStarlyID() == self.starlyID {
                sellerStakedCardCollection.unstake(id: stakeId)
            }
        }

        init(
            nftID: UInt64,
            starlyID: String,
            bidPrice: UFix64,
            bidVaultType: Type,
            bidderAddress: Address,
            bidderFungibleReceiver: Capability<&{FungibleToken.Receiver}>,
            bidderFungibleProvider: &AnyResource{FungibleToken.Provider},
            beneficiarySaleCutReceiver: StarlyCardMarket.SaleCutReceiverV2,
            creatorSaleCutReceiver: StarlyCardMarket.SaleCutReceiverV2,
            additionalSaleCutReceivers: [StarlyCardMarket.SaleCutReceiverV2],
        ) {
            pre {
                bidPrice > 0.0: "The bid price must be non zero"
                bidderFungibleProvider.isInstance(bidVaultType): "Wrong Bid fungible provider type"
                StarlyCardMarket.checkSaleCutReceiverV2(saleCutReceiver: beneficiarySaleCutReceiver): "Cannot borrow receiver in beneficiarySaleCutReceiver"
                StarlyCardMarket.checkSaleCutReceiverV2(saleCutReceiver: creatorSaleCutReceiver): "Cannot borrow receiver in creatorSaleCutReceiver"
                StarlyCardMarket.checkSaleCutReceiversV2(saleCutReceivers: additionalSaleCutReceivers): "Cannot borrow receiver in additionalSaleCutReceivers"
            }

            self.id = StarlyCardBidV3.totalCount
            self.nftID = nftID
            self.starlyID = starlyID
            self.bidPrice = bidPrice
            self.bidVaultType = bidVaultType
            self.bidderAddress = bidderAddress
            self.bidderFungibleReceiver = bidderFungibleReceiver
            self.beneficiarySaleCutReceiver = beneficiarySaleCutReceiver
            self.creatorSaleCutReceiver = creatorSaleCutReceiver
            self.additionalSaleCutReceivers = additionalSaleCutReceivers

            self.remainingResource = StarlyCardStaking.getRemainingResourceWithDefault(starlyID: starlyID)

            let beneficiaryCutAmount = self.bidPrice * self.beneficiarySaleCutReceiver.percent
            let creatorCutAmount = self.bidPrice * self.creatorSaleCutReceiver.percent
            var additionalSaleCutAmountSum = 0.0
            var additionalSaleCuts: [StarlyCardMarket.SaleCut] = []
            for additionalSaleCutReceiver in self.additionalSaleCutReceivers {
            let additionalCutAmount = self.bidPrice * additionalSaleCutReceiver.percent
                additionalSaleCutAmountSum = additionalSaleCutAmountSum + additionalCutAmount
                additionalSaleCuts.append(StarlyCardMarket.SaleCut(
                    address: additionalSaleCutReceiver.receiver.address,
                    amount: additionalCutAmount,
                    percent: additionalSaleCutReceiver.percent));
            }

            self.bidVault <- bidderFungibleProvider.withdraw(amount: bidPrice)

            StarlyCardBidV3.totalCount = StarlyCardBidV3.totalCount + (1 as UInt64)

            emit StarlyCardBidCreated(
                bidID: self.id,
                nftID: self.nftID,
                starlyID: self.starlyID,
                bidPrice: self.bidPrice,
                bidVaultType: self.bidVaultType.identifier,
                bidderAddress: self.bidderAddress,
                beneficiarySaleCut: StarlyCardMarket.SaleCut(
                    address: self.beneficiarySaleCutReceiver.receiver.address,
                    amount: beneficiaryCutAmount,
                    percent: self.beneficiarySaleCutReceiver.percent),
                creatorSaleCut: StarlyCardMarket.SaleCut(
                    address: self.creatorSaleCutReceiver.receiver.address,
                    amount: creatorCutAmount,
                    percent: self.creatorSaleCutReceiver.percent),
                additionalSaleCuts: additionalSaleCuts
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
        pub fun insert(bid: @StarlyCardBidV3.Bid)
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
            sellerMarketCollection: &StarlyCardMarket.Collection,
            cardStakeId: UInt64?)

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

        pub fun insert(bid: @StarlyCardBidV3.Bid) {
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
            sellerMarketCollection: &StarlyCardMarket.Collection,
            cardStakeId: UInt64?
        ) {
            let bid <- self.remove(bidID: bidID)
            bid.accept(
                bidderCardCollection: bidderCardCollection,
                sellerFungibleReceiver: sellerFungibleReceiver,
                sellerCardCollection: sellerCardCollection,
                sellerStakedCardCollection: sellerStakedCardCollection,
                sellerMarketCollection: sellerMarketCollection,
                cardStakeId: cardStakeId
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
        bidderFungibleProvider: &AnyResource{FungibleToken.Provider},
        beneficiarySaleCutReceiver: StarlyCardMarket.SaleCutReceiverV2,
        creatorSaleCutReceiver: StarlyCardMarket.SaleCutReceiverV2,
        minterSaleCutReceiver: StarlyCardMarket.SaleCutReceiverV2,
    ): @Bid {
        let parsedStarlyID = StarlyIDParser.parse(starlyID: starlyID)
        let collectionID = parsedStarlyID.collectionID
        let starlyRoyalty = StarlyRoyalties.getStarlyRoyalty()
        let collectionRoyalty = StarlyRoyalties.getCollectionRoyalty(collectionID: collectionID)
            ?? panic("Could not get creator royalty")
        let minterRoyalty = StarlyRoyalties.getMinterRoyalty(collectionID: collectionID, starlyID: starlyID)
            ?? panic("Could not get minter royalty")

        assert(beneficiarySaleCutReceiver.receiver.address == starlyRoyalty.address, message: "Incorrect Starly royalty address")
        assert(creatorSaleCutReceiver.receiver.address == collectionRoyalty.address, message: "Incorrect creator royalty address")
        assert(minterSaleCutReceiver.receiver.address == minterRoyalty.address, message: "Incorrect minter royalty address")

        assert(beneficiarySaleCutReceiver.percent == starlyRoyalty.cut, message: "Incorrect Starly royalty percent")
        assert(creatorSaleCutReceiver.percent == collectionRoyalty.cut, message: "Incorrect creator royalty percent")
        assert(minterSaleCutReceiver.percent == minterRoyalty.cut, message: "Incorrect minter royalty percent")

        return <- create Bid(
            nftID: nftID,
            starlyID: starlyID,
            bidPrice: bidPrice,
            bidVaultType: bidVaultType,
            bidderAddress: bidderAddress,
            bidderFungibleReceiver: bidderFungibleReceiver,
            bidderFungibleProvider: bidderFungibleProvider,
            beneficiarySaleCutReceiver: beneficiarySaleCutReceiver,
            creatorSaleCutReceiver: creatorSaleCutReceiver,
            additionalSaleCutReceivers: [minterSaleCutReceiver],
        )
    }

    pub fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    init() {
        self.totalCount = 0
        self.CollectionStoragePath = /storage/starlyCardBidV3Collection
        self.CollectionPublicPath = /public/starlyCardBidV3Collection
    }
}
