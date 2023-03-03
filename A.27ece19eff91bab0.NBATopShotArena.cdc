import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import FreshmintMetadataViews from 0x0c82d33d4666f1f7

pub contract NBATopShotArena: NonFungibleToken {

    pub let version: String

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, editionID: UInt64, serialNumber: UInt64)
    pub event Burned(id: UInt64)
    pub event EditionCreated(edition: Edition)
    pub event EditionClosed(id: UInt64, size: UInt64)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let CollectionPrivatePath: PrivatePath
    pub let AdminStoragePath: StoragePath

    /// The total number of NBATopShotArena NFTs that have been minted.
    ///
    pub var totalSupply: UInt64

    /// The total number of NBATopShotArena editions that have been created.
    ///
    pub var totalEditions: UInt64

    /// A list of royalty recipients that is attached to all NFTs
    /// minted by this contract.
    ///
    access(contract) let royalties: [MetadataViews.Royalty]
    
    /// Return the royalty recipients for this contract.
    ///
    pub fun getRoyalties(): [MetadataViews.Royalty] {
        return NBATopShotArena.royalties
    }

    /// The collection-level metadata for all NFTs minted by this contract.
    ///
    pub let collectionMetadata: MetadataViews.NFTCollectionDisplay

    pub struct Metadata {
    
        /// The core metadata fields for a NBATopShotArena NFT edition.
        ///
        pub let name: String
        pub let description: String
        pub let thumbnail: String
        pub let asset: String
        pub let assetType: String
        pub let eventName: String
        pub let eventDate: String
        pub let externalURL: String

        /// Optional attributes for a NBATopShotArena NFT edition.
        ///
        pub let attributes: {String: String}

        init(
            name: String,
            description: String,
            thumbnail: String,
            asset: String,
            assetType: String,
            eventName: String,
            eventDate: String,
            externalURL: String,
            attributes: {String: String}
        ) {
            self.name = name
            self.description = description
            self.thumbnail = thumbnail
            self.asset = asset
            self.assetType = assetType
            self.eventName = eventName
            self.eventDate = eventDate
            self.externalURL = externalURL
            
            self.attributes = attributes
        }
    }

    pub struct Edition {

        pub let id: UInt64

        /// The maximum number of NFTs that can be minted in this edition.
        ///
        /// If nil, the edition has no size limit.
        ///
        pub let limit: UInt64?

        /// The number of NFTs minted in this edition.
        ///
        /// This field is incremented each time a new NFT is minted.
        /// It cannot exceed the limit defined above.
        ///
        pub var size: UInt64

        /// The number of NFTs in this edition that have been burned.
        ///
        /// This field is incremented each time an NFT is burned.
        ///
        pub var burned: UInt64

        /// Return the total supply of NFTs in this edition.
        ///
        /// The supply is the number of NFTs minted minus the number burned.
        ///
        pub fun supply(): UInt64 {
            return self.size - self.burned
        }

        /// A flag indicating whether this edition is closed for minting.
        ///
        pub var isClosed: Bool

        /// The metadata for this edition.
        ///
        pub let metadata: Metadata

        init(
            id: UInt64,
            limit: UInt64?,
            metadata: Metadata
        ) {
            self.id = id
            self.limit = limit
            self.metadata = metadata

            self.size = 0
            self.burned = 0

            self.isClosed = false
        }

        /// Increment the size of this edition.
        ///
        access(contract) fun incrementSize() {
            self.size = self.size + (1 as UInt64)
        }

        /// Increment the burn count for this edition.
        ///
        access(contract) fun incrementBurned() {
            self.burned = self.burned + (1 as UInt64)
        }

        /// Close this edition and prevent further minting.
        ///
        /// Note: an edition is automatically closed when 
        /// it reaches its size limit, if defined.
        ///
        access(contract) fun close() {
            self.isClosed = true
        }
    }

    access(self) let editions: {UInt64: Edition}

    pub fun getEdition(id: UInt64): Edition? {
        return NBATopShotArena.editions[id]
    }

    /// This dictionary indexes editions by their mint ID.
    ///
    /// It is populated at mint time and used to prevent duplicate mints.
    /// The mint ID can be any unique string value,
    /// for example the hash of the edition metadata.
    ///
    access(self) let editionsByMintID: {String: UInt64}

    pub fun getEditionByMintID(mintID: String): UInt64? {
        return NBATopShotArena.editionsByMintID[mintID]
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

        pub let id: UInt64

        pub let editionID: UInt64
        pub let serialNumber: UInt64

        init(
            editionID: UInt64,
            serialNumber: UInt64
        ) {
            self.id = self.uuid
            self.editionID = editionID
            self.serialNumber = serialNumber
        }

        /// Return the edition that this NFT belongs to.
        ///
        pub fun getEdition(): Edition {
            return NBATopShotArena.getEdition(id: self.editionID)!
        }

        pub fun getViews(): [Type] {
            return [   
                Type<MetadataViews.Display>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTView>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Edition>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            let edition = self.getEdition()

            switch view {
                case Type<MetadataViews.Display>():
                    return self.resolveDisplay(edition.metadata)
                case Type<MetadataViews.ExternalURL>():
                    return self.resolveExternalURL()
                case Type<MetadataViews.NFTView>():
                    return self.resolveNFTView(edition.metadata)
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return self.resolveNFTCollectionDisplay()
                case Type<MetadataViews.NFTCollectionData>():
                    return self.resolveNFTCollectionData()
                case Type<MetadataViews.Royalties>():
                    return self.resolveRoyalties()
                case Type<MetadataViews.Edition>():
                    return self.resolveEditionView(edition)
                case Type<MetadataViews.Serial>():
                    return self.resolveSerialView(self.serialNumber)
            }

            return nil
        }

        pub fun resolveDisplay(_ metadata: Metadata): MetadataViews.Display {
            return MetadataViews.Display(
                name: metadata.name,
                description: metadata.description,
                thumbnail: FreshmintMetadataViews.ipfsFile(file: metadata.thumbnail)
            )
        }
        
        pub fun resolveExternalURL(): MetadataViews.ExternalURL {
            return MetadataViews.ExternalURL("https://nbatopshot.com")
        }
        
        pub fun resolveNFTView(_ metadata: Metadata): MetadataViews.NFTView {
            return MetadataViews.NFTView(
                id: self.id,
                uuid: self.uuid,
                display: self.resolveDisplay(metadata),
                externalURL: self.resolveExternalURL(),
                collectionData: self.resolveNFTCollectionData(),
                collectionDisplay: self.resolveNFTCollectionDisplay(),
                royalties : self.resolveRoyalties(),
                traits: nil
            )
        }
        
        pub fun resolveNFTCollectionDisplay(): MetadataViews.NFTCollectionDisplay {
            return NBATopShotArena.collectionMetadata
        }
        
        pub fun resolveNFTCollectionData(): MetadataViews.NFTCollectionData {
            return MetadataViews.NFTCollectionData(
                storagePath: NBATopShotArena.CollectionStoragePath,
                publicPath: NBATopShotArena.CollectionPublicPath,
                providerPath: NBATopShotArena.CollectionPrivatePath,
                publicCollection: Type<&NBATopShotArena.Collection{NBATopShotArena.NBATopShotArenaCollectionPublic}>(),
                publicLinkedType: Type<&NBATopShotArena.Collection{NBATopShotArena.NBATopShotArenaCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
                providerLinkedType: Type<&NBATopShotArena.Collection{NBATopShotArena.NBATopShotArenaCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(),
                createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                    return <-NBATopShotArena.createEmptyCollection()
                })
            )
        }
        
        pub fun resolveRoyalties(): MetadataViews.Royalties {
            return MetadataViews.Royalties(NBATopShotArena.getRoyalties())
        }
        
        pub fun resolveEditionView(_ edition: Edition): MetadataViews.Edition {
            return MetadataViews.Edition(
                name: "Edition",
                number: self.serialNumber,
                max: edition.size
            )
        }

        pub fun resolveSerialView(_ serialNumber: UInt64): MetadataViews.Serial {
            return MetadataViews.Serial(
                number: serialNumber
            )
        }

        destroy() {
            NBATopShotArena.totalSupply = NBATopShotArena.totalSupply - (1 as UInt64)

            // Update the burn count for the NFT's edition
            let edition = self.getEdition()

            edition.incrementBurned()

            NBATopShotArena.editions[edition.id] = edition

            emit Burned(id: self.id)
        }
    }

    pub resource interface NBATopShotArenaCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowNBATopShotArena(id: UInt64): &NBATopShotArena.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow NBATopShotArena reference: The ID of the returned reference is incorrect"
            }
        }
    }
    
    pub resource Collection: NBATopShotArenaCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        
        /// A dictionary of all NFTs in this collection indexed by ID.
        ///
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}
    
        init () {
            self.ownedNFTs <- {}
        }
    
        /// Remove an NFT from the collection and move it to the caller.
        ///
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) 
                ?? panic("Requested NFT to withdraw does not exist in this collection")
    
            emit Withdraw(id: token.id, from: self.owner?.address)
    
            return <- token
        }
    
        /// Deposit an NFT into this collection.
        ///
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @NBATopShotArena.NFT
    
            let id: UInt64 = token.id
    
            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token
    
            emit Deposit(id: id, to: self.owner?.address)
    
            destroy oldToken
        }
    
        /// Return an array of the NFT IDs in this collection.
        ///
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }
    
        /// Return a reference to an NFT in this collection.
        ///
        /// This function panics if the NFT does not exist in this collection.
        ///
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }
    
        /// Return a reference to an NFT in this collection
        /// typed as NBATopShotArena.NFT.
        ///
        /// This function returns nil if the NFT does not exist in this collection.
        ///
        pub fun borrowNBATopShotArena(id: UInt64): &NBATopShotArena.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &NBATopShotArena.NFT
            }
    
            return nil
        }
    
        /// Return a reference to an NFT in this collection
        /// typed as MetadataViews.Resolver.
        ///
        /// This function panics if the NFT does not exist in this collection.
        ///
        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let nftRef = nft as! &NBATopShotArena.NFT
            return nftRef as &AnyResource{MetadataViews.Resolver}
        }
    
        destroy() {
            destroy self.ownedNFTs
        }
    }
    
    /// Return a new empty collection.
    ///
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    /// The administrator resource used to mint and reveal NFTs.
    ///
    pub resource Admin {

        /// Create a new NFT edition.
        ///
        /// This function does not mint any NFTs. It only creates the
        /// edition data that will later be associated with minted NFTs.
        ///
        pub fun createEdition(
            mintID: String,
            limit: UInt64?,
            name: String,
            description: String,
            thumbnail: String,
            asset: String,
            assetType: String,
            eventName: String,
            eventDate: String,
            externalURL: String,
            attributes: {String: String}
        ): UInt64 {
            let metadata = Metadata(
                name: name,
                description: description,
                thumbnail: thumbnail,
                asset: asset,
                assetType: assetType,
                eventName: eventName,
                eventDate: eventDate,
                externalURL: externalURL,
                attributes: attributes
            )

            // Prevent multiple editions from being minted with the same mint ID
            assert(
                NBATopShotArena.editionsByMintID[mintID] == nil,
                message: "an edition has already been created with mintID=".concat(mintID)
            )

            let edition = Edition(
                id: NBATopShotArena.totalEditions,
                limit: limit,
                metadata: metadata
            )

            // Save the edition
            NBATopShotArena.editions[edition.id] = edition

            // Update the mint ID index
            NBATopShotArena.editionsByMintID[mintID] = edition.id

            emit EditionCreated(edition: edition)

            NBATopShotArena.totalEditions = NBATopShotArena.totalEditions + (1 as UInt64)

            return edition.id
        }

        /// Close an existing edition.
        ///
        /// This prevents new NFTs from being minted into the edition.
        /// An edition cannot be reopened after it is closed.
        ///
        pub fun closeEdition(editionID: UInt64) {
            let edition = NBATopShotArena.editions[editionID]
                ?? panic("edition does not exist")

            // Prevent the edition from being closed more than once
            assert(edition.isClosed == false, message: "edition is already closed")

            edition.close()

            // Save the updated edition
            NBATopShotArena.editions[editionID] = edition

            emit EditionClosed(id: edition.id, size: edition.size)
        }

        /// Mint a new NFT.
        ///
        /// This function will mint the next NFT in this edition
        /// and automatically assign the serial number.
        ///
        /// This function will panic if the edition has already
        /// reached its maximum size.
        ///
        pub fun mintNFT(editionID: UInt64): @NBATopShotArena.NFT {
            let edition = NBATopShotArena.editions[editionID]
                ?? panic("edition does not exist")

            // Do not mint into a closed edition
            assert(edition.isClosed == false, message: "edition is closed for minting")

            // Increase the edition size by one
            edition.incrementSize()

            // The NFT serial number is the new edition size
            let serialNumber = edition.size

            let nft <- create NBATopShotArena.NFT(
                editionID: editionID,
                serialNumber: serialNumber
            )

            emit Minted(id: nft.id, editionID: editionID, serialNumber: serialNumber)

            // Close the edition if it reaches its size limit
            if let limit = edition.limit {
                if edition.size == limit {
                    edition.close()

                    emit EditionClosed(id: edition.id, size: edition.size)
                }
            }

            // Save the updated edition
            NBATopShotArena.editions[editionID] = edition

            NBATopShotArena.totalSupply = NBATopShotArena.totalSupply + (1 as UInt64)

            return <- nft
        }
    }

    /// Return a public path that is scoped to this contract.
    ///
    pub fun getPublicPath(suffix: String): PublicPath {
        return PublicPath(identifier: "NBATopShotArena_".concat(suffix))!
    }

    /// Return a private path that is scoped to this contract.
    ///
    pub fun getPrivatePath(suffix: String): PrivatePath {
        return PrivatePath(identifier: "NBATopShotArena_".concat(suffix))!
    }

    /// Return a storage path that is scoped to this contract.
    ///
    pub fun getStoragePath(suffix: String): StoragePath {
        return StoragePath(identifier: "NBATopShotArena_".concat(suffix))!
    }

    /// Return a collection name with an optional bucket suffix.
    ///
    pub fun makeCollectionName(bucketName maybeBucketName: String?): String {
        if let bucketName = maybeBucketName {
            return "Collection_".concat(bucketName)
        }

        return "Collection"
    }

    /// Return a queue name with an optional bucket suffix.
    ///
    pub fun makeQueueName(bucketName maybeBucketName: String?): String {
        if let bucketName = maybeBucketName {
            return "Queue_".concat(bucketName)
        }

        return "Queue"
    }

    priv fun initAdmin(admin: AuthAccount) {
        // Create an empty collection and save it to storage
        let collection <- NBATopShotArena.createEmptyCollection()

        admin.save(<- collection, to: NBATopShotArena.CollectionStoragePath)

        admin.link<&NBATopShotArena.Collection>(NBATopShotArena.CollectionPrivatePath, target: NBATopShotArena.CollectionStoragePath)

        admin.link<&NBATopShotArena.Collection{NonFungibleToken.CollectionPublic, NBATopShotArena.NBATopShotArenaCollectionPublic, MetadataViews.ResolverCollection}>(NBATopShotArena.CollectionPublicPath, target: NBATopShotArena.CollectionStoragePath)
        
        // Create an admin resource and save it to storage
        let adminResource <- create Admin()

        admin.save(<- adminResource, to: self.AdminStoragePath)
    }

    init(collectionMetadata: MetadataViews.NFTCollectionDisplay, royalties: [MetadataViews.Royalty]) {

        self.version = "0.7.0"

        self.CollectionPublicPath = NBATopShotArena.getPublicPath(suffix: "Collection")
        self.CollectionStoragePath = NBATopShotArena.getStoragePath(suffix: "Collection")
        self.CollectionPrivatePath = NBATopShotArena.getPrivatePath(suffix: "Collection")

        self.AdminStoragePath = NBATopShotArena.getStoragePath(suffix: "Admin")

        self.royalties = royalties
        self.collectionMetadata = collectionMetadata

        self.totalSupply = 0
        self.totalEditions = 0

        self.editions = {}
        self.editionsByMintID = {}
        
        self.initAdmin(admin: self.account)

        emit ContractInitialized()
    }
}
