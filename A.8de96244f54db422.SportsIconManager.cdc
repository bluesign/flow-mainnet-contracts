/*
    Description: Administrative Contract for SportsIcon NFT Collectibles
    
    Exposes all functionality for an administrator of SportsIcon to
    make creations and modifications pertaining to SportsIcon Collectibles
*/

import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import FlowToken from 0x1654653399040a61
import FUSD from 0x3c5959b568896393
import SportsIconBeneficiaries from 0x8de96244f54db422
import SportsIconCollectible from 0x8de96244f54db422

pub contract SportsIconManager {
    pub let ManagerStoragePath: StoragePath
    pub let ManagerPublicPath: PublicPath

    // -----------------------------------------------------------------------
    // SportsIcon Manager Events
    // -----------------------------------------------------------------------
    pub event SetMetadataUpdated(setID: UInt64)
    pub event EditionMetadataUpdated(setID: UInt64, editionNumber: UInt64)
    pub event PublicSalePriceUpdated(setID: UInt64, fungibleTokenType: String, price: UFix64?)
    pub event PublicSaleTimeUpdated(setID: UInt64, startTime: UFix64?, endTime: UFix64?)

    // Allows for access to where SportsIcon FUSD funds should head towards.
    // Mapping of `FungibleToken Identifier` -> `Receiver Capability`
    // Currently usable is FLOW and FUSD as payment receivers
    access(self) var adminPaymentReceivers: { String : Capability<&{FungibleToken.Receiver}> }

    pub resource interface ManagerPublic {
        pub fun mintNftFromPublicSaleWithFUSD(setID: UInt64, quantity: UInt32, vault: @FungibleToken.Vault): @SportsIconCollectible.Collection
        pub fun mintNftFromPublicSaleWithFLOW(setID: UInt64, quantity: UInt32, vault: @FungibleToken.Vault): @SportsIconCollectible.Collection
    }

    pub resource Manager: ManagerPublic {
        /*
            Set creation
        */
        pub fun addNFTSet(mediaURL: String, maxNumberOfEditions: UInt64, data: {String:String},
                mintBeneficiaries: SportsIconBeneficiaries.Beneficiaries,
                marketBeneficiaries: SportsIconBeneficiaries.Beneficiaries): UInt64 {
            let setID = SportsIconCollectible.addNFTSet(mediaURL: mediaURL, maxNumberOfEditions: maxNumberOfEditions, data: data,
                    mintBeneficiaries: mintBeneficiaries, marketBeneficiaries: marketBeneficiaries)
            return setID
        }

        /*
            Modification of properties and metadata for a set
        */
        pub fun updateSetMetadata(setID: UInt64, metadata: {String: String}) {
            SportsIconCollectible.updateSetMetadata(setID: setID, metadata: metadata)
            emit SetMetadataUpdated(setID: setID)
        }

        pub fun updateMediaURL(setID: UInt64, mediaURL: String) {
            SportsIconCollectible.updateMediaURL(setID: setID, mediaURL: mediaURL)
            emit SetMetadataUpdated(setID: setID)
        }

        pub fun updateFLOWPublicSalePrice(setID: UInt64, price: UFix64?) {
            SportsIconCollectible.updateFLOWPublicSalePrice(setID: setID, price: price)
            emit PublicSalePriceUpdated(setID: setID, fungibleTokenType: "FLOW", price: price)
        }

        pub fun updateFUSDPublicSalePrice(setID: UInt64, price: UFix64?) {
            SportsIconCollectible.updateFUSDPublicSalePrice(setID: setID, price: price)
            emit PublicSalePriceUpdated(setID: setID, fungibleTokenType: "FUSD", price: price)
        }

        pub fun updateEditionMetadata(setID: UInt64, editionNumber: UInt64, metadata: {String: String}) {
            SportsIconCollectible.updateEditionMetadata(setID: setID, editionNumber: editionNumber, metadata: metadata)
            emit EditionMetadataUpdated(setID: setID, editionNumber: editionNumber)
        }
        
        /*
            Modification of a set's public sale settings
        */
        // fungibleTokenType is expected to be 'FLOW' or 'FUSD'
        pub fun setAdminPaymentReceiver(fungibleTokenType: String, paymentReceiver: Capability<&{FungibleToken.Receiver}>) {
            SportsIconManager.setAdminPaymentReceiver(fungibleTokenType: fungibleTokenType, paymentReceiver: paymentReceiver)
        }

        pub fun updatePublicSaleStartTime(setID: UInt64, startTime: UFix64?) {
            SportsIconCollectible.updatePublicSaleStartTime(setID: setID, startTime: startTime)
            let setMetadata = SportsIconCollectible.getMetadataForSetID(setID: setID)!
            emit PublicSaleTimeUpdated(
                setID: setID,
                startTime: setMetadata.getPublicSaleStartTime(),
                endTime: setMetadata.getPublicSaleEndTime()
            )
        }

        pub fun updatePublicSaleEndTime(setID: UInt64, endTime: UFix64?) {
            SportsIconCollectible.updatePublicSaleEndTime(setID: setID, endTime: endTime)
            let setMetadata = SportsIconCollectible.getMetadataForSetID(setID: setID)!
            emit PublicSaleTimeUpdated(
                setID: setID,
                startTime: setMetadata.getPublicSaleStartTime(),
                endTime: setMetadata.getPublicSaleEndTime()
            )
        }

        /* Minting functions */
        // Mint a single next edition NFT
        access(self) fun mintSequentialEditionNFT(setID: UInt64): @SportsIconCollectible.NFT {
            return <-SportsIconCollectible.mintSequentialEditionNFT(setID: setID) 
        }

        // Mint many editions of NFTs
        pub fun batchMintSequentialEditionNFTs(setID: UInt64, quantity: UInt32): @SportsIconCollectible.Collection {
            pre {
                quantity >= 1 && quantity <= 10 : "May only mint between 1 and 10 collectibles at a single time."
            }
            let collection <- SportsIconCollectible.createEmptyCollection() as! @SportsIconCollectible.Collection
            var counter: UInt32 = 0
            while (counter < quantity) {
                collection.deposit(token: <-self.mintSequentialEditionNFT(setID: setID))
                counter = counter + 1
            }
            return <-collection
        }

        // Mint a specific edition of an NFT - usable for auctions, because edition numbers are set by ending auction ordering
        pub fun mintNFT(setID: UInt64, editionNumber: UInt64): @SportsIconCollectible.NFT {
            return <-SportsIconCollectible.mintNFT(setID: setID, editionNumber: editionNumber)
        }

        // Allows direct minting of a NFT as part of a public sale.
        // This function takes in a vault that can be of multiple types of fungible tokens.
        // The proper fungible token is to be checked prior to this function call
        access(self) fun mintNftFromPublicSale(setID: UInt64, quantity: UInt32, vault: @FungibleToken.Vault,
                    price: UFix64, paymentReceiver: Capability<&{FungibleToken.Receiver}>): @SportsIconCollectible.Collection {
            pre {
                quantity >= 1 && quantity <= 10 : "May only mint between 1 and 10 collectibles at a time"
                SportsIconCollectible.getMetadataForSetID(setID: setID) != nil :
                    "SetID does not exist"
                SportsIconCollectible.getMetadataForSetID(setID: setID)!.isPublicSaleActive() :
                    "Public minting is not currently allowed"
            }
            let totalPrice = price * UFix64(quantity)

            // Ensure that the provided balance is equal to our expected price for the NFTs
            assert(totalPrice == vault.balance)

            // Mint `quantity` number of NFTs from this drop to the collection
            var counter = UInt32(0)
            let uuids: [UInt64] = []
            let collection <- SportsIconCollectible.createEmptyCollection() as! @SportsIconCollectible.Collection
            while (counter < quantity) {
                let collectible <- self.mintSequentialEditionNFT(setID: setID)
                uuids.append(collectible.uuid)
                collection.deposit(token: <-collectible)
                counter = counter + UInt32(1)
            }
            // Retrieve the money from the given vault and place it in the appropriate locations
            let setInfo = SportsIconCollectible.getMetadataForSetID(setID: setID)!
            let mintBeneficiaries = setInfo.getMintBeneficiaries()
            let adminPaymentReceiver = paymentReceiver.borrow()!
            mintBeneficiaries.payOut(paymentReceiver: paymentReceiver, payment: <-vault, tokenIDs: uuids)
            return <-collection
        }

        /*
            Public functions
        */
        // Ensure that the passed in vault is FUSD, and pass the expected FUSD sale price for this set
        pub fun mintNftFromPublicSaleWithFUSD(setID: UInt64, quantity: UInt32, vault: @FungibleToken.Vault): @SportsIconCollectible.Collection {
            pre {
                SportsIconCollectible.getMetadataForSetID(setID: setID)!.getFUSDPublicSalePrice() != nil :
                    "Public sale price not set for this set"
            }
            let fusdVault <- vault as! @FUSD.Vault
            let price = SportsIconCollectible.getMetadataForSetID(setID: setID)!.getFUSDPublicSalePrice()!
            let paymentReceiver = SportsIconManager.adminPaymentReceivers["FUSD"]!
            return <-self.mintNftFromPublicSale(setID: setID, quantity: quantity, vault: <-fusdVault, price: price,
                                        paymentReceiver: paymentReceiver)
        }

        // Ensure that the passed in vault is a FLOW vault, and pass the expected FLOW sale price for this set
        pub fun mintNftFromPublicSaleWithFLOW(setID: UInt64, quantity: UInt32, vault: @FungibleToken.Vault): @SportsIconCollectible.Collection {
            pre {
                SportsIconCollectible.getMetadataForSetID(setID: setID)!.getFLOWPublicSalePrice() != nil :
                    "Public sale price not set for this set"
            }
            let flowVault <- vault as! @FlowToken.Vault
            let price = SportsIconCollectible.getMetadataForSetID(setID: setID)!.getFLOWPublicSalePrice()!
            let paymentReceiver = SportsIconManager.adminPaymentReceivers["FLOW"]!
            return <-self.mintNftFromPublicSale(setID: setID, quantity: quantity, vault: <-flowVault, price: price,
                            paymentReceiver: paymentReceiver)
        }
    }

    /* Mutating functions */
    access(contract) fun setAdminPaymentReceiver(fungibleTokenType: String, paymentReceiver: Capability<&{FungibleToken.Receiver}>) {
        pre {
            fungibleTokenType == "FLOW" || fungibleTokenType == "FUSD" : "Must provide either flow or fusd as fungible token keys"
            paymentReceiver.borrow() != nil : "Invalid payment receivier capability provided"
            fungibleTokenType == "FLOW" && paymentReceiver.borrow()!.isInstance(Type<@FlowToken.Vault>()) : "Invalid flow token vault provided"
            fungibleTokenType == "FUSD" && paymentReceiver.borrow()!.isInstance(Type<@FUSD.Vault>()) : "Invalid flow token vault provided"
        }
        self.adminPaymentReceivers[fungibleTokenType] = paymentReceiver
    }

    /* Public Functions */
    pub fun getManagerPublic(): Capability<&SportsIconManager.Manager{SportsIconManager.ManagerPublic}> {
        return self.account.getCapability<&SportsIconManager.Manager{SportsIconManager.ManagerPublic}>(self.ManagerPublicPath)
    }

    init() {
        self.ManagerStoragePath = /storage/sportsIconManager
        self.ManagerPublicPath = /public/sportsIconManager
        self.account.save(<- create Manager(), to: self.ManagerStoragePath)
        self.account.link<&SportsIconManager.Manager{SportsIconManager.ManagerPublic}>(self.ManagerPublicPath, target: self.ManagerStoragePath)

        // If FUSD isn't setup on this manager account already, set it up - it is required to receive funds
        // and redirect sales of NFTs where we've lost the FUSD vault access to a seller on secondary market
        let existingVault = self.account.borrow<&FUSD.Vault>(from: /storage/fusdVault)
        if (existingVault == nil) {
            self.account.save(<-FUSD.createEmptyVault(), to: /storage/fusdVault)
            self.account.link<&FUSD.Vault{FungibleToken.Receiver}>(
                /public/fusdReceiver,
                target: /storage/fusdVault
            )
            self.account.link<&FUSD.Vault{FungibleToken.Balance}>(
                /public/fusdBalance,
                target: /storage/fusdVault
            )
        }
        self.adminPaymentReceivers = {}
        self.adminPaymentReceivers["FUSD"] = self.account.getCapability<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdReceiver)
        self.adminPaymentReceivers["FLOW"] = self.account.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
    }
}