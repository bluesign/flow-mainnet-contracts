// SPDX-License-Identifier: Unlicense

import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448

pub contract StoreFrontAuction {

    // The total amount of AuctionItems that have been created
    pub var totalAuctions: UInt64

    /// Path where the public capability for the `Collection` is available
    pub let collectionPublicPath: PublicPath

    /// Path where the `Collection` is stored
    pub let collectionStoragePath: StoragePath

    // Events
    pub event AuctionItemsCreated(auctionId: UInt64, nftID: UInt64, startPrice: UFix64, seller: Address?)
    pub event AuctionBidCreated(auctionId: UInt64, bidPrice: UFix64, buyer: Address?)
    pub event AuctionSettled(auctionId: UInt64, price: UFix64)
    pub event AuctionCanceled(auctionId: UInt64)

    // AuctionItem contains the Resources and metadata for a single auction
    pub resource AuctionItem {

        pub(set) var NFT: @NonFungibleToken.NFT?
        pub let bidVault: @FungibleToken.Vault
        pub(set) var meta: ItemMeta

        init(
            NFT: @NonFungibleToken.NFT,
            bidVault: @FungibleToken.Vault,
            meta: ItemMeta
        ) {
            self.NFT <- NFT
            self.bidVault <- bidVault
            self.meta = meta

            StoreFrontAuction.totalAuctions = StoreFrontAuction.totalAuctions + UInt64(1)
        }

        // depositBidTokens deposits the bidder's tokens into the AuctionItem's Vault
        pub fun depositBidTokens(vault: @FungibleToken.Vault) {
            self.bidVault.deposit(from: <-vault)
        }

        // withdrawNFT removes the NFT from the AuctionItem and returns it to the caller
        pub fun withdrawNFT(): @NonFungibleToken.NFT {
            let NFT <- self.NFT <- nil
            return <- NFT!
        }

        // updateRecipientVaultCap updates the bidder's Vault capability, providing the
        // us with a way to return their FungibleTokens
        access(contract) fun updateRecipientVaultCap(cap: Capability<&{FungibleToken.Receiver}>) {
            let meta = self.meta
            meta.recipientVaultCap = cap

            self.meta = meta
        }

        // sendNFT sends the NFT to the Collection belonging to the provided Capability
        access(contract) fun sendNFT(_ capability: Capability<&{NonFungibleToken.CollectionPublic}>) {
            // borrow a reference to the owner's NFT receiver
            if let collectionRef = capability.borrow() {
                let NFT <- self.withdrawNFT()
                // deposit the token into the owner's collection
                collectionRef.deposit(token: <-NFT)
            } else {
                panic("Unable to borrow collection reference")
            }
        }

        // sendBidTokens sends the bid tokens to the Vault Receiver belonging to the provided Capability
        access(contract) fun sendBidTokens(_ capability: Capability<&{FungibleToken.Receiver}>) {
            // borrow a reference to the owner's NFT receiver
            if let vaultRef = capability.borrow() {
                let bidVaultRef = &self.bidVault as &FungibleToken.Vault
                vaultRef.deposit(from: <-bidVaultRef.withdraw(amount: bidVaultRef.balance))
            } else {
                panic("Couldn't get vault reference")
            }
        }

        destroy() {
            // send the NFT back to auction owner
            self.sendNFT(self.meta.ownerCollectionCap)

            // if there's a bidder...
            if let vaultCap = self.meta.recipientVaultCap {
                // ...send the bid tokens back to the bidder
                self.sendBidTokens(vaultCap)
            }

            destroy self.NFT
            destroy self.bidVault
        }
    }

    // ItemMeta contains the metadata for an AuctionItem
    pub struct ItemMeta {

        // Auction Settings
        pub let auctionID: UInt64
        pub let minimumBidIncrement: UFix64

        // Auction State
        pub var startPrice: UFix64
        pub(set) var currentPrice: UFix64
        pub(set) var auctionCompleted: Bool
        pub let finishAtTimestamp: UFix64

        // Recipient's Receiver Capabilities
        pub(set) var recipientCollectionCap: Capability<&{NonFungibleToken.CollectionPublic}>
        pub(set) var recipientVaultCap: Capability<&{FungibleToken.Receiver}>?

        // Owner's Receiver Capabilities
        pub let ownerCollectionCap: Capability<&{NonFungibleToken.CollectionPublic}>
        pub let ownerVaultCap: Capability<&{FungibleToken.Receiver}>

        init(
            minimumBidIncrement: UFix64,
            startPrice: UFix64,
            ownerCollectionCap: Capability<&{NonFungibleToken.CollectionPublic}>,
            ownerVaultCap: Capability<&{FungibleToken.Receiver}>,
            finishAtTimestamp: UFix64
        ) {
            self.auctionID = StoreFrontAuction.totalAuctions + UInt64(1)
            self.minimumBidIncrement = minimumBidIncrement
            self.startPrice = startPrice
            self.currentPrice = startPrice
            self.auctionCompleted = false
            self.recipientCollectionCap = ownerCollectionCap
            self.recipientVaultCap = ownerVaultCap
            self.ownerCollectionCap = ownerCollectionCap
            self.ownerVaultCap = ownerVaultCap
            self.finishAtTimestamp = finishAtTimestamp
        }
    }

    // AuctionPublic is a resource interface that restricts users to
    // retreiving the auction price list and placing bids
    pub resource interface AuctionPublic {
        pub fun getAuctionPrices(): {UInt64: UFix64}
        pub fun placeBid(
            id: UInt64,
            bidTokens: @FungibleToken.Vault,
            vaultCap: Capability<&{FungibleToken.Receiver}>,
            collectionCap: Capability<&{NonFungibleToken.CollectionPublic}>
        )
    }

    // AuctionCollection contains a dictionary of AuctionItems and provides
    // methods for manipulating the AuctionItems
    pub resource AuctionCollection: AuctionPublic {

        // Auction Items
        pub var auctionItems: @{UInt64: AuctionItem}

        init() {
            self.auctionItems <- {}
        }

        // addTokenToauctionItems adds an NFT to the auction items and sets the meta data
        // for the auction item
        pub fun addTokenToAuctionItems(token: @NonFungibleToken.NFT, minimumBidIncrement: UFix64, startPrice: UFix64, bidVault: @FungibleToken.Vault, collectionCap: Capability<&{NonFungibleToken.CollectionPublic}>, vaultCap: Capability<&{FungibleToken.Receiver}>, finishAtTimestamp: UFix64) {

            // create a new auction meta resource
            let meta = ItemMeta(
                minimumBidIncrement: minimumBidIncrement,
                startPrice: startPrice,
                ownerCollectionCap: collectionCap,
                ownerVaultCap: vaultCap,
                finishAtTimestamp: finishAtTimestamp
            )
            let nftID = token.id
            // create a new auction items resource container
            let item <- create AuctionItem(
                NFT: <-token,
                bidVault: <-bidVault,
                meta: meta
            )

            let id = item.meta.auctionID

            // update the auction items dictionary with the new resources
            let oldItem <- self.auctionItems[id] <- item
            destroy oldItem

            emit AuctionItemsCreated(auctionId: id, nftID: nftID, startPrice: startPrice, seller: collectionCap.borrow()!.owner?.address)
        }

        // getAuctionPrices returns a dictionary of available NFT IDs with their current price
        pub fun getAuctionPrices(): {UInt64: UFix64} {
            pre {
                self.auctionItems.keys.length > 0: "There are no auction items"
            }

            let priceList: {UInt64: UFix64} = {}

            for id in self.auctionItems.keys {
                let itemRef = (&self.auctionItems[id] as? &AuctionItem?)!
                if itemRef.meta.auctionCompleted == false {
                    priceList[id] = itemRef.meta.currentPrice
                }
            }

            return priceList
        }

        // settleAuction sends the auction item to the highest bidder
        // and deposits the FungibleTokens into the auction owner's account
        pub fun settleAuction(_ id: UInt64) {
            let itemRef = (&self.auctionItems[id] as &AuctionItem?)!
            let itemMeta = itemRef.meta

            if itemMeta.auctionCompleted {
                panic("This auction is already settled")
            }

            if itemRef.NFT == nil {
                panic("Auction doesn't exist")
            }

            // return if there are no bids to settle
            if itemMeta.currentPrice == itemMeta.startPrice {
                self.returnAuctionItemToOwner(id)
                log("No bids. Nothing to settle")
                return
            }

            self.exchangeTokens(id)

            itemMeta.auctionCompleted = true

            emit AuctionSettled(auctionId: id, price: itemMeta.currentPrice)

            if let item <- self.auctionItems.remove(key: id) {
                item.meta = itemMeta
                self.auctionItems[id] <-! item
            }
        }

        // exchangeTokens sends the purchased NFT to the buyer and the bidTokens to the seller
        pub fun exchangeTokens(_ id: UInt64) {

            let itemRef = (&self.auctionItems[id] as &AuctionItem?)!

            if itemRef.NFT == nil {
                panic("Auction doesn't exist")
            }

            let itemMeta = itemRef.meta

            itemRef.sendNFT(itemMeta.recipientCollectionCap)
            itemRef.sendBidTokens(itemMeta.ownerVaultCap)
        }

        // placeBid sends the bidder's tokens to the bid vault and updates the
        // currentPrice of the current auction item
        pub fun placeBid(id: UInt64, bidTokens: @FungibleToken.Vault, vaultCap: Capability<&{FungibleToken.Receiver}>, collectionCap: Capability<&{NonFungibleToken.CollectionPublic}>)
            {
            pre {
                self.auctionItems[id] != nil:
                    "NFT doesn't exist"
            }

            // Get the auction item resources
            let itemRef = (&self.auctionItems[id] as &AuctionItem?)!
            let itemMeta = itemRef.meta

            if itemMeta.auctionCompleted {
                panic("auction has already completed")
            }

            if (bidTokens.balance - itemMeta.currentPrice) < itemMeta.minimumBidIncrement {
                panic("bid amount be larger than minimum bid increment")
            }

            if itemMeta.finishAtTimestamp < getCurrentBlock().timestamp {
                panic("auction is not available")
            }

            if itemRef.bidVault.balance != UFix64(0) {
                if let vaultCap = itemMeta.recipientVaultCap {
                    itemRef.sendBidTokens(itemMeta.recipientVaultCap!)
                } else {
                    panic("unable to get recipient Vault capability")
                }
            }

            // Update the auction item
            itemRef.depositBidTokens(vault: <-bidTokens)
            itemRef.updateRecipientVaultCap(cap: vaultCap)

            // Update the current price of the token
            itemMeta.currentPrice = itemRef.bidVault.balance

            // Add the bidder's Vault and NFT receiver references
            itemMeta.recipientCollectionCap = collectionCap

            itemRef.meta = itemMeta

            emit AuctionBidCreated(auctionId: id, bidPrice: itemMeta.currentPrice, buyer: collectionCap.borrow()!.owner?.address)
        }

        // releasePreviousBid returns the outbid user's tokens to
        // their vault receiver
        pub fun releasePreviousBid(_ id: UInt64) {
            // get a reference to the auction items resources
            let itemRef = (&self.auctionItems[id] as &AuctionItem?)!
            let itemMeta = itemRef.meta
            // release the bidTokens from the vault back to the bidder
            if let vaultCap = itemMeta.recipientVaultCap {
                itemRef.sendBidTokens(itemMeta.recipientVaultCap!)
            } else {
                log("unable to get vault capability")
            }
        }

        // returnAuctionItemToOwner releases any bids and returns the NFT
        // to the owner's Collection
        pub fun returnAuctionItemToOwner(_ id: UInt64) {
            let itemRef = (&self.auctionItems[id] as &AuctionItem?)!
            let itemMeta = itemRef.meta

            // release the bidder's tokens
            self.releasePreviousBid(id)

            // clear the NFT's meta data
            let oldItem <- self.auctionItems[id] <- nil
            destroy oldItem
        }

        // cancel auction and returns the NFT to the owner's Collection
        pub fun cancelAndReturnAuctionItemToOwner(_ id: UInt64) {
            self.returnAuctionItemToOwner(id)

            emit AuctionCanceled(auctionId: id)
        }

        destroy() {
            for id in self.auctionItems.keys {
                self.returnAuctionItemToOwner(id)
            }
            // destroy the empty resources
            destroy self.auctionItems
        }
    }

    // createAuctionCollection returns a new AuctionCollection resource to the caller
    pub fun createAuctionCollection(): @AuctionCollection {
        let auctionCollection <- create AuctionCollection()
        return <- auctionCollection
    }

    init() {
        self.totalAuctions = UInt64(0)
        self.collectionPublicPath = /public/StoreFrontAuctionCollection0xd953a7bdc5e2f7f0
        self.collectionStoragePath = /storage/StoreFrontAuctionCollection0xd953a7bdc5e2f7f0
    }
}
