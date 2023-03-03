import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract UFC_NFT: NonFungibleToken {

    // UFC_NFT Events
    //
    // Emitted when the UFC_NFT contract is created
    pub event ContractInitialized()

    // Emitted when an NFT is minted
    pub event Minted(id: UInt64, setId: UInt32, seriesId: UInt32)

    // Events for Series-related actions
    //
    // Emitted when a new Series is created
    pub event SeriesCreated(seriesId: UInt32)
    // Emitted when a Series is sealed, meaning Series metadata
    // cannot be updated
    pub event SeriesSealed(seriesId: UInt32)
    // Emitted when a Series' metadata is updated
    pub event SeriesMetadataUpdated(seriesId: UInt32)

    // Events for Set-related actions
    //
    // Emitted when a new Set is created
    pub event SetCreated(seriesId: UInt32, setId: UInt32)
    // Emitted when a Set's metadata is updated
    pub event SetMetadataUpdated(seriesId: UInt32, setId: UInt32)

    // Events for Collection-related actions
    //
    // Emitted when an NFT is withdrawn from a Collection
    pub event Withdraw(id: UInt64, from: Address?)
    // Emitted when an NFT is deposited into a Collection
    pub event Deposit(id: UInt64, to: Address?)

    // Emitted when an NFT is destroyed
    pub event NFTDestroyed(id: UInt64)
    // Named Paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath
    pub let AdminPrivatePath: PrivatePath

    // totalSupply
    // The total number of UFC_NFT that have been minted
    //
    pub var totalSupply: UInt64

    // Variable size dictionary of SetData structs
    access(self) var setData: {UInt32: NFTSetData}

    // Variable size dictionary of SeriesData structs
    access(self) var seriesData: {UInt32: SeriesData}

    // Variable size dictionary of Series resources
    access(self) var series: @{UInt32: Series}


    // An NFTSetData is a Struct that holds metadata associated with
    // a specific NFT Set.
    pub struct NFTSetData {

        // Unique ID for the Set
        pub let setId: UInt32

        // Series ID the Set belongs to
        pub let seriesId: UInt32

        // Maximum number of editions that can be minted in this Set
        pub let maxEditions: UInt32
                  
        // The JSON metadata for each NFT edition can be stored off-chain on IPFS.
        // This is an optional dictionary of IPFS hashes, which will allow marketplaces
        // to pull the metadata for each NFT edition
        access(self) var ipfsMetadataHashes: {UInt32: String}

        // Set level metadata
        // Dictionary of metadata key value pairs
        access(self) var metadata: {String: String}
        
        init(
            setId: UInt32,
            seriesId: UInt32,
            maxEditions: UInt32,
            ipfsMetadataHashes: {UInt32: String},
            metadata: {String: String}) {

            self.setId = setId
            self.seriesId = seriesId
            self.maxEditions = maxEditions
            self.metadata = metadata
            self.ipfsMetadataHashes = ipfsMetadataHashes
        }

        pub fun getIpfsMetadataHash(editionNum: UInt32): String? {
            return self.ipfsMetadataHashes[editionNum]
        }

        pub fun getMetadata(): {String: String} {
            return self.metadata
        }

        pub fun getMetadataField(field: String): String? {
            return self.metadata[field]
        }
    }

    // A SeriesData is a struct that groups metadata for a 
    // a related group of NFTSets.
    pub struct SeriesData {

        // Unique ID for the Series
        pub let seriesId: UInt32

        // Dictionary of metadata key value pairs
        access(self) var metadata: {String: String}

        init(
            seriesId: UInt32,
            metadata: {String: String}) {
            self.seriesId = seriesId
            self.metadata = metadata
        }

        pub fun getMetadata(): {String: String} {
            return self.metadata
        }
    }


    // A Series is special resource type that contains functions to mint UFC_NFT NFTs, 
    // add NFTSets, update NFTSet and Series metadata, and seal Series.
	pub resource Series {

        // Unique ID for the Series
        pub let seriesId: UInt32

        // Array of NFTSets that belong to this Series
        pub var setIds: [UInt32]

        // Series sealed state
        pub var seriesSealedState: Bool;

        // Set sealed state
        access(self) var setSealedState: {UInt32: Bool};

        // Current number of editions minted per Set
        pub var numberEditionsMintedPerSet: {UInt32: UInt32}

        init(
            seriesId: UInt32,
            metadata: {String: String}) {

            self.seriesId = seriesId
            self.seriesSealedState = false
            self.numberEditionsMintedPerSet = {}
            self.setIds = []
            self.setSealedState = {}

            UFC_NFT.seriesData[seriesId] = SeriesData(
                    seriesId: seriesId,
                    metadata: metadata
            )

            emit SeriesCreated(seriesId: seriesId)   
        }

        pub fun addNftSet(
            setId: UInt32,
            maxEditions: UInt32,
            ipfsMetadataHashes: {UInt32: String},
            metadata: {String: String}) {
            pre {
                self.setIds.contains(setId) == false: "The Set has already been added to the Series."
            }

            // Create the new Set struct
            var newNFTSet = NFTSetData(
                setId: setId,
                seriesId: self.seriesId,
                maxEditions: maxEditions,
                ipfsMetadataHashes: ipfsMetadataHashes,
                metadata: metadata
            )

            // Add the NFTSet to the array of Sets
            self.setIds.append(setId)

            // Initialize the NFT edition count to zero
            self.numberEditionsMintedPerSet[setId] = 0

            // Store it in the sets mapping field
            UFC_NFT.setData[setId] = newNFTSet

            emit SetCreated(seriesId: self.seriesId, setId: setId)
        }

        // updateSeriesMetadata
        // For practical reasons, a short period of time is given to update metadata
        // following Series creation or minting of the NFT editions. Once the Series is
        // sealed, no updates to the Series metadata will be possible - the information
        // is permanent and immutable.
        pub fun updateSeriesMetadata(metadata: {String: String}) {
            pre {
                self.seriesSealedState == false:
                    "The Series is permanently sealed. No metadata updates can be made."
            }
            let newSeriesMetadata = SeriesData(
                    seriesId: self.seriesId,
                    metadata: metadata
            )  
            // Store updated Series in the Series mapping field
            UFC_NFT.seriesData[self.seriesId] = newSeriesMetadata

            emit SeriesMetadataUpdated(seriesId: self.seriesId)
        }

        // updateSetMetadata
        // For practical reasons, a short period of time is given to update metadata
        // following Set creation or minting of the NFT editions. Once the Series is
        // sealed, no updates to the Set metadata will be possible - the information
        // is permanent and immutable.
        pub fun updateSetMetadata(
            setId: UInt32,
            maxEditions: UInt32,
            ipfsMetadataHashes: {UInt32: String},
            metadata: {String: String}) {
            pre {
                self.seriesSealedState == false:
                    "The Series is permanently sealed. No metadata updates can be made."
                self.setIds.contains(setId) == true: "The Set is not part of this Series."
            }
            let newSetMetadata = NFTSetData(
                setId: setId,
                seriesId: self.seriesId,
                maxEditions: maxEditions,
                ipfsMetadataHashes: ipfsMetadataHashes,
                metadata: metadata
            )
            // Store updated Set in the Sets mapping field
            UFC_NFT.setData[setId] = newSetMetadata

            emit SetMetadataUpdated(seriesId: self.seriesId, setId: setId)
        }

		// mintUFC_NFT
        // Mints a new NFT with a new ID
		// and deposits it in the recipients collection using their collection reference
        //
	    pub fun mintUFC_NFT(
            recipient: &{NonFungibleToken.CollectionPublic},
            tokenId: UInt64,
            setId: UInt32) {
            
            pre {
                self.numberEditionsMintedPerSet[setId] != nil: "The Set does not exist."
                self.numberEditionsMintedPerSet[setId]! <= UFC_NFT.getSetMaxEditions(setId: setId)!:
                    "Set has reached maximum NFT edition capacity."
            }

            // Gets the number of editions that have been minted so far in 
            // this set
            let editionNum: UInt32 = self.numberEditionsMintedPerSet[setId]! + (1 as UInt32)

			// deposit it in the recipient's account using their reference
			recipient.deposit(token: <-create UFC_NFT.NFT(
                tokenId: tokenId,
                setId: setId,
                editionNum: editionNum
            ))

            // Increment the count of global NFTs 
            UFC_NFT.totalSupply = UFC_NFT.totalSupply + (1 as UInt64)

            // Update the count of Editions minted in the set
            self.numberEditionsMintedPerSet[setId] = editionNum
        }

        // mintEditionUFC_NFT
        // Mints a new NFT with a new ID and specific edition Num (random open edition)
		// and deposits it in the recipients collection using their collection reference
        //
	    pub fun mintEditionUFC_NFT(
            recipient: &{NonFungibleToken.CollectionPublic},
            tokenId: UInt64,
            setId: UInt32,
            edition: UInt32) {
            
            pre {
                self.numberEditionsMintedPerSet[setId] != nil: "The Set does not exist."
                self.numberEditionsMintedPerSet[setId]! <= UFC_NFT.getSetMaxEditions(setId: setId)!:
                    "Set has reached maximum NFT edition capacity."
            }

			// deposit it in the recipient's account using their reference
			recipient.deposit(token: <-create UFC_NFT.NFT(
                tokenId: tokenId,
                setId: setId,
                editionNum: edition
            ))

            // Increment the count of global NFTs 
            UFC_NFT.totalSupply = UFC_NFT.totalSupply + (1 as UInt64)

            // Update the count of Editions minted in the set
            self.numberEditionsMintedPerSet[setId] = self.numberEditionsMintedPerSet[setId]! + (1 as UInt32)
        }

        // batchMintUFC_NFT
        // Mints multiple new NFTs given and deposits the NFTs
        // into the recipients collection using their collection reference
		pub fun batchMintUFC_NFT(
            recipient: &{NonFungibleToken.CollectionPublic},
            setId: UInt32,
            tokenIds: [UInt64]) {

            pre {
                tokenIds.length > 0:
                    "Number of token Ids must be > 0"
            }

            for tokenId in tokenIds {
                self.mintUFC_NFT(
                    recipient: recipient,
                    tokenId: tokenId,
                    setId: setId
                )
            }
		}

        // sealSeries
        // Once a series is sealed, the metadata for the NFTs in the Series can no
        // longer be updated
        //
        pub fun sealSeries() {
            pre {
                self.seriesSealedState == false: "The Series is already sealed"
            }
            self.seriesSealedState = true

            emit SeriesSealed(seriesId: self.seriesId)
        }
	}

    // A resource that represents the UFC_NFT NFT
    //
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        // The token's ID
        pub let id: UInt64

        // The Set id references this NFT belongs to
        pub let setId: UInt32

        // The specific edition number for this NFT
        pub let editionNum: UInt32

        // initializer
        //
        init(
          tokenId: UInt64,
          setId: UInt32,
          editionNum: UInt32) {

            self.id = tokenId
            self.setId = setId
            self.editionNum = editionNum

            let seriesId = UFC_NFT.getSetSeriesId(setId: setId)!

            emit Minted(id: self.id, setId: setId, seriesId: seriesId)
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.Medias>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: UFC_NFT.getSetMetadataByField(setId: self.setId, field: "name")!,
                        description: UFC_NFT.getSetMetadataByField(setId: self.setId, field: "description")!,
                        thumbnail: MetadataViews.HTTPFile(
                            url: UFC_NFT.getSetMetadataByField(setId: self.setId, field: "preview")!
                        )
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                case Type<MetadataViews.Editions>():
                    let maxEditions = UFC_NFT.setData[self.setId]?.maxEditions ?? 0
                    let editionName = UFC_NFT.getSetMetadataByField(setId: self.setId, field: "name")!
                    let editionInfo = MetadataViews.Edition(name: editionName, number: UInt64(self.editionNum), max: maxEditions > 0 ? UInt64(maxEditions) : nil)
                    let editionList: [MetadataViews.Edition] = [editionInfo]
                    return MetadataViews.Editions(
                        editionList
                    )
                case Type<MetadataViews.ExternalURL>():
                    if let externalBaseURL = UFC_NFT.getSetMetadataByField(setId: self.setId, field: "external_token_base_url") {
                        return MetadataViews.ExternalURL(externalBaseURL.concat("/").concat(self.id.toString()))
                    }
                    return MetadataViews.ExternalURL("")
                case Type<MetadataViews.Royalties>():
                    let royalties: [MetadataViews.Royalty] = []
                    // There is only a legacy {String: String} dictionary to store royalty information.
                    // There may be multiple royalty cuts defined per NFT. Pull each royalty
                    // based on keys that have the "royalty_addr_" prefix in the dictionary.
                    for metadataKey in UFC_NFT.getSetMetadata(setId: self.setId)!.keys {
                        // For efficiency, only check keys that are > 13 chars, which is the length of "royalty_addr_" key
                        if metadataKey.length >= 13 {
                            if metadataKey.slice(from: 0, upTo: 13) == "royalty_addr_" {
                                // A royalty has been found. Use the suffix from the key for the royalty name.
                                let royaltyName = metadataKey.slice(from: 13, upTo: metadataKey.length)
                                let royaltyAddress = UFC_NFT.convertStringToAddress(UFC_NFT.getSetMetadataByField(setId: self.setId, field: "royalty_addr_".concat(royaltyName))!)!
                                let royaltyReceiver: PublicPath = PublicPath(identifier: UFC_NFT.getSetMetadataByField(setId: self.setId, field: "royalty_rcv_".concat(royaltyName))!)!
                                let royaltyCut = UFC_NFT.getSetMetadataByField(setId: self.setId, field: "royalty_cut_".concat(royaltyName))!
                                let cutValue: UFix64 = UFC_NFT.royaltyCutStringToUFix64(royaltyCut)
                                if cutValue != 0.0 {
                                    royalties.append(MetadataViews.Royalty(
                                        receiver: getAccount(royaltyAddress).getCapability<&FungibleToken.Vault{FungibleToken.Receiver}>(royaltyReceiver),
                                        cut: cutValue,
                                        description: UFC_NFT.getSetMetadataByField(setId: self.setId, field: "royalty_desc_".concat(royaltyName))!
                                    )
                                    )
                                }
                            }
                        }
                    }
                    return MetadataViews.Royalties(cutInfos: royalties)
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: UFC_NFT.CollectionStoragePath,
                        publicPath: UFC_NFT.CollectionPublicPath,
                        providerPath: /private/UFC_NFT,
                        publicCollection: Type<&UFC_NFT.Collection{UFC_NFT.UFC_NFTCollectionPublic,NonFungibleToken.CollectionPublic}>(),
                        publicLinkedType: Type<&UFC_NFT.Collection{UFC_NFT.UFC_NFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&UFC_NFT.Collection{UFC_NFT.UFC_NFTCollectionPublic,NonFungibleToken.Provider,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-UFC_NFT.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let squareImage = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://media.gigantik.io/ufc/square.png"
                        ),
                        mediaType: "image/png"
                    )
                    let bannerImage = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://media.gigantik.io/ufc/banner.png"
                        ),
                        mediaType: "image/png"
                    )
                    var socials: {String: MetadataViews.ExternalURL} = {}
                    for metadataKey in UFC_NFT.getSetMetadata(setId: self.setId)!.keys {
                        // For efficiency, only check keys that are > 18 chars, which is the length of "collection_social_" key
                        if metadataKey.length >= 18 {
                            if metadataKey.slice(from: 0, upTo: 18) == "collection_social_" {
                                // A social URL has been found. Set the name to only the collection social key suffix.
                                socials.insert(key: metadataKey.slice(from: 18, upTo: metadataKey.length), MetadataViews.ExternalURL(UFC_NFT.getSetMetadataByField(setId: self.setId, field: metadataKey)!))
                            }
                        }
                    }
                    return MetadataViews.NFTCollectionDisplay(
                        name: UFC_NFT.getSetMetadataByField(setId: self.setId, field: "collection_name") ?? "",
                        description: UFC_NFT.getSetMetadataByField(setId: self.setId, field: "collection_description") ?? "",
                        externalURL: MetadataViews.ExternalURL(UFC_NFT.getSetMetadataByField(setId: self.setId, field: "external_url") ?? ""),
                        squareImage: squareImage,
                        bannerImage: bannerImage,
                        socials: socials
                    )
                case Type<MetadataViews.Traits>():
                    let traitDictionary: {String: AnyStruct} = {}
                    // There is only a legacy {String: String} dictionary to store trait information.
                    // There may be multiple traits defined per NFT. Pull trait information
                    // based on keys that have the "trait_" prefix in the dictionary.
                    for metadataKey in UFC_NFT.getSetMetadata(setId: self.setId)!.keys {
                        // For efficiency, only check keys that are > 6 chars, which is the length of "trait_" key
                        if metadataKey.length >= 6 {
                            if metadataKey.slice(from: 0, upTo: 6) == "trait_" {
                                // A trait has been found. Set the trait name to only the trait key suffix.
                                traitDictionary.insert(key: metadataKey.slice(from: 6, upTo: metadataKey.length), UFC_NFT.getSetMetadataByField(setId: self.setId, field: metadataKey)!)
                            }
                        }
                    }
                    return MetadataViews.dictToTraits(dict: traitDictionary, excludedNames: [])
                case Type<MetadataViews.Medias>():
                    return MetadataViews.Medias(
                        items: [
                            MetadataViews.Media(
                                file: MetadataViews.HTTPFile(
                                    url: UFC_NFT.getSetMetadataByField(setId: self.setId, field: "image")!
                                ),
                                mediaType: self.getMimeType()
                            )
                        ]
                    )
            }
            return nil
        }

        pub fun getMimeType(): String {
            var metadataFileType = UFC_NFT.getSetMetadataByField(setId: self.setId, field: "image_file_type")!.toLower()
            switch metadataFileType {
                case "mp4":
                    return "video/mp4"
                case "mov":
                    return "video/quicktime"
                case "webm":
                    return "video/webm"
                case "ogv":
                    return "video/ogg"
                case "png":
                    return "image/png"
                case "jpeg":
                    return "image/jpeg"
                case "jpg":
                    return "image/jpeg"
                case "gif":
                    return "image/gif"
                case "webp":
                    return "image/webp"
                case "svg":
                    return "image/svg+xml"
                case "glb":
                    return "model/gltf-binary"
                case "gltf":
                    return "model/gltf+json"
                case "obj":
                    return "model/obj"
                case "mtl":
                    return "model/mtl"
                case "mp3":
                    return "audio/mpeg"
                case "ogg":
                    return "audio/ogg"
                case "oga":
                    return "audio/ogg"
                case "wav":
                    return "audio/wav"
                case "html":
                    return "text/html"
            }
            return ""
        }

        // If the NFT is destroyed, emit an event
        destroy() {
            UFC_NFT.totalSupply = UFC_NFT.totalSupply - (1 as UInt64)
            emit NFTDestroyed(id: self.id)
        }
    }

    // Admin is a special authorization resource that 
    // allows the owner to perform important NFT 
    // functions
    //
    pub resource Admin {

        pub fun addSeries(seriesId: UInt32, metadata: {String: String}) {
            pre {
                UFC_NFT.series[seriesId] == nil:
                    "Cannot add Series: The Series already exists"
            }

            // Create the new Series
            var newSeries <- create Series(
                seriesId: seriesId,
                metadata: metadata
            )

            // Add the new Series resource to the Series dictionary in the contract
            UFC_NFT.series[seriesId] <-! newSeries
        }

        pub fun borrowSeries(seriesId: UInt32): &Series  {
            pre {
                UFC_NFT.series[seriesId] != nil:
                    "Cannot borrow Series: The Series does not exist"
            }

            // Get a reference to the Series and return it
            return (&UFC_NFT.series[seriesId] as &Series?)!
        }

        pub fun createNewAdmin(): @Admin {
            return <-create Admin()
        }

    }

    // This is the interface that users can cast their NFT Collection as
    // to allow others to deposit UFC_NFT into their Collection. It also allows for reading
    // the details of UFC_NFT in the Collection.
    pub resource interface UFC_NFTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun batchDeposit(tokens: @NonFungibleToken.Collection)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowUFC_NFT(id: UInt64): &UFC_NFT.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow UFC_NFT reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // Collection
    // A collection of UFC_NFT NFTs owned by an account
    //
    pub resource Collection: UFC_NFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an UInt64 ID field
        //
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        // withdraw
        // Removes an NFT from the collection and moves it to the caller
        //
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // batchWithdraw withdraws multiple NFTs and returns them as a Collection
        //
        // Parameters: ids: An array of IDs to withdraw
        //
        // Returns: @NonFungibleToken.Collection: The collection of withdrawn tokens
        //

        pub fun batchWithdraw(ids: [UInt64]): @NonFungibleToken.Collection {
            // Create a new empty Collection
            var batchCollection <- create Collection()
            
            // Iterate through the ids and withdraw them from the Collection
            for id in ids {
                batchCollection.deposit(token: <-self.withdraw(withdrawID: id))
            }
            
            // Return the withdrawn tokens
            return <-batchCollection
        }

        // deposit
        // Takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        //
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @UFC_NFT.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // batchDeposit takes a Collection object as an argument
        // and deposits each contained NFT into this Collection
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

        // getIDs
        // Returns an array of the IDs that are in the collection
        //
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT
        // Gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        //
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        // borrowUFC_NFT
        // Gets a reference to an NFT in the collection as a UFC_NFT,
        // exposing all of its fields.
        // This is safe as there are no functions that can be called on the UFC_NFT.
        //
        pub fun borrowUFC_NFT(id: UInt64): &UFC_NFT.NFT? {
            let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
            return ref as! &UFC_NFT.NFT?
        }

        // borrowViewResolver
        // Gets a reference to the MetadataViews resolver in the collection,
        // giving access to all metadata information made available.
        //
        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let UFC_NFTNft = nft as! &UFC_NFT.NFT
            return UFC_NFTNft as &AnyResource{MetadataViews.Resolver}
        }

        // destructor
        destroy() {
            destroy self.ownedNFTs
        }

        // initializer
        //
        init () {
            self.ownedNFTs <- {}
        }
    }

    // createEmptyCollection
    // public function that anyone can call to create a new empty collection
    //
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // fetch
    // Get a reference to a UFC_NFT from an account's Collection, if available.
    // If an account does not have a UFC_NFT.Collection, panic.
    // If it has a collection but does not contain the Id, return nil.
    // If it has a collection and that collection contains the Id, return a reference to that.
    //
    pub fun fetch(_ from: Address, id: UInt64): &UFC_NFT.NFT? {
        let collection = getAccount(from)
            .getCapability(UFC_NFT.CollectionPublicPath)
            .borrow<&UFC_NFT.Collection{UFC_NFT.UFC_NFTCollectionPublic}>()
            ?? panic("Couldn't get collection")
        // We trust UFC_NFT.Collection.borrowUFC_NFT to get the correct id
        // (it checks it before returning it).
        return collection.borrowUFC_NFT(id: id)
    }

    // getAllSeries returns all the sets
    //
    // Returns: An array of all the series that have been created
    pub fun getAllSeries(): [UFC_NFT.SeriesData] {
        return UFC_NFT.seriesData.values
    }

    // getAllSets returns all the sets
    //
    // Returns: An array of all the sets that have been created
    pub fun getAllSets(): [UFC_NFT.NFTSetData] {
        return UFC_NFT.setData.values
    }

    // getSeriesMetadata returns the metadata that the specified Series
    //            is associated with.
    // 
    // Parameters: seriesId: The id of the Series that is being searched
    //
    // Returns: The metadata as a String to String mapping optional
    pub fun getSeriesMetadata(seriesId: UInt32): {String: String}? {
        return UFC_NFT.seriesData[seriesId]?.getMetadata()
    }

    // getSetMaxEditions returns the the maximum number of NFT editions that can
    //        be minted in this Set.
    // 
    // Parameters: setId: The id of the Set that is being searched
    //
    // Returns: The max number of NFT editions in this Set
    pub fun getSetMaxEditions(setId: UInt32): UInt32? {
        return UFC_NFT.setData[setId]?.maxEditions
    }

    // getSetMetadata returns all the metadata associated with a specific Set
    // 
    // Parameters: setId: The id of the Set that is being searched
    //
    // Returns: The metadata as a String to String mapping optional
    pub fun getSetMetadata(setId: UInt32): {String: String}? {
        return UFC_NFT.setData[setId]?.getMetadata()
    }

    // getSetSeriesId returns the Series Id the Set belongs to
    // 
    // Parameters: setId: The id of the Set that is being searched
    //
    // Returns: The Series Id
    pub fun getSetSeriesId(setId: UInt32): UInt32? {
        return UFC_NFT.setData[setId]?.seriesId
    }

    // getSetMetadata returns all the ipfs hashes for each nft 
    //     edition in the Set.
    // 
    // Parameters: setId: The id of the Set that is being searched
    //
    // Returns: The ipfs hashes of nft editions as a Array of Strings
    pub fun getIpfsMetadataHashByNftEdition(setId: UInt32, editionNum: UInt32): String? {
        // Don't force a revert if the setId or field is invalid
        if let set = UFC_NFT.setData[setId] {
            return set.getIpfsMetadataHash(editionNum: editionNum)
        } else {
            return nil
        }
    }

    // getSetMetadataByField returns the metadata associated with a 
    //                        specific field of the metadata
    // 
    // Parameters: setId: The id of the Set that is being searched
    //             field: The field to search for
    //
    // Returns: The metadata field as a String Optional
    pub fun getSetMetadataByField(setId: UInt32, field: String): String? {
        // Don't force a revert if the setId or field is invalid
        if let set = UFC_NFT.setData[setId] {
            return set.getMetadataField(field: field)
        } else {
            return nil
        }
    }

    // stringToAddress Converts a string to a Flow address
    // 
    // Parameters: input: The address as a String
    //
    // Returns: The flow address as an Address Optional
	pub fun convertStringToAddress(_ input: String): Address? {
		var address=input
		if input.utf8[1] == 120 {
			address = input.slice(from: 2, upTo: input.length)
		}
		var r:UInt64 = 0 
		var bytes = address.decodeHex()

		while bytes.length>0{
			r = r  + (UInt64(bytes.removeFirst()) << UInt64(bytes.length * 8 ))
		}

		return Address(r)
	}

    // royaltyCutStringToUFix64 Converts a royalty cut string
    //        to a UFix64
    // 
    // Parameters: royaltyCut: The cut value 0.0 - 1.0 as a String
    //
    // Returns: The royalty cut as a UFix64
    pub fun royaltyCutStringToUFix64(_ royaltyCut: String): UFix64 {
        var decimalPos = 0
        if royaltyCut[0] == "." {
            decimalPos = 1
        } else if royaltyCut[1] == "." {
            if royaltyCut[0] == "1" {
                // "1" in the first postiion must be 1.0 i.e. 100% cut
                return 1.0
            } else if royaltyCut[0] == "0" {
                decimalPos = 2
            }
        } else {
            // Invalid royalty value
            return 0.0
        }

        var royaltyCutStrLen = royaltyCut.length
        if royaltyCut.length > (8 + decimalPos) {
            // UFix64 is capped at 8 digits after the decimal
            // so truncate excess decimal values from the string
            royaltyCutStrLen = (8 + decimalPos)
        }
        let royaltyCutPercentValue = royaltyCut.slice(from: decimalPos, upTo: royaltyCutStrLen)
        var bytes = royaltyCutPercentValue.utf8
        var i = 0
        var cutValueInteger: UInt64 = 0
        var cutValueDivisor: UFix64 = 1.0
        let zeroAsciiIntValue: UInt64 = 48
        // First convert the string to a non-decimal Integer
        while i < bytes.length {
            cutValueInteger = (cutValueInteger * 10) + UInt64(bytes[i]) - zeroAsciiIntValue
            cutValueDivisor = cutValueDivisor * 10.0
            i = i + 1
        }

        // Convert the resulting Integer to a decimal in the range 0.0 - 0.99999999
        return (UFix64(cutValueInteger) / cutValueDivisor)
    }

    // initializer
    //
	init() {
        // Set named paths
        self.CollectionStoragePath = /storage/UFC_NFTCollection
        self.CollectionPublicPath = /public/UFC_NFTCollection
        self.AdminStoragePath = /storage/UFC_NFTAdmin
        self.AdminPrivatePath = /private/UFC_NFTAdminUpgrade

        // Initialize the total supply
        self.totalSupply = 0

        self.setData = {}
        self.seriesData = {}
        self.series <- {}

        // Put Admin in storage
        self.account.save(<-create Admin(), to: self.AdminStoragePath)

        self.account.link<&UFC_NFT.Admin>(
            self.AdminPrivatePath,
            target: self.AdminStoragePath
        ) ?? panic("Could not get a capability to the admin")

        emit ContractInitialized()
	}
}