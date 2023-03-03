/*
    Description: Smart contract for FridgeMagnetV1

    This smart contract is the main and has the core functionality for 
    FridgeMagnetV1's Tester.

    It contains "Admin" resource for performing the essential tasks.
    Admin can mint a new NFT, which will be stored in the contract -> to be sent
    to the users (using transaction) in the next stage.

    The contract has "Collection" resource, an obj that every NFT owner will 
    store in their account to hold the NFT they own.

    This main account will have its own NFT collection to hold the NFTs that will
    be sent to the users on the platform's logics.

 */

// These both imports' accounts are for test, 
// Emulator -> 0xf8d6e0586b0a20c7, Testnet -> 0x631e88ae7f1d7c20, for mainnet -> 0x1d7e57aa55817448
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract FridgeMagnetV1: NonFungibleToken {

    // Path constants declaration (so that paths don't have to be hard coded)
    // in transaction && scripts

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath

    // Events -----------------

    // Emitted when FridgeMagnetV1 is created
    pub event ContractInitialized()

    // Emitted when an NFT is withdrawn
    pub event Withdraw(id: UInt64, from: Address?)

    // Emitted when an NFT is deposited
    pub event Deposit(id: UInt64, to: Address?)

    // Emitted when an NFT is minted
    pub event NFTMinted(NFTID: UInt64, setID: UInt32, serialNumber: UInt32, mintingDate: UFix64)

    // Emitted when a Set is created
    pub event SetCreated(setID: UInt32)

    // Variables -----------------

    // Variable's dictionary of Set struct
    access(self) var setDatas: {UInt32: SetData}

    // Variable's dictionary of Set resource
    access(self) var sets: @{UInt32: Set}

    // The ID used to create the new Sets
    // When a new Set is created, setID is assigned to this, then it increases by 1
    pub var nextSetID: UInt32

    // Total number of FridgeMagnetV1's NFTs that have been "minted" to date (mint counter)
    // and to be used as global NFT IDs
    pub var totalSupply: UInt64

    // Contract-level Composite Type Definitions -----------------

    // SetData is a struct to hold name and metadata associated with a specific collectible
    // NFTs will reference to an individual Set as the owner of its name and metadata
    // It is publicly accessible so anyone can read it with a getter function at the end of this contract
    // TODO: Improve fields var for easier tracking the data (eg. Set of drops on specific time; Edition/Weekly drops)
    pub struct SetData {
        // The unique ID for the Set
        pub let setID: UInt32

        // Name of the Set
        pub let name: String

        // Description of the Set
        pub let description: String

        // Image of the Set
        pub let image: String

        access(self) var metadata: {String: AnyStruct}

        init(
            name: String, 
            description: String, 
            image: String,
            metadata: {String: AnyStruct},
        ) {
            pre {
                name.length > 0: "A new Set name cannot be empty"
                description.length > 0: "A new Set description cannot be empty"
                image.length != 0: "A new Set image cannot be empty"
                metadata.length != 0: "A new Set metadata cannot be empty"
            }
            self.setID = FridgeMagnetV1.nextSetID
            self.name = name
            self.description = description
            self.image = image
            self.metadata = metadata
        }

        pub fun getMetadata(): {String: AnyStruct} {
            return self.metadata
        }
    }

    // Set is a resource that hold the functions to mainly mint NFTs
    // Only Admin resource has the ability to perform these; It is stored in a private field in the contract
    // NFTs are minted by a Set and listed in the Set that minted them.
    pub resource Set {
        // The unique ID for the Set
        pub let setID: UInt32
        
        // Number of NFTs minted per this Set
        // Value is stored in the NFT as for example: ---> 74 /105 (number 74 out of 105 in total)
        access(contract) var numberNFTMintedPerSet: UInt32

        init(
            name: String,
            description: String,
            image: String,
            metadata: {String: AnyStruct}
        ) {
            self.setID = FridgeMagnetV1.nextSetID
            self.numberNFTMintedPerSet = 0

            // Create and store SetData for this set in the account's storage
            FridgeMagnetV1.setDatas[self.setID] = SetData(
                name: name, 
                description: description, 
                image: image,
                metadata: metadata
            )
        }

        // mintNFT is a function to mint a new NFT on the specific Set
        // Param: setID -> ID of the Set 
        // Return: A minted NFT
        pub fun mintNFT(): @NFT {
            // Get the number of NFT that already minted in this Set
            let numNFTInSet = self.numberNFTMintedPerSet

            // Mint new NFT
            let newNFT: @NFT <- create NFT(
                setID: self.setID,
                serialNumber: numNFTInSet + UInt32(1)
            )

            // Increase count for NFT in this Set by 1
            self.numberNFTMintedPerSet = numNFTInSet + UInt32(1)

            // Note: Don't need to worry about increasing nextSetID && totalSupply for future use
            // It's implemented in createSet && NFT's init()

            return <-newNFT
        }

        // Batch minter
        pub fun batchMintNFT(quantity: UInt64): @Collection {
            let newNFTCollection <- create Collection()

            var i: UInt64 = 0
            while i < quantity {
                newNFTCollection.deposit(token: <-self.mintNFT())
                i = i + UInt64(1)
            }

            return <-newNFTCollection
        }

        pub fun getNumberNFTMintedPerSet(): UInt32 {
            return self.numberNFTMintedPerSet
        }
    }

    // Struct that has all the Set's data
    // Used by getSetData (see the end of this contract)
    pub struct QuerySetData {
        // Declare all the fields we want to query
        pub let setID: UInt32
        pub let name: String
        pub let description: String
        pub let numberNFTMintedPerSet: UInt32

        init(setID: UInt32) {
            pre {
                FridgeMagnetV1.sets[setID] != nil: "The Set with this ID doesn't exist : message from getSetData"
            }

            let set = (&FridgeMagnetV1.sets[setID] as &Set?)!
            let setData = FridgeMagnetV1.setDatas[setID]!

            self.setID = setID
            self.name = setData.name
            self.description = setData.description
            self.numberNFTMintedPerSet = set.numberNFTMintedPerSet
        }

        pub fun getNumberNFTMintedPerSet(): UInt32 {
            return self.numberNFTMintedPerSet
        }

    }

    // Struct for NFT data
    // ***Place this for future use*** eg. Add some extra data to 
    pub struct NFTData {
        // The ID of the Set that the NFT references to
        pub let setID: UInt32

        // Identifier; no. of NFT in a specific Set ( -->74 / 105)
        pub let serialNumber: UInt32

        // Put minting date (unix timestamp) on the NFT
        pub let mintingDate: UFix64

        init(
            setID: UInt32,
            serialNumber: UInt32,
        ) {
            self.setID = setID
            self.serialNumber = serialNumber
            self.mintingDate = getCurrentBlock().timestamp
        }
    }

    // Custom struct to be used in resolveView
    pub struct FridgeMagnetV1CustomViews {
        // All the var we want to view
        pub let name: String
        pub let description: String
        pub let image: String

        pub let setID: UInt32
        pub let serialNumber: UInt32
        pub let totalNFTInSet: UInt32?

        pub let externalUrl: String?
        pub let location: String?
        pub let mintingDate: UFix64

        init(
            name: String,
            description: String,
            image: String,
            setID: UInt32,
            serialNumber: UInt32,
            totalNFTInSet: UInt32?,
            externalUrl: String?,
            location: String?,
            mintingDate: UFix64
        ) {
            self.name = name
            self.description = description
            self.image = image
            self.setID = setID
            self.serialNumber = serialNumber
            self.totalNFTInSet = totalNFTInSet
            self.externalUrl = externalUrl
            self.location = location
            self.mintingDate = mintingDate
        }
    }

    // Resource that represents NFTs
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        // The global unique ID for each NFT
        pub let id: UInt64

        // Struct of NFT metadata
        pub let data: NFTData

        init(
            setID: UInt32,
            serialNumber: UInt32,
        ) {
            // Increase "global NFT IDs" by 1 (Start with 1 in the contract sequel)
            FridgeMagnetV1.totalSupply = FridgeMagnetV1.totalSupply + UInt64(1)

            // Assign to as global unique ID
            self.id = FridgeMagnetV1.totalSupply

            // Set the data struct
            self.data = NFTData(setID: setID, serialNumber: serialNumber)

            emit NFTMinted(NFTID: self.id, setID: self.data.setID, serialNumber: self.data.serialNumber, mintingDate: self.data.mintingDate)
        }

        // Functions for resolveView function

        pub fun name(): String {
            let name: String = FridgeMagnetV1.getSetName(setID: self.data.setID) ?? ""

            return name
        }

        pub fun description(): String {
            let description: String = FridgeMagnetV1.getSetDescription(setID: self.data.setID) ?? ""
            let number: String = self.data.serialNumber.toString()

            return description
                .concat(" #")
                .concat(number)
        }

        pub fun image(): String {
            let image: String = FridgeMagnetV1.getSetImage(setID: self.data.setID) ?? ""

            return image
        }

        pub fun getSetMetadataByField(field: String): AnyStruct? {
            if let set = FridgeMagnetV1.setDatas[self.data.setID] {
                return set.getMetadata()[field]
            } else {
                return nil
            }
            
        }

        
        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<FridgeMagnetV1CustomViews>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name(),
                        description: self.description(),
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.image()
                        )
                    )
                case Type<FridgeMagnetV1CustomViews>():

                    let externalUrl = self.getSetMetadataByField(field: "externalUrl") ?? ""
                    let location = self.getSetMetadataByField(field: "location") ?? ""

                    return FridgeMagnetV1CustomViews(
                        name: self.name(),
                        description: self.description(),
                        image: self.image(),
                        setID: self.data.setID,
                        serialNumber: self.data.serialNumber,
                        totalNFTInSet: FridgeMagnetV1.getTotalNFTInSet(setID: self.data.setID),
                        externalUrl: externalUrl as? String,
                        location: location as? String,
                        mintingDate: self.data.mintingDate
                    )
            }

            return nil
        }
    }

    // Resource that is owned by Admin or smart contract
    // it allows them to call functions inside
    pub resource Admin {
        // This func creates (mints) a new Set with new ID in this contract storage
        // Param: name -> name of the Set
        // Return: ID of the created Set
        pub fun createSet(name: String, description: String, image: String, metadata: {String: AnyStruct}): UInt32 {
            // Create new Set
            var newSet <- create Set(name: name, description: description, image: image, metadata: metadata)

            // Increase nextSetID by 1
            FridgeMagnetV1.nextSetID = FridgeMagnetV1.nextSetID + UInt32(1)

            let newSetID = newSet.setID

            emit SetCreated(setID: newSetID)

            // Store the new Set in the account's storage
            FridgeMagnetV1.sets[newSetID] <-! newSet

            return newSetID
        }

        // This func returns a reference to the Set
        // For Admin to call it and mint NFT on the borrowed Set (transaction)
        // Param: setID -> ID of the Set we want to call
        // Return: A reference to the Set (w/all fields & methods)
        pub fun borrowSet(setID: UInt32): &Set {
            pre {
                FridgeMagnetV1.sets[setID] != nil: "Set doesn't exist, please check"
            }

            return (&FridgeMagnetV1.sets[setID] as &Set?)!
        }
        
        // This func creates new Admin resource
        pub fun createNewAdmin(): @Admin {
            return <-create Admin()
        }
    }


    // This interface allows users to borrow the functions inside publicly to perform tasks
    pub resource interface NFTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowFridgeMagnetV1NFT(id: UInt64): &FridgeMagnetV1.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow ExampleNFT reference: the ID of the returned reference is incorrect"
            }
        }
    }

    // Collection is a main resource for "every" user to store their owned NFTs in their accounts
    pub resource Collection: NFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // Dictionary of NFT conforming tokens
        // NFT is a resource type with an UInt64 ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        // Initialize NFTs field to an empty Collection
        init() {
            self.ownedNFTs <- {}
        }

        // withdraw removes an NFT from the Collection and moves it to the caller
        // Param: withdrawID -> ID of the NFT
        // Return: token (: @NonFungibleToken.NFT)
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID)
                ?? panic ("Cannot withdraw: This collection does not contain an NFT with this ID")
            
            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit is a function that takes a NFT as an argument and adds it to
        // the Collection dictionary
        // Param: token -> the NFT that will be deposited to the Collection
        pub fun deposit(token: @NonFungibleToken.NFT) {
            // Make sure that the token has the correct type (as our @FridgeMagnetV1.NFT)
            let token <- token as! @FridgeMagnetV1.NFT
            
            // Get the token's ID
            let id: UInt64 = token.id

            // Add the new token to the dictionary
            let oldToken <- self.ownedNFTs[id] <- token

            // Trigger event to let listeners know that the NFT was deposited
            emit Deposit(id: id, to: self.owner?.address)

            // Destroy the old token
            destroy oldToken
        }

        // getIDs returns an array of the IDs that are in the Collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT returns a borrowed reference to NFT in the Collection
        // Param: id -> ID of the NFT we want to get reference
        // Return: A reference to the NFT
        // Caller can only read its ID
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        // borrowFridgeMagnetV1NFT returns a borrowed reference to NFT in the Collection
        // Param: id -> ID of the NFT we want to get reference
        // Return: A reference to the NFT
        // Caller can read data and call methods
        // setID, serialNumber, or use it to call getSetData(setID)
        pub fun borrowFridgeMagnetV1NFT(id: UInt64): &FridgeMagnetV1.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &FridgeMagnetV1.NFT
            } else {
                return nil
            }           
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let FridgeMagnetV1NFT = nft as! &FridgeMagnetV1.NFT
            return FridgeMagnetV1NFT as &AnyResource{MetadataViews.Resolver}
        }

        // Need to destroy the placeholder Collection
        destroy() {
            destroy self.ownedNFTs
        }
    }

    // Contract-level Function Definitions -----------------

    // createEmptyCollection creates a new, empty Collection for users
    // Once they create this in their storage they can receive the NFTs
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <-create FridgeMagnetV1.Collection()
    }

    // getAllSets returns all Set and values
    // Return: An array of all created Sets
    pub fun getAllSets(): [FridgeMagnetV1.SetData] {
        return FridgeMagnetV1.setDatas.values
    }

    // getTotalNFTinSet returns the number of NFTs that has been minted in a Set
    // Param: setID -> ID of the Set we are searching
    // Return: Total number of NFTs minted in a Set
    pub fun getTotalNFTInSet(setID: UInt32): UInt32? {
        if let setdata = self.getSetData(setID: setID) {
            let total = setdata.getNumberNFTMintedPerSet()

            return total
        } else {
            return nil
        }
    }

    // getSetData returns data of the Set
    // Param: setID -> ID of the Set we are searching
    // Return: QuerySetData struct
    pub fun getSetData(setID: UInt32): QuerySetData? {
        if FridgeMagnetV1.sets[setID] == nil {
            return nil
        } else {
            return QuerySetData(setID: setID)
        }
    }

    // getSetName returns name of the Set
    // Param: setID -> ID of the Set we are searching
    // Return: Name of the Set
    pub fun getSetName(setID: UInt32): String? {
        return FridgeMagnetV1.setDatas[setID]?.name
    }

    // getSetDescription returns description of the Set
    // Param: setID -> ID of the Set we are searching
    // Return: Description of the Set
    pub fun getSetDescription(setID: UInt32): String? {
        return FridgeMagnetV1.setDatas[setID]?.description
    }

    // getSetImage returns image of the Set
    // Param: setID -> ID of the Set we are searching
    // Return: An image of the Set
    pub fun getSetImage(setID: UInt32): String? {
        return FridgeMagnetV1.setDatas[setID]?.image
    }

    // Add more func to call for the business logics HERE ^^^
    // 
    // -----------------

    // Initialize fields
    init() {
        self.setDatas = {}
        self.sets <- {}
        self.nextSetID = 1
        self.totalSupply = 0

        self.CollectionStoragePath = /storage/FridgeMagnetV1Collection
        self.CollectionPublicPath = /public/FridgeMagnetV1Collection
        self.AdminStoragePath = /storage/FridgeMagnetV1Admin

        // Create an NFT Collection on the account storage
        let collection <- create Collection()
        self.account.save<@Collection>(<-collection, to: self.CollectionStoragePath)

        // Publish a reference to the Collection in the storage (public capability)
        self.account.link<&{NFTCollectionPublic}>(self.CollectionPublicPath, target: self.CollectionStoragePath)

        // Store a minter resource in storage
        self.account.save<@Admin>(<-create Admin(), to: self.AdminStoragePath)

        emit ContractInitialized()
    }
}