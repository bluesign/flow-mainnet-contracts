
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

/*
    Genies is structured similarly to TopShot.
    Unlike TopShot, we use resources for all entities and manage access to their data
    by copying it to structs (this simplifies access control, in particular write access).
    We also encapsulate resource creation for the admin in member functions on the parent type.
    
    There are 4 levels of entity:
    1. Series.
    2. Genies Collection (not to be confused with an NFT Collection).
    3. Edition.
    4. Genies NFT (an NFT).
    Each exists conceptually within the thing above it.
    And each must be created or closed by the thing above it.

    Note that we cache some information (Series names/ids, counts of deactivated entities) rather
    than calculate it each time.
    This is enabled by encapsulation and saves gas for entity lifecycle operations.

    Note that the behaviours of Series.closeAllCollections(), Series.deactivate(), and Series.init()
    are kept separate to allow ending one series in various ways without starting another.
    They are called in the correct order in Admin.advanceSeries().
 */

// The Genies NFTs and metadata contract
//
pub contract Genies: NonFungibleToken {
    //------------------------------------------------------------
    // Events
    //------------------------------------------------------------

    // Contract Events
    //
    pub event ContractInitialized()

    // NFT Collection (not Genies Collection!) Events
    //
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    // Series Events
    //
    // Emitted when a new series has been triggered by an admin
    pub event NewSeriesStarted(newCurrentSeries: UInt32, name: String, metadata: {String: String})
    pub event SeriesDeactivated(id: UInt32)

    // Collection Events
    //
    pub event CollectionCreated(id: UInt32, seriesID: UInt32, name: String, metadata: {String: String})
    pub event CollectionClosed(id: UInt32)

    // Edition Events
    //
    pub event EditionCreated(id: UInt32, collectionID: UInt32, name: String, metadata: {String: String})
    pub event EditionRetired(id: UInt32)

    // NFT Events
    //
    pub event NFTMinted(id: UInt64, editionID: UInt32, serialNumber: UInt32)
    pub event NFTBurned(id: UInt64)

    //------------------------------------------------------------
    // Named values
    //------------------------------------------------------------

    // Named Paths
    //
    pub let CollectionStoragePath:  StoragePath
    pub let CollectionPublicPath:   PublicPath
    pub let AdminStoragePath:       StoragePath
    pub let MinterPrivatePath:      PrivatePath

    //------------------------------------------------------------
    // Publcly readable contract state
    //------------------------------------------------------------

    // Entity Counts
    //
    pub var totalSupply:        UInt64
    pub var currentSeriesID:    UInt32
    pub var nextCollectionID:   UInt32
    pub var nextEditionID:    UInt32

    //------------------------------------------------------------
    // Internal contract state
    //------------------------------------------------------------

    // Metadata Dictionaries
    //
    // This is so we can find Series by their names (via seriesByID)
    access(self) let seriesIDByName:    {String: UInt32}
    // This avoids storing Series in an array where the index is off by one
    access(self) let seriesByID:        @{UInt32: Series}
    access(self) let collectionByID:    @{UInt32: GeniesCollection}
    access(self) let editionByID:     @{UInt32: Edition}

    //------------------------------------------------------------
    // Series
    //------------------------------------------------------------

    // A public struct to access Series data
    //
    pub struct SeriesData {
        pub let id: UInt32
        pub let name: String
        pub let metadata: {String: String}
        pub let active: Bool
        pub let collectionIDs: [UInt32]
        pub let collectionsOpen: UInt32

        // initializer
        //
        init (id: UInt32) {    
            let series = (&Genies.seriesByID[id] as &Genies.Series?)!
            self.id = series.id
            self.name = series.name
            self.metadata = series.metadata
            self.active = series.active
            self.collectionIDs = series.collectionIDs
            self.collectionsOpen = series.collectionsOpen
        }
    }

    // A top-level Series with a unique ID and name
    //
    pub resource Series {
        pub let id: UInt32
        pub let name: String
        // Contents writable if borrowed!
        // This is deliberate, as it allows admins to update the data.
        pub let metadata: {String: String}
        // We manage this list, but need to access it to fill out the struct,
        // so it is access(contract)
        access(contract) let collectionIDs: [UInt32]
        pub var collectionsOpen: UInt32
        pub var active: Bool

        // Deactivate this series
        //
        pub fun deactivate() {
            pre {
                self.active == true: "not active"
                self.collectionsOpen == 0: "must closeAllCollections before deactivating"
            }

            self.active = false

            emit SeriesDeactivated(id: self.id)
        }

        // Create and add a collection to the series.
        // You can only do so via this function, which updates the relevant fields.
        //
        pub fun addCollection(
            collectionName: String,
            collectionMetadata: {String: String}
        ): UInt32 {
            pre {
                self.active == true: "Cannot add collection to previous series"
            }

            let collection <- create Genies.GeniesCollection(
                seriesID: self.id,
                name: collectionName,
                metadata: collectionMetadata
            )
            let collectionID = collection.id
            Genies.collectionByID[collectionID] <-! collection
            self.collectionIDs.append(collectionID)
            self.collectionsOpen = self.collectionsOpen + 1 as UInt32

            return collectionID
        }

        // Close a collection, and update the relevant fields
        //
        pub fun closeGeniesCollection(collectionID: UInt32) {
            pre {
                Genies.collectionByID[collectionID] != nil: "no such collectionID"
            }

            let collection = (&Genies.collectionByID[collectionID] as &Genies.GeniesCollection?)!
            collection.close()
            // Add this check to fix the underflow issue caused by the mismatch of collectionsOpen and actual Open counts.
            // Remove the if check in the next release 
            if self.collectionsOpen > 0 {
                self.collectionsOpen = self.collectionsOpen - 1 as UInt32
            }   
        }

        // Recursively ensure that all of the collections are closed,
        // and all the editions in each are retired,
        // allowing advanceSeries to proceed
        //
        pub fun closeAllGeniesCollections() {
            for collectionID in self.collectionIDs {
                let collection = (&Genies.collectionByID[collectionID] as &Genies.GeniesCollection?)!
                if collection.open {
                    collection.retireAllEditions()
                    self.closeGeniesCollection(collectionID: collectionID)
                }
            }
        }

        // initializer
        // We pass in ID as the logic for it is more complex than it should be,
        // and we don't want to spread it out.
        //
        init (id: UInt32, name: String, metadata: {String: String}) {
            pre {
                !Genies.seriesIDByName.containsKey(name): "A Series with that name already exists"
            }

            self.id = id
            self.name = name
            self.metadata = metadata
            self.collectionIDs = []
            self.collectionsOpen = 0 as UInt32
            self.active = true

            emit NewSeriesStarted(
                newCurrentSeries: self.id,
                name: self.name,
                metadata: self.metadata
            )
        }
    }

    // Get the publicly available data for a Series by id
    //
    pub fun getSeriesData(id: UInt32): Genies.SeriesData {
        pre {
            Genies.seriesByID[id] != nil: "Cannot borrow series, no such id"
        }

        return Genies.SeriesData(id: id)
    }

    // Get the publicly available data for a Series by name
    //
    pub fun getSeriesDataByName(name: String): Genies.SeriesData {
        pre {
            Genies.seriesIDByName[name] != nil: "Cannot borrow series, no such name"
        }

        let id = Genies.seriesIDByName[name]!

        return Genies.SeriesData(id: id)
    }

    // Get all series names (this will be *long*)
    //
    pub fun getAllSeriesNames(): [String] {
        return Genies.seriesIDByName.keys
    }

    // Get series id for name
    //
    pub fun getSeriesIDByName(name: String): UInt32? {
        return Genies.seriesIDByName[name]
    }

    //------------------------------------------------------------
    // GeniesCollection
    //------------------------------------------------------------

    // A public struct to access GeniesCollection data
    //
    pub struct GeniesCollectionData {
        pub let id: UInt32
        pub let seriesID: UInt32
        pub let name: String
        pub let metadata: {String: String}
        pub let open: Bool
        pub let editionIDs: [UInt32]
        pub let editionsActive: UInt32

        // initializer
        //
        init (id: UInt32) {
            let collection = (&Genies.collectionByID[id] as &Genies.GeniesCollection?)!
            self.id = id
            self.seriesID = collection.seriesID
            self.name = collection.name
            self.metadata = collection.metadata
            self.open = collection.open
            self.editionIDs = collection.editionIDs
            self.editionsActive = collection.editionsActive
        }
    }

    // A Genies collection (not to be confused with a NonFungibleToken.Collection) within a series
    //
    pub resource GeniesCollection {
        pub let id: UInt32
        pub let seriesID: UInt32
        pub let name: String
        // Contents writable if borrowed!
        // This is deliberate, as it allows admins to update the data.
        pub let metadata: {String: String}
        pub var open: Bool
        // We manage this list, but need to access it to fill out the struct,
        // so it is access(contract)
        access(contract) let editionIDs: [UInt32]
        pub var editionsActive: UInt32

        // Create and add an Edition to the collection.
        // You can only do so via this function, which updates the relevant fields.
        //
        pub fun addEdition(
            editionName: String,
            editionMetadata: {String: String}
        ): UInt32 {
            pre {
                self.open == true: "Cannot add edition to closed collection"
            }
            let edition <- create Genies.Edition(
                collectionID: self.id,
                name: editionName,
                metadata: editionMetadata
            )

            let editionID = edition.id
            Genies.editionByID[editionID] <-! edition
            self.editionIDs.append(editionID)
            self.editionsActive = self.editionsActive + 1 as UInt32

            return editionID
        }

        // Update metadata field of an Edition to the collection
        //
        pub fun updateEdition(
            editionID: UInt32,
            editionMetadata: {String: String}
        ) {
            pre {
                Genies.editionByID[editionID] != nil: "editionID doesn't exist"
                self.editionIDs.contains(editionID) : "editionID doesn't belong to this collection"
            }

            let edition = (&Genies.editionByID[editionID] as &Edition?)!
            for key in editionMetadata.keys {
                let value = editionMetadata[key]
                if value != nil {
                    edition.setMetadata(key: key, value: value!)
                }
            }
        }


        // Close an Edition, and update the relevant fields
        //
        pub fun retireEdition(editionID: UInt32) {
            pre {
                Genies.editionByID[editionID] != nil: "editionID doesn't exist"
            }

            let edition = (&Genies.editionByID[editionID] as &Edition?)!
            edition.retire()
            self.editionsActive = self.editionsActive - 1 as UInt32
        }

        // Retire all of the Editions, allowing this collection to be closed
        //
        pub fun retireAllEditions() {
            for editionID in self.editionIDs {
                self.retireEdition(editionID: editionID)
            }
        }

        // Close the collection
        // access(contract) to enforce calling through its parent series
        //
        access(contract) fun close() {
            pre{
                self.open: "Already closed"
                self.editionsActive == 0:
                    "All editions in this collection must be closed before closing it"
            }

            self.open = false

            emit CollectionClosed(id: self.id)
        }

        // initializer
        //
        init (seriesID: UInt32, name: String, metadata: {String: String}) {
            pre {
                Genies.seriesByID.containsKey(seriesID) != nil: "seriesID does not exist"
            }

            self.id = Genies.nextCollectionID
            self.seriesID = seriesID
            self.name = name
            self.metadata = metadata
            self.editionIDs = []
            self.editionsActive = 0 as UInt32
            self.open = true

            Genies.nextCollectionID = Genies.nextCollectionID + 1 as UInt32

            emit CollectionCreated(id: self.id, seriesID: self.seriesID, name: self.name, metadata: self.metadata)
        }
    }

    // Get the publicly available data for a GeniesCollection
    // Not an NFT Collection!
    //
    pub fun getGeniesCollectionData(id: UInt32): Genies.GeniesCollectionData {
        pre {
            Genies.collectionByID[id] != nil: "Cannot borrow Genies collection, no such id"
        }

        return GeniesCollectionData(id: id)
    }

    //------------------------------------------------------------
    // Edition
    //------------------------------------------------------------

    // A public struct to access Edition data
    //
    pub struct EditionData {
        pub let id: UInt32
        pub let collectionID: UInt32
        pub let name: String
        pub let metadata: {String: String}
        pub let open: Bool
        pub let numMinted: UInt32

        // initializer
        //
        init (id: UInt32) {
            let edition = (&Genies.editionByID[id] as &Genies.Edition?)!
            self.id = id
            self.collectionID = edition.collectionID
            self.name = edition.name
            self.metadata = edition.metadata
            self.open = edition.open
            self.numMinted = edition.numMinted
        }
    }

    // An Edition (NFT type) within a Genies collection
    //
    pub resource Edition {
        pub let id: UInt32
        pub let collectionID: UInt32
        pub let name: String
        // Contents writable if borrowed!
        // This is deliberate, as it allows admins to update the data.
        pub let metadata: {String: String}
        pub var numMinted: UInt32
        pub var open: Bool

        // Retire this edition so that no more Genies NFTs can be minted in it
        // access(contract) to enforce calling through its parent GeniesCollection
        //
        access(contract) fun retire() {
            pre {
                self.open == true: "already retired"
            }

            self.open = false

            emit EditionRetired(id: self.id)
        }

        pub fun setMetadata(key: String, value: String) {
            self.metadata[key] = value
        }

        // Mint a Genies NFT in this edition, with the given minting mintingDate.
        // Note that this will panic if this edition is retired.
        //
        pub fun mint(): @Genies.NFT {
            pre {
                self.open: "edition closed, cannot mint"
            }

            // Keep a running total (you'll notice we used this as the serial number
            // and pre-increment it so that serial numbers start at 1 ).
            self.numMinted = self.numMinted + 1 as UInt32

            // Create the Genies NFT, filled out with our information
            let geniesNFT <- create NFT(
                id: Genies.totalSupply,
                editionID: self.id,
                serialNumber: self.numMinted
            )
            Genies.totalSupply = Genies.totalSupply + 1

            return <- geniesNFT
        }

        // initializer
        //
        init (
            collectionID: UInt32,
            name: String,
            metadata: {String: String}
        ) {
            pre {
                Genies.collectionByID.containsKey(collectionID): "collectionID does not exist"
            }

            self.id = Genies.nextEditionID
            self.collectionID = collectionID
            self.name = name
            self.metadata = metadata
            self.numMinted = 0 as UInt32
            self.open = true

            Genies.nextEditionID = Genies.nextEditionID + 1 as UInt32

            emit EditionCreated(
                id: self.id,
                collectionID: self.collectionID,
                name: self.name,
                metadata: self.metadata
            )
        }
    }

    // Get the publicly available data for an Edition
    //
    pub fun getEditionData(id: UInt32): EditionData {
        pre {
            Genies.editionByID[id] != nil: "Cannot borrow edition, no such id"
        }

        let edition = (&Genies.editionByID[id] as &Genies.Edition?)!

        return EditionData(id: id)
    }

    //------------------------------------------------------------
    // NFT
    //------------------------------------------------------------

    // A Genies NFT
    //
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let editionID: UInt32
        pub let serialNumber: UInt32
        pub let mintingDate: UFix64

        // Destructor
        //
        destroy() {
            emit NFTBurned(id: self.id)
        }

        // NFT initializer
        //
        init(
            id: UInt64,
            editionID: UInt32,
            serialNumber: UInt32
        ) {
            pre {
                Genies.editionByID[editionID] != nil: "no such editionID"
                (&Genies.editionByID[editionID] as &Edition?)!.open:
                    "editionID is retired"
            }

            self.id = id
            self.editionID = editionID
            self.serialNumber = serialNumber
            self.mintingDate = getCurrentBlock().timestamp

            emit NFTMinted(id: self.id, editionID: self.editionID, serialNumber: self.serialNumber)
        }

        pub fun getWearableSKU(): String {
            let edition = Genies.getEditionData(id: self.editionID)
            if edition.metadata["avatarWearableSKU"] != nil {
                return edition.metadata["avatarWearableSKU"]!
            } else {
                return ""
            }
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Traits>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            let edition = Genies.getEditionData(id: self.editionID)
            let collection = Genies.getGeniesCollectionData(id: edition.collectionID)
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: edition.name,
                        description: "Serial #"
                                    .concat(self.serialNumber.toString())
                                    .concat(" of ")
                                    .concat(edition.name)
                                    .concat(" from ")
                                    .concat(collection.name)
                                    .concat(" collection"),
                        thumbnail: MetadataViews.HTTPFile(
                                    url:"https://warehouse-assets.genies.com/"
                                        .concat(self.getWearableSKU())
                                        .concat("/wearable-container.png")
                        )
                    )
                case Type<MetadataViews.Editions>():
                    return MetadataViews.Editions([
                        MetadataViews.Edition(
                            name: edition.name,
                            number: UInt64(self.serialNumber),
                            max: UInt64(edition.numMinted),
                        )
                    ])
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                case Type<MetadataViews.Royalties>():
                    var royalties: [MetadataViews.Royalty] = []
                    return MetadataViews.Royalties(royalties) 
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://warehouse.genies.com/nft/".concat(self.id.toString()))
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: Genies.CollectionStoragePath,
                        publicPath: Genies.CollectionPublicPath,
                        providerPath: /private/GeniesNFTCollection,
                        publicCollection: Type<&Genies.Collection{Genies.GeniesNFTCollectionPublic}>(),
                        publicLinkedType: Type<&Genies.Collection{Genies.GeniesNFTCollectionPublic, NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&Genies.Collection{Genies.GeniesNFTCollectionPublic, NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <- Genies.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return MetadataViews.NFTCollectionDisplay(
                        name: "Genies",
                        description: "Empowering humans to build avatar ecosystems.",
                        externalURL: MetadataViews.ExternalURL("https://warehouse.genies.com"),
                        squareImage: MetadataViews.Media(
                                        file: MetadataViews.HTTPFile(
                                            url: "https://warehouse.genies.com/static/images/logo.png"
                                        ),
                                        mediaType: "image/png"
                                    ),
                        bannerImage: MetadataViews.Media(
                                        file: MetadataViews.HTTPFile(
                                            url: "https://warehouse.genies.com/static/images/banner.png"
                                        ),
                                        mediaType: "image/png"
                                    ),
                        socials: {
                            "instagram": MetadataViews.ExternalURL("https://www.instagram.com/genies"),
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/genies"),
                            "tiktok": MetadataViews.ExternalURL("https://www.tiktok.com/@genies"),
                            "discord": MetadataViews.ExternalURL("https://discord.com/invite/genies")
                        }
                    )
                case Type<MetadataViews.Traits>():
                    let excludedTraits = ["rarity", "type", "designSlot", "publisher"];
                    let traitsView = MetadataViews.dictToTraits(dict: edition.metadata, excludedNames: excludedTraits);
                    
                    if edition.metadata["designSlot"] != nil {
                        let designSlot = edition.metadata["designSlot"]!
                        let designSlotTrait = MetadataViews.Trait(
                            name: "designSlot", 
                            value: designSlot.slice(from: 20, upTo: designSlot.length), 
                            displayType: "String", 
                            rarity: nil
                        ) 
                        traitsView.addTrait(designSlotTrait)
                    }
                    return traitsView
            }
            return nil
        }
    }

    //------------------------------------------------------------
    // Collection
    //------------------------------------------------------------

    // A public collection interface that allows Genies NFTs to be borrowed
    //
    pub resource interface GeniesNFTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun batchDeposit(tokens: @NonFungibleToken.Collection)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowGeniesNFT(id: UInt64): &Genies.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow Genies NFT reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // An NFT Collection (not to be confused with a GeniesCollection)
    //
    pub resource Collection:
        NonFungibleToken.Provider,
        NonFungibleToken.Receiver,
        NonFungibleToken.CollectionPublic,
        GeniesNFTCollectionPublic,
        MetadataViews.ResolverCollection
    {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an UInt64 ID field
        //
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        // withdraw removes an NFT from the collection and moves it to the caller
        //
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        //
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @Genies.NFT
            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // batchDeposit takes a Collection object as an argument
        // and deposits each contained NFT into this Collection
        //
        pub fun batchDeposit(tokens: @NonFungibleToken.Collection) {
            // Get an array of the IDs to be deposited
            let keys = tokens.getIDs()

            // Iterate through the keys in the collection and deposit each one
            for key in keys {
                self.deposit(token: <-tokens.withdraw(withdrawID: key))
            }

            // Destroy the empty Collection
            destroy tokens
        }

        // getIDs returns an array of the IDs that are in the collection
        //
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT gets a reference to an NFT in the collection
        //
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        // borrowGeniesNFT gets a reference to an NFT in the collection
        //
        pub fun borrowGeniesNFT(id: UInt64): &Genies.NFT? {
            if self.ownedNFTs[id] != nil {
                return (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)! as! &Genies.NFT
            } else {
                return nil
            }
        }

        // borrowViewResolver
        // Gets a reference to the MetadataViews resolver in the collection,
        // giving access to all metadata information made available.
        //
        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let GeniesNft = nft as! &Genies.NFT
            return GeniesNft as &AnyResource{MetadataViews.Resolver}
        }

        // Collection destructor
        //
        destroy() {
            destroy self.ownedNFTs
        }

        // Collection initializer
        //
        init() {
            self.ownedNFTs <- {}
        }
    }

    // public function that anyone can call to create a new empty collection
    //
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    //------------------------------------------------------------
    // Admin
    //------------------------------------------------------------

    // An interface containing the Admin function that allows minting NFTs
    //
    pub resource interface NFTMinter {
        // Mint a single NFT
        // The Edition for the given ID must already exist
        //
        pub fun mintNFT(editionID: UInt32): @Genies.NFT
    }

    // A resource that allows managing metadata and minting NFTs
    //
    pub resource Admin: NFTMinter {
        // Create a new series and set it to be the current one, deactivating the previous one if needed.
        // You probably want to call closeAllCollections() on the current series before this.
        //
        pub fun advanceSeries(
            nextSeriesName: String,
            nextSeriesMetadata: {String: String}
        ): UInt32 {
            pre {
                Genies.seriesByID[Genies.currentSeriesID] == nil
                    || (&Genies.seriesByID[Genies.currentSeriesID] as &Genies.Series?)!.collectionsOpen == 0:
                    "All collections must be closed before advancing the series"
            }

            // The contract starts with currentSeriesID 0 but no entry for series zero.
            // We have to call advanceSeries to create series 0, so we have to handle that special case.
            // This test handles that case.
            // Its body will be called every time after the initial advance, which is what we want.
            if Genies.seriesByID[Genies.currentSeriesID] != nil {
                let currentSeries = (&Genies.seriesByID[Genies.currentSeriesID] as &Genies.Series?)!
                if currentSeries.active {
                    // Make sure everything in the series is closed
                    currentSeries.closeAllGeniesCollections()
                    // Deactivate the current series
                    currentSeries.deactivate()
                    // Advance the currentSeriesID
                    Genies.currentSeriesID = Genies.currentSeriesID + 1 as UInt32
                }
            }

            // Create and store the new series
            let series <- create Genies.Series(
                id: Genies.currentSeriesID,
                name: nextSeriesName,
                metadata: nextSeriesMetadata
            )
            Genies.seriesByID[Genies.currentSeriesID] <-! series

            // Cache the new series's name => ID
            Genies.seriesIDByName[nextSeriesName] = Genies.currentSeriesID

            // Return the new ID for convenience
            return Genies.currentSeriesID
        }

        // Borrow a Series
        //
        pub fun borrowSeries(id: UInt32): &Genies.Series {
            pre {
                Genies.seriesByID[id] != nil: "Cannot borrow series, no such id"
            }

            return (&Genies.seriesByID[id] as &Genies.Series?)!
        }

        // Borrow a Genies Collection. Not an NFT Collection!
        //
        pub fun borrowGeniesCollection(id: UInt32): &Genies.GeniesCollection {
            pre {
                Genies.collectionByID[id] != nil: "Cannot borrow Genies collection, no such id"
            }

            return (&Genies.collectionByID[id] as &Genies.GeniesCollection?)!
        }

        // Borrow an Edition
        //
        pub fun borrowEdition(id: UInt32): &Genies.Edition {
            pre {
                Genies.editionByID[id] != nil: "Cannot borrow edition, no such id"
            }

            return (&Genies.editionByID[id] as &Genies.Edition?)!
        }

        // Mint a single NFT
        // The Edition for the given ID must already exist
        //
        pub fun mintNFT(editionID: UInt32): @Genies.NFT {
            pre {
                // Make sure the edition we are creating this NFT in exists
                Genies.editionByID.containsKey(editionID): "No such EditionID"
            }

            return <- self.borrowEdition(id: editionID).mint()
        }
    }

    //------------------------------------------------------------
    // Contract lifecycle
    //------------------------------------------------------------

    // Genies contract initializer
    //
    init() {
        // Set the named paths
        self.CollectionStoragePath = /storage/GeniesNFTCollection
        self.CollectionPublicPath = /public/GeniesNFTCollection
        self.AdminStoragePath = /storage/GeniesAdmin
        self.MinterPrivatePath = /private/GeniesMinter

        // Initialize the entity counts
        self.totalSupply = 0
        self.currentSeriesID = 0
        self.nextCollectionID = 0
        self.nextEditionID = 0

        // Initialize the metadata lookup dictionaries
        self.seriesByID <- {}
        self.seriesIDByName = {}
        self.collectionByID <- {}
        self.editionByID <- {}

        // Create an Admin resource and save it to storage
        let admin <- create Admin()
        self.account.save(<-admin, to: self.AdminStoragePath)
        // Link capabilites to the admin constrained to the Minter
        // and Metadata interfaces
        self.account.link<&Genies.Admin{Genies.NFTMinter}>(
            self.MinterPrivatePath,
            target: self.AdminStoragePath
        )

        // Let the world know we are here
        emit ContractInitialized()
    }
}