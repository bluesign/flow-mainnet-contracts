// Black Hunter's Market
// Yosh! -swt
//
//
import FungibleToken from 0xf233dcee88fe0abe
import FUSD from 0x3c5959b568896393
import NonFungibleToken from 0x1d7e57aa55817448 
import NFTDayTreasureChest from 0x117396d8a72ad372

pub contract BlackMarketplace {

    // -----------------------------------------------------------------------
    // BlackMarketplace Events
    // -----------------------------------------------------------------------
    pub event ForSale(id: UInt64, price: UFix64)
    pub event PriceChanged(id: UInt64, newPrice: UFix64)
    pub event TokenPurchased(id: UInt64, price: UFix64, from:Address, to:Address)
    pub event RoyaltyPaid(id:UInt64, amount: UFix64, to:Address, name:String)
    pub event SaleWithdrawn(id: UInt64)

    // -----------------------------------------------------------------------
    // Named Paths
    // -----------------------------------------------------------------------
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    pub let marketplaceWallet: Capability<&FUSD.Vault{FungibleToken.Receiver}>
    access(contract) var whitelistUsed: [Address]
    access(contract) var sellers: [Address]

    pub resource interface SalePublic {
        pub fun purchaseWithWhitelist(tokenID: UInt64, recipientCap: Capability<&{NFTDayTreasureChest.NFTDayTreasureChestCollectionPublic}>, buyTokens: @FungibleToken.Vault)
        pub fun purchaseWithTreasureChest(tokenID: UInt64, recipientCap: Capability<&{NFTDayTreasureChest.NFTDayTreasureChestCollectionPublic}>, buyTokens: @FungibleToken.Vault, chest: @NFTDayTreasureChest.NFT): @NFTDayTreasureChest.NFT
        pub fun idPrice(tokenID: UInt64): UFix64?
        pub fun getIDs(): [UInt64]
    }

    pub resource SaleCollection: SalePublic {

        access(self) var forSale: @{UInt64: NFTDayTreasureChest.NFT}

        access(self) var prices: {UInt64: UFix64}

        access(account) let ownerVault: Capability<&AnyResource{FungibleToken.Receiver}>

        init (vault: Capability<&AnyResource{FungibleToken.Receiver}>) {
            self.forSale <- {}
            self.ownerVault = vault
            self.prices = {}
        }

        pub fun withdraw(tokenID: UInt64): @NFTDayTreasureChest.NFT {
            self.prices.remove(key: tokenID)
            let token <- self.forSale.remove(key: tokenID) ?? panic("missing NFT")
            emit SaleWithdrawn(id: tokenID)
            return <-token
        }

        pub fun listForSale(token: @NFTDayTreasureChest.NFT, price: UFix64) {
            let id = token.id

            self.prices[id] = price

            let oldToken <- self.forSale[id] <- token
            destroy oldToken

            if !BlackMarketplace.sellers.contains(self.owner!.address) {
                BlackMarketplace.sellers.append(self.owner!.address)
            }

            emit ForSale(id: id, price: price)
        }

        pub fun changePrice(tokenID: UInt64, newPrice: UFix64) {
            self.prices[tokenID] = newPrice

            emit PriceChanged(id: tokenID, newPrice: newPrice)
        }

        // Requires a whitelist to purchase
        pub fun purchaseWithWhitelist(tokenID: UInt64, recipientCap: Capability<&{NFTDayTreasureChest.NFTDayTreasureChestCollectionPublic}>, buyTokens: @FungibleToken.Vault) {
            pre {
                self.forSale[tokenID] != nil && self.prices[tokenID] != nil:
                    "No token matching this ID for sale!"
                buyTokens.balance >= (self.prices[tokenID] ?? 0.0):
                    "Not enough tokens to by the NFT!"
                !BlackMarketplace.whitelistUsed.contains(recipientCap.borrow()!.owner!.address): 
                    "Cannot purchase: Whitelist used"
                NFTDayTreasureChest.getWhitelist().contains(recipientCap.borrow()!.owner!.address): 
                "Cannot purchase: Must be whitelisted"
            }

            let recipient=recipientCap.borrow()!

            let price = self.prices[tokenID]!
            
            self.prices[tokenID] = nil

            let vaultRef = self.ownerVault.borrow()
                ?? panic("Could not borrow reference to owner token vault")
            
            let token <-self.withdraw(tokenID: tokenID)

            let marketplaceWallet = BlackMarketplace.marketplaceWallet.borrow()!
            let marketplaceFee = price * 0.05 // 5% marketplace cut
            marketplaceWallet.deposit(from: <-buyTokens.withdraw(amount: marketplaceFee))

            emit RoyaltyPaid(id: tokenID, amount:marketplaceFee, to: marketplaceWallet.owner!.address, name: "Marketplace")

            vaultRef.deposit(from: <-buyTokens)

            recipient.deposit(token: <- token)

            BlackMarketplace.whitelistUsed.append(recipient.owner!.address)

            emit TokenPurchased(id: tokenID, price: price, from: vaultRef.owner!.address, to:  recipient.owner!.address)
        }

        // Requires a chest to purchase
        pub fun purchaseWithTreasureChest(tokenID: UInt64, recipientCap: Capability<&{NFTDayTreasureChest.NFTDayTreasureChestCollectionPublic}>, buyTokens: @FungibleToken.Vault, chest: @NFTDayTreasureChest.NFT): @NFTDayTreasureChest.NFT {
            pre {
                self.forSale[tokenID] != nil && self.prices[tokenID] != nil:
                    "No token matching this ID for sale!"
                buyTokens.balance >= (self.prices[tokenID] ?? 0.0):
                    "Not enough tokens to by the NFT!"
            }

            let recipient=recipientCap.borrow()!

            let price = self.prices[tokenID]!
            
            self.prices[tokenID] = nil

            let vaultRef = self.ownerVault.borrow()
                ?? panic("Could not borrow reference to owner token vault")
            
            let token <-self.withdraw(tokenID: tokenID)

            let marketplaceWallet = BlackMarketplace.marketplaceWallet.borrow()!
            let marketplaceFee = price * 0.05 // 5% marketplace cut
            marketplaceWallet.deposit(from: <-buyTokens.withdraw(amount: marketplaceFee))

            emit RoyaltyPaid(id: tokenID, amount:marketplaceFee, to: marketplaceWallet.owner!.address, name: "Marketplace")

            vaultRef.deposit(from: <-buyTokens)

            recipient.deposit(token: <- token)

            emit TokenPurchased(id: tokenID, price: price, from: vaultRef.owner!.address, to:  recipient.owner!.address)

            return <-chest
        }

        pub fun idPrice(tokenID: UInt64): UFix64? {
            return self.prices[tokenID]
        }

        pub fun getIDs(): [UInt64] {
            return self.forSale.keys
        }

        destroy() {
            destroy self.forSale
        }
    }

    pub fun createSaleCollection(ownerVault: Capability<&{FungibleToken.Receiver}>): @SaleCollection {
        return <- create SaleCollection(vault: ownerVault)
    }

    pub fun getWhitelistUsed(): [Address] {
        return self.whitelistUsed
    }

    pub fun getSellers(): [Address] {
        return self.sellers
    }

    init() {
        self.CollectionStoragePath = /storage/BasicBeastsBlackMarketplace
        self.CollectionPublicPath = /public/BasicBeastsBlackMarketplace

        if self.account.borrow<&FUSD.Vault>(from: /storage/fusdVault) == nil {
            // Create a new FUSD Vault and put it in storage
            self.account.save(<-FUSD.createEmptyVault(), to: /storage/fusdVault)

            // Create a public capability to the Vault that only exposes
            // the deposit function through the Receiver interface
            self.account.link<&FUSD.Vault{FungibleToken.Receiver}>(
                /public/fusdReceiver,
                target: /storage/fusdVault
            )

            // Create a public capability to the Vault that only exposes
            // the balance field through the Balance interface
            self.account.link<&FUSD.Vault{FungibleToken.Balance}>(
                /public/fusdBalance,
                target: /storage/fusdVault
            )
        }

        self.marketplaceWallet = self.account.getCapability<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdReceiver)
        self.whitelistUsed = []
        self.sellers = []
        
    }
}
 