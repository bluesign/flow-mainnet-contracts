import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import AthleteStudioMintCache from 0x27ece19eff91bab0

pub contract AthleteStudio: NonFungibleToken {

    pub let version: String

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, editionID: UInt64, serialNumber: UInt64)
    pub event Burned(id: UInt64)
    pub event EditionCreated(edition: Edition)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let CollectionPrivatePath: PrivatePath
    pub let AdminStoragePath: StoragePath

    /// The total number of Athlete Studio NFTs that have been minted.
    ///
    pub var totalSupply: UInt64

    /// The total number of Athlete Studio NFT editions that have been created.
    ///
    pub var totalEditions: UInt64

    /// The royalty information for all Athlete Studio NFTs.
    ///
    pub var royalty: MetadataViews.Royalty?

    pub struct Metadata {
    
        pub let name: String
        pub let description: String
        pub let thumbnail: String
        pub let asset: String
        pub let assetType: String
        pub let athleteID: Int
        pub let athleteName: String
        pub let athleteURL: String
        pub let itemType: String
        pub let itemCategory: String
        pub let series: String
        pub let eventName: String
        pub let eventDate: String
        pub let eventType: String
        pub let signed: Bool

        init(
            name: String,
            description: String,
            thumbnail: String,
            asset: String,
            assetType: String,
            athleteID: Int,
            athleteName: String,
            athleteURL: String,
            itemType: String,
            itemCategory: String,
            series: String,
            eventName: String,
            eventDate: String,
            eventType: String,
            signed: Bool,
        ) {
            self.name = name
            self.description = description
            self.thumbnail = thumbnail
            self.asset = asset
            self.assetType = assetType
            self.athleteID = athleteID
            self.athleteName = athleteName
            self.athleteURL = athleteURL
            self.itemType = itemType
            self.itemCategory = itemCategory
            self.series = series
            self.eventName = eventName
            self.eventDate = eventDate
            self.eventType = eventType
            self.signed = signed
        }
    }

    pub struct Edition {

        pub let id: UInt64

        /// The maximum size of this edition.
        ///
        pub let size: UInt64

        /// The number of NFTs minted in this edition.
        ///
        /// The count cannot exceed the edition size.
        ///
        pub var count: UInt64

        /// The metadata for this edition.
        ///
        pub let metadata: Metadata

        init(
            id: UInt64,
            size: UInt64,
            metadata: Metadata
        ) {
            self.id = id
            self.size = size
            self.metadata = metadata

            // An edition starts with a count of zero
            self.count = 0
        }

        /// Increment the NFT count of this edition.
        ///
        /// The count cannot exceed the edition size.
        ///
        access(contract) fun incrementCount() {
            post {
                self.count <= self.size: "edition has already reached its maximum size"
            }

            self.count = self.count + (1 as UInt64)
        }
    }

    access(self) let editions: {UInt64: Edition}

    pub fun getEdition(id: UInt64): Edition? {
        return AthleteStudio.editions[id]
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
            return AthleteStudio.getEdition(id: self.editionID)!
        }

        pub fun getViews(): [Type] {
            return [   
                Type<MetadataViews.NFTView>(),
                Type<MetadataViews.Display>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Edition>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Media>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            let edition = self.getEdition()

            switch view {
                case Type<MetadataViews.NFTView>():
                    return self.resolveNFTView(edition.metadata)
                case Type<MetadataViews.Display>():
                    return self.resolveDisplay(edition.metadata)
                case Type<MetadataViews.ExternalURL>():
                    return self.resolveExternalURL(edition.metadata)
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
                case Type<MetadataViews.Media>():
                    return self.resolveMedia(edition.metadata)
            }

            return nil
        }

        pub fun resolveNFTView(_ metadata: Metadata): MetadataViews.NFTView {
            return MetadataViews.NFTView(
                id: self.id,
                uuid: self.uuid,
                display: self.resolveDisplay(metadata),
                externalURL: self.resolveExternalURL(metadata),
                collectionData: self.resolveNFTCollectionData(),
                collectionDisplay: self.resolveNFTCollectionDisplay(),
                royalties : self.resolveRoyalties(),
                traits: nil
            )
        }
        
        pub fun resolveDisplay(_ metadata: Metadata): MetadataViews.Display {
            return MetadataViews.Display(
                name: metadata.name,
                description: metadata.description,
                thumbnail: MetadataViews.IPFSFile(cid: metadata.thumbnail, path: nil)
            )
        }
        
        pub fun resolveExternalURL(_ metadata: Metadata): MetadataViews.ExternalURL {
            return MetadataViews.ExternalURL(metadata.athleteURL)
        }

        pub fun resolveNFTCollectionDisplay(): MetadataViews.NFTCollectionDisplay {
            let media = MetadataViews.Media(
                file: MetadataViews.HTTPFile(
                    url: "https://d3w5a827wx4ops.cloudfront.net/athlete-studio-logo-light.png"
                ),
                mediaType: "image/png"
            )
        
            return MetadataViews.NFTCollectionDisplay(
                name: "Athlete Studio NFTs",
                description: "Officially licensed NFTs from Pro Athletes.",
                externalURL: MetadataViews.ExternalURL("https://athlete.studio"),
                squareImage: media,
                bannerImage: media,
                socials: {
                    "twitter": MetadataViews.ExternalURL("https://athlete.studio/twitter"),
                    "instagram": MetadataViews.ExternalURL("https://athlete.studio/instagram")
                }
            )
        }
        
        pub fun resolveNFTCollectionData(): MetadataViews.NFTCollectionData {
            return MetadataViews.NFTCollectionData(
                storagePath: AthleteStudio.CollectionStoragePath,
                publicPath: AthleteStudio.CollectionPublicPath,
                providerPath: AthleteStudio.CollectionPrivatePath,
                publicCollection: Type<&AthleteStudio.Collection{AthleteStudio.AthleteStudioCollectionPublic}>(),
                publicLinkedType: Type<&AthleteStudio.Collection{AthleteStudio.AthleteStudioCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
                providerLinkedType: Type<&AthleteStudio.Collection{AthleteStudio.AthleteStudioCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(),
                createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                    return <-AthleteStudio.createEmptyCollection()
                })
            )
        }
        
        pub fun resolveRoyalties(): MetadataViews.Royalties {
            // Return the Athlete Studio royalty if one is set
            if let royalty = AthleteStudio.royalty {
                return MetadataViews.Royalties([royalty])
            }

            return MetadataViews.Royalties([])
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

        pub fun resolveMedia(_ metadata: Metadata): MetadataViews.Media {
            return MetadataViews.Media(
                file: MetadataViews.IPFSFile(cid: metadata.asset, path: nil),
                mediaType: metadata.assetType
            )
        }
        
        destroy() {
            AthleteStudio.totalSupply = AthleteStudio.totalSupply - (1 as UInt64)

            emit Burned(id: self.id)
        }
    }

    pub resource interface AthleteStudioCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowAthleteStudio(id: UInt64): &AthleteStudio.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow AthleteStudio reference: The ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: AthleteStudioCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        
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
            let token <- token as! @AthleteStudio.NFT

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
        /// typed as AthleteStudio.NFT.
        ///
        /// This function returns nil if the NFT does not exist in this collection.
        ///
        pub fun borrowAthleteStudio(id: UInt64): &AthleteStudio.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &AthleteStudio.NFT
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
            let nftRef = nft as! &AthleteStudio.NFT
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
            size: UInt64,
            name: String,
            description: String,
            thumbnail: String,
            asset: String,
            assetType: String,
            athleteID: Int,
            athleteName: String,
            athleteURL: String,
            itemType: String,
            itemCategory: String,
            series: String,
            eventName: String,
            eventDate: String,
            eventType: String,
            signed: Bool,
        ): UInt64 {
            // Prevent multiple editions from being minted with the same mint ID
            assert(
                AthleteStudioMintCache.getEditionByMintID(mintID: mintID) == nil,
                message: "an edition has already been created with mintID=".concat(mintID)
            )

            let metadata = Metadata(
                name: name,
                description: description,
                thumbnail: thumbnail,
                asset: asset,
                assetType: assetType,
                athleteID: athleteID,
                athleteName: athleteName,
                athleteURL: athleteURL,
                itemType: itemType,
                itemCategory: itemCategory,
                series: series,
                eventName: eventName,
                eventDate: eventDate,
                eventType: eventType,
                signed: signed,
            )

            let edition = Edition(
                id: AthleteStudio.totalEditions,
                size: size,
                metadata: metadata
            )

            AthleteStudio.editions[edition.id] = edition

            emit EditionCreated(edition: edition)

            // Update the mint ID index
            AthleteStudioMintCache.insertEditionMintID(mintID: mintID, editionID: edition.id)

            AthleteStudio.totalEditions = AthleteStudio.totalEditions + (1 as UInt64)

            return edition.id
        }

        /// Mint a new NFT.
        ///
        /// This function will mint the next NFT in this edition
        /// and automatically assign the serial number.
        ///
        /// This function will panic if the edition has already
        /// reached its maximum size.
        ///
        pub fun mintNFT(editionID: UInt64): @AthleteStudio.NFT {
            let edition = AthleteStudio.editions[editionID]
                ?? panic("edition does not exist")

            // Increase the edition count by one
            edition.incrementCount()

            // The NFT serial number is the new edition count
            let serialNumber = edition.count

            let nft <- create AthleteStudio.NFT(
                editionID: editionID,
                serialNumber: serialNumber
            )

            // Save the updated edition
            AthleteStudio.editions[editionID] = edition

            emit Minted(id: nft.id, editionID: editionID, serialNumber: serialNumber)

            AthleteStudio.totalSupply = AthleteStudio.totalSupply + (1 as UInt64)

            return <- nft
        }

        /// Set the royalty percentage and receiver for all Athlete Studio NFTs.
        ///
        pub fun setRoyalty(royalty: MetadataViews.Royalty) {
            AthleteStudio.royalty = royalty
        }
    }

    /// Return a public path that is scoped to this contract.
    ///
    pub fun getPublicPath(suffix: String): PublicPath {
        return PublicPath(identifier: "AthleteStudio_".concat(suffix))!
    }

    /// Return a private path that is scoped to this contract.
    ///
    pub fun getPrivatePath(suffix: String): PrivatePath {
        return PrivatePath(identifier: "AthleteStudio_".concat(suffix))!
    }

    /// Return a storage path that is scoped to this contract.
    ///
    pub fun getStoragePath(suffix: String): StoragePath {
        return StoragePath(identifier: "AthleteStudio_".concat(suffix))!
    }

    priv fun initAdmin(admin: AuthAccount) {
        // Create an empty collection and save it to storage
        let collection <- AthleteStudio.createEmptyCollection()

        admin.save(<- collection, to: AthleteStudio.CollectionStoragePath)

        admin.link<&AthleteStudio.Collection>(AthleteStudio.CollectionPrivatePath, target: AthleteStudio.CollectionStoragePath)

        admin.link<&AthleteStudio.Collection{NonFungibleToken.CollectionPublic, AthleteStudio.AthleteStudioCollectionPublic, MetadataViews.ResolverCollection}>(AthleteStudio.CollectionPublicPath, target: AthleteStudio.CollectionStoragePath)
        
        // Create an admin resource and save it to storage
        let adminResource <- create Admin()

        admin.save(<- adminResource, to: self.AdminStoragePath)
    }

    init() {

        self.version = "0.0.24"

        self.CollectionPublicPath = AthleteStudio.getPublicPath(suffix: "Collection")
        self.CollectionStoragePath = AthleteStudio.getStoragePath(suffix: "Collection")
        self.CollectionPrivatePath = AthleteStudio.getPrivatePath(suffix: "Collection")

        self.AdminStoragePath = AthleteStudio.getStoragePath(suffix: "Admin")

        self.totalSupply = 0
        self.totalEditions = 0

        self.editions = {}

        self.royalty = nil
        
        self.initAdmin(admin: self.account)

        emit ContractInitialized()
    }
}
