import VictoryNFTCollectionItem from 0x91960a2ca966a13e
import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448

/*
    This is a VictoryNFTCollectionItem sale contract for the DApp to use
    in order to list and sell VictoryNFTCollectionItem.

    It allows:
    - Anyone to create Sale Offers and place them in a collection, making it
      publicly accessible.
    - Anyone to accept the offer and buy the item.

 */

pub contract VictoryNFTCollectionStorefront {
    // SaleOffer events.
    //
    // A sale offer has been created.
    pub event SaleOfferCreated(seller: Address, bundleID: UInt64, saleType: UInt8, price: UFix64, startTime: UInt32, endTime: UInt32, targetPrice: UFix64)
    // Someone has purchased an item that was offered for sale.
    pub event SaleOfferAccepted(seller: Address, bundleID: UInt64)
    // A sale offer has been destroyed, with or without being accepted.
    pub event SaleOfferFinished(seller: Address, bundleID: UInt64)
    
    // Collection events.
    //
    // A sale offer has been removed from the collection of Address.
    pub event CollectionRemovedSaleOffer(bundleID: UInt64, owner: Address)
    // A sale offer has had its price raised.
    pub event CollectionPriceRaised(bundleID: UInt64, price: UFix64, bidder: Address)
    // A sale offer has been inserted into the collection of owner.
    pub event CollectionInsertedSaleOffer(
      bundleID: UInt64,
      owner: Address, 
      price: UFix64,
      saleType: UInt8,
      startTime: UInt32,
      endTime: UInt32,
      targetPrice: UFix64
    )

    // Named paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    // SaleOfferPublicView
    // An interface providing a read-only view of a SaleOffer
    //
    pub resource interface SaleOfferPublicView {
        pub var saleCompleted: Bool
        pub let bundleID: UInt64
        pub let itemIDs: [UInt64]
        pub var price: UFix64
        pub let saleType: UInt8
        pub let startTime: UInt32
        pub let endTime: UInt32
        pub let targetPrice: UFix64
        pub let royaltyFactor: UFix64
        pub let originalOwner: Address
        pub let seller: Address
        pub var winner: Address
    }

    // SaleOffer
    // A bundle of VictoryNFTCollectionItem NFTs being offered to sale for a set fee paid in Flow.
    //
    pub resource SaleOffer: SaleOfferPublicView {
        // Whether the sale has completed with someone purchasing the item.
        pub var saleCompleted: Bool

        // The ID for the bundle
        pub let bundleID: UInt64

        // The VictoryNFTCollectionItem NFT IDs for sale.
        pub let itemIDs: [UInt64]

        // The sale payment price.
        pub var price: UFix64

        // The sale type
        pub let saleType: UInt8

        // The time to start the sale
        pub let startTime: UInt32

        // The time of the end of the sale
        pub let endTime: UInt32

        // The sale target price.
        pub let targetPrice: UFix64

        // The royalty factor for the sale
        pub let royaltyFactor: UFix64

        // The original owner of the item(s)
        pub let originalOwner: Address

        // The seller of the item(s)
        pub let seller: Address

        // The (current) winner of the item(s)
        pub var winner: Address

        // The collection containing the IDs.
        access(self) let sellerItemProvider: Capability<&VictoryNFTCollectionItem.Collection{NonFungibleToken.Provider}>

        // The Flow vault that will receive the payment if the sale completes successfully.
        access(self) let sellerPaymentReceiver: Capability<&{FungibleToken.Receiver}>

        // The Flow vault that will receive royalty from the payment if the sale completes successfully.
        access(self) let royaltyPaymentReceiver: Capability<&{FungibleToken.Receiver}>

        // Called by a purchaser to accept the sale offer.
        // If they send the correct payment, and if the item is still available,
        // the VictoryNFTCollectionItem NFT will be placed in their VictoryNFTCollectionItem.Collection.
        //
        // Also called when an auction end time is reached to complete the transaction with the highest bidder
        // NOTE: need to take action if buyer does not have sufficient funds
        //
        pub fun accept(
            buyerCollection: &VictoryNFTCollectionItem.Collection{NonFungibleToken.Receiver},
            buyerPayment: @FungibleToken.Vault,
            ownerPaymentReceiver: Capability<&{FungibleToken.Receiver}>
        ) {
            pre {
                buyerPayment.balance == self.price: "payment does not equal offer price"
                self.saleCompleted == false: "the sale offer has already been accepted"
            }

            self.saleCompleted = true

            // if owner == original owner then transfer royalty to royalty receiver
            if (self.seller == self.originalOwner) {
                let royaltyPayment <- buyerPayment.withdraw(amount: self.price * self.royaltyFactor)
                self.royaltyPaymentReceiver.borrow()!.deposit(from: <- royaltyPayment)
            }
            // else transfer royalty to original owner + royalty receiver
            else {
                let royaltyPayment <- buyerPayment.withdraw(amount: self.price * self.royaltyFactor)
                self.royaltyPaymentReceiver.borrow()!.deposit(from: <- royaltyPayment)
        
                let ownerPayment <- buyerPayment.withdraw(amount: self.price * self.royaltyFactor)
                ownerPaymentReceiver.borrow()!.deposit(from: <- ownerPayment)
            }

            // deposit remainder in the seller's vault
            self.sellerPaymentReceiver.borrow()!.deposit(from: <-buyerPayment)

            // withdraw NFTs from the seller and deposit them for the buyer
            var i: Int = 0;
            while i < self.itemIDs.length {
                let nft <- self.sellerItemProvider.borrow()!.withdraw(withdrawID: self.itemIDs[i])
                buyerCollection.deposit(token: <-nft)
                i = i + 1
            }

            // emit an event
            emit SaleOfferAccepted(seller: self.seller, bundleID: self.bundleID)
        }

        // Called by a bidder to raise the bid on a sale offer.
        //
        pub fun raisePrice(
            newPrice: UFix64,
            bidder: Address
        ) {
            pre {
                // price can only go up unless this is the very first bid
                newPrice > self.price || ((newPrice == self.price) && (self.seller == self.winner)): "price can only go up"
                self.saleCompleted == false: "the sale offer has already been accepted"
            }

            self.price = newPrice
            self.winner = bidder
        }

        // destructor
        //
        destroy() {
            // Whether the sale completed or not, publicize that it is being withdrawn.
            emit SaleOfferFinished(seller: self.seller, bundleID: self.bundleID)
        }

        // initializer
        // Take the information required to create a sale offer, notably the capability
        // to transfer the VictoryNFTCollectionItem NFT and the capability to receive Flow in payment.
        //
        init(
            sellerItemProvider: Capability<&VictoryNFTCollectionItem.Collection{NonFungibleToken.Provider, VictoryNFTCollectionItem.VictoryNFTCollectionItemCollectionPublic}>,
            bundleID: UInt64,
            sellerPaymentReceiver: Capability<&{FungibleToken.Receiver}>,
            price: UFix64,
            saleType: UInt8,
            startTime: UInt32,
            endTime: UInt32,
            targetPrice: UFix64,
            royaltyPaymentReceiver: Capability<&{FungibleToken.Receiver}>,
            royaltyFactor: UFix64
        ) {
            pre {
                sellerItemProvider.borrow() != nil: "Cannot borrow seller"
                sellerPaymentReceiver.borrow() != nil: "Cannot borrow sellerPaymentReceiver"
                royaltyPaymentReceiver.borrow() != nil: "Cannot borrow royaltyPaymentReceiver"
                royaltyFactor < 1.0: "Royalty factor cannot be greater than 100%"
            }

            // initialize
            self.saleCompleted = false

            // store the bundle ID
            self.bundleID = bundleID

            // make sure the item ID list is valid
            let collectionRef = sellerItemProvider.borrow()!
            let itemIDs = collectionRef.getBundleIDs(bundleID: bundleID)
            var i: Int = 0;
            while i < itemIDs.length {
                assert(
                    collectionRef.borrowVictoryItem(id: itemIDs[i]) != nil,
                    message: "Specified NFT is not available in the owner's collection"
                )
                i = i + 1
            }

            // assume all the items are owned by the same owner
            let firstNFT = collectionRef.borrowVictoryItem(id: itemIDs[0])
            self.originalOwner = firstNFT!.originalOwner
            self.seller = firstNFT!.owner!.address
            self.sellerItemProvider = sellerItemProvider

            // store the item IDs
            i = 0;
            self.itemIDs = []
            while i < itemIDs.length {
                self.itemIDs.append(itemIDs[i])
                i = i + 1
            }

            // store various other details of the offer
            self.sellerPaymentReceiver = sellerPaymentReceiver
            self.price = price
            self.saleType = saleType
            self.startTime = startTime
            self.endTime = endTime
            self.targetPrice = targetPrice
            self.royaltyPaymentReceiver = royaltyPaymentReceiver
            self.royaltyFactor = royaltyFactor

            // initialize winner to be the seller
            self.winner = self.seller

            // emit an event
            emit SaleOfferCreated(seller: self.seller,
                                  bundleID: self.bundleID, 
                                  saleType: self.saleType, 
                                  price: self.price, 
                                  startTime: self.startTime, 
                                  endTime: self.endTime, 
                                  targetPrice: self.targetPrice)
        }
    }

    // CollectionManager
    // An interface for adding and removing SaleOffers to a collection, intended for
    // use by the collection's owner.
    //
    pub resource interface CollectionManager {
        pub fun createSaleOffer (
                sellerItemProvider: Capability<&VictoryNFTCollectionItem.Collection{NonFungibleToken.Provider, VictoryNFTCollectionItem.VictoryNFTCollectionItemCollectionPublic}>,
                bundleID: UInt64,
                sellerPaymentReceiver: Capability<&{FungibleToken.Receiver}>,
                price: UFix64,
                saleType: UInt8,
                startTime: UInt32,
                endTime: UInt32,
                targetPrice: UFix64,
                royaltyPaymentReceiver: Capability<&{FungibleToken.Receiver}>,
                royaltyFactor: UFix64
            ): @SaleOffer 
        pub fun insert(offer: @VictoryNFTCollectionStorefront.SaleOffer)
        pub fun remove(bundleID: UInt64): @SaleOffer 
    }

    // CollectionPurchaser
    // An interface to allow purchasing items via SaleOffers in a collection.
    // This function is also provided by CollectionPublic, it is here to support
    // more fine-grained access to the collection for as yet unspecified future use cases.
    //
    pub resource interface CollectionPurchaser {
        pub fun purchase(
            bundleID: UInt64,
            buyerCollection: &VictoryNFTCollectionItem.Collection{NonFungibleToken.Receiver},
            buyerPayment: @FungibleToken.Vault,
            ownerPaymentReceiver: Capability<&{FungibleToken.Receiver}>
        )
    }

    // CollectionPublic
    // An interface to allow listing and borrowing SaleOffers, and purchasing items via SaleOffers in a collection.
    //
    pub resource interface CollectionPublic {
        pub fun getSaleOfferIDs(): [UInt64]
        pub fun borrowSaleItem(bundleID: UInt64): &SaleOffer{SaleOfferPublicView}?
        pub fun placeBid(
            bundleID: UInt64, 
            bidPrice: UFix64, 
            bidder: Address
        )
        pub fun purchase(
            bundleID: UInt64,
            buyerCollection: &VictoryNFTCollectionItem.Collection{NonFungibleToken.Receiver},
            buyerPayment: @FungibleToken.Vault,
            ownerPaymentReceiver: Capability<&{FungibleToken.Receiver}>
        )
   }

    // Collection
    // A resource that allows its owner to manage a list of SaleOffers, and purchasers to interact with them.
    //
    pub resource Collection : CollectionManager, CollectionPurchaser, CollectionPublic {
        pub var saleOffers: @{UInt64: SaleOffer}

        // createSaleOffer
        // Make creating a SaleOffer publicly accessible.
        //
        pub fun createSaleOffer (
            sellerItemProvider: Capability<&VictoryNFTCollectionItem.Collection{NonFungibleToken.Provider, VictoryNFTCollectionItem.VictoryNFTCollectionItemCollectionPublic}>,
            bundleID: UInt64,
            sellerPaymentReceiver: Capability<&{FungibleToken.Receiver}>,
            price: UFix64,
            saleType: UInt8,
            startTime: UInt32,
            endTime: UInt32,
            targetPrice: UFix64,
            royaltyPaymentReceiver: Capability<&{FungibleToken.Receiver}>,
            royaltyFactor: UFix64
        ): @SaleOffer {
            return <-create SaleOffer(
                sellerItemProvider: sellerItemProvider,
                bundleID: bundleID,
                sellerPaymentReceiver: sellerPaymentReceiver,
                price: price,
                saleType: saleType,
                startTime: startTime,
                endTime: endTime,
                targetPrice: targetPrice,
                royaltyPaymentReceiver: royaltyPaymentReceiver,
                royaltyFactor: royaltyFactor
            )
        }

        // insert
        // Insert a SaleOffer into the collection, replacing one with the same itemID if present.
        //
         pub fun insert(offer: @VictoryNFTCollectionStorefront.SaleOffer) {
            let bundleID: UInt64 = offer.bundleID
            let owner: Address = offer.originalOwner
            let price: UFix64 = offer.price
            let saleType: UInt8 = offer.saleType
            let startTime: UInt32 = offer.startTime
            let endTime: UInt32 = offer.endTime
            let targetPrice: UFix64 = offer.targetPrice

            // add the new offer to the dictionary which removes the old one
            let oldOffer <- self.saleOffers[bundleID] <- offer
            destroy oldOffer

            emit CollectionInsertedSaleOffer(
              bundleID: bundleID,
              owner: self.owner?.address!,
              price: price,
              saleType: saleType,
              startTime: startTime,
              endTime: endTime,
              targetPrice: targetPrice
            )
        }

        // remove
        // Remove and return a SaleOffer from the collection.
        pub fun remove(bundleID: UInt64): @SaleOffer {
            emit CollectionRemovedSaleOffer(bundleID: bundleID, owner: self.owner?.address!)
            return <-(self.saleOffers.remove(key: bundleID) ?? panic("missing SaleOffer"))
        }
 
        // purchase
        // If the caller passes a valid itemID and the item is still for sale, and passes a Flow vault
        // typed as a FungibleToken.Vault (Flow.deposit() handles the type safety of this)
        // containing the correct payment amount, this will transfer the VictoryItem to the caller's
        // VictoryNFTCollectionItem collection.
        // It will then remove and destroy the offer.
        // Note that is means that events will be emitted in this order:
        //   1. Collection.CollectionRemovedSaleOffer
        //   2. VictoryNFTCollectionItem.Withdraw
        //   3. VictoryNFTCollectionItem.Deposit
        //   4. SaleOffer.SaleOfferFinished
        //
        pub fun purchase(
            bundleID: UInt64,
            buyerCollection: &VictoryNFTCollectionItem.Collection{NonFungibleToken.Receiver},
            buyerPayment: @FungibleToken.Vault,
            ownerPaymentReceiver: Capability<&{FungibleToken.Receiver}>
        ) {
            pre {
                self.saleOffers[bundleID] != nil: "SaleOffer does not exist in the collection!"
            }
            let offer <- self.remove(bundleID: bundleID)
            offer.accept(buyerCollection: buyerCollection, buyerPayment: <-buyerPayment, ownerPaymentReceiver: ownerPaymentReceiver)
            destroy offer
        }

        // placeBid
        // Accept a bid on a bundle from a specified potential buyer.
        pub fun placeBid(
            bundleID: UInt64,
            bidPrice: UFix64,
            bidder: Address
        ) {
            pre {
                self.saleOffers[bundleID] != nil: "SaleOffer does not exist in the collection!"
            }
            // remove the offer so we can change it
            let offer <- self.saleOffers.remove(key: bundleID)!
            // raise the price
            offer.raisePrice(newPrice: bidPrice, bidder: bidder)
            // restore the offer
            self.saleOffers[bundleID] <-! offer

            // emit an event
            emit CollectionPriceRaised(
              bundleID: bundleID,
              price: bidPrice,
              bidder: bidder
            )
        }

        // getSaleOfferIDs
        // Returns an array of the IDs that are in the collection
        //
        pub fun getSaleOfferIDs(): [UInt64] {
            return self.saleOffers.keys
        }

        // borrowSaleItem
        // Returns an Optional read-only view of the SaleItem for the given itemID if it is contained by this collection.
        // The optional will be nil if the provided itemID is not present in the collection.
        //
        pub fun borrowSaleItem(bundleID: UInt64): &SaleOffer{SaleOfferPublicView}? {
            if self.saleOffers[bundleID] == nil {
                return nil
            } else {
                return &self.saleOffers[bundleID] as &SaleOffer{SaleOfferPublicView}
            }
        }

        // destructor
        //
        destroy () {
            destroy self.saleOffers
        }

        // constructor
        //
        init () {
            self.saleOffers <- {}
        }
    }

    // createEmptyCollection
    // Make creating a Collection publicly accessible.
    //
    pub fun createEmptyCollection(): @Collection {
        return <-create Collection()
    }

    init () {
        self.CollectionStoragePath = /storage/VictoryNFTCollectionStorefrontCollection
        self.CollectionPublicPath = /public/VictoryNFTCollectionStorefrontCollection
    }
}
