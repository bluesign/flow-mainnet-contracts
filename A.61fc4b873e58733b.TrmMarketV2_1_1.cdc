/**

    TrmMarketV2_1_1.cdc

    Description: Contract definitions for users to sell and/or rent out their assets

    Marketplace is where users can create a sale collection that they
    store in their account storage. In the sale collection, 
    they can put their NFTs up for sale/rent with a price and publish a 
    reference so that others can see the sale.

    If another user sees an NFT that they want to buy,
    they can send fungible tokens that equal the buy price
    to buy the NFT.  The NFT is transferred to them when
    they make the purchase.

    If another user sees an NFT that they want to rent,
    they can send fungible tokens that equal the rent price
    to rent the NFT. The Rent NFT will be minted and 
    transferred to them.

    Each user who wants to sell/rent out tokens will have a sale 
    collection instance in their account that contains price information 
    for each node in their collection. The sale holds a capability that 
    links to their main asset collection.

    They can give a reference to this collection to a central contract
    so that it can list the sales in a central place

    When a user creates a sale, they will supply four arguments:
    - A TrmAssetV2_1.Collection capability that allows their sale to withdraw an asset when it is purchased.
    - A FungibleToken.Receiver capability as the place where the payment for the token goes.
    - A FungibleToken.Receiver capability specifying a beneficiary, where a cut of the purchase gets sent. 
    - A cut percentage, specifying how much the beneficiary will recieve.
    
    The cut percentage can be set to zero if the user desires and they 
    will receive the entirety of the purchase. Trm will initialize sales 
    for users with the Trm admin vault as the vault where cuts get 
    deposited to.
**/

import TrmAssetV2_1 from 0x61fc4b873e58733b
import TrmRentV2_1 from 0x61fc4b873e58733b
import NonFungibleToken from 0x1d7e57aa55817448

pub contract TrmMarketV2_1_1 {
    /// -----------------------------------------------------------------------
    /// TRM Market contract Event definitions
    /// -----------------------------------------------------------------------

    /// Event that emitted when the NFT contract is initialized
    pub event ContractInitialized()
    /// Emitted when an Asset is listed for transfer
    pub event AssetListedForTransfer(assetTokenID: UInt64, salePrice: UFix64?, auctionPrice: UFix64?, auctionStartTimestamp: UFix64?, auctionPeriodSeconds: UFix64?, seller: Address?)
    /// Emitted when an Asset is listed for transfer
    pub event AssetBatchListedForTransfer(assetTokenIDs: [UInt64], salePrice: UFix64?, auctionPrice: UFix64?, auctionStartTimestamp: UFix64?, auctionPeriodSeconds: UFix64?, seller: Address?)
    /// Emitted when an Asset is listed for rent
    pub event AssetListedForRent(assetTokenID: UInt64, price: UFix64?, rentalPeriodSeconds: UFix64, seller: Address?)
    /// Emitted when an Asset is listed for rent
    pub event AssetBatchListedForRent(assetTokenIDs: [UInt64], price: UFix64?, rentalPeriodSeconds: UFix64, seller: Address?)
    /// Emitted when the sale price of a listed asset has changed
    pub event AssetTransferListingChanged(assetTokenID: UInt64, salePrice: UFix64?, auctionPrice: UFix64?, auctionStartTimestamp: UFix64?, auctionPeriodSeconds: UFix64?, seller: Address?)
    /// Emitted when the sale price of a listed asset has changed
    pub event AssetBatchTransferListingChanged(assetTokenIDs: [UInt64], salePrice: UFix64?, auctionPrice: UFix64?, auctionStartTimestamp: UFix64?, auctionPeriodSeconds: UFix64?, seller: Address?)
    /// Emitted when the rent price of a listed asset has changed
    pub event AssetRentListingChanged(assetTokenID: UInt64, price: UFix64?, rentalPeriodSeconds: UFix64, seller: Address?)
    /// Emitted when the rent price of a listed asset has changed
    pub event AssetBatchRentListingChanged(assetTokenIDs: [UInt64], price: UFix64?, rentalPeriodSeconds: UFix64, seller: Address?)
    /// Emitted when a token is purchased from the market
    pub event AssetTransferred(assetTokenID: UInt64, price: UFix64, seller: Address?, buyer: Address?, paymentID: String)
    /// Emitted when a token is rented from the market
    pub event AssetRented(assetTokenID: UInt64, rentID: UInt64, price: UFix64, expiryTimestamp: UFix64, assetName: String, assetDescription: String, assetURL: String, assetThumbnailURL: String, assetMetadata: {String: String}, kID: String, seller: Address?, buyer: Address?, rentalPeriodSeconds: UFix64, paymentID: String)
    /// Emitted when a token has been delisted for sale
    pub event AssetDelistedForTransfer(assetTokenID: UInt64, owner: Address?)
    /// Emitted when a token has been delisted for sale
    pub event AssetBatchDelistedForTransfer(assetTokenIDs: [UInt64], owner: Address?)
    /// Emitted when a token has been delisted for rent
    pub event AssetDelistedForRent(assetTokenID: UInt64, owner: Address?)
    /// Emitted when a token has been delisted for rent
    pub event AssetBatchDelistedForRent(assetTokenIDs: [UInt64], owner: Address?)

    /// Path where the `SaleCollection` is stored
    pub let marketStoragePath: StoragePath
    /// Path where the public capability for the `SaleCollection` is
    pub let marketPublicPath: PublicPath
    /// Path where the private capability for the `SaleCollection` is
    pub let marketPrivatePath: PrivatePath
    /// Path where the 'Admin' resource is stored
    pub let adminStoragePath: StoragePath

    /// The private capability for minting rent tokens
    pub var minterCapability: Capability<&TrmRentV2_1.Minter>

    pub resource RentListing {
        pub var price: UFix64
        pub var rentalPeriodSeconds: UFix64

        access(contract) fun setRentalPeriodSeconds(seconds: UFix64) {
            self.rentalPeriodSeconds = seconds
        }

        init(rentalPeriodSeconds: UFix64) {
            self.price = UFix64(0)
            self.rentalPeriodSeconds = rentalPeriodSeconds
        }
    }

    pub resource TransferListing {
        pub var price: UFix64

        init() {
            self.price = UFix64(0)
        }
    }

    /// SalePublic 
    //
    /// The interface that a user can publish a capability to their sale
    /// to allow others to access their sale
    pub resource interface SalePublic {
        access(contract) fun listForTransfer(tokenID: UInt64, salePrice: UFix64?, auctionPrice: UFix64?, auctionStartTimestamp: UFix64?, auctionPeriodSeconds: UFix64?)
        access(contract) fun listForRent(tokenID: UInt64, price: UFix64?, rentalPeriodSeconds: UFix64?)
        access(contract) fun batchListForTransfer(tokenIDs: [UInt64], salePrice: UFix64?, auctionPrice: UFix64?, auctionStartTimestamp: UFix64?, auctionPeriodSeconds: UFix64?)
        access(contract) fun batchListForRent(tokenIDs: [UInt64], price: UFix64?, rentalPeriodSeconds: UFix64?)
        access(contract) fun cancelTransfer(tokenID: UInt64)
        access(contract) fun cancelRent(tokenID: UInt64)
        access(contract) fun batchCancelTransfer(tokenIDs: [UInt64])
        access(contract) fun batchCancelRent(tokenIDs: [UInt64])
        access(contract) fun transfer(tokenID: UInt64, adminAccount: &TrmAssetV2_1.Admin, recipientAddress: Address, price: UFix64, paymentID: String)
        access(contract) fun rent(tokenID: UInt64, price: UFix64, recipient: Capability<&{TrmRentV2_1.CollectionPublic}>, paymentID: String): UInt64

        pub fun getTransferListing(tokenID: UInt64): &TransferListing?
        pub fun getRentListing(tokenID: UInt64): &RentListing?
        pub fun getTransferIDs(): [UInt64]
        pub fun getRentIDs(): [UInt64]
        pub fun borrowAsset(id: UInt64): &TrmAssetV2_1.NFT? {
            /// If the result isn't nil, the id of the returned reference
            /// should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id): 
                    "Cannot borrow Asset reference: The ID of the returned reference is incorrect"
            }
        }
    }

    /// SaleCollection
    ///
    /// This is the main resource that token sellers will store in their account
    /// to manage the NFTs that they are selling/renting. The SaleCollection keeps 
    /// track of the price of each token.
    /// 
    /// When a token is purchased, a cut is taken from the tokens
    /// and sent to the beneficiary, then the rest are sent to the seller.
    ///
    /// The seller chooses who the beneficiary is and what percentage
    /// of the tokens gets taken from the purchase
    pub resource SaleCollection: SalePublic {

        /// A reference to collection of the user's assets 
        access(self) var ownerCollection: Capability<&TrmAssetV2_1.Collection>

        /// Dictionary of the transfer prices for each NFT by ID
        access(self) var transferListings: @{UInt64: TransferListing}

        /// Dictionary of the rent prices for each NFT by ID
        access(self) var rentListings: @{UInt64: RentListing}

        init (ownerCollection: Capability<&TrmAssetV2_1.Collection>) {
            pre {
                /// Check that the owner's asset collection capability is correct
                ownerCollection.check(): 
                    "Owner's Asset Collection Capability is invalid!"
            }
            
            /// create an empty collection to store the assets that are for transfer and rent
            self.ownerCollection = ownerCollection
            
            /// prices are initially empty because there are no assets for transfer and rent
            self.transferListings <- {}
            self.rentListings <- {}
        }

        destroy() {
            destroy self.transferListings
            destroy self.rentListings
        }

        /// listForTransfer lists an NFT for transfer in this transfer collection at the specified price, or updates an existing listing
        ///
        /// Parameters: tokenID: The id of the NFT to be put up for transfer
        ///             salePrice: The sale price of the NFT(This is just returned back as an event)
        ///             auctionPrice: The auction price of the NFT(This is just returned back as an event)
        ///             auctionStartTimestamp: The auction start timestamp
        ///             auctionPeriodSeconds: The period for which auction will last
        access(contract) fun listForTransfer(tokenID: UInt64, salePrice: UFix64?, auctionPrice: UFix64?, auctionStartTimestamp: UFix64?, auctionPeriodSeconds: UFix64?) {
            pre {
                self.ownerCollection.borrow()!.idExists(id: tokenID):
                    "Asset does not exist in the owner's collection"
            }

            if self.transferListings.containsKey(tokenID) {
                emit AssetTransferListingChanged(assetTokenID: tokenID, salePrice: salePrice, auctionPrice: auctionPrice, auctionStartTimestamp: auctionStartTimestamp, auctionPeriodSeconds: auctionPeriodSeconds, seller: self.owner?.address)
            } else {
                let oldTransferListing <- self.transferListings[tokenID] <- create TransferListing()
                destroy oldTransferListing

                emit AssetListedForTransfer(assetTokenID: tokenID, salePrice: salePrice, auctionPrice: auctionPrice, auctionStartTimestamp: auctionStartTimestamp, auctionPeriodSeconds: auctionPeriodSeconds, seller: self.owner?.address)
            }
        }

        /// listForRent lists an NFT for rent in this sale collection at the specified price and rental period, or updates an existing listing
        ///
        /// Parameters: tokenID: The id of the NFT to be put up for rent
        ///             price: The rent price of the NFT(This is just returned back as an event)
        ///             rentalPeriodSeconds: The rental period (in seconds)
        access(contract) fun listForRent(tokenID: UInt64, price: UFix64?, rentalPeriodSeconds: UFix64?) {
            pre {
                self.ownerCollection.borrow()!.idExists(id: tokenID):
                    "Asset does not exist in the owner's collection"
            }

            if let rentListing <- self.rentListings.remove(key: tokenID) {
                if(rentalPeriodSeconds != nil) {
                    rentListing.setRentalPeriodSeconds(seconds: rentalPeriodSeconds!)
                }

                let oldRentListing <- self.rentListings[tokenID] <- rentListing
                destroy oldRentListing

                let rentListingRef = (&self.rentListings[tokenID] as &RentListing?)!

                emit AssetRentListingChanged(assetTokenID: tokenID, price: price, rentalPeriodSeconds: rentListingRef.rentalPeriodSeconds, seller: self.owner?.address)
            } else {
                assert(rentalPeriodSeconds != nil, message: "Rental period must be supplied for new listing")

                let oldRentListing <- self.rentListings[tokenID] <- create RentListing(rentalPeriodSeconds: rentalPeriodSeconds!)
                destroy oldRentListing

                emit AssetListedForRent(assetTokenID: tokenID, price: price, rentalPeriodSeconds: rentalPeriodSeconds!, seller: self.owner?.address)
            }
        }

        /// batchListForTransfer lists an array of NFTs for transfer in this transfer collection at the specified price, or updates existing listings
        ///
        /// Parameters: tokenIDs: The array of NFT IDs to be put up for transfer
        ///             salePrice: The sale price of the NFT(This is just returned back as an event)
        ///             auctionPrice: The auction price of the NFT(This is just returned back as an event)
        ///             auctionStartTimestamp: The auction start timestamp
        ///             auctionPeriodSeconds: The period for which auction will last
        access(contract) fun batchListForTransfer(tokenIDs: [UInt64], salePrice: UFix64?, auctionPrice: UFix64?, auctionStartTimestamp: UFix64?, auctionPeriodSeconds: UFix64?) {

            let existingTransferListings: [UInt64] = []
            let nonExistingTransferListings: [UInt64] = []

            for tokenID in tokenIDs {
                if (!self.ownerCollection.borrow()!.idExists(id: tokenID)) {
                    panic("Asset does not exist in the owner's collection: ".concat(tokenID.toString()))
                }

                if self.transferListings.containsKey(tokenID) {
                    existingTransferListings.append(tokenID)
                } else {
                    let oldTransferListing <- self.transferListings[tokenID] <- create TransferListing()
                    destroy oldTransferListing

                    nonExistingTransferListings.append(tokenID)
                }
            }

            if (nonExistingTransferListings.length > 0) {
                emit AssetBatchListedForTransfer(assetTokenIDs: nonExistingTransferListings, salePrice: salePrice, auctionPrice: auctionPrice, auctionStartTimestamp: auctionStartTimestamp, auctionPeriodSeconds: auctionPeriodSeconds, seller: self.owner?.address)
            }

            if (existingTransferListings.length > 0) {
                emit AssetBatchTransferListingChanged(assetTokenIDs: existingTransferListings, salePrice: salePrice, auctionPrice: auctionPrice, auctionStartTimestamp: auctionStartTimestamp, auctionPeriodSeconds: auctionPeriodSeconds, seller: self.owner?.address)
            }
        }

        /// batchListForRent lists an array of NFTs for rent in this sale collection at the specified price and rental period, or updates existing listings
        ///
        /// Parameters: tokenIDs: The array of NFT IDs to be put up for rent
        ///             price: The rent price of the NFT(This is just returned back as an event)
        ///             rentalPeriodSeconds: The rental period (in seconds)
        access(contract) fun batchListForRent(tokenIDs: [UInt64], price: UFix64?, rentalPeriodSeconds: UFix64?) {

            let existingRentListings: [UInt64] = []
            let nonExistingRentListings: [UInt64] = []

            for tokenID in tokenIDs {
                if (!self.ownerCollection.borrow()!.idExists(id: tokenID)) {
                    panic("Asset does not exist in the owner's collection: ".concat(tokenID.toString()))
                }

                if let rentListing <- self.rentListings.remove(key: tokenID) {
                    if(rentalPeriodSeconds != nil) {
                        rentListing.setRentalPeriodSeconds(seconds: rentalPeriodSeconds!)
                    }

                    let oldRentListing <- self.rentListings[tokenID] <- rentListing
                    destroy oldRentListing

                    let rentListingRef = (&self.rentListings[tokenID] as &RentListing?)!

                    existingRentListings.append(tokenID)
                } else {
                    assert(rentalPeriodSeconds != nil, message: "Rental period must be supplied for new listing")

                    let oldRentListing <- self.rentListings[tokenID] <- create RentListing(rentalPeriodSeconds: rentalPeriodSeconds!)
                    destroy oldRentListing

                    nonExistingRentListings.append(tokenID)
                }
            }

            if (nonExistingRentListings.length > 0) {
                emit AssetBatchListedForRent(assetTokenIDs: nonExistingRentListings, price: price, rentalPeriodSeconds: rentalPeriodSeconds!, seller: self.owner?.address)
            }

            if (existingRentListings.length > 0) {
                emit AssetBatchRentListingChanged(assetTokenIDs: existingRentListings, price: price, rentalPeriodSeconds: rentalPeriodSeconds!, seller: self.owner?.address)
            }
        }

        /// cancelTransfer cancels an asset transfer and clears its price
        ///
        /// Parameters: tokenID: the ID of the token to remove from the transfer
        access(contract) fun cancelTransfer(tokenID: UInt64) {
            pre {
                self.transferListings[tokenID] != nil:
                    "Asset not listed for transfer"
            }

            /// Remove the listing from the listing dictionary
            let oldTransferListing <- self.transferListings.remove(key: tokenID)
            destroy oldTransferListing
            
            /// Emit the event for delisting a moment from the Transfer
            emit AssetDelistedForTransfer(assetTokenID: tokenID, owner: self.owner?.address)
        }

        /// cancelRent cancels an asset rent and clears its price
        ///
        /// Parameters: tokenID: the ID of the token to remove from the sale
        access(contract) fun cancelRent(tokenID: UInt64) {
            pre {
                self.rentListings[tokenID] != nil:
                    "Asset not listed for rent"
            }

            /// Remove the listing from the listings dictionary
            let oldRentListing <- self.rentListings.remove(key: tokenID)
            destroy oldRentListing
            
            /// Emit the event for delisting an asset for rent
            emit AssetDelistedForRent(assetTokenID: tokenID, owner: self.owner?.address)
        }

        /// batchCancelTransfer cancels the transfer listings for the array of NFTs
        ///
        /// Parameters: tokenIDs: The array of NFT IDs to be removed for transfer
        access(contract) fun batchCancelTransfer(tokenIDs: [UInt64]) {
            for tokenID in tokenIDs {
                if (self.transferListings[tokenID] == nil) {
                    panic("Asset not listed for transfer: ".concat(tokenID.toString()))
                }

                /// Remove the listing from the listing dictionary
                let oldTransferListing <- self.transferListings.remove(key: tokenID)
                destroy oldTransferListing
            }

            /// Emit the event for delisting a moment from the Transfer
            emit AssetBatchDelistedForTransfer(assetTokenIDs: tokenIDs, owner: self.owner?.address)
        }

        /// batchCancelRent cancels the rent listings for the array of NFTs
        ///
        /// Parameters: tokenIDs: The array of NFT IDs to be removed for rent
        access(contract) fun batchCancelRent(tokenIDs: [UInt64]) {
            for tokenID in tokenIDs {
                if (self.rentListings[tokenID] == nil) {
                    panic("Asset not listed for rent: ".concat(tokenID.toString()))
                }

                /// Remove the listing from the listings dictionary
                let oldRentListing <- self.rentListings.remove(key: tokenID)
                destroy oldRentListing
            }

            /// Emit the event for delisting an asset for rent
            emit AssetBatchDelistedForRent(assetTokenIDs: tokenIDs, owner: self.owner?.address)
        }

        /// purchase lets a user send tokens to purchase an NFT that is for sale
        /// the purchased NFT is returned to the transaction context that called it
        ///
        /// Parameters: tokenID: the ID of the NFT to purchase
        ///             adminAccount: Admin Account
        ///             recipientAddress: Recipient Address
        ///             price: transaction price for the transfer
        ///             paymentID
        access(contract) fun transfer(tokenID: UInt64, adminAccount: &TrmAssetV2_1.Admin, recipientAddress: Address, price: UFix64, paymentID: String) {
            pre {
                self.transferListings.containsKey(tokenID):
                    "No token matching this ID for transfer!"

                self.owner?.address != recipientAddress:
                    "The recipient and owner cannot be same"
            }

            let transferListingRef = (&self.transferListings[tokenID] as &TransferListing?)!

            /// Remove the transfer listing
            if let transferListing <- self.transferListings.remove(key: tokenID) {
                destroy transferListing
            }

            /// Remove for rent listing
            if let rentListing <- self.rentListings.remove(key: tokenID) {
                destroy rentListing
            }

            let boughtAsset <- adminAccount.withdrawAsset(assetCollectionAddress: self.owner!.address, id: tokenID)

            adminAccount.depositAsset(assetCollectionAddress: recipientAddress, token: <-boughtAsset)

            emit AssetTransferred(assetTokenID: tokenID, price: price, seller: self.owner?.address, buyer: recipientAddress, paymentID: paymentID)
        }

        /// rent lets a user send tokens to rent an NFT that is for rent
        /// the newly minted rent NFT is returned to the transaction context that called it
        ///
        /// Parameters: tokenID: the ID of the NFT to purchase
        ///             price: transaction price for the rent
        ///             recipient: Recipient Collection to receive Rent Token
        access(contract) fun rent(tokenID: UInt64, price: UFix64, recipient: Capability<&{TrmRentV2_1.CollectionPublic}>, paymentID: String): UInt64 {
            pre {
                self.rentListings.containsKey(tokenID):
                    "No token matching this ID for rent!"

                recipient.check():
                    "Invalid receiver capability"

                recipient.borrow()!.owner?.address != self.ownerCollection.borrow()!.owner?.address:
                    "The recipient and owner cannot be same"
            }

            let rentListingRef = (&self.rentListings[tokenID] as &RentListing?)!

            /// Read the rental period for the token
            let rentalPeriodSeconds = rentListingRef.rentalPeriodSeconds

            let ownerCollectionRef = self.ownerCollection.borrow()!
            
            assert(ownerCollectionRef.idExists(id: tokenID) == true, message: "Specified token ID not found in owner collection")

            let expiry = rentalPeriodSeconds + getCurrentBlock().timestamp

            let minterRef = TrmMarketV2_1_1.minterCapability.borrow()!

            let kID = ownerCollectionRef.getKID(id: tokenID)
            let assetName = ownerCollectionRef.getAssetName(id: tokenID)
            let assetDescription = ownerCollectionRef.getAssetDescription(id: tokenID)
            let assetURL = ownerCollectionRef.getAssetURL(id: tokenID)
            let assetThumbnailURL = ownerCollectionRef.getAssetThumbnailURL(id: tokenID)
            // let assetMetadata = ownerCollectionRef.getAssetMetadata(id: tokenID)
            let assetMetadata: {String: String} = {}

            let rentTokenID = minterRef.mintNFT(assetTokenID: tokenID, kID: kID, assetName: assetName, assetDescription: assetDescription, assetURL: assetURL, assetThumbnailURL: assetThumbnailURL, assetMetadata: assetMetadata, expiryTimestamp: expiry, recipient: recipient.borrow()!)

            emit AssetRented(assetTokenID: tokenID, rentID: rentTokenID, price: price, expiryTimestamp: expiry, assetName: assetName, assetDescription: assetDescription, assetURL: assetURL, assetThumbnailURL: assetThumbnailURL, assetMetadata: assetMetadata, kID: kID, seller: self.owner?.address, buyer: recipient.borrow()!.owner?.address, rentalPeriodSeconds: rentalPeriodSeconds, paymentID: paymentID)

            return rentTokenID
        }

        /// getTransferListing returns the transfer listing of a specific token in the collection
        /// 
        /// Parameters: tokenID: The ID of the NFT whose listing to get
        ///
        /// Returns: TransferListing: The transfer listing of the token including price
        pub fun getTransferListing(tokenID: UInt64): &TransferListing? {
            if self.transferListings.containsKey(tokenID) {
                return &self.transferListings[tokenID] as &TransferListing?
            }
            return nil
        }

        /// getRentListing returns the rent listing of a specific token in the collection
        /// 
        /// Parameters: tokenID: The ID of the NFT whose listing to get
        ///
        /// Returns: RentListing: The rent listing of the token including price, rental period
        pub fun getRentListing(tokenID: UInt64): &RentListing? {
            if self.rentListings.containsKey(tokenID) {
                return &self.rentListings[tokenID] as &RentListing?
            }
            return nil
        }

        /// getTransferIDs returns an array of token IDs that are for transfer
        pub fun getTransferIDs(): [UInt64] {
            return self.transferListings.keys
        }

        /// getRentIDs returns an array of token IDs that are for sale
        pub fun getRentIDs(): [UInt64] {
            return self.rentListings.keys
        }

        /// borrowAsset Returns a borrowed reference to an Asset in the Collection so that the caller can read data from it
        ///
        /// Parameters: id: The ID of the token to borrow a reference to
        ///
        /// Returns: &TrmAssetV2_1.NFT? Optional reference to a token for transfer so that the caller can read its data
        pub fun borrowAsset(id: UInt64): &TrmAssetV2_1.NFT? {
            /// first check this collection
            if self.transferListings[id] != nil || self.rentListings[id] != nil {
                let ref = self.ownerCollection.borrow()!.borrowAsset(id: id)
                return ref
            } 
            return nil
        }
    }

    /// createCollection returns a new collection resource to the caller
    pub fun createSaleCollection(ownerCollection: Capability<&TrmAssetV2_1.Collection>): @SaleCollection {

        return <- create SaleCollection(ownerCollection: ownerCollection)
    }

    /// Admin is a special authorization resource that 
    /// allows the admin to perform important functions
    pub resource Admin {

        pub fun listForTransfer(
            saleCollectionAddress: Address, 
            tokenID: UInt64, 
            salePrice: UFix64?, 
            auctionPrice: UFix64?,
            auctionStartTimestamp: UFix64?,
            auctionPeriodSeconds: UFix64?
        ) {
            let saleCollectionCapability = getAccount(saleCollectionAddress).getCapability<&TrmMarketV2_1_1.SaleCollection{TrmMarketV2_1_1.SalePublic}>(
                TrmMarketV2_1_1.marketPublicPath
                ).borrow()
            ?? panic("Could not borrow sale collection capability from provided sale collection address")

            saleCollectionCapability.listForTransfer(tokenID: tokenID, salePrice: salePrice, auctionPrice: auctionPrice, auctionStartTimestamp: auctionStartTimestamp, auctionPeriodSeconds: auctionPeriodSeconds)
        }

        pub fun listForRent(
            saleCollectionAddress: Address, 
            tokenID: UInt64, 
            price: UFix64?,
            rentalPeriodSeconds: UFix64?
        ) {
            let saleCollectionCapability = getAccount(saleCollectionAddress).getCapability<&TrmMarketV2_1_1.SaleCollection{TrmMarketV2_1_1.SalePublic}>(
                TrmMarketV2_1_1.marketPublicPath
                ).borrow()
            ?? panic("Could not borrow sale collection capability from provided sale collection address")

            saleCollectionCapability.listForRent(tokenID: tokenID, price: price, rentalPeriodSeconds: rentalPeriodSeconds)
        }

        pub fun batchListForTransfer(
            saleCollectionAddress: Address, 
            tokenIDs: [UInt64], 
            salePrice: UFix64?, 
            auctionPrice: UFix64?,
            auctionStartTimestamp: UFix64?,
            auctionPeriodSeconds: UFix64?
        ) {
            let saleCollectionCapability = getAccount(saleCollectionAddress).getCapability<&TrmMarketV2_1_1.SaleCollection{TrmMarketV2_1_1.SalePublic}>(
                TrmMarketV2_1_1.marketPublicPath
                ).borrow()
            ?? panic("Could not borrow sale collection capability from provided sale collection address")

            saleCollectionCapability.batchListForTransfer(tokenIDs: tokenIDs, salePrice: salePrice, auctionPrice: auctionPrice, auctionStartTimestamp: auctionStartTimestamp, auctionPeriodSeconds: auctionPeriodSeconds)
        }

        pub fun batchListForRent(
            saleCollectionAddress: Address, 
            tokenIDs: [UInt64], 
            price: UFix64?,
            rentalPeriodSeconds: UFix64?
        ) {
            let saleCollectionCapability = getAccount(saleCollectionAddress).getCapability<&TrmMarketV2_1_1.SaleCollection{TrmMarketV2_1_1.SalePublic}>(
                TrmMarketV2_1_1.marketPublicPath
                ).borrow()
            ?? panic("Could not borrow sale collection capability from provided sale collection address")

            saleCollectionCapability.batchListForRent(tokenIDs: tokenIDs, price: price, rentalPeriodSeconds: rentalPeriodSeconds)
        }

        pub fun cancelTransfer(
            saleCollectionAddress: Address, 
            tokenID: UInt64
        ) {
            let saleCollectionCapability = getAccount(saleCollectionAddress).getCapability<&TrmMarketV2_1_1.SaleCollection{TrmMarketV2_1_1.SalePublic}>(
                TrmMarketV2_1_1.marketPublicPath
                ).borrow()
            ?? panic("Could not borrow sale collection capability from provided sale collection address")
            
            saleCollectionCapability.cancelTransfer(tokenID: tokenID)
        }

        pub fun cancelRent(
            saleCollectionAddress: Address, 
            tokenID: UInt64
        ) {
            let saleCollectionCapability = getAccount(saleCollectionAddress).getCapability<&TrmMarketV2_1_1.SaleCollection{TrmMarketV2_1_1.SalePublic}>(
                TrmMarketV2_1_1.marketPublicPath
                ).borrow()
            ?? panic("Could not borrow sale collection capability from provided sale collection address")
            
            saleCollectionCapability.cancelRent(tokenID: tokenID)
        }

        pub fun batchCancelTransfer(
            saleCollectionAddress: Address, 
            tokenIDs: [UInt64]
        ) {
            let saleCollectionCapability = getAccount(saleCollectionAddress).getCapability<&TrmMarketV2_1_1.SaleCollection{TrmMarketV2_1_1.SalePublic}>(
                TrmMarketV2_1_1.marketPublicPath
                ).borrow()
            ?? panic("Could not borrow sale collection capability from provided sale collection address")
            
            saleCollectionCapability.batchCancelTransfer(tokenIDs: tokenIDs)
        }

        pub fun batchCancelRent(
            saleCollectionAddress: Address, 
            tokenIDs: [UInt64]
        ) {
            let saleCollectionCapability = getAccount(saleCollectionAddress).getCapability<&TrmMarketV2_1_1.SaleCollection{TrmMarketV2_1_1.SalePublic}>(
                TrmMarketV2_1_1.marketPublicPath
                ).borrow()
            ?? panic("Could not borrow sale collection capability from provided sale collection address")
            
            saleCollectionCapability.batchCancelRent(tokenIDs: tokenIDs)
        }

        pub fun transfer(
            saleCollectionAddress: Address, 
            tokenID: UInt64,
            assetAdminResource: &TrmAssetV2_1.Admin,
            recipientAddress: Address,
            price: UFix64,
            paymentID: String
        ) {
            let saleCollectionCapability = getAccount(saleCollectionAddress).getCapability<&TrmMarketV2_1_1.SaleCollection{TrmMarketV2_1_1.SalePublic}>(
                TrmMarketV2_1_1.marketPublicPath
                ).borrow()
            ?? panic("Could not borrow sale collection capability from provided sale collection address")
            
            saleCollectionCapability.transfer(tokenID: tokenID, adminAccount: assetAdminResource, recipientAddress: recipientAddress, price: price, paymentID: paymentID)
        }

        pub fun rent(
            saleCollectionAddress: Address, 
            tokenID: UInt64,
            price: UFix64,
            recipient: Capability<&{TrmRentV2_1.CollectionPublic}>,
            paymentID: String
        ): UInt64 {
            let saleCollectionCapability = getAccount(saleCollectionAddress).getCapability<&TrmMarketV2_1_1.SaleCollection{TrmMarketV2_1_1.SalePublic}>(
                TrmMarketV2_1_1.marketPublicPath
                ).borrow()
            ?? panic("Could not borrow sale collection capability from provided sale collection address")
            
            return saleCollectionCapability.rent(tokenID: tokenID, price: price, recipient: recipient, paymentID: paymentID)
        }
    }

    init() {
        // Settings paths
        self.marketStoragePath = /storage/TrmMarketV2_1_1SaleCollection
        self.marketPublicPath = /public/TrmMarketV2_1_1SaleCollection
        self.marketPrivatePath = /private/TrmMarketV2_1_1SaleCollection
        self.adminStoragePath = /storage/TrmMarketV2_1_1Admin

        /// First, check to see if a admin resource already exists
        if self.account.type(at: self.adminStoragePath) == nil {
        
            /// Put the Admin in storage
            self.account.save<@Admin>(<- create Admin(), to: self.adminStoragePath)
        }

        /// obtain Admin's private rent minter capability
        self.minterCapability = self.account.getCapability<&TrmRentV2_1.Minter>(TrmRentV2_1.minterPrivatePath)

        emit ContractInitialized()
    }
}
 