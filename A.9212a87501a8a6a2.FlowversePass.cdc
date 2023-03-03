// MAINNET

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe

pub contract FlowversePass: NonFungibleToken {

    // Events
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event EntityCreated(id: UInt64, metadata: {String:String})
    pub event SetCreated(setID: UInt64, name: String, description: String, externalURL: String, isPrivate: Bool, imageIPFS: String)
    pub event SetUpdated(setID: UInt64, description: String?, externalURL: String?, imageIPFS: String?)
    pub event EntityAddedToSet(setID: UInt64, entityID: UInt64)
    pub event EntityRetiredFromSet(setID: UInt64, entityID: UInt64, numNFTs: UInt64)
    pub event SetLocked(setID: UInt64)
    pub event NFTMinted(nftID: UInt64, nftUUID: UInt64, entityID: UInt64, setID: UInt64, mintNumber: UInt64, minterAddress: Address)
    pub event NFTDestroyed(nftID: UInt64)

    // Named Paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath

    access(self) var entityDatas: {UInt64: Entity}
    access(self) var setDatas: {UInt64: SetData}
    access(self) var sets: @{UInt64: Set}

    // Total number of FlowversePass NFTs that have been minted
    pub var totalSupply: UInt64

    // Incremented ID used to create entities
    pub var nextEntityID: UInt64

    // Incremented ID used to create sets
    pub var nextSetID: UInt64

    // Entity is a Struct that holds metadata associated 
    // with an NFT entity
    // NFTs will all reference a single entity as the owner of
    // its metadata. The entities are publicly accessible, so anyone can
    // read the metadata associated with a specific entity ID
    pub struct Entity {
        // Unique ID for the entity
        pub let entityID: UInt64

        // Stores all the metadata about the entity as a string mapping
        // This is not the long term way NFT metadata will be stored.
        pub let metadata: {String: String}

        init(metadata: {String: String}) {
            pre {
                metadata.length != 0: "New Entity metadata cannot be empty"
            }
            self.entityID = FlowversePass.nextEntityID
            self.metadata = metadata
        }
    }

    // A Set is a group of Entities, like a group of collectibles.
    // An Entity can exist in multiple different sets. 
    // SetData is a struct that is stored in a field of the contract.
    pub struct SetData {

        // Unique ID for the Set
        pub let setID: UInt64

        // Name of the Set
        pub let name: String

        // Description of the Set
        pub let description: String

        // externalURL of the Set
        pub let externalURL: String

        // Image of the Set
        pub let imageIPFS: String

        // Indicates if this Set is listed / available to public
        // e.g. admin may create a private collection for air dropping nfts
        pub var isPrivate: Bool

        init(setID: UInt64, name: String, description: String, externalURL: String, imageIPFS: String, isPrivate: Bool) {
            pre {
                name.length > 0: "New set name cannot be empty"
                description.length > 0: "New set description cannot be empty"
                imageIPFS.length > 0: "New set imageIPFS cannot be empty"
            }
            
            self.setID = setID
            self.name = name
            self.description = description
            self.externalURL = externalURL
            self.imageIPFS = imageIPFS
            self.isPrivate = isPrivate
        }
    }

    // Set is a resource type that contains the functions to add and remove
    // Entities from a set and mint NFTs.
    //
    // It is stored in a private field in the contract so that
    // the admin resource can call its methods.
    //
    // The admin can add Entitys to a Set so that the set can mint NFTs
    // that reference that entity data.
    // The NFTs that are minted by a Set will be listed as belonging to
    // the Set that minted it, as well as the Entity it references.
    // 
    // Admin can also lock Entitys from the Set, meaning that the locked
    // Entity can no longer have NFTs minted from it.
    //
    // If the admin locks the Set, no more Entitys can be added to it, but 
    // NFTs can still be minted.
    //
    // If lockAll() and lock() are called back-to-back, 
    // the Set is closed off forever and nothing more can be done with it.
    pub resource Set {

        // Unique ID for the set
        pub let setID: UInt64

        // Array of entities that are a part of this set.
        // When a entity is added to the set, its ID gets appended here.
        // The ID does not get removed from this array when a entities is locked.
        access(self) var entities: [UInt64]

        // Map of entity IDs that Indicates if a entity in this Set can be minted.
        // When a entities is added to a Set, it is mapped to false (not locked).
        // When a entity is retired, this is set to true and cannot be changed.
        access(self) var retired: {UInt64: Bool}

        // Indicates if the Set is currently locked.
        // When a Set is created, it is unlocked 
        // and entities are allowed to be added to it.
        // When a set is locked, entities cannot be added.
        // A Set can never be changed from locked to unlocked,
        // the decision to lock a Set it is final.
        // If a Set is locked, entities cannot be added, but
        // NFTs can still be minted from entities
        // that exist in the Set.
        pub var locked: Bool

        // Mapping of Entity IDs that indicates the number of NFTs 
        // that have been minted for specific Entitys in this Set.
        // When a NFT is minted, this value is stored in the NFT to
        // show its place in the Set, eg. 13 of 60.
        access(self) var numMintedPerEntity: {UInt64: UInt64}

        pub var totalMinted: UInt64

        init()
         {
            self.setID = FlowversePass.nextSetID
            self.entities = []
            self.retired = {}
            self.locked = false
            self.numMintedPerEntity = {}
            self.totalMinted = 0
        }

        // addEntity adds an entity to the set
        //
        // Parameters: entityID: The ID of the entity that is being added
        //
        // Pre-Conditions:
        // The entity needs to be an existing entity
        // The Set needs to be not locked
        // The entity can't have already been added to the Set
        //
        pub fun addEntity(entityID: UInt64) {
            pre {
                FlowversePass.entityDatas[entityID] != nil: "Cannot add the Entity to Set: Entity doesn't exist."
                !self.locked: "Cannot add the entity to the Set after the set has been locked."
                self.numMintedPerEntity[entityID] == nil: "The entity has already been added to the set."
            }

            // Add the Entity to the array of Plays
            self.entities.append(entityID)

            // Open the Entity up for minting
            self.retired[entityID] = false

            // Initialize the Entity count to zero
            self.numMintedPerEntity[entityID] = 0

            emit EntityAddedToSet(setID: self.setID, entityID: entityID)
        }

        // addEntities adds multiple entities to the Set
        //
        // Parameters: entityIDs: The IDs of the entities that are being added
        //
        pub fun addEntities(entityIDs: [UInt64]) {
            for entity in entityIDs {
                self.addEntity(entityID: entity)
            }
        }

        // retireEntity retires a Entity from the Set so that it can't mint new NFTs
        //
        // Parameters: entityID: The ID of the Entity that is being retired
        //
        // Pre-Conditions:
        // The Entity is part of the Set and not retired (available for minting).
        // 
        pub fun retireEntity(entityID: UInt64) {
            pre {
                self.retired[entityID] != nil: "Cannot retire the entity: Entity doesn't exist in this set!"
            }

            if !self.retired[entityID]! {
                self.retired[entityID] = true

                emit EntityRetiredFromSet(setID: self.setID, entityID: entityID, numNFTs: self.numMintedPerEntity[entityID]!)
            }
        }

        // retireAll retires all the entities in the Set
        // Afterwards, none of the retired entities will be able to mint new instances
        //
        pub fun retireAll() {
            for entity in self.entities {
                self.retireEntity(entityID: entity)
            }
        }

        // lock() locks the Set so that no more Entitys can be added to it
        //
        // Pre-Conditions:
        // The Set should not be locked
        pub fun lock() {
            if !self.locked {
                self.locked = true
                emit SetLocked(setID: self.setID)
            }
        }

        // mint mints a new entity instance and returns the newly minted instance of an entity
        // 
        // Parameters: 
        // entityID: The ID of the Entity that the NFT references
        // minterAddress: The address of the minter
        //
        // Pre-Conditions:
        // The Entity must exist in the Set and be allowed to mint new NFTs
        //
        // Returns: The NFT that was minted
        // 
        pub fun mint(entityID: UInt64, minterAddress: Address): @NFT {
            pre {
                self.retired[entityID] != nil: "Cannot mint: the entity doesn't exist."
                !self.retired[entityID]!: "Cannot mint from this entity: the entity has been retired."
            }

            // Gets the number of NFTs that have been minted for this Entity
            // to use as this NFT's serial number
            let numInEntity = self.numMintedPerEntity[entityID]!

            // Mint the new NFT
            let newNFT: @NFT <- create NFT(mintNumber: numInEntity + UInt64(1),
                                              entityID: entityID,
                                              setID: self.setID,
                                              minterAddress: minterAddress)

            // Increment the number of copies minted for this NFT
            self.numMintedPerEntity[entityID] = numInEntity + UInt64(1)

            self.totalMinted = self.totalMinted + UInt64(1)

            return <-newNFT
        }

        // batchMint mints an arbitrary quantity of NFTs 
        // and returns them as a Collection
        //
        // Parameters: entityID: the ID of the Entity that the NFTs are minted for
        //             quantity: The quantity of NFTs to be minted
        //
        // Returns: Collection object that contains all the NFTs that were minted
        //
        pub fun batchMint(entityID: UInt64, quantity: UInt64, minterAddress: Address): @Collection {
            let newCollection <- create Collection()

            var i: UInt64 = 0
            while i < quantity {
                newCollection.deposit(token: <-self.mint(entityID: entityID, minterAddress: minterAddress))
                i = i + UInt64(1)
            }

            return <-newCollection
        }

        pub fun getEntities(): [UInt64] {
            return self.entities
        }

        pub fun getRetired(): {UInt64: Bool} {
            return self.retired
        }

        pub fun getNumMintedPerEntity(): {UInt64: UInt64} {
            return self.numMintedPerEntity
        }

        pub fun getTotalMinted(): UInt64 {
            return self.totalMinted
        }
    }

    // Struct that contains all of the important data about a set
    // Can be easily queried by instantiating the `QuerySetData` object
    // with the desired set ID
    // let setData = FlowversePass.QuerySetData(setID: 12)
    //
    pub struct QuerySetData {
        pub let setID: UInt64
        pub let name: String
        pub let description: String
        pub let externalURL: String
        pub let imageIPFS: String
        pub let isPrivate: Bool
        access(self) var entities: [UInt64]
        access(self) var retired: {UInt64: Bool}
        pub var locked: Bool
        access(self) var numMintedPerEntity: {UInt64: UInt64}
        pub var totalMinted: UInt64

        init(setID: UInt64) {
            pre {
                FlowversePass.sets[setID] != nil: "The set with the provided ID does not exist"
            }

            let set = (&FlowversePass.sets[setID] as &Set?)!
            let setData = FlowversePass.setDatas[setID]!

            self.setID = setID
            self.name = setData.name
            self.description = setData.description
            self.externalURL = setData.externalURL
            self.imageIPFS = setData.imageIPFS
            self.entities = set.getEntities()
            self.retired = set.getRetired()
            self.locked = set.locked
            self.numMintedPerEntity = set.getNumMintedPerEntity()
            self.totalMinted = set.getTotalMinted()
            self.isPrivate = setData.isPrivate
        }

        pub fun getEntities(): [UInt64] {
            return self.entities
        }

        pub fun getRetired(): {UInt64: Bool} {
            return self.retired
        }

        pub fun getNumMintedPerEntity(): {UInt64: UInt64} {
            return self.numMintedPerEntity
        }
    }

    // NFT Resource that represents the Entity instances
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        // Global unique NFT ID
        pub let id: UInt64

        // The ID of the Set that the NFT comes from
        pub let setID: UInt64

        // The ID of the Entity that the NFT references
        pub let entityID: UInt64

        // The minterAddress of the NFT
        pub let minterAddress: Address

        // The serial number of the NFT, number minted for this entity in the set
        pub let mintNumber: UInt64

        init(mintNumber: UInt64, entityID: UInt64, setID: UInt64, minterAddress: Address) {
            // Increment the global NFT ID
            FlowversePass.totalSupply = FlowversePass.totalSupply + UInt64(1)

            self.id = FlowversePass.totalSupply

            self.mintNumber = mintNumber
            self.entityID = entityID
            self.setID = setID
            self.minterAddress = minterAddress

            emit NFTMinted(nftID: self.id, nftUUID: self.uuid, entityID: entityID, setID: self.setID, mintNumber: self.mintNumber, minterAddress: self.minterAddress)
        }

        // If the NFT is destroyed, emit an event to indicate 
        // to outside observers that it has been destroyed
        destroy() {
            emit NFTDestroyed(nftID: self.id)
        }

        pub fun name(): String {
            let name: String = FlowversePass.getEntityMetaDataByField(entityID: self.entityID, field: "name") ?? ""
            return name.concat(" #").concat(self.mintNumber.toString())
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Edition>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.Medias>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            let fileExtension = FlowversePass.getEntityMetaDataByField(entityID: self.entityID, field: "fileExtension") ?? ""
            switch view {
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: FlowversePass.CollectionStoragePath,
                        publicPath: FlowversePass.CollectionPublicPath,
                        providerPath: /private/FlowversePassCollection,
                        publicCollection: Type<&FlowversePass.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, FlowversePass.CollectionPublic, MetadataViews.ResolverCollection}>(),
                        publicLinkedType: Type<&FlowversePass.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, FlowversePass.CollectionPublic, MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&FlowversePass.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, FlowversePass.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
                        createEmptyCollection: (fun(): @NonFungibleToken.Collection {return <- FlowversePass.createEmptyCollection()})
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let querySetData = FlowversePass.getSetData(setID: self.setID)!
                    let squareImage = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://flowverse-mystery-pass.s3.filebase.com/mainnet/squareImage.jpg"
                        ),
                        mediaType: "image/jpg"
                    )
                    let bannerImage = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://flowverse-mystery-pass.s3.filebase.com/mainnet/bannerImage.jpg"
                        ),
                        mediaType: "image/jpg"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: querySetData.name,
                        description: querySetData.description,
                        externalURL: MetadataViews.ExternalURL(querySetData.externalURL),
                        squareImage: squareImage,
                        bannerImage: bannerImage,
                        socials: {
                            "discord": MetadataViews.ExternalURL("https://discord.gg/flowverse"),
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/flowverse_"),
                            "instagram": MetadataViews.ExternalURL("https://www.instagram.com/flowverseofficial")
                        }
                    )
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name(),
                        description: FlowversePass.getEntityMetaDataByField(entityID: self.entityID, field: "description") ?? "",
                        thumbnail: MetadataViews.HTTPFile(url: "https://flowverse-mystery-pass.s3.filebase.com/mainnet/nft_thumbnail.gif")
                    )
                case Type<MetadataViews.Royalties>():
                    let feeReceiverAddress: Address = 0x604b63bcbef5974f
                    let feeCut: UFix64 = 0.05
                    let royalties : [MetadataViews.Royalty] = [
                        MetadataViews.Royalty(
                            receiver: getAccount(feeReceiverAddress).getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)!,
                            cut: feeCut,
                            description: "Creator Royalty Fee")
                    ]
                    return MetadataViews.Royalties(cutInfos: royalties)
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(self.mintNumber)
                case Type<MetadataViews.Edition>():
                    return MetadataViews.Edition(
                        name: FlowversePass.getEntityMetaDataByField(entityID: self.entityID, field: "name") ?? "",
                        number: self.mintNumber,
                        max: 1111
                    )
                case Type<MetadataViews.Traits>():
                    return MetadataViews.Traits([])
                case Type<MetadataViews.ExternalURL>():
                    let baseURL = "https://nft.flowverse.co/collections/FlowversePass/"
                    return MetadataViews.ExternalURL(baseURL.concat(self.owner!.address.toString()).concat("/".concat(self.id.toString())))
                case Type<MetadataViews.Medias>():
                    let video = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://flowverse-mystery-pass.s3.filebase.com/mainnet/nft.".concat(fileExtension)
                        ),
                        mediaType: "video/".concat(fileExtension)
                    )
                    return MetadataViews.Medias([video])
            }

            return nil
        }   
    }

    pub resource SetMinter {
        pub let setID: UInt64

        init(setID: UInt64) {
            self.setID = setID
        }

        pub fun mint(entityID: UInt64, minterAddress: Address): @NFT {
            let setRef = (&FlowversePass.sets[self.setID] as &Set?)!
            return <- setRef.mint(entityID: entityID, minterAddress: minterAddress)
        }
    }

    // Admin is a special authorization resource that 
    // allows the owner to perform important functions to modify the 
    // various aspects of the Entities, Sets, and NFTs
    //
    pub resource Admin {

        // createEntity creates a new Entity struct 
        // and stores it in the Entities dictionary in the FlowversePass smart contract
        pub fun createEntity(metadata: {String: String}): UInt64 {
            // Create the new Entity
            var newEntity = Entity(metadata: metadata)
            let newID = newEntity.entityID

            // Increment the ID so that it isn't used again
            FlowversePass.nextEntityID = FlowversePass.nextEntityID + UInt64(1)

            // Store it in the contract storage
            FlowversePass.entityDatas[newID] = newEntity
            
            emit EntityCreated(id: newID, metadata: metadata)

            return newID
        }

        // createSet creates a new Set resource and stores it
        // in the sets mapping in the contract
        pub fun createSet(name: String, description: String, externalURL: String, imageIPFS: String, isPrivate: Bool): UInt64 {
            // Create a new SetData for this Set
            let setData = SetData(
                setID: FlowversePass.nextSetID,
                name: name,
                description: description,
                externalURL: externalURL,
                imageIPFS: imageIPFS,
                isPrivate: isPrivate
            )

            // Create the new Set
            var newSet <- create Set()

             // Increment the setID so that it isn't used again
            FlowversePass.nextSetID = FlowversePass.nextSetID + UInt64(1)
            
            let newID = newSet.setID

            emit SetCreated(setID: newID, name: name, description: description, externalURL: externalURL, isPrivate: isPrivate, imageIPFS: imageIPFS)

            // Store in contract storage
            FlowversePass.setDatas[newID] = setData
            FlowversePass.sets[newID] <-! newSet

            return newID
        }
        
        // updateSetData updates set info including: description, externalURL, imageIPFS
        pub fun updateSetData(setID: UInt64, description: String?, externalURL: String?, imageIPFS: String?) {
            pre {
                FlowversePass.setDatas.containsKey(setID): "Set data does not exist"
                FlowversePass.sets.containsKey(setID): "Set data does not exist"
                FlowversePass.sets[setID]?.locked == false: "Locked set data cannot be updated"
            }
            var setData = FlowversePass.setDatas[setID]!
            let updatedSetData = SetData(
                setID: setID,
                name: setData.name,
                description: description ?? setData.description,
                externalURL: externalURL ?? setData.externalURL,
                imageIPFS: imageIPFS ?? setData.imageIPFS,
                isPrivate: setData.isPrivate
            )
            FlowversePass.setDatas[setID] = updatedSetData
            emit SetUpdated(setID: setID, description: description, externalURL: externalURL, imageIPFS: imageIPFS)
        }

        // borrowSet returns a reference to a set in the contract
        // so that the admin can call methods on it
        pub fun borrowSet(setID: UInt64): &Set {
            pre {
                FlowversePass.sets[setID] != nil: "Cannot borrow Set: The Set doesn't exist"
            }
            
            // Get a reference to the Set and return it
            // use `&` to indicate the reference to the object and type
            return (&FlowversePass.sets[setID] as &Set?)!
        }

        pub fun createSetMinter(setID: UInt64): @SetMinter {
            return <- create SetMinter(setID: setID)
        }

        // createNewAdmin creates a new Admin resource
        pub fun createNewAdmin(): @Admin {
            return <-create Admin()
        }
    }

    // Public interface for the FlowversePass Collection that allows users access to certain functionalities
    pub resource interface CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun batchDeposit(tokens: @NonFungibleToken.Collection)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowFlowversePassNFT(id: UInt64): &FlowversePass.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow FlowversePass reference: The ID of the returned reference is incorrect"
            }
        }
        pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver}
    }

    // Collection
    // A collection of FlowversePass NFTs owned by an account
    pub resource Collection: CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // Dictionary of entity instances conforming tokens
        // NFT is a resource type with a UInt64 ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <-token
        }

        pub fun batchWithdraw(ids: [UInt64]): @NonFungibleToken.Collection {
            var batchCollection <- create Collection()
            for id in ids {
                batchCollection.deposit(token: <-self.withdraw(withdrawID: id))
            }
            return <-batchCollection
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @FlowversePass.NFT
            let id: UInt64 = token.id
            let oldToken <- self.ownedNFTs[id] <- token
            emit Deposit(id: id, to: self.owner?.address)
            destroy oldToken
        }

        pub fun batchDeposit(tokens: @NonFungibleToken.Collection) {
            let keys = tokens.getIDs()
            for key in keys {
                self.deposit(token: <-tokens.withdraw(withdrawID: key))
            }
            destroy tokens
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowFlowversePassNFT(id: UInt64): &FlowversePass.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &FlowversePass.NFT
            } else {
                return nil
            }
        }
        
        pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)! 
            let flowverseNFT = nft as! &FlowversePass.NFT
            return flowverseNFT as &{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // -----------------------------------------------------------------------
    // FlowversePass contract-level function definitions
    // -----------------------------------------------------------------------

    // createEmptyCollection
    // public function that anyone can call to create a new empty collection
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create FlowversePass.Collection()
    }

    // getAllEntities returns all the entities available
    pub fun getAllEntities(): [FlowversePass.Entity] {
        return FlowversePass.entityDatas.values
    }

    // getEntity returns an entity by ID
    pub fun getEntity(entityID: UInt64): FlowversePass.Entity? {
        return self.entityDatas[entityID]
    }

    // getEntityMetaData returns all the metadata associated with a specific Entity
    pub fun getEntityMetaData(entityID: UInt64): {String: String}? {
        return self.entityDatas[entityID]?.metadata
    }
    
    pub fun getEntityMetaDataByField(entityID: UInt64, field: String): String? {
        if let entity = FlowversePass.entityDatas[entityID] {
            return entity.metadata[field]
        } else {
            return nil
        }
    }


    // getSetData returns the data that the specified Set
    //            is associated with.
    // 
    // Parameters: setID: The id of the Set that is being searched
    //
    // Returns: The QuerySetData struct that has all the important information about the set
    pub fun getSetData(setID: UInt64): QuerySetData? {
        if FlowversePass.sets[setID] == nil {
            return nil
        } else {
            return QuerySetData(setID: setID)
        }
    }
    
    // getSetName returns the name that the specified Set
    //            is associated with.
    // 
    // Parameters: setID: The id of the Set that is being searched
    //
    // Returns: The name of the Set
    pub fun getSetName(setID: UInt64): String? {
        // Don't force a revert if the setID is invalid
        return FlowversePass.setDatas[setID]?.name
    }

    // getSetIDsByName returns the IDs that the specified Set name
    //                 is associated with.
    pub fun getSetIDsByName(setName: String): [UInt64]? {
        var setIDs: [UInt64] = []

        for setData in FlowversePass.setDatas.values {
            if setName == setData.name {
                setIDs.append(setData.setID)
            }
        }

        if setIDs.length == 0 {
            return nil
        } else {
            return setIDs
        }
    }

    // getAllSetDatas returns all the set datas available
    pub fun getAllSetDatas(): [SetData] {
        return FlowversePass.setDatas.values
    }

    // getEntitiesInSet returns the list of Entity IDs that are in the Set
    pub fun getEntitiesInSet(setID: UInt64): [UInt64]? {
        return FlowversePass.sets[setID]?.getEntities()
    }

    // isSetEntityRetired returns a boolean that indicates if a Set/Entity combination
    //                  is retired.
    //                  If an entity is retired, it still remains in the Set,
    //                  but NFTs can no longer be minted from it.
    pub fun isSetEntityRetired(setID: UInt64, entityID: UInt64): Bool? {
        if let setdata = self.getSetData(setID: setID) {
            // See if the Entity is retired from this Set
            let retired = setdata.getRetired()[entityID]

            // Return the retired status
            return retired
        } else {
            // If the Set wasn't found, return nil
            return nil
        }
    }

    pub fun isSetLocked(setID: UInt64): Bool? {
        return FlowversePass.sets[setID]?.locked
    }

    // getNumInstancesOfEntity return the number of entity instances that have been 
    //                        minted in a set.
    //
    // Parameters: setID: The id of the Set that is being searched
    //             entityID: The id of the Entity that is being searched
    //
    // Returns: The total number of entity instances (NFTs) 
    //          that have been minted in a set
    pub fun getNumInstancesOfEntity(setID: UInt64, entityID: UInt64): UInt64? {
        if let setdata = self.getSetData(setID: setID) {
            // return numMintedPerEntity
            return setdata.getNumMintedPerEntity()[entityID]
        } else {
            // If the set wasn't found return nil
            return nil
        }
    }

    // -----------------------------------------------------------------------
    // FlowversePass initialization function
    // -----------------------------------------------------------------------
    //
    init() {
        self.CollectionStoragePath = /storage/FlowversePassCollection
        self.CollectionPublicPath = /public/FlowversePassCollection
        self.AdminStoragePath = /storage/FlowversePassAdmin

        // Initialize contract fields
        self.entityDatas = {}
        self.setDatas = {}
        self.sets <- {}
        self.nextEntityID = 1
        self.nextSetID = 1
        self.totalSupply = 0

        // Put a new Collection in storage
        self.account.save<@Collection>(<- create Collection(), to: self.CollectionStoragePath)

        // Create a public capability for the Collection
        self.account.link<&Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, CollectionPublic, MetadataViews.ResolverCollection}>(self.CollectionPublicPath, target: self.CollectionStoragePath)

        // Put the Admin resource in storage
        self.account.save<@Admin>(<- create Admin(), to: self.AdminStoragePath)

        emit ContractInitialized()
    }
}
