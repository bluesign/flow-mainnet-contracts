// SPDX-License-Identifier: Unlicense

import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import ARTIFACTV2 from 0x24de869c5e40b2eb
import ARTIFACTPackV3 from 0x24de869c5e40b2eb
import ARTIFACTAdminV2 from 0x24de869c5e40b2eb
import Interfaces from 0x24de869c5e40b2eb
import MetadataViews from 0x1d7e57aa55817448

pub contract ARTIFACTMarketV2 {

    // -----------------------------------------------------------------------
    // ARTIFACTMarketV2 contract-level fields.
    // These contain actual values that are stored in the smart contract.
    // -----------------------------------------------------------------------
    
    // The next listing ID that is used to create Listing. 
    // Every time a Listing is created, nextListingID is assigned 
    // to the new Listing's ID and then is incremented by 1.
    pub var nextListingID: UInt64

    /// Path where the `SaleCollection` is stored
    pub let marketStoragePath: StoragePath

    /// Path where the public capability for the `SaleCollection` is
    pub let marketPublicPath: PublicPath

    /// Path where the `MarketManager` is stored
    pub let managerPath: StoragePath

    /// Event used on Listing is created 
    pub event ARTIFACTMarketListed(listingID: UInt64, price: UFix64, saleCuts: {Address: UFix64}, seller: Address?, databaseID: String, nftID: UInt64?, packTemplateID: UInt64?, preSalePrice: UFix64)
    
    /// Event used on Listing is purchased 
    pub event ARTIFACTMarketPurchased(listingID: UInt64, packID: UInt64, owner: Address?, databaseID: String)
    
    /// Event used on Listing is removed 
    pub event ARTIFACTMarketListingRemoved(listingID: UInt64, owner: Address?)

    // -----------------------------------------------------------------------
    // ARTIFACTMarketV2 contract-level Composite Type definitions
    // -----------------------------------------------------------------------
    // These are just *definitions* for Types that this contract
    // and other accounts can use. These definitions do not contain
    // actual stored values, but an instance (or object) of one of these Types
    // can be created by this contract that contains stored values.
    // ----------------------------------------------------------------------- 

    // Listing is a Struct that holds all informations about 
    // the NFT put up to sell
    //
    pub struct Listing {
        pub let ID: UInt64
        // The ID of the NFT
        pub let nftID: UInt64?
        // The ID of the Pack NFT template
        pub let packTemplateID: UInt64?
        // The Type of the FungibleToken that payments must be made in.
        pub let salePaymentVaultType: Type
        // The amount that must be paid in the specified FungibleToken.
        pub let salePrice: UFix64
        // The amount that must be paid in the specified FungibleToken.
        pub let preSalePrice: UFix64
        // This specifies the division of payment between recipients.
        access(account) let saleCuts: [SaleCut]
        pub let sellerCapability: Capability<&{FungibleToken.Receiver}>

        // The whitelist used on pre-sale function
        access(account) var whitelist: [Address]
        // The field to check if is pre-sale
        pub var isPreSale: Bool
        // The field save buyer
        access(account) let buyers: {Address: UInt64}
        // The field with max limit per buyer
        access(account) var preSaleBuyerMaxLimit: {Address: UInt64}
        // Royalties applied on NFTs.
        access(account) let nftSaleCuts: [SaleCut]

        // initializer
        //
        init (
            ID: UInt64,
            nftID: UInt64?,
            packTemplateID: UInt64?,
            salePrice: UFix64,
            saleCuts: [SaleCut],
            salePaymentVaultType: Type,
            sellerCapability: Capability<&{FungibleToken.Receiver}>,
            whitelist: [Address],
            isPreSale: Bool,
            preSaleBuyerMaxLimit: {Address: UInt64},
            preSalePrice: UFix64,
            nftSaleCuts: [SaleCut]
        ) {
            pre {
                salePrice >= 0.0 : "Listing must be not negative price"
                sellerCapability.borrow() != nil: 
                    "Sellers's Receiver Capability is invalid!"
                ARTIFACTMarketV2.totalSaleCuts(saleCuts: saleCuts) <= 100.0: "SaleCuts can't be greater a 100"
            }
            self.ID = ID
            self.nftID = nftID
            self.packTemplateID = packTemplateID
            self.saleCuts = saleCuts
            self.salePrice = salePrice
            self.salePaymentVaultType = salePaymentVaultType
            self.sellerCapability = sellerCapability
            self.whitelist = whitelist
            self.isPreSale = isPreSale
            self.buyers = {}
            self.preSaleBuyerMaxLimit = preSaleBuyerMaxLimit
            self.preSalePrice = preSalePrice
            self.nftSaleCuts = nftSaleCuts
        }

        pub fun changePreSaleStatus(isPreSale: Bool){
            self.isPreSale = isPreSale
        }

        pub fun increaseBuyers(userAddress: Address, quantity: UInt64 ){
            
            if self.buyers[userAddress] == nil {
                self.buyers[userAddress] = 0
            }

            self.buyers[userAddress] = self.buyers[userAddress]! + quantity
        }

        pub fun getPrice(): UFix64 {
            if self.isPreSale == true {
                return self.preSalePrice
            } 

            return self.salePrice
        }
        
        pub fun updateWhitelist(whitelist: [Address], preSaleBuyerMaxLimit: {Address: UInt64}) {
            self.whitelist = whitelist
            self.preSaleBuyerMaxLimit = preSaleBuyerMaxLimit
        }

        pub fun getBuyers(): Int {
            return self.buyers.keys.length
        }
    }

    // SaleCut
    // A struct representing a recipient that must be sent a certain amount
    // of the payment when a token is sold.
    //
    pub struct SaleCut {
        // The receiver for the payment.
        // Note that we do not store an address to find the Vault that this represents,
        // as the link or resource that we fetch in this way may be manipulated,
        // so to find the address that a cut goes to you must get this struct and then
        // call receiver.borrow()!.owner.address on it.
        // This can be done efficiently in a script.
        pub let receiver: Capability<&{FungibleToken.Receiver}>

        // The percentage of the payment that will be paid to the receiver.
        pub let percentage: UFix64

        // initializer
        //
        init(receiver: Capability<&{FungibleToken.Receiver}>, percentage: UFix64) {
            self.receiver = receiver
            self.percentage = percentage
        }
    }

    // ManagerPublic 
    //
    // The interface that a user can publish a capability to their sale
    // to allow others to access their sale
    pub resource interface ManagerPublic {
       pub fun purchase(listingID: UInt64, buyTokens: &FungibleToken.Vault, databaseID: String, owner: Address, userPackCollection: &ARTIFACTPackV3.Collection{ARTIFACTPackV3.CollectionPublic}, userCollection: &ARTIFACTV2.Collection{ARTIFACTV2.CollectionPublic}, quantity: UInt64)

       pub fun purchaseOnPreSale(listingID: UInt64, buyTokens: &FungibleToken.Vault, databaseID: String, owner: Address, userPackCollection: &ARTIFACTPackV3.Collection{ARTIFACTPackV3.CollectionPublic}, userCollection: &ARTIFACTV2.Collection{ARTIFACTV2.CollectionPublic}, quantity: UInt64)

        pub fun getIDs(): [UInt64]

        pub fun getListings(): [Listing]
    }

    // MarketManager
    // An interface for adding and removing Listings within a ARTIFACTMarketV2,
    // intended for use by the ARTIFACTAdminV2's own
    //
    pub resource interface MarketManager {
        // createListing
        // Allows the ARTIFACTV2 owner to create and insert Listings.
        //
        pub fun createListing(
            nftID: UInt64?,
            packTemplateID: UInt64?,
            salePrice: UFix64, 
            saleCuts: [SaleCut], 
            salePaymentVaultType: Type,
            sellerCapability: Capability<&{FungibleToken.Receiver}>,
            databaseID: String,
            whitelist: [Address], 
            isPreSale: Bool,
            preSaleBuyerMaxLimit: {Address: UInt64},
            preSalePrice: UFix64,
            nftSaleCuts: [SaleCut]
        )
        // removeListing
        // Allows the ARTIFACTMarketV2 owner to remove any sale listing, acepted or not.
        //
        pub fun removeListing(listingID: UInt64)

        // changePreSaleStatus
        // Allows the ARTIFACTMarketV2 owner change pre-sale status.
        //
        pub fun changePreSaleStatus(listingID: UInt64, isPreSale: Bool)

        pub fun updateWhitelist(listingResourceID: UInt64, whitelist: [Address], preSaleBuyerMaxLimit: {Address: UInt64})
    }

    pub resource Manager: ManagerPublic, MarketManager {

        /// A capability to create new packs
        access(self) var superAdminTokenReceiver: Capability<&ARTIFACTAdminV2.AdminTokenReceiver>
        
        /// A collection of the nfts that the user has for sale 
        access(self) var ownerCollection: Capability<&ARTIFACTV2.Collection>

        access(self) var listings: {UInt64: Listing}

        init (superAdminTokenReceiver: Capability<&ARTIFACTAdminV2.AdminTokenReceiver>, ownerCollection: Capability<&ARTIFACTV2.Collection>) {
            pre {
                superAdminTokenReceiver.borrow()!.getSuperAdminRef() != nil : "Must be a super admin account"
            }

            self.superAdminTokenReceiver = superAdminTokenReceiver
            self.ownerCollection = ownerCollection
            self.listings = {}
        }

        /// listForSale lists an NFT for sale in this sale collection
        /// at the specified price
        ///
        /// Parameters: nftID: The NFT ID
        /// Parameters: packTemplateID: The Pack NFT template ID
        /// Parameters: salePrice: The sale price
        /// Parameters: saleCuts: The royalties applied on purchase
        /// Parameters: salePaymentVaultType: The vault type
        /// Parameters: sellerCapability: The seller capability to transfer FUSD
        /// Parameters: databaseID: The database id
        //
        pub fun createListing(nftID: UInt64?, packTemplateID: UInt64?, salePrice: UFix64, saleCuts: [SaleCut], salePaymentVaultType: Type, sellerCapability: Capability<&{FungibleToken.Receiver}>, databaseID: String, whitelist: [Address], isPreSale: Bool, preSaleBuyerMaxLimit: {Address: UInt64}, preSalePrice: UFix64, nftSaleCuts: [SaleCut]) {
            pre {
                salePrice >= 0.0 : "must not be negative price"
                preSalePrice >= 0.0 : "must have a not negative preSalePrice "
                nftID != nil || packTemplateID != nil: "must pass one template ID"
                (self.getNumberValue(value: nftID != nil) + self.getNumberValue(value: packTemplateID != nil)) == 1 : "must pass only one template ID"
            }

            let listingID = ARTIFACTMarketV2.nextListingID
            ARTIFACTMarketV2.nextListingID = listingID + 1

            let listing = Listing(
                ID: listingID,
                nftID: nftID, 
                packTemplateID: packTemplateID, 
                salePrice: salePrice,
                saleCuts: saleCuts,
                salePaymentVaultType: salePaymentVaultType,
                sellerCapability: sellerCapability,
                whitelist: whitelist,
                isPreSale: isPreSale,
                preSaleBuyerMaxLimit: preSaleBuyerMaxLimit,
                preSalePrice: preSalePrice,
                nftSaleCuts: nftSaleCuts
            )

            self.listings[listingID] = listing

            let saleCutsInfo: {Address: UFix64} = {}
            
            for cut in saleCuts {
                saleCutsInfo[cut.receiver.address] = cut.percentage
            }

            emit ARTIFACTMarketListed(listingID: listingID, price: salePrice, saleCuts: saleCutsInfo, seller: self.owner?.address, databaseID: databaseID, nftID: nftID, packTemplateID: packTemplateID, preSalePrice: preSalePrice)
        }

        pub fun getNumberValue(value: Bool): UInt64 {
            if value == true {
                return 1
            }

            return 0
        }

        /// cancelSale cancels a sale and clears its price
        ///
        /// Parameters: listingID: the ID of the listing to withdraw from the sale
        ///
        pub fun removeListing(listingID: UInt64) {
            // Remove the price from the prices dictionary
            self.listings.remove(key: listingID)
            
            // Emit the event for withdrawing a from the Sale
            emit ARTIFACTMarketListingRemoved(listingID: listingID, owner: self.owner?.address)
        }

        /// purchase lets a user send tokens to purchase an NFT that is for sale
        /// the purchased NFT is returned to the transaction context that called it
        ///
        /// Parameters: listingID: the ID of the listing to purchase
        /// Parameters: buyTokens: the fungible tokens that are used to buy the NFT
        /// Parameters: databaseID: The database id
        /// Parameters: owner: The new owner of the pack
        /// Parameters: userPackCollection: The pack collection 
        /// Parameters: userCollection: The nft collection 
        /// Parameters: quantity: Quantity of pack to buy
        ///
        pub fun purchase(listingID: UInt64, buyTokens: &FungibleToken.Vault, databaseID: String, owner: Address, userPackCollection: &ARTIFACTPackV3.Collection{ARTIFACTPackV3.CollectionPublic}, userCollection: &ARTIFACTV2.Collection{ARTIFACTV2.CollectionPublic}, quantity: UInt64) {
            pre {
                !self.listings[listingID]!.isPreSale : "sale is not available"
            }

            self.purchaseListing(listingID: listingID, buyTokens: buyTokens, databaseID: databaseID, owner: owner, userPackCollection: userPackCollection, userCollection: userCollection, quantity: quantity)
        }

        /// purchase pre sale lets a user send tokens to purchase an NFT that is for pre-sale 
        /// the purchased NFT is returned to the transaction context that called it
        ///
        /// Parameters: listingID: the ID of the listing to purchase
        /// Parameters: buyTokens: the fungible tokens that are used to buy the NFT
        /// Parameters: databaseID: The database id
        /// Parameters: owner: The new owner of the pack
        /// Parameters: userPackCollection: The pack collection 
        /// Parameters: userCollection: The nft collection 
        /// Parameters: quantity: Quantity of pack to buy
        ///
        pub fun purchaseOnPreSale(listingID: UInt64, buyTokens: &FungibleToken.Vault, databaseID: String, owner: Address, userPackCollection: &ARTIFACTPackV3.Collection{ARTIFACTPackV3.CollectionPublic}, userCollection: &ARTIFACTV2.Collection{ARTIFACTV2.CollectionPublic}, quantity: UInt64) {
            pre {
                self.listings[listingID]!.isPreSale : "sale is not available"
                self.listings[listingID]!.whitelist.contains(userPackCollection.owner!.address) :"sale available for users in whitelist"
                userPackCollection.owner!.address == userCollection.owner!.address : "Pack collection and User collection should be same wallet"
                self.checkBuyerMaxLimit(address: userPackCollection.owner!.address, listingID: listingID, quantity: quantity) : "pre-sale offer is not available for this wallet"
            }

            let listing = self.listings[listingID]!;
            listing.increaseBuyers(userAddress: userPackCollection.owner!.address,quantity: quantity)
            
            self.listings[listingID] = listing

            self.purchaseListing(listingID: listingID, buyTokens: buyTokens, databaseID: databaseID, owner: owner, userPackCollection: userPackCollection, userCollection: userCollection, quantity: quantity)
        }

        access(self) fun purchaseListing(listingID: UInt64, buyTokens: &FungibleToken.Vault, databaseID: String, owner: Address, userPackCollection: &ARTIFACTPackV3.Collection{ARTIFACTPackV3.CollectionPublic}, userCollection: &ARTIFACTV2.Collection{ARTIFACTV2.CollectionPublic}, quantity: UInt64){
            pre {
                quantity <= 200 : "Max quantity is 200"
                self.listings.containsKey(listingID) : "listingID not found"
                buyTokens.isInstance(self.listings[listingID]!.salePaymentVaultType):"payment vault is not requested fungible token"
            }

            var i : UInt64 = 0
            while i < quantity {
                if(!self.listings.containsKey(listingID)){
                    panic("listing can't be purchase")
                }

                let listing = self.listings[listingID]!

                let price = listing.getPrice()

                let buyerVault <-buyTokens.withdraw(amount: price)

                let nftTemplate = self.getTemplateInformation(listing: listing)

                var nft <- self.getNFT(nft: nftTemplate, owner: owner, listing: listing, quantity: quantity)
                    
                for saleCut in listing.saleCuts {
                    let receiverCut <- buyerVault.withdraw(amount: price * (saleCut.percentage / 100.0))
                    saleCut.receiver.borrow()!.deposit(from: <-receiverCut)
                }
                
                listing.sellerCapability.borrow()!.deposit(from: <-buyerVault)

                emit ARTIFACTMarketPurchased(listingID: listingID, packID: nft.id, owner: owner, databaseID: databaseID)

                self.removeListingByGenericNFT(nft: nftTemplate, listing: listing)

                if(listing.packTemplateID != nil){
                    userPackCollection.deposit(token: <-nft)
                } else {
                    userCollection.deposit(token: <-nft)
                }

                i = i + 1
            }
         }

        
        // getTemplateInformation based in the listing fields get the
        // NFT ID or NFT template ID or Pack NFT template struct
        //
        // Parameters: listing: The listing struct
        //
        // returns: AnyStruct the NFT reference
        access(self) fun getTemplateInformation(listing: Listing): AnyStruct {
            if(listing.packTemplateID != nil){
                return ARTIFACTPackV3.getPackTemplate(templateId: listing.packTemplateID!)!
            } else if (listing.nftID != nil) {
                return listing.nftID
            } 

            panic("Listing don't have any template information")
        }

        // checkBuyerMaxLimit function to check if wallet can buy on pre-sale
        access(self) fun checkBuyerMaxLimit(address: Address, listingID: UInt64, quantity: UInt64): Bool {
            let listing = self.listings[listingID]!
            
            if (listing.preSaleBuyerMaxLimit.containsKey(address)) {

                var quantityBuyer: UInt64 = 0
                if listing.buyers.containsKey(address) {
                    quantityBuyer = listing.buyers[address]!
                }

                return listing.preSaleBuyerMaxLimit[address]! >= quantityBuyer + quantity
            }

            return !listing.buyers.containsKey(address) && quantity == 1
        }

        // getNFT based in the listing fields get/create the
        // NFT or NFT template or Pack NFT
        //
        // Parameters: nft: The nft struct or NFT ID
        // Parameters: owner: The owner
        // Parameters: listing: The listing struct
        // Parameters: quantity: The quantity used to validate the maxQuantityPerTransaction
        //
        // returns: @NonFungibleToken.NFT the NFT or Pack
        access(self) fun getNFT(nft: AnyStruct, owner: Address, listing: Listing, quantity: UInt64): @NonFungibleToken.NFT {
            if(listing.packTemplateID != nil){
                let packTemplate = nft as! ARTIFACTPackV3.PackTemplate
                if(packTemplate.maxQuantityPerTransaction < quantity){
                    panic("quantity is greater than max quantity")
                }

                let adminRef = self.superAdminTokenReceiver.borrow()!.getAdminRef()!
                let adminOpenerRef = self.superAdminTokenReceiver.borrow()!.getAdminOpenerRef()
                var royalties: [MetadataViews.Royalty] = []
                for cut in listing.nftSaleCuts {
                    royalties.append(MetadataViews.Royalty(recepient: cut.receiver, cut: cut.percentage / 100.0, description: ""))
                }

                return <- adminRef.createPack(packTemplate: packTemplate, adminRef: adminOpenerRef, owner: owner, listingID: listing.ID, royalties: royalties)
            } else if (listing.nftID != nil) {
                return <- self.ownerCollection.borrow()!.withdraw(withdrawID: listing.nftID!)
            } 

            panic("Error to get NFT from template")
        }

        // removeListingByGenericNFT based in the listing fields remove the sale offer
        //
        // Parameters: nft: The nft struct or NFT ID
        // Parameters: listing: The listing struct
        //
        access(self) fun removeListingByGenericNFT(nft: AnyStruct, listing: Listing) {
            if(listing.packTemplateID != nil){
                let packTemplate = nft as! ARTIFACTPackV3.PackTemplate
                if (packTemplate.totalSupply <= ARTIFACTPackV3.numberMintedByPack[listing.ID]!){
                    self.removeListing(listingID: listing.ID)
                }
            } else if (listing.nftID != nil) {
                self.removeListing(listingID: listing.ID)
            } else {
                panic("Error to remove listing from template")
            }
        }

        /// getIDs returns an array of token IDs that are for sale
        pub fun getIDs(): [UInt64] {
            return self.listings.keys 
        }

        /// getListings returns an array of Listing that are for sale
        pub fun getListings(): [Listing] {
            return self.listings.values
        }

        /// getListings returns an array of Listing that are for sale
        pub fun getBuyersByListingID(listingID: UInt64): Int {
            return self.listings[listingID]!.getBuyers()
        }
        
        // updateWhitelist
        // Update listing whitelist 
        pub fun updateWhitelist(listingResourceID: UInt64, whitelist: [Address], preSaleBuyerMaxLimit: {Address: UInt64}) {
            pre {
                self.listings[listingResourceID] != nil: "could not find listing with given id"
            }

            let listing = (&self.listings[listingResourceID] as! &Listing?)!

            listing.updateWhitelist(whitelist: whitelist, preSaleBuyerMaxLimit: preSaleBuyerMaxLimit)            
        }

        pub fun changePreSaleStatus(listingID: UInt64, isPreSale: Bool) {
            pre {
                self.listings.containsKey(listingID) : "listingID not found"
            }

            self.listings[listingID]!.changePreSaleStatus(isPreSale: isPreSale)
        }
    }

    // -----------------------------------------------------------------------
    // ARTIFACTMarketV2 contract-level function definitions
    // -----------------------------------------------------------------------

    // createManager creates a new Manager resource
    //
    pub fun createManager(superAdminTokenReceiver: Capability<&ARTIFACTAdminV2.AdminTokenReceiver>, ownerCollection: Capability<&ARTIFACTV2.Collection>): @Manager {
        return <- create Manager(superAdminTokenReceiver: superAdminTokenReceiver, ownerCollection: ownerCollection)
    }
    
    // createSaleCut creates a new SaleCut to a receiver user
    // with a specific percentage.
    //
    pub fun createSaleCut(receiver: Capability<&{FungibleToken.Receiver}>, percentage: UFix64): SaleCut {
        return SaleCut(receiver: receiver, percentage: percentage)
    }

    // totalSaleCuts sum all percentages in a array of SaleCut
    //
    pub fun totalSaleCuts(saleCuts: [SaleCut]): UFix64 {
        var total: UFix64 = 0.0

        for cut in saleCuts {
            total = cut.percentage + total
        }

        return total
    }

    init() {
        self.marketStoragePath = /storage/ARTIFACTMarketV2Collection
        self.marketPublicPath = /public/ARTIFACTMarketV2Collection
        self.managerPath = /storage/ARTIFACTMarketV2Manager

        self.nextListingID = 1
        
        if(self.account.borrow<&{ARTIFACTPackV3.CollectionPublic}>(from: ARTIFACTPackV3.collectionStoragePath) == nil) {
            let collection <- ARTIFACTPackV3.createEmptyCollection() as! @ARTIFACTPackV3.Collection 
            self.account.save<@ARTIFACTPackV3.Collection>(<- collection, to: ARTIFACTPackV3.collectionStoragePath)
            self.account.link<&{ARTIFACTPackV3.CollectionPublic}>(ARTIFACTPackV3.collectionPublicPath, target: ARTIFACTPackV3.collectionStoragePath)
        }

        if(self.account.borrow<&{ARTIFACTMarketV2.ManagerPublic}>(from: ARTIFACTMarketV2.marketStoragePath) == nil) {
            let ownerCollection = self.account.link<&ARTIFACTV2.Collection>(ARTIFACTV2.collectionPrivatePath, target: ARTIFACTV2.collectionStoragePath)!        
            let superAdminTokenReceiverCapability = self.account.link<&ARTIFACTAdminV2.AdminTokenReceiver>(ARTIFACTAdminV2.ARTIFACTAdminTokenReceiverPrivatePath , target: ARTIFACTAdminV2.ARTIFACTAdminTokenReceiverStoragePath)!    

            self.account.save(<- create ARTIFACTMarketV2.Manager(superAdminTokenReceiver: superAdminTokenReceiverCapability, ownerCollection: ownerCollection), to: ARTIFACTMarketV2.marketStoragePath)

            self.account.link<&ARTIFACTMarketV2.Manager{ARTIFACTMarketV2.ManagerPublic}>(ARTIFACTMarketV2.marketPublicPath, target: ARTIFACTMarketV2.marketStoragePath)
        }
    }
}
 