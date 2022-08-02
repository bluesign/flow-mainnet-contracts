import NonFungibleToken from 0xa8d493db1bb4df56
import SolarpupsNFT from 0xa8d493db1bb4df56
import FungibleToken from 0xf233dcee88fe0abe
import FlowToken from 0x1654653399040a61

/*
 * This contract is used to realize all kind of market sell activities within Solarpups.
 * The market supports direct payments for custom assets. A SolarpupsCredit is used for
 * all market activities so a buyer have to exchange his source currency in order to buy something.
 *
 * A market item is a custom asset which is offered by the token holder for sale. These items can either be
 * already minted (list offering) or can be minted on the fly during the payment process handling (lazy offering).
 * Lazy offerings are especially useful to rule a time based drop or an edition based drop with a hard supply cut after the drop.
 *
 * Each payment is divided into different shares for the platform, creator (royalty) and the owner of the asset.
 */
pub contract SolarpupsMarket {
    pub event MarketItemLocked(assetId: String)
    pub event MarketItemUnlocked(assetId: String)
    pub event MarketItemInserted(assetId: String, owner: Address, price: UFix64)
    pub event MarketItemRemoved (assetId: String, owner: Address)
    pub event MarketItemSold(assetId: String, owner: Address, tokenIds: [UInt64])
    pub event MarketItemSoldOut(assetId: String, owner: Address)
    pub event MarketItemPayout(assetId: String, amount: UFix64)

    pub let SolarpupsMarketStorePublicPath:  PublicPath
    pub let SolarpupsMarketAdminStoragePath: StoragePath
    pub let SolarpupsMarketStoreStoragePath: StoragePath
    pub let SolarpupsMarketTokenStoragePath: StoragePath

    access(self) var totalPayments: UInt64

    /**
     * The resource interface definition for all payment implementations.
     * A payment resource is used to buy a Solarpups asset, and it is created
     * by an PaymentExchange resource.
     */
    pub resource Payment {
        pub var amount: UFix64
        pub let paymentVault: @FungibleToken.Vault

        init(vault: @FungibleToken.Vault) {
            SolarpupsMarket.totalPayments = SolarpupsMarket.totalPayments + (1 as UInt64)
            self.paymentVault <- vault as! @FlowToken.Vault
            self.amount = self.paymentVault.balance
        }

        pub fun split(_ amount: UFix64): @Payment {
            pre { amount <= self.amount: "amount must be lower than or equal to payment amount" }
            self.amount = self.amount - amount

            return <- create Payment(vault: <- self.paymentVault.withdraw(amount: amount))
        }

        destroy() {
          destroy self.paymentVault
        }
    }

    /**
     * Resource interface which can be used to read public information about a market item.
     */
    pub resource interface PublicMarketItem {
        pub let assetId:     String
        pub var price:       UFix64
        pub fun getSupply(): Int
        pub fun getLocked(): UInt64
        pub fun getShares(): {Address:UFix64}
    }

    /**
     * Resource interface for all nft offerings on the Solarpups market.
     */
    pub resource interface NFTOffering {
        pub fun provide(): @NonFungibleToken.Collection
        pub fun getSupply(): Int
        pub fun lock()
        pub fun unlock()
        pub fun getReceiver(): Capability<&{FungibleToken.Receiver}>
        pub fun getRoyaltyReceiver(): Capability<&{FungibleToken.Receiver}>
    }

    /**
     * A ListOffering is a nft offering based on a list of already minted NFTs.
     * These NFTs were directly handled out of the owners NFT collection.
     */
    pub resource ListOffering: NFTOffering {
        pub let tokenIds:          [UInt64]
        pub let assetId:           String
        pub var locked:            UInt64
        access(self) let provider: Capability<&{NonFungibleToken.Provider}>
        access(self) let receiver: Capability<&{FungibleToken.Receiver}>
        access(self) let royaltyReceiver: Capability<&{FungibleToken.Receiver}>

        pub fun provide(): @NonFungibleToken.Collection {
            let sourceCollection = self.provider.borrow()!
            let targetCollection <- SolarpupsNFT.createEmptyCollection()
            let tokenId = self.tokenIds.removeFirst()
            let token <- sourceCollection.withdraw(withdrawID: tokenId) as! @SolarpupsNFT.NFT

            assert(token.data.assetId == self.assetId, message: "asset id mismatch")
            targetCollection.deposit(token: <- token)
            return <- targetCollection
        }

        pub fun getReceiver(): Capability<&{FungibleToken.Receiver}> {
          return self.receiver
        }

        pub fun getRoyaltyReceiver(): Capability<&{FungibleToken.Receiver}> {
          return self.royaltyReceiver
        }

        pub fun getSupply(): Int {
            return self.tokenIds.length
        }

        pub fun lock() {
            pre { self.tokenIds.length >= 1: "not enough elements to lock" }
            self.locked = self.locked + (1 as UInt64)
        }

        pub fun unlock() {
            pre { self.locked >= (1 as UInt64): "not enough elements to unlock" }
            self.locked = self.locked - (1 as UInt64)
        }

        init(tokenIds: [UInt64], assetId: String, provider: Capability<&{NonFungibleToken.Provider}>, receiver: Capability<&{FungibleToken.Receiver}>, royaltyReceiver: Capability<&{FungibleToken.Receiver}>) {
            pre {
                provider.borrow() != nil: "Cannot borrow seller"
                tokenIds.length > 0: "token ids must not be empty"
            }
            self.tokenIds = tokenIds
            self.assetId  = assetId
            self.provider = provider
            self.receiver = receiver
            self.royaltyReceiver = royaltyReceiver
            self.locked   = 0
        }
    }

    /**
     * A LazyOffering is a nft offering based on a NFT minter resource which means that these NFTs
     * are going to be minted only after a successful sale.
     */
    pub resource LazyOffering: NFTOffering {
        pub let assetId: String
        pub var locked:  UInt64
        pub let minter:  @SolarpupsNFT.Minter
        access(self) let receiver: Capability<&{FungibleToken.Receiver}>
        access(self) let royaltyReceiver: Capability<&{FungibleToken.Receiver}>

        pub fun provide(): @NonFungibleToken.Collection {
            return <- self.minter.mint(assetId: self.assetId)
        }

        pub fun getReceiver(): Capability<&{FungibleToken.Receiver}> {
          return self.receiver
        }

        pub fun getRoyaltyReceiver(): Capability<&{FungibleToken.Receiver}> {
          return self.royaltyReceiver
        }

        pub fun getSupply(): Int {
            let supply = SolarpupsNFT.getAsset(assetId: self.assetId)?.supply
            let maxSupply = Int(supply!.max)
            let curSupply = Int(supply!.cur)
            return maxSupply - curSupply
        }

        pub fun lock() {
            pre { self.getSupply() >= 1: "not enough elements to lock" }
            self.locked = self.locked + (1 as UInt64)
        }

        pub fun unlock() {
            pre { self.locked >= (1 as UInt64): "not enough elements to unlock" }
            self.locked = self.locked - (1 as UInt64)
        }

        init(assetId: String, minter: @SolarpupsNFT.Minter, receiver: Capability<&{FungibleToken.Receiver}>, royaltyReceiver: Capability<&{FungibleToken.Receiver}>) {
            self.assetId = assetId
            self.minter <- minter
            self.locked  = 0
            self.receiver = receiver
            self.royaltyReceiver = royaltyReceiver
        }

        destroy() {
            destroy self.minter
        }
    }

    /**
     * This resource represents a Solarpups asset for sale and can be offered based on a list of already minted NFT tokens
     * or in a lazy manner where NFTs were only minted after a successful sale. The price of a market item can be changed.
     */
    pub resource MarketItem: PublicMarketItem {
        pub let assetId: String
        pub var price:   UFix64
        pub var locked:  UInt64
        access(self) let shares:  {Address:UFix64}
        access(self) let nftOffering: @{NFTOffering}

        // Returns a boolean value which indicates if the market item is sold out.
        access(contract) fun sell(nftReceiver: &{NonFungibleToken.Receiver}, payment: @Payment): Bool {

            let receiver = self.nftOffering.getReceiver()
            let balance = payment.amount
            let royalty = SolarpupsNFT.getAsset(assetId: self.assetId)?.royalty;
            let royaltyReceiver = self.nftOffering.getRoyaltyReceiver()

            self.emitRoyaltyShare(payment: <- payment.split(balance * UFix64(royalty!)), receiver: royaltyReceiver)
            self.emitDefaultShare(payment: <- payment, receiver: receiver)

            let tokens <- self.nftOffering.provide()
            let ids = tokens.getIDs()

            for key in ids {
                nftReceiver.deposit(token: <-tokens.withdraw(withdrawID: key))
            }
            if (self.owner?.address != nil) {
                let owner = self.owner?.address!
                emit MarketItemSold(assetId: self.assetId, owner: owner, tokenIds: ids)
            }
            destroy tokens

            return self.nftOffering.getSupply() == 0
        }

        access(self) fun emitDefaultShare(payment: @Payment, receiver: Capability<&{FungibleToken.Receiver}>) {
            let balance = payment.amount
            for recipient in self.shares.keys {
                let share <- payment.split(balance * self.shares[recipient]!)
                self.payout(payment: <- share, receiver: receiver)
            }
            assert(payment.amount == 0.0, message: "invalid recipient payments")
            destroy payment
        }

        access(self) fun emitRoyaltyShare(payment: @Payment, receiver: Capability<&{FungibleToken.Receiver}>) {
            let balance = payment.amount
            let creators = SolarpupsNFT.getAsset(assetId: self.assetId)!.creators
            let creatorMap = creators as {Address: UFix64}
            for creatorId in creatorMap.keys {
                let share <- payment.split(balance * creatorMap[creatorId]!)
                self.payout(payment: <- share, receiver: receiver)
            }
            assert(payment.amount == 0.0, message: "invalid royalty payments")
            destroy payment
        }

        access(self) fun payout(payment: @Payment, receiver: Capability<&{FungibleToken.Receiver}>) {
            emit MarketItemPayout(assetId: self.assetId, amount: payment.amount)

            let receiverCapability = receiver.borrow()
            let vault <- payment.paymentVault.withdraw(amount: payment.amount)
            let vaultCopy <- vault
            receiverCapability!.deposit(from: <- vaultCopy)

            destroy payment
        }

        pub fun getSupply(): Int {
            return self.nftOffering.getSupply()
        }

        pub fun lock() {
            self.nftOffering.lock()
            self.locked = self.locked + (1 as UInt64)
            emit MarketItemLocked(assetId: self.assetId)
        }

        pub fun unlock() {
            self.nftOffering.unlock()
            self.locked = self.locked - (1 as UInt64)
            emit MarketItemUnlocked(assetId: self.assetId)
        }

        pub fun getLocked(): UInt64 {
            return self.locked
        }

        pub fun getShares(): {Address:UFix64} {
            return self.shares
        }

        pub fun setPrice(price: UFix64) {
            pre { self.locked == (0 as UInt64): "cannot change price due to locked items" }
            self.price = price
        }

        destroy() {
            assert(self.locked == (0 as UInt64), message: "cannot destroy market item due to locked items")
            destroy self.nftOffering
        }

        init(assetId: String, price: UFix64, nftOffering: @{NFTOffering}, shares: {Address:UFix64}) {
            self.assetId      = assetId
            self.price        = price
            self.nftOffering <- nftOffering
            self.shares       = shares
            self.locked       = 0

            // check if asset is available
            SolarpupsNFT.getAsset(assetId: assetId)

            assert(shares.length > 0, message: "no recipient(s) found")
            var sum:UFix64 = 0.0
            for share in shares.values {
                sum = sum + share
            }
            assert(sum == 1.0, message: "invalid recipient shares")
        }
    }

    pub fun createMarketItem(assetId: String, price: UFix64, nftOffering: @{NFTOffering}, shares: {Address:UFix64}): @MarketItem {
        return <-create MarketItem(assetId: assetId, price: price, nftOffering: <- nftOffering, shares: shares)
    }

    /**
     * This resource interface defines all admin functions of a market store
     */
    pub resource interface MarketStoreAdmin {
        pub fun lock(token: &MarketToken, assetId: String)
        pub fun unlock(token: &MarketToken, assetId: String)
        pub fun lockOffering(token: &MarketToken, assetId: String)
        pub fun unlockOffering(token: &MarketToken, assetId: String)
    }

    /**
     * This resource interface defines all functions of a market store resource used by the market store owner.
     */
    pub resource interface MarketStoreManager {
        pub fun insert(item: @MarketItem)
        pub fun remove(assetId: String): @MarketItem
    }

    /**
     * This resource interface defines all public functions of a market store resource.
     */
    pub resource interface PublicMarketStore {
        pub fun getAssetIds(): [String]
        pub fun borrowMarketItem(assetId: String): &MarketItem{PublicMarketItem}?
        pub fun buy(assetId: String, payment: @Payment, receiver: &{NonFungibleToken.Receiver})
    }

    /**
     * The MarketStore resource is used to collect all market items for sale.
     * Market items can either be directly bought.
     */
    pub resource MarketStore : MarketStoreManager, PublicMarketStore, MarketStoreAdmin {
        pub let items: @{String: MarketItem}
        pub let lockedItems: {String:String}

        pub fun insert(item: @MarketItem) {
            let assetId = item.assetId
            let price = item.price
            let ex = "listing exists for assetId: ".concat(assetId)
            assert(self.items[item.assetId] == nil, message: ex)
            let oldOffer <- self.items[item.assetId] <- item
            destroy oldOffer

            if (self.owner?.address != nil) {
                emit MarketItemInserted(assetId: assetId, owner: self.owner?.address!, price: price)
            }
        }

        pub fun remove(assetId: String): @MarketItem {
            if (self.owner?.address != nil) {
                emit MarketItemRemoved(assetId: assetId, owner: self.owner?.address!)
            }
            return <-(self.items.remove(key: assetId) ?? panic("missing market item"))
        }

        pub fun buy(assetId: String, payment: @Payment, receiver: &{NonFungibleToken.Receiver}) {
            pre {
                self.items[assetId] != nil: "market item not found"
                self.lockedItems[assetId] == nil: "market item is locked"
            }

            let offer = &self.items[assetId] as &MarketItem?
            let offerPrice = offer?.price
            let price = UFix64(offerPrice!) * 1.0

            if (offer == nil) {
              destroy payment
            } else {
              let ex = "payment mismatch: ".concat(payment.amount.toString()).concat(" != ").concat(price.toString())
              assert(payment.amount == price, message: ex)
            let soldOut = offer!.sell(nftReceiver: receiver, payment: <- payment)
              let itemSoldOut = soldOut as! Bool
              if (itemSoldOut) {
                  destroy self.remove(assetId: assetId)
                  if (self.owner?.address != nil) {
                      emit MarketItemSoldOut(assetId: assetId, owner: self.owner?.address!)
                  }
              }
            }
        }

        pub fun lock(token: &MarketToken, assetId: String) {
            self.lockedItems[assetId] = assetId
        }

        pub fun unlock(token: &MarketToken, assetId: String) {
            self.lockedItems.remove(key: assetId)
        }

        pub fun lockOffering(token: &MarketToken, assetId: String) {
            pre { self.items[assetId] != nil: "asset not found" }
            let item = &self.items[assetId] as! &MarketItem?
            item?.lock()
        }

        pub fun unlockOffering(token: &MarketToken, assetId: String) {
            pre { self.items[assetId] != nil: "asset not found" }
            let item = &self.items[assetId] as! &MarketItem?
            item?.unlock()
        }

        pub fun getAssetIds(): [String] {
            return self.items.keys
        }

        pub fun borrowMarketItem(assetId: String): &MarketItem{PublicMarketItem}? {
            if self.items[assetId] == nil { return nil }
            else { return &self.items[assetId] as &MarketItem{PublicMarketItem}? }
        }

        destroy() {
            destroy self.items
        }

        init() {
            self.items <- {}
            self.lockedItems = {}
        }
    }

    pub fun createMarketStore(): @MarketStore {
        return <-create MarketStore()
    }

    pub fun createListOffer(tokenIds: [UInt64], assetId: String, provider: Capability<&{NonFungibleToken.Provider}>, receiver: Capability<&{FungibleToken.Receiver}>, royaltyReceiver: Capability<&{FungibleToken.Receiver}>): @ListOffering {
        return <- create ListOffering(tokenIds: tokenIds, assetId: assetId, provider: provider, receiver: receiver, royaltyReceiver: royaltyReceiver)
    }

    pub fun createLazyOffer(assetId: String, minter: @SolarpupsNFT.Minter, receiver: Capability<&{FungibleToken.Receiver}>, royaltyReceiver: Capability<&{FungibleToken.Receiver}>): @LazyOffering {
        return <- create LazyOffering(assetId: assetId, minter: <- minter, receiver: receiver, royaltyReceiver: royaltyReceiver)
    }

    pub fun createMarketAdmin(): @MarketAdmin {
        return <-create MarketAdmin()
    }

    /**
     * This resource is used by the administrator as an argument of a public function
     * in order to restrict access to that function.
     */
    pub resource MarketToken {}

    /*
     * This resource is the administrator object of the Solarpups market.
     * It can be used to alter the payment mechanisms without redeploying the contract.
     */
    pub resource MarketAdmin {
        pub fun createPayment(vault: @FungibleToken.Vault): @Payment {
            return <- create Payment(vault: <- vault)
        }
    }

    init() {
        self.SolarpupsMarketStorePublicPath  = /public/SolarpupsMarketStoreProd01
        self.SolarpupsMarketAdminStoragePath = /storage/SolarpupsMarketAdminProd01
        self.SolarpupsMarketStoreStoragePath = /storage/SolarpupsMarketStoreProd01
        self.SolarpupsMarketTokenStoragePath = /storage/SolarpupsMarketTokenProd01

        self.totalPayments = 0

        self.account.save(<- create MarketAdmin(), to: self.SolarpupsMarketAdminStoragePath)
        self.account.save(<- create MarketStore(), to: self.SolarpupsMarketStoreStoragePath)
        self.account.save(<- create MarketToken(), to: self.SolarpupsMarketTokenStoragePath)
        self.account.link<&{SolarpupsMarket.PublicMarketStore, SolarpupsMarket.MarketStoreAdmin}>(self.SolarpupsMarketStorePublicPath, target: self.SolarpupsMarketStoreStoragePath)
    }
}
