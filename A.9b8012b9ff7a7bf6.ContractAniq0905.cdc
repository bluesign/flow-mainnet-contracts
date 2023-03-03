//  SPDX-License-Identifier: UNLICENSED
//
//  Description: Attack On Titan Legacy
//  This is NonFungibleToken and Anique NFT.
//
//  authors: Atsushi Otani atsushi.ootani@anique.jp
//
import NonFungibleToken from 0x1d7e57aa55817448
import Anique from 0xe2e1689b53e92a82

pub contract ContractAniq0905: NonFungibleToken, Anique {
    // -----------------------------------------------------------------------
    // ContractAniq0905 contract Events
    // -----------------------------------------------------------------------

    // Events for Contract-Related actions
    //
    // Emitted when the ContractAniq0905 contract is created
    pub event ContractInitialized()

    // Events for Item-Related actions
    //
    // Emitted when a new Item struct is created
    pub event ItemCreated(id: UInt32, metadata: {String:String})

    // Events for Collectible-Related actions
    //
    // Emitted when an CollectibleData NFT is minted
    pub event CollectibleMinted(collectibleID: UInt64, itemID: UInt32, serialNumber: UInt32)
    // Emitted when an CollectibleData NFT is destroyed
    pub event CollectibleDestroyed(collectibleID: UInt64)

    // events for Collection-related actions
    //
    // Emitted when an CollectibleData is withdrawn from a Collection
    pub event Withdraw(id: UInt64, from: Address?)
    // Emitted when an CollectibleData is deposited into a Collection
    pub event Deposit(id: UInt64, to: Address?)

    // paths
    pub let collectionStoragePath: StoragePath
    pub let collectionPublicPath: PublicPath
    pub let collectionPrivatePath: PrivatePath
    pub let adminStoragePath: StoragePath
    pub let saleCollectionStoragePath: StoragePath
    pub let saleCollectionPublicPath: PublicPath

    // -----------------------------------------------------------------------
    // ContractAniq0905 contract-level fields.
    // These contain actual values that are stored in the smart contract.
    // -----------------------------------------------------------------------

    // fields for Item-related
    //
    // variable size dictionary of Item resources
    access(self) var items: @{UInt32: Item}

    // The ID that is used to create Items.
    pub var nextItemID: UInt32

    // fields for Collectible-related
    //
    // Total number of CollectibleData NFTs that have been minted ever.
    pub var totalSupply: UInt64

    // -----------------------------------------------------------------------
    // ContractAniq0905 contract-level Composite Type definitions
    // -----------------------------------------------------------------------

    // The structure that represents Item
    // each digital content which ContractAniq0905 deal with on Flow
    //
    pub struct ItemData {

        pub let itemID: UInt32

        pub let metadata: {String: String}

        init(itemID: UInt32) {
            let item = (&ContractAniq0905.items[itemID] as &Item?)!

            self.itemID = item.itemID
            self.metadata = item.metadata
        }
   }

    // Item is a resource type that contains the functions to mint Collectibles.
    //
    // It is stored in a private field in the contract so that
    // the admin resource can call its methods and that there can be
    // public getters for some of its fields
    //
    // The admin can mint Collectibles that refer from Item.
    pub resource Item {

        // unique ID for the Item
        pub let itemID: UInt32

        // Stores all the metadata about the item as a string mapping
        // This is not the long term way NFT metadata will be stored. It's a temporary
        // construct while we figure out a better way to do metadata.
        //
        pub let metadata: {String: String}

        // The number of Collectibles that have been minted per Item.
        access(contract) var numberMintedPerItem: UInt32

        init(metadata: {String: String}) {
            pre {
                metadata.length != 0: "New Item metadata cannot be empty"
            }
            self.itemID = ContractAniq0905.nextItemID
            self.metadata = metadata
            self.numberMintedPerItem = 0

            // increment the nextItemID so that it isn't used again
            ContractAniq0905.nextItemID = ContractAniq0905.nextItemID + 1

            emit ItemCreated(id: self.itemID, metadata: metadata)
        }

        // mintCollectible mints a new Collectible and returns the newly minted Collectible
        //
        // Returns: The NFT that was minted
        //
        pub fun mintCollectible(): @NFT {
            // get the number of Collectibles that have been minted for this Item
            // to use as this Collectible's serial number
            let numInItem = self.numberMintedPerItem

            // mint the new Collectible
            let newCollectible: @NFT <- create NFT(serialNumber: numInItem + 1,
                                              itemID: self.itemID)

            // Increment the count of Collectibles minted for this Item
            self.numberMintedPerItem = numInItem + 1

            return <-newCollectible
        }

        // batchMintCollectible mints an arbitrary quantity of Collectibles
        // and returns them as a Collection
        //
        // Parameters: itemID: the ID of the Item that the Collectibles are minted for
        //             quantity: The quantity of Collectibles to be minted
        //
        // Returns: Collection object that contains all the Collectibles that were minted
        //
        pub fun batchMintCollectible(quantity: UInt64): @Collection {
            let newCollection <- create Collection()

            var i: UInt64 = 0
            while i < quantity {
                newCollection.deposit(token: <-self.mintCollectible())
                i = i + 1
            }

            return <-newCollection
        }

        // Returns: the number of Collectibles
        pub fun getNumberMinted(): UInt32 {
            return self.numberMintedPerItem
        }
    }

    // The structure holds metadata of an Collectible
    pub struct CollectibleData {
        // The ID of the Item that the Collectible references
        pub let itemID: UInt32

        // The place in the Item that this Collectible was minted
        pub let serialNumber: UInt32

        init(itemID: UInt32, serialNumber: UInt32) {
            self.itemID = itemID
            self.serialNumber = serialNumber
        }
    }

    // The resource that represents the CollectibleData NFTs
    //
    pub resource NFT: NonFungibleToken.INFT, Anique.INFT {

        // Global unique collectibleData ID
        pub let id: UInt64

        // Struct of Collectible metadata
        pub let data: CollectibleData

        init(serialNumber: UInt32, itemID: UInt32) {
            // Increment the global Collectible IDs
            ContractAniq0905.totalSupply = ContractAniq0905.totalSupply + 1

            // set id
            self.id = ContractAniq0905.totalSupply

            // Set the metadata struct
            self.data = CollectibleData(itemID: itemID, serialNumber: serialNumber)

            emit CollectibleMinted(collectibleID: self.id, itemID: itemID, serialNumber: self.data.serialNumber)
        }

        destroy() {
            emit CollectibleDestroyed(collectibleID: self.id)
        }
    }

    // interface that represents ContractAniq0905 collections to public
    // extends of NonFungibleToken.CollectionPublic
    pub resource interface CollectionPublic {

        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT

        // deposit multi tokens
        pub fun batchDeposit(tokens: @Anique.Collection)

        // contains NFT
        pub fun contains(id: UInt64): Bool

        // borrow NFT as ContractAniq0905 token
        pub fun borrowContractAniq0905Collectible(id: UInt64): auth &NFT
    }

    // Collection is a resource that every user who owns NFTs
    // will store in their account to manage their NFTs
    //
    pub resource Collection: CollectionPublic, NonFungibleToken.Receiver, NonFungibleToken.Provider, NonFungibleToken.CollectionPublic {
        // Dictionary of CollectibleData conforming tokens
        // NFT is a resource type with a UInt64 ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init() {
            self.ownedNFTs <- {}
        }

        // withdraw removes a Collectible from the Collection and moves it to the caller
        //
        // Parameters: withdrawID: The ID of the NFT
        // that is to be removed from the Collection
        //
        // returns: @NonFungibleToken.NFT the token that was withdrawn
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {

            // Remove the nft from the Collection
            let token <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic("Cannot withdraw: Collectible does not exist in the collection")

            emit Withdraw(id: token.id, from: self.owner?.address)

            // Return the withdrawn token
            return <- token
        }

        // batchWithdraw withdraws multiple tokens and returns them as a Collection
        //
        // Parameters: collectibleIds: An array of IDs to withdraw
        //
        // Returns: @NonFungibleToken.Collection: A collection that contains
        //                                        the withdrawn collectibles
        //
        pub fun batchWithdraw(collectibleIds: [UInt64]): @Anique.Collection {
            // Create a new empty Collection
            var batchCollection <- create Collection()

            // Iterate through the collectibleIds and withdraw them from the Collection
            for collectibleID in collectibleIds {
                batchCollection.deposit(token: <-self.withdraw(withdrawID: collectibleID))
            }

            // Return the withdrawn tokens
            return <-batchCollection
        }

        // deposit takes a Collectible and adds it to the Collections dictionary
        //
        // Parameters: token: the NFT to be deposited in the collection
        //
        pub fun deposit(token: @NonFungibleToken.NFT) {

            // Cast the deposited token as an ContractAniq0905 NFT to make sure
            // it is the correct type
            let token <- token as! @ContractAniq0905.NFT

            // Get the token's ID
            let id = token.id

            // Add the new token to the dictionary
            let oldToken <- self.ownedNFTs[id] <- token

            // Only emit a deposit event if the Collection
            // is in an account's storage
            if self.owner?.address != nil {
                emit Deposit(id: id, to: self.owner?.address)
            }

            // Destroy the empty old token that was "removed"
            destroy oldToken
        }

        // batchDeposit takes a Collection object as an argument
        // and deposits each contained NFT into this Collection
        pub fun batchDeposit(tokens: @Anique.Collection) {

            // Get an array of the IDs to be deposited
            let keys = tokens.getIDs()

            // Iterate through the keys in the collection and deposit each one
            for key in keys {
                self.deposit(token: <-tokens.withdraw(withdrawID: key))
            }

            // Destroy the empty Collection
            destroy tokens
        }

        // getIDs returns an array of the IDs that are in the Collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // contains returns whether ID is in the Collection
        pub fun contains(id: UInt64): Bool {
            return self.ownedNFTs[id] != nil
        }

        // borrowNFT Returns a borrowed reference to a Collectible in the Collection
        // so that the caller can read its ID
        //
        // Parameters: id: The ID of the NFT to get the reference for
        //
        // Returns: A reference to the NFT
        //
        // Note: This only allows the caller to read the ID of the NFT,
        // not any ContractAniq0905 specific data. Please use borrowCollectible to
        // read Collectible data.
        //
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowAniqueNFT(id: UInt64): auth &Anique.NFT {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            return nft as! auth &Anique.NFT
        }

        // borrowContractAniq0905Collectible returns a borrowed reference
        // to an ContractAniq0905 Collectible
        pub fun borrowContractAniq0905Collectible(id: UInt64): auth &NFT {
            pre {
                self.ownedNFTs[id] != nil: "NFT does not exist in the collection!"
            }
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            return nft as! auth &NFT
        }

        // If a transaction destroys the Collection object,
        // All the NFTs contained within are also destroyed!
        //
        destroy() {
            destroy self.ownedNFTs
        }
    }

    // Admin is a special authorization resource that
    // allows the owner to perform important functions to modify the
    // various aspects of the Items, CollectibleDatas, etc.
    //
    pub resource Admin {

        // createItem creates a new Item struct
        // and stores it in the Items dictionary field in the ContractAniq0905 smart contract
        //
        // Parameters: metadata: A dictionary mapping metadata titles to their data
        //                       example: {"Title": "Excellent Anime", "Author": "John Smith"}
        //
        // Returns: the ID of the new Item object
        //
        pub fun createItem(metadata: {String: String}): UInt32 {
            // Create the new Item
            var newItem <- create Item(metadata: metadata)
            let itemId = newItem.itemID

            // Store it in the contract storage
            ContractAniq0905.items[newItem.itemID] <-! newItem

            return itemId
        }

        // borrowItem returns a reference to a Item in the ContractAniq0905
        // contract so that the admin can call methods on it
        //
        // Parameters: itemID: The ID of the Item that you want to
        // get a reference to
        //
        // Returns: A reference to the Item with all of the fields
        // and methods exposed
        //
        pub fun borrowItem(itemID: UInt32): &Item {
            pre {
                ContractAniq0905.items[itemID] != nil: "Cannot borrow Item: The Item doesn't exist"
            }

            return (&ContractAniq0905.items[itemID] as &Item?)!
        }

        // createNewAdmin creates a new Admin resource
        //
        pub fun createNewAdmin(): @Admin {
            return <-create Admin()
        }
    }

    // -----------------------------------------------------------------------
    // ContractAniq0905 contract-level function definitions
    // -----------------------------------------------------------------------

    // createEmptyCollection creates a new, empty Collection object so that
    // a user can store it in their account storage.
    // Once they have a Collection in their storage, they are able to receive
    // Collectibles in transactions.
    //
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <-create ContractAniq0905.Collection()
    }

    // getNumCollectiblesInItem return the number of Collectibles that have been
    //                        minted from a certain Item.
    //
    // Parameters: itemID: The id of the Item that is being searched
    //
    // Returns: The total number of Collectibles
    //          that have been minted from a Item
    pub fun getNumCollectiblesInItem(itemID: UInt32): UInt32 {
        let item = (&ContractAniq0905.items[itemID] as &Item?)!
        return item.numberMintedPerItem
    }

    // -----------------------------------------------------------------------
    // ContractAniq0905 initialization function
    // -----------------------------------------------------------------------
    //
    init() {
        // Initialize contract fields
        self.items <- {}
        self.nextItemID = 1
        self.totalSupply = 0

        self.collectionStoragePath     = /storage/ContractAniq0905Collection
        self.collectionPublicPath      =  /public/ContractAniq0905Collection
        self.collectionPrivatePath     = /private/ContractAniq0905Collection
        self.adminStoragePath          = /storage/ContractAniq0905Admin
        self.saleCollectionStoragePath = /storage/ContractAniq0905SaleCollection
        self.saleCollectionPublicPath  =  /public/ContractAniq0905SaleCollection

        // Put a new Collection in storage
        self.account.save<@Collection>(<- create Collection(), to: self.collectionStoragePath)

        // Create a public capability for the Collection
        self.account.link<&{CollectionPublic}>(self.collectionPublicPath, target: self.collectionStoragePath)

        // Put the Admin in storage
        self.account.save<@Admin>(<- create Admin(), to: self.adminStoragePath)

        emit ContractInitialized()
    }
}