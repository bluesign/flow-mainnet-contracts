/*
    Description: Smart contract for FridgeMagnet

    This smart contract is the main and has the core functionality for 
    FridgeMagnet's application.

    It contains "Admin" resource for performing the essential tasks.
    Admin can create a new Set, which holds the details of NFTs FridgeMagnet's
    business users have issued to their customers.

    The contract has "Collection" resource, an object that every NFT owner will 
    store in their account to hold the NFT they own/receive.

    This main account performs minting process to creator address indicated
    inside the component and only them can distribute the NFTs.

 */

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe

pub contract FridgeMagnet: NonFungibleToken {

    // Path constants declaration (so that paths don't have to be hard coded)
    // in transaction && scripts

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath

    // Events -----------------

    // Emitted when FridgeMagnet is created
    pub event ContractInitialized()

    // Emitted when an NFT is withdrawn
    pub event Withdraw(id: UInt64, from: Address?)

    // Emitted when an NFT is deposited
    pub event Deposit(id: UInt64, to: Address?)

    // Emitted when an NFT is minted
    pub event NFTMinted(NFTID: UInt64, setID: UInt64, serialNumber: UInt64, creator: Address, mintingDate: UFix64)

    // Emitted when a Set is created
    pub event SetCreated(setID: UInt64)

    // Emitted when a Set is modified data
    pub event SetUpdated(setID: UInt64, name: String)

    // Emitted when a Set's transferrable is changed
    pub event UpdateTransferrable(setID: UInt64, transferrable: Bool)

    // Emitted when locking a Set
    pub event SetLocked(setID: UInt64, name: String)

    // Emitted when unlocking a Set
    pub event SetUnlocked(setID: UInt64, name: String)

    // Variables -----------------

    // Variable's dictionary of Set struct
    access(self) var setDatas: {UInt64: SetData}

    // Variable's dictionary of Set resource
    access(self) var sets: @{UInt64: Set}

    // The ID used to create the new Sets
    // When a new Set is created, setID is assigned to this, then it increases by 1
    pub var nextSetID: UInt64

    // Total number of FridgeMagnet's NFTs that have been "minted" to date (mint counter)
    // and to be used as global NFT IDs
    pub var totalSupply: UInt64

    // Contract-level Composite Type Definitions -----------------

    // SetData is a struct to hold name and metadata associated with a specific collectible
    // NFTs will reference to an individual Set as the owner of its name and metadata
    // It is publicly accessible so anyone can read it with a getter function at the end of this contract
    // TODO: Improve fields var for easier tracking the data (eg. Set of drops on specific time; Edition/Weekly drops)
    pub struct SetData {
        // The unique ID for the Set
        pub let setID: UInt64

        // Name of the Set
        pub let name: String

        // Description of the Set
        pub let description: String

        // Image of the Set
        pub let image: String

        access(self) var metadata: {String: AnyStruct}

        // Set limited NFT allowed to mint per Set
        pub let limitNFT: UInt64?

        // Set if the NFT is transferrable or not
        pub var transferrable: Bool

        init(
            setID: UInt64,
            name: String, 
            description: String, 
            image: String,
            metadata: {String: AnyStruct},
            limitNFT: UInt64?,
            transferrable: Bool,
        ) {
            pre {
                name.length > 0: "A new Set name cannot be empty"
                description.length > 0: "A new Set description cannot be empty"
                image.length != 0: "A new Set image cannot be empty"
                metadata.length != 0: "A new Set metadata cannot be empty"
            }
            self.setID = setID
            self.name = name
            self.description = description
            self.image = image
            self.metadata = metadata
            self.limitNFT = limitNFT
            self.transferrable = transferrable
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
        pub let setID: UInt64
        
        // Number of NFTs minted per this Set
        // Value is stored in the NFT as for example: ---> 74 /105 (number 74 out of 105 in total)
        access(contract) var numberNFTMintedPerSet: UInt64

        pub var locked: Bool

        init(
            name: String,
            description: String,
            image: String,
            metadata: {String: AnyStruct},
            limitNFT: UInt64?,
            transferrable: Bool,
        ) {
            self.setID = FridgeMagnet.nextSetID
            self.numberNFTMintedPerSet = 0
            self.locked = false

            // Create and store SetData for this set in the account's storage
            FridgeMagnet.setDatas[self.setID] = SetData(
                setID: self.setID,
                name: name, 
                description: description, 
                image: image,
                metadata: metadata,
                limitNFT: limitNFT,
                transferrable: transferrable,
            )
        }

        // mintNFT is a function to mint a new NFT on the specific Set
        // Param: setID -> ID of the Set 
        // Return: A minted NFT
        pub fun mintNFT(creator: Address): @NFT {
            // If Set is locked, minter cannot mint new NFTs
            pre {
                !self.locked: "Cannot Mint: This Set is locked"
            }
            
            // Get the number of NFT that already minted in this Set
            let numNFTInSet = self.numberNFTMintedPerSet

            if let limitNFT = FridgeMagnet.setDatas[self.setID]!.limitNFT {
                if UInt64(numNFTInSet) >= limitNFT {
                    panic("This Set has reached limited NFT allowed to mint")
                }
            }

            // Mint new NFT
            let newNFT: @NFT <- create NFT(
                setID: self.setID,
                serialNumber: numNFTInSet + UInt64(1),
                creator: creator
            )

            // Increase count for NFT in this Set by 1
            self.numberNFTMintedPerSet = numNFTInSet + UInt64(1)

            // Note: Don't need to worry about increasing nextSetID && totalSupply for future use
            // It's implemented in createSet && NFT's init()

            return <-newNFT
        }

        // Batch minter
        pub fun batchMintNFT(quantity: UInt64, creator: Address): @Collection {
            let newNFTCollection <- create Collection()

            var i: UInt64 = 0
            while i < quantity {
                newNFTCollection.deposit(token: <-self.mintNFT(creator: creator))
                i = i + UInt64(1)
            }

            return <-newNFTCollection
        }

        pub fun getNumberNFTMintedPerSet(): UInt64 {
            return self.numberNFTMintedPerSet
        }

        pub fun updateName(newName: String) {
            pre {
                newName.length > 0: "An update Set name cannot be empty!!!"
                !self.locked: "Cannot update: This Set is locked"
            }

            let oldSetData = FridgeMagnet.setDatas[self.setID]!

            FridgeMagnet.setDatas[self.setID] = SetData(
                setID: self.setID,
                name: newName, 
                description: oldSetData.description, 
                image: oldSetData.image,
                metadata: oldSetData.getMetadata(),
                limitNFT: oldSetData.limitNFT,
                transferrable: oldSetData.transferrable,
            )

            emit SetUpdated(setID: self.setID, name: oldSetData.name)
        }

        pub fun updateDescription(newDescription: String) {
            pre {
                newDescription.length > 0: "An update Set description cannot be empty!!!"
                !self.locked: "Cannot update: This Set is locked"
            }

            let oldSetData = FridgeMagnet.setDatas[self.setID]!

            FridgeMagnet.setDatas[self.setID] = SetData(
                setID: self.setID,
                name: oldSetData.name, 
                description: newDescription, 
                image: oldSetData.image,
                metadata: oldSetData.getMetadata(),
                limitNFT: oldSetData.limitNFT,
                transferrable: oldSetData.transferrable,
            )

            emit SetUpdated(setID: self.setID, name: oldSetData.name)
        }

        pub fun updateImage(newImage: String) {
            pre {
                newImage.length != 0: "An update Set image cannot be empty!!!"
                !self.locked: "Cannot update: This Set is locked"
            }

            let oldSetData = FridgeMagnet.setDatas[self.setID]!

            FridgeMagnet.setDatas[self.setID] = SetData(
                setID: self.setID,
                name: oldSetData.name, 
                description: oldSetData.description, 
                image: newImage,
                metadata: oldSetData.getMetadata(),
                limitNFT: oldSetData.limitNFT,
                transferrable: oldSetData.transferrable,
            )

            emit SetUpdated(setID: self.setID, name: oldSetData.name)
        }

        pub fun updateMetadata(newMetadata: {String: AnyStruct}) {
            pre {
                newMetadata.length != 0 : "An update Metadata cannot be empty!!!"
                !self.locked: "Cannot update: This Set is locked"
            }

            let oldSetData = FridgeMagnet.setDatas[self.setID]!

            FridgeMagnet.setDatas[self.setID] = SetData(
                setID: self.setID,
                name: oldSetData.name, 
                description: oldSetData.description, 
                image: oldSetData.image,
                metadata: newMetadata,
                limitNFT: oldSetData.limitNFT,
                transferrable: oldSetData.transferrable,
            )

            emit SetUpdated(setID: self.setID, name: oldSetData.name)
        }

        pub fun toggleTransferrable() {
            
            let oldSetData = FridgeMagnet.setDatas[self.setID]!

            // Toggle true <-> false
            var newTransferrable = !oldSetData.transferrable

            FridgeMagnet.setDatas[self.setID] = SetData(
                setID: self.setID,
                name: oldSetData.name, 
                description: oldSetData.description, 
                image: oldSetData.image,
                metadata: oldSetData.getMetadata(),
                limitNFT: oldSetData.limitNFT,
                transferrable: newTransferrable,
            )

            emit UpdateTransferrable(setID: self.setID, transferrable: newTransferrable)
        }

        pub fun lock() {
            pre {
                self.locked == false: "This Set is already locked"
            }

            self.locked = true

            emit SetLocked(setID: self.setID, name: FridgeMagnet.setDatas[self.setID]!.name)
        }

        pub fun unlock() {
            pre {
                self.locked == true: "This Set is already unlocked"
            }

            self.locked = false

            emit SetUnlocked(setID: self.setID, name: FridgeMagnet.setDatas[self.setID]!.name)
        }
    }

    // Struct that has all the Set's data
    // Used by getSetData (see the end of this contract)
    pub struct QuerySetData {
        // Declare all the fields we want to query
        pub let setID: UInt64
        pub let name: String
        pub let description: String
        pub let numberNFTMintedPerSet: UInt64
        pub let limitNFT: UInt64?
        pub var transferrable: Bool
        pub var locked: Bool

        init(setID: UInt64) {
            pre {
                FridgeMagnet.sets[setID] != nil: "The Set with this ID doesn't exist : message from getSetData"
            }

            let set = (&FridgeMagnet.sets[setID] as &Set?)!
            let setData = FridgeMagnet.setDatas[setID]!

            self.setID = setID
            self.name = setData.name
            self.description = setData.description
            self.numberNFTMintedPerSet = set.numberNFTMintedPerSet
            self.limitNFT = setData.limitNFT
            self.transferrable = setData.transferrable
            self.locked = set.locked
        }

        pub fun getNumberNFTMintedPerSet(): UInt64 {
            return self.numberNFTMintedPerSet
        }

    }

    // Struct for NFT data
    pub struct NFTData {
        // The ID of the Set that the NFT references to
        pub let setID: UInt64

        // Identifier; no. of NFT in a specific Set ( -->74 / 105)
        pub let serialNumber: UInt64

        // Points to Creator of the NFT
        pub let creator: Address

        // Put minting date (unix timestamp) on the NFT
        pub let mintingDate: UFix64

        init(
            setID: UInt64,
            serialNumber: UInt64,
            creator: Address,
        ) {
            self.setID = setID
            self.serialNumber = serialNumber
            self.creator = creator
            self.mintingDate = getCurrentBlock().timestamp
        }
    }

    // Custom struct to be used in resolveView
    pub struct FridgeMagnetMetadataView {
        // All the var we want to view
        pub let name: String
        pub let description: String
        pub let image: String

        pub let setID: UInt64
        pub let serialNumber: UInt64
        pub let totalNFTInSet: UInt64?
        pub let limitNFT: UInt64?
        pub var transferrable: Bool

        pub let externalUrl: String?

        pub var isVirtual: Bool?

        pub let location: String?
        pub let businessName: String?
        pub let type: String?
        pub let additionalData: String?
        pub let mintingDate: UFix64

        init(
            name: String,
            description: String,
            image: String,
            setID: UInt64,
            serialNumber: UInt64,
            totalNFTInSet: UInt64?,
            limitNFT: UInt64?,
            transferrable: Bool,
            externalUrl: String?,
            isVirtual: Bool?,
            location: String?,
            businessName: String?,
            type: String?,
            additionalData: String?,
            mintingDate: UFix64
        ) {
            self.name = name
            self.description = description
            self.image = image
            self.setID = setID
            self.serialNumber = serialNumber
            self.totalNFTInSet = totalNFTInSet
            self.limitNFT = limitNFT
            self.transferrable = transferrable
            self.externalUrl = externalUrl
            self.isVirtual = isVirtual
            self.location = location
            self.businessName = businessName
            self.type = type
            self.additionalData = additionalData
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
            setID: UInt64,
            serialNumber: UInt64,
            creator: Address,
        ) {
            // Increase "global NFT IDs" by 1 (Start with 1 in the contract sequel)
            FridgeMagnet.totalSupply = FridgeMagnet.totalSupply + UInt64(1)

            // Assign to as global unique ID
            self.id = FridgeMagnet.totalSupply

            // Set the data struct
            self.data = NFTData(setID: setID, serialNumber: serialNumber, creator: creator)

            emit NFTMinted(NFTID: self.id, setID: self.data.setID, serialNumber: self.data.serialNumber, creator: self.data.creator, mintingDate: self.data.mintingDate)
        }

        // Functions for resolveView function

        pub fun name(): String {
            let name: String = FridgeMagnet.getSetName(setID: self.data.setID) ?? ""

            return name
        }

        pub fun description(): String {
            let description: String = FridgeMagnet.getSetDescription(setID: self.data.setID) ?? ""
            let number: String = self.data.serialNumber.toString()

            return description
        }

        pub fun image(): String {
            let image: String = FridgeMagnet.getSetImage(setID: self.data.setID) ?? ""

            return image
        }

        pub fun limitNFT(): UInt64? {
            let limitNFT: UInt64? = FridgeMagnet.getSetLimitNFT(setID: self.data.setID)

            return limitNFT        
        }

        pub fun transferrable(): Bool {
            var transferrable: Bool = FridgeMagnet.setDatas[self.data.setID]?.transferrable ?? false

            return transferrable
        }

        pub fun getSetMetadataByField(field: String): AnyStruct? {
            if let set = FridgeMagnet.setDatas[self.data.setID] {
                return set.getMetadata()[field]
            } else {
                return nil
            }
        }
        
        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>(),
                Type<FridgeMagnetMetadataView>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name(),
                        description: self.description(),
                        thumbnail: MetadataViews.IPFSFile(
                            cid: self.image(), path: nil
                        )
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties([
                        MetadataViews.Royalty(
                            recipient: getAccount(0x6349b46b05716b13).getCapability<&AnyResource{FungibleToken.Receiver}>(MetadataViews.getRoyaltyReceiverPublicPath()),
                            cut: 0.05, // just in case somebody put the NFT for "secondary sale"
                            description: "FridgeMagnet takes 5% secondary sales royalty"
                        )
                    ])
                case Type<MetadataViews.ExternalURL>():

                    let businessName = self.getSetMetadataByField(field: "businessName") ?? ""
                    let business = businessName as! String

                    return MetadataViews.ExternalURL(
                        "https://www.fridgemagnet.xyz/nft/editions/space/".concat(self.data.setID.toString())
                    )
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: FridgeMagnet.CollectionStoragePath,
                        publicPath: FridgeMagnet.CollectionPublicPath,
                        providerPath: /private/CollectionPrivatePath,
                        publicCollection: Type<&FridgeMagnet.Collection{FridgeMagnet.NFTCollectionPublic}>(),
                        publicLinkedType: Type<&FridgeMagnet.Collection{FridgeMagnet.NFTCollectionPublic, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&FridgeMagnet.Collection{FridgeMagnet.NFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <- FridgeMagnet.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let squareMedia = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                           url: "https://www.fridgemagnet.xyz/Flow_squareImage.png"
                        ),
                        mediaType: "image/png"
                    )
                    let bannerMedia = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://www.fridgemagnet.xyz/Flow_bannerImage.png"
                        ),
                        mediaType: "image/png"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "FridgeMagnet",
                        description: "FridgeMagnet makes creating and managing NFT membership campaigns accessible.",
                        externalURL: MetadataViews.ExternalURL("https://www.fridgemagnet.xyz"),
                        squareImage: squareMedia,
                        bannerImage: bannerMedia,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/FridgemagnetXYZ")
                        }
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.data.serialNumber
                    )
                case Type<FridgeMagnetMetadataView>():

                    var isVirtual = self.getSetMetadataByField(field: "isVirtual") ?? false

                    let location = self.getSetMetadataByField(field: "location") ?? ""
                    let businessName = self.getSetMetadataByField(field: "businessName") ?? ""
                    let type = self.getSetMetadataByField(field: "type") ?? ""
                    let additionalData = self.getSetMetadataByField(field: "additionalData") ?? ""

                    let business = businessName as! String
                    let externalUrl = "https://www.fridgemagnet.xyz/nft/editions/space/".concat(self.data.setID.toString())

                    return FridgeMagnetMetadataView(
                        name: self.name(),
                        description: self.description(),
                        image: self.image(),
                        setID: self.data.setID,
                        serialNumber: self.data.serialNumber,
                        totalNFTInSet: FridgeMagnet.getTotalNFTInSet(setID: self.data.setID),
                        limitNFT: self.limitNFT(),
                        transferrable: self.transferrable(),
                        externalUrl: externalUrl as? String,
                        isVirtual: isVirtual as? Bool,
                        location: location as? String,
                        businessName: businessName as? String,
                        type: type as? String,
                        additionalData: additionalData as? String,
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
        pub fun createSet(name: String, description: String, image: String, metadata: {String: AnyStruct}, limitNFT: UInt64?, transferrable: Bool): UInt64 {
            // Create new Set
            var newSet <- create Set(name: name, description: description, image: image, metadata: metadata, limitNFT: limitNFT, transferrable: transferrable)

            // Increase nextSetID by 1
            FridgeMagnet.nextSetID = FridgeMagnet.nextSetID + UInt64(1)

            let newSetID = newSet.setID

            emit SetCreated(setID: newSetID)

            // Store the new Set in the account's storage
            FridgeMagnet.sets[newSetID] <-! newSet

            return newSetID
        }

        // This func returns a reference to the Set
        // For Admin to call it and mint NFT on the borrowed Set (transaction)
        // Param: setID -> ID of the Set we want to call
        // Return: A reference to the Set (w/all fields & methods)
        pub fun borrowSet(setID: UInt64): &Set {
            pre {
                FridgeMagnet.sets[setID] != nil: "Set doesn't exist, please check"
            }

            return (&FridgeMagnet.sets[setID] as &Set?)!
        }
        
        // This func creates new Admin resource
        pub fun createNewAdmin(): @Admin {
            return <-create Admin()
        }
    }


    // This interface allows users to borrow the functions inside publicly to perform tasks
    pub resource interface NFTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun batchDeposit(tokens: @NonFungibleToken.Collection)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowFridgeMagnetNFT(id: UInt64): &FridgeMagnet.NFT? {
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
            let nft <- token as! @FridgeMagnet.NFT

            // Cannot transfer if not transferrable
            // Creator has privilage to transfer (to users)
            if !nft.transferrable() && self.owner?.address != nft.data.creator {
                panic("This NFT is not transferrable")
            }
            
            
            emit Withdraw(id: nft.id, from: self.owner?.address)

            return <-nft
        }

        // batchWithdraw removes NFTs from the Collection and moves them to the caller
        // Param: withdrawIDs -> array of IDs of the NFTs
        // Return: A Collection containing NFTs (: @NonFungibleToken.Collection)
        pub fun batchWithdraw(withdrawIDs: [UInt64]): @NonFungibleToken.Collection {
            // Create empty Collection to put withdrawed NFTs in
            var collection <- create Collection()

            for withdrawID in withdrawIDs {
                collection.deposit(token: <-self.withdraw(withdrawID: withdrawID))
            }

            return <-collection
        }

        // deposit is a function that takes a NFT as an argument and adds it to
        // the Collection dictionary
        // Param: token -> the NFT that will be deposited to the Collection
        pub fun deposit(token: @NonFungibleToken.NFT) {
            // Make sure that the token has the correct type (as our @FridgeMagnet.NFT)
            let token <- token as! @FridgeMagnet.NFT
            
            // Get the token's ID
            let id: UInt64 = token.id

            // Add the new token to the dictionary
            let oldToken <- self.ownedNFTs[id] <- token

            // Trigger event to let listeners know that the NFT was deposited
            emit Deposit(id: id, to: self.owner?.address)

            // Destroy the old token
            destroy oldToken
        }

        // batchDeposit is a function that takes a Collection of NFTs as an argument
        // and adds each of them to the the Collection dictionary
        pub fun batchDeposit(tokens: @NonFungibleToken.Collection) {
            // Get an array of IDs in the Collection
            let keys = tokens.getIDs()
            
            // Deposite each key
            for key in keys {
                self.deposit(token: <-tokens.withdraw(withdrawID: key))
            }

            // Destroy the tokens
            destroy tokens
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

        // borrowFridgeMagnetNFT returns a borrowed reference to NFT in the Collection
        // Param: id -> ID of the NFT we want to get reference
        // Return: A reference to the NFT
        // Caller can read data and call methods
        // setID, serialNumber, or use it to call getSetData(setID)
        pub fun borrowFridgeMagnetNFT(id: UInt64): &FridgeMagnet.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &FridgeMagnet.NFT
            } else {
                return nil
            }           
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let FridgeMagnetNFT = nft as! &FridgeMagnet.NFT
            return FridgeMagnetNFT as &AnyResource{MetadataViews.Resolver}
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
        return <-create FridgeMagnet.Collection()
    }

    // getAllSets returns all Set and values
    // Return: An array of all created Sets
    pub fun getAllSets(): [FridgeMagnet.SetData] {
        return FridgeMagnet.setDatas.values
    }

    // getTotalNFTinSet returns the number of NFTs that has been minted in a Set
    // Param: setID -> ID of the Set we are searching
    // Return: Total number of NFTs minted in a Set
    pub fun getTotalNFTInSet(setID: UInt64): UInt64? {
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
    pub fun getSetData(setID: UInt64): QuerySetData? {
        if FridgeMagnet.sets[setID] == nil {
            return nil
        } else {
            return QuerySetData(setID: setID)
        }
    }

    // getSetName returns name of the Set
    // Param: setID -> ID of the Set we are searching
    // Return: Name of the Set
    pub fun getSetName(setID: UInt64): String? {
        return FridgeMagnet.setDatas[setID]?.name
    }

    // getSetDescription returns description of the Set
    // Param: setID -> ID of the Set we are searching
    // Return: Description of the Set
    pub fun getSetDescription(setID: UInt64): String? {
        return FridgeMagnet.setDatas[setID]?.description
    }

    // getSetImage returns image of the Set
    // Param: setID -> ID of the Set we are searching
    // Return: An image of the Set
    pub fun getSetImage(setID: UInt64): String? {
        return FridgeMagnet.setDatas[setID]?.image
    }

    // getSetLimitNFT returns limitNFT of the Set
    // Param: setID -> ID of the Set we are searching
    // Return: A limit amount of NFT in the Set
    pub fun getSetLimitNFT(setID: UInt64): UInt64? {
        return FridgeMagnet.setDatas[setID]?.limitNFT
    }

    // isSetLocked checks if Set is locked or not
    // Param: setID -> ID of the Set we are checking
    // Return: Bool
    pub fun isSetLocked(setID: UInt64): Bool? {
        return FridgeMagnet.sets[setID]?.locked
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

        self.CollectionStoragePath = /storage/FridgeMagnetCollection
        self.CollectionPublicPath = /public/FridgeMagnetCollection
        self.AdminStoragePath = /storage/FridgeMagnetAdmin

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