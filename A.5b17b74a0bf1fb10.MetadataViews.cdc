import NonFungibleToken from 0x1d7e57aa55817448

/// This contract implements the metadata standard proposed
/// in FLIP-0636.
/// 
/// Ref: https://github.com/onflow/flow/blob/master/flips/20210916-nft-metadata.md
/// 
/// Structs and resources can implement one or more
/// metadata types, called views. Each view type represents
/// a different kind of metadata, such as a creator biography
/// or a JPEG image file.
///
pub contract MetadataViews {

    /// Provides access to a set of metadata views. A struct or 
    /// resource (e.g. an NFT) can implement this interface to provide access to 
    /// the views that it supports.
    ///
    pub resource interface Resolver {
        pub fun getViews(): [Type]
        pub fun resolveView(_ view: Type): AnyStruct?
    }

    /// A group of view resolvers indexed by ID.
    ///
    pub resource interface ResolverCollection {
        pub fun borrowViewResolver(id: UInt64): &{Resolver}
        pub fun getIDs(): [UInt64]
    }

    /// Basic view that includes the name, description and thumbnail for an 
    /// object. Most objects should implement this view.
    /// NFTView is a group of views used to give a complete picture of an NFT
    ///
    pub struct NFTView {
        pub let id: UInt64
        pub let uuid: UInt64
        pub let display: Display?
        pub let externalURL: ExternalURL?
        pub let collectionData: NFTCollectionData?
        pub let collectionDisplay: NFTCollectionDisplay?

        init(
            id : UInt64,
            uuid : UInt64,
            display : Display?,
            externalURL : ExternalURL?,
            collectionData : NFTCollectionData?,
            collectionDisplay : NFTCollectionDisplay?,
        ) {
            self.id = id
            self.uuid = uuid
            self.display = display
            self.externalURL = externalURL
            self.collectionData = collectionData
            self.collectionDisplay = collectionDisplay
        }
    }

    /// Helper to get an NFT view 
    ///
    /// @param id: The NFT id
    /// @param viewResolver: A reference to the resolver resource
    /// @return A NFTView struct
    ///
    pub fun getNFTView(id: UInt64, viewResolver: &{Resolver}) : NFTView {
        let nftView = viewResolver.resolveView(Type<NFTView>())
        if nftView != nil {
            return nftView! as! NFTView
        }

        return NFTView(
            id : id,
            uuid: viewResolver.uuid,
            display: self.getDisplay(viewResolver),
            externalURL : self.getExternalURL(viewResolver),
            collectionData : self.getNFTCollectionData(viewResolver),
            collectionDisplay : self.getNFTCollectionDisplay(viewResolver),
        )
    }

    pub struct Display {

        /// The name of the object. 
        ///
        /// This field will be displayed in lists and therefore should
        /// be short an concise.
        ///
        pub let name: String

        /// A written description of the object. 
        ///
        /// This field will be displayed in a detailed view of the object,
        /// so can be more verbose (e.g. a paragraph instead of a single line).
        ///
        pub let description: String

        /// A small thumbnail representation of the object.
        ///
        /// This field should be a web-friendly file (i.e JPEG, PNG)
        /// that can be displayed in lists, link previews, etc.
        ///
        pub let thumbnail: AnyStruct{File}
        pub let videoURI: String
        pub let ipfsVideo: IPFSFile

        init(
            name: String,
            description: String,
            thumbnail: AnyStruct{File},
            videoURI: String,
            ipfsVideo: IPFSFile,
        ) {
            self.name = name
            self.description = description
            self.thumbnail = thumbnail
            self.videoURI = videoURI
            self.ipfsVideo = ipfsVideo
        }
    }

    /// Helper to get Display in a typesafe way
    ///
    /// @param viewResolver: A reference to the resolver resource
    /// @return An optional Display struct
    ///
    pub fun getDisplay(_ viewResolver: &{Resolver}) : Display? {
        if let view = viewResolver.resolveView(Type<Display>()) {
            if let v = view as? Display {
                return v
            }
        }
        return nil
    }

    /// Generic interface that represents a file stored on or off chain. Files 
    /// can be used to references images, videos and other media.
    ///
    pub struct interface File {
        pub fun uri(): String
    }

    /// View to expose a file that is accessible at an HTTP (or HTTPS) URL. 
    ///
    pub struct HTTPFile: File {
        pub let url: String

        init(url: String) {
            self.url = url
        }

        pub fun uri(): String {
            return self.url
        }
    }

    /// View to expose a file stored on IPFS.
    /// IPFS images are referenced by their content identifier (CID)
    /// rather than a direct URI. A client application can use this CID
    /// to find and load the image via an IPFS gateway.
    ///
    pub struct IPFSFile: File {

        /// CID is the content identifier for this IPFS file.
        ///
        /// Ref: https://docs.ipfs.io/concepts/content-addressing/
        ///
        pub let cid: String

        /// Path is an optional path to the file resource in an IPFS directory.
        ///
        /// This field is only needed if the file is inside a directory.
        ///
        /// Ref: https://docs.ipfs.io/concepts/file-systems/
        ///
        pub let path: String?

        init(cid: String, path: String?) {
            self.cid = cid
            self.path = path
        }

        /// This function returns the IPFS native URL for this file.
        /// Ref: https://docs.ipfs.io/how-to/address-ipfs-on-web/#native-urls
        ///
        /// @return The string containing the file uri
        ///
        pub fun uri(): String {
            if let path = self.path {
                return "ipfs://".concat(self.cid).concat("/").concat(path)
            }

            return "ipfs://".concat(self.cid)
        }
    }

    /// Optional view for collections that issue multiple objects
    /// with the same or similar metadata, for example an X of 100 set. This 
    /// information is useful for wallets and marketplaces.
    /// An NFT might be part of multiple editions, which is why the edition 
    /// information is returned as an arbitrary sized array
    ///
    pub struct Edition {

        /// The name of the edition
        /// For example, this could be Set, Play, Series,
        /// or any other way a project could classify its editions
        pub let name: String?

        /// The edition number of the object.
        /// For an "24 of 100 (#24/100)" item, the number is 24.
        pub let number: UInt64

        /// The max edition number of this type of objects.
        /// This field should only be provided for limited-editioned objects.
        /// For an "24 of 100 (#24/100)" item, max is 100.
        /// For an item with unlimited edition, max should be set to nil.
        /// 
        pub let max: UInt64?

        init(name: String?, number: UInt64, max: UInt64?) {
            if max != nil {
                assert(number <= max!, message: "The number cannot be greater than the max number!")
            }
            self.name = name
            self.number = number
            self.max = max
        }
    }

    /// Wrapper view for multiple Edition views
    /// 
    pub struct Editions {

        /// An arbitrary-sized list for any number of editions
        /// that the NFT might be a part of
        pub let infoList: [Edition]

        init(_ infoList: [Edition]) {
            self.infoList = infoList
        }
    }

    /// Helper to get Editions in a typesafe way
    ///
    /// @param viewResolver: A reference to the resolver resource
    /// @return An optional Editions struct
    ///
    pub fun getEditions(_ viewResolver: &{Resolver}) : Editions? {
        if let view = viewResolver.resolveView(Type<Editions>()) {
            if let v = view as? Editions {
                return v
            }
        }
        return nil
    }

    /// View representing a project-defined serial number for a specific NFT
    /// Projects have different definitions for what a serial number should be
    /// Some may use the NFTs regular ID and some may use a different 
    /// classification system. The serial number is expected to be unique among 
    /// other NFTs within that project
    ///
    pub struct Serial {
        pub let number: UInt64

        init(_ number: UInt64) {
            self.number = number
        }
    }

    /// Helper to get Serial in a typesafe way
    ///
    /// @param viewResolver: A reference to the resolver resource
    /// @return An optional Serial struct
    ///
    pub fun getSerial(_ viewResolver: &{Resolver}) : Serial? {
        if let view = viewResolver.resolveView(Type<Serial>()) {
            if let v = view as? Serial {
                return v
            }
        }
        return nil
    }

     /// View to represent, a file with an correspoiding mediaType.
    ///
    pub struct Media {

        /// File for the media
        ///
        pub let file: AnyStruct{File}

        /// media-type comes on the form of type/subtype as described here 
        /// https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types
        ///
        pub let mediaType: String

        init(file: AnyStruct{File}, mediaType: String) {
          self.file=file
          self.mediaType=mediaType
        }
    }

    /// Wrapper view for multiple media views
    ///
    pub struct Medias {

        /// An arbitrary-sized list for any number of Media items
        pub let items: [Media]

        init(_ items: [Media]) {
            self.items = items
        }
    }

    /// Helper to get Medias in a typesafe way
    ///
    /// @param viewResolver: A reference to the resolver resource
    /// @return A optional Medias struct
    ///
    pub fun getMedias(_ viewResolver: &{Resolver}) : Medias? {
        if let view = viewResolver.resolveView(Type<Medias>()) {
            if let v = view as? Medias {
                return v
            }
        }
        return nil
    }

    /// View to expose a URL to this item on an external site.
    /// This can be used by applications like .find and Blocto to direct users 
    /// to the original link for an NFT.
    ///
    pub struct ExternalURL {
        pub let url: String

        init(_ url: String) {
            self.url=url
        }
    }

    /// Helper to get ExternalURL in a typesafe way
    ///
    /// @param viewResolver: A reference to the resolver resource
    /// @return A optional ExternalURL struct
    ///
    pub fun getExternalURL(_ viewResolver: &{Resolver}) : ExternalURL? {
        if let view = viewResolver.resolveView(Type<ExternalURL>()) {
            if let v = view as? ExternalURL {
                return v
            }
        }
        return nil
    }

    /// View to expose the information needed store and retrieve an NFT.
    /// This can be used by applications to setup a NFT collection with proper 
    /// storage and public capabilities.
    ///
    pub struct NFTCollectionData {
        /// Path in storage where this NFT is recommended to be stored.
        pub let storagePath: StoragePath

        /// Public path which must be linked to expose public capabilities of this NFT
        /// including standard NFT interfaces and metadataviews interfaces
        pub let publicPath: PublicPath

        /// Private path which should be linked to expose the provider
        /// capability to withdraw NFTs from the collection holding NFTs
        pub let providerPath: PrivatePath

        /// Public collection type that is expected to provide sufficient read-only access to standard
        /// functions (deposit + getIDs + borrowNFT)
        /// This field is for backwards compatibility with collections that have not used the standard
        /// NonFungibleToken.CollectionPublic interface when setting up collections. For new
        /// collections, this may be set to be equal to the type specified in `publicLinkedType`.
        pub let publicCollection: Type

        /// Type that should be linked at the aforementioned public path. This is normally a
        /// restricted type with many interfaces. Notably the `NFT.CollectionPublic`,
        /// `NFT.Receiver`, and `MetadataViews.ResolverCollection` interfaces are required.
        pub let publicLinkedType: Type

        /// Type that should be linked at the aforementioned private path. This is normally
        /// a restricted type with at a minimum the `NFT.Provider` interface
        pub let providerLinkedType: Type

        /// Function that allows creation of an empty NFT collection that is intended to store
        /// this NFT.
        pub let createEmptyCollection: ((): @NonFungibleToken.Collection)

        init(
            storagePath: StoragePath,
            publicPath: PublicPath,
            providerPath: PrivatePath,
            publicCollection: Type,
            publicLinkedType: Type,
            providerLinkedType: Type,
            createEmptyCollectionFunction: ((): @NonFungibleToken.Collection)
        ) {
            pre {
                publicLinkedType.isSubtype(of: Type<&{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>()): "Public type must include NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, and MetadataViews.ResolverCollection interfaces."
                providerLinkedType.isSubtype(of: Type<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>()): "Provider type must include NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, and MetadataViews.ResolverCollection interface."
            }
            self.storagePath=storagePath
            self.publicPath=publicPath
            self.providerPath = providerPath
            self.publicCollection=publicCollection
            self.publicLinkedType=publicLinkedType
            self.providerLinkedType = providerLinkedType
            self.createEmptyCollection=createEmptyCollectionFunction
        }
    }

    /// Helper to get NFTCollectionData in a way that will return an typed Optional
    ///
    /// @param viewResolver: A reference to the resolver resource
    /// @return A optional NFTCollectionData struct
    ///
    pub fun getNFTCollectionData(_ viewResolver: &{Resolver}) : NFTCollectionData? {
        if let view = viewResolver.resolveView(Type<NFTCollectionData>()) {
            if let v = view as? NFTCollectionData {
                return v
            }
        }
        return nil
    }

    /// View to expose the information needed to showcase this NFT's
    /// collection. This can be used by applications to give an overview and 
    /// graphics of the NFT collection this NFT belongs to.
    ///
    pub struct NFTCollectionDisplay {
        // Name that should be used when displaying this NFT collection.
        pub let name: String

        // Description that should be used to give an overview of this collection.
        pub let description: String

        // External link to a URL to view more information about this collection.
        pub let externalURL: ExternalURL

        // Square-sized image to represent this collection.
        pub let squareImage: Media

        // Banner-sized image for this collection, recommended to have a size near 1200x630.
        pub let bannerImage: Media

        // Social links to reach this collection's social homepages.
        // Possible keys may be "instagram", "twitter", "discord", etc.
        pub let socials: {String: ExternalURL}

        init(
            name: String,
            description: String,
            externalURL: ExternalURL,
            squareImage: Media,
            bannerImage: Media,
            socials: {String: ExternalURL}
        ) {
            self.name = name
            self.description = description
            self.externalURL = externalURL
            self.squareImage = squareImage
            self.bannerImage = bannerImage
            self.socials = socials
        }
    }

    /// Helper to get NFTCollectionDisplay in a way that will return a typed 
    /// Optional
    ///
    /// @param viewResolver: A reference to the resolver resource
    /// @return A optional NFTCollection struct
    ///
    pub fun getNFTCollectionDisplay(_ viewResolver: &{Resolver}) : NFTCollectionDisplay? {
        if let view = viewResolver.resolveView(Type<NFTCollectionDisplay>()) {
            if let v = view as? NFTCollectionDisplay {
                return v
            }
        }
        return nil
    }
}
 