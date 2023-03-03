import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract YahooPartnersCollectible: NonFungibleToken {

    // Events
    //
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64)

    // Named Paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath

    // totalSupply
    // The total number of YahooPartnersCollectible that have been minted
    //
    pub var totalSupply: UInt64

    // metadata for each item
    // 
    access(contract) var itemMetadata: {UInt64: Metadata}

    // Type Definitions
    // 
    pub struct Metadata {
        pub let name: String
        pub let description: String

        // mediaType: MIME type of the media
        // - image/png
        // - image/jpeg
        // - video/mp4
        // - audio/mpeg
        pub let mediaType: String

        // mediaHash: IPFS storage hash
        pub let mediaHash: String

        // additional metadata
        access(self) let additional: {String: String}

        // number of items
        pub(set) var itemCount: UInt64

        init(name: String, description: String, mediaType: String, mediaHash: String, additional: {String: String}) {
            self.name = name
            self.description = description
            self.mediaType = mediaType
            self.mediaHash = mediaHash
            self.additional = additional
            self.itemCount = 0
        }

        pub fun getAdditional(): {String: String} {
            return self.additional
        }
    }

    // NFT
    // A Yahoo Collectible NFT
    //
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        // The token's ID
        pub let id: UInt64

        // The token's type
        pub let itemID: UInt64

        // The token's edition number
        pub let editionNumber: UInt64

        // initializer
        //
        init(initID: UInt64, itemID: UInt64) {
            self.id = initID
            self.itemID = itemID

            let metadata = YahooPartnersCollectible.itemMetadata[itemID] ?? panic("itemID not valid")
            self.editionNumber = metadata.itemCount + (1 as UInt64)

            // Increment the edition count by 1
            metadata.itemCount = self.editionNumber

            YahooPartnersCollectible.itemMetadata[itemID] = metadata
        }

        // Expose metadata
        pub fun getMetadata(): Metadata? {
            return YahooPartnersCollectible.itemMetadata[self.itemID]
        }

        pub fun getRoyalties(): MetadataViews.Royalties {
            var royalties: [MetadataViews.Royalty] = []
            let receiver = getAccount(0x77e38c96fda5c5c5).getCapability<&FungibleToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)

            royalties.append(
                MetadataViews.Royalty(
                    receiver: receiver,
                    cut: 0.025,
                    description: "Royalty receiver for Yahoo partners"
                )
            )

            return MetadataViews.Royalties(
                royalties
            )
        }

        pub fun getEditions(): MetadataViews.Editions {
            let metadata = self.getMetadata() ?? panic("missing metadata")

            let editionInfo = MetadataViews.Edition(name: metadata.name, number: self.editionNumber, max: metadata.itemCount)
            let editionList: [MetadataViews.Edition] = [editionInfo]

            return MetadataViews.Editions(
                editionList
            )
        }

        pub fun getExternalURL(): MetadataViews.ExternalURL {
            return MetadataViews.ExternalURL("https://bay.blocto.app/flow/yahooPartners/".concat(self.id.toString()))
        }

        pub fun getCollectionData(): MetadataViews.NFTCollectionData {
            return MetadataViews.NFTCollectionData(
                storagePath: YahooPartnersCollectible.CollectionStoragePath,
                publicPath: YahooPartnersCollectible.CollectionPublicPath,
                providerPath: /private/yahooPartnersCollectibleCollection,
                publicCollection: Type<&YahooPartnersCollectible.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, YahooPartnersCollectible.CollectionPublic, MetadataViews.ResolverCollection}>(),
                publicLinkedType: Type<&YahooPartnersCollectible.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, YahooPartnersCollectible.CollectionPublic, MetadataViews.ResolverCollection}>(),
                providerLinkedType: Type<&YahooPartnersCollectible.Collection>(),
                createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                    return <-YahooPartnersCollectible.createEmptyCollection()
                })
            )
        }

        pub fun getCollectionDisplay(): MetadataViews.NFTCollectionDisplay {
            let squareImage = MetadataViews.Media(
                file: MetadataViews.HTTPFile(
                    url: "https://raw.githubusercontent.com/portto/assets/main/nft/flow/yahoo/logo.png"
                ),
                mediaType: "image/png"
            )

            let bannerImager = MetadataViews.Media(
                file: MetadataViews.HTTPFile(
                    url: "https://raw.githubusercontent.com/portto/assets/main/nft/flow/yahoo/banner.png"
                ),
                mediaType: "image/png"
            )

            return MetadataViews.NFTCollectionDisplay(
                name: "Yahoo Partners",
                description: "NFT partners of Yahoo Taiwan",
                externalURL: MetadataViews.ExternalURL("https://bay.blocto.app/market?collections=yahoo_partners"),
                squareImage: squareImage,
                bannerImage: bannerImager,
                socials: {
                    "twitter": MetadataViews.ExternalURL("https://twitter.com/Yahoo")
                }
            )
        }

        pub fun getTraits(): MetadataViews.Traits {
            let metadata = self.getMetadata() ?? panic("missing metadata")

            return MetadataViews.dictToTraits(dict: metadata.getAdditional(), excludedNames: [])
        }

        pub fun getMedias(): MetadataViews.Medias {
            let metadata = self.getMetadata() ?? panic("missing metadata")

            let file = MetadataViews.IPFSFile(
                cid: metadata.mediaHash,
                path: nil
            )
            let mediaInfo = MetadataViews.Media(file: file, mediaType: metadata.mediaType)
            let mediaList: [MetadataViews.Media] = [mediaInfo]

            return MetadataViews.Medias(
                mediaList
            )
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.IPFSFile>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.Medias>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    let metadata = self.getMetadata() ?? panic("missing metadata")

                    return MetadataViews.Display(
                        name: metadata.name,
                        description: metadata.description,
                        thumbnail: MetadataViews.IPFSFile(
                            cid: metadata.mediaHash,
                            path: nil
                        )
                    )

                case Type<MetadataViews.Royalties>():
                    return self.getRoyalties()

                case Type<MetadataViews.Editions>():
                    return self.getEditions()
                
                case Type<MetadataViews.ExternalURL>():
                    return self.getExternalURL()

                case Type<MetadataViews.NFTCollectionData>():
                    return self.getCollectionData()
    
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return self.getCollectionDisplay()
            
                case Type<MetadataViews.IPFSFile>():
                    return MetadataViews.IPFSFile(
                        cid: self.getMetadata()!.mediaHash,
                        path: nil
                    )

                case Type<MetadataViews.Traits>():
                    return self.getTraits()

                case Type<MetadataViews.Medias>():
                    return self.getMedias()
            }

            return nil
        }
    }

    pub resource interface CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowYahooPartnersCollectible(id: UInt64): &YahooPartnersCollectible.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow YahooPartnersCollectible reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // Collection
    // A collection of YahooPartnersCollectible NFTs owned by an account
    //
    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
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

        // deposit
        // Takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        //
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @YahooPartnersCollectible.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
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

        // borrowYahooPartnersCollectible
        // Gets a reference to an NFT in the collection as a YahooPartnersCollectible,
        // exposing all of its fields.
        // This is safe as there are no functions that can be called on the YahooPartnersCollectible.
        //
        pub fun borrowYahooPartnersCollectible(id: UInt64): &YahooPartnersCollectible.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &YahooPartnersCollectible.NFT
            } else {
                return nil
            }
        }

        // borrowViewResolver
        // Gets a reference to an MetadataView.Resolver in the collection as a YahooCollectible.
        // This is safe as there are no functions that can be called on the YahooCollectible.
        //
        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let exampleNFT = nft as! &YahooPartnersCollectible.NFT
            return exampleNFT as &AnyResource{MetadataViews.Resolver}
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

    // Admin
    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
    pub resource Admin {

        // mintNFT
        // Mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        //
        pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, itemID: UInt64, codeHash: String?) {
            pre {
                codeHash == nil || !YahooPartnersCollectible.checkCodeHashUsed(codeHash: codeHash!): "duplicated codeHash"
            }
            
            emit Minted(id: YahooPartnersCollectible.totalSupply)

            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-create YahooPartnersCollectible.NFT(initID: YahooPartnersCollectible.totalSupply, itemID: itemID))
            YahooPartnersCollectible.totalSupply = YahooPartnersCollectible.totalSupply + (1 as UInt64)

            // if minter passed in codeHash, register it to dictionary
            if let checkedCodeHash = codeHash {
                let redeemedCodes = YahooPartnersCollectible.account.load<{String: Bool}>(from: /storage/redeemedCodes)!
                redeemedCodes[checkedCodeHash] = true
                YahooPartnersCollectible.account.save<{String: Bool}>(redeemedCodes, to: /storage/redeemedCodes)
            }
        }

        // batchMintNFT
        // Mints a batch of new NFTs
        // and deposit it in the recipients collection using their collection reference
        //
        pub fun batchMintNFT(recipient: &{NonFungibleToken.CollectionPublic}, itemID: UInt64, count: Int) {
            var index = 0
        
            while index < count {
                self.mintNFT(
                    recipient: recipient,
                    itemID: itemID,
                    codeHash: nil
                )

                index = index + 1
            }
        }

        // registerMetadata
        // Registers metadata for a itemID
        //
        pub fun registerMetadata(itemID: UInt64, metadata: Metadata) {
            pre {
                YahooPartnersCollectible.itemMetadata[itemID] == nil: "duplicated itemID"
            }

            YahooPartnersCollectible.itemMetadata[itemID] = metadata
        }

        // updateMetadata
        // Registers metadata for a itemID
        //
        pub fun updateMetadata(itemID: UInt64, metadata: Metadata) {
            pre {
                YahooPartnersCollectible.itemMetadata[itemID] != nil: "itemID does not exist"
            }

            metadata.itemCount = YahooPartnersCollectible.itemMetadata[itemID]!.itemCount

            // update metadata
            YahooPartnersCollectible.itemMetadata[itemID] = metadata
        }
    }

    // fetch
    // Get a reference to a YahooPartnersCollectible from an account's Collection, if available.
    // If an account does not have a YahooPartnersCollectible.Collection, panic.
    // If it has a collection but does not contain the itemID, return nil.
    // If it has a collection and that collection contains the itemID, return a reference to that.
    //
    pub fun fetch(_ from: Address, itemID: UInt64): &YahooPartnersCollectible.NFT? {
        let collection = getAccount(from)
            .getCapability(YahooPartnersCollectible.CollectionPublicPath)!
            .borrow<&YahooPartnersCollectible.Collection>()
            ?? panic("Couldn't get collection")
        // We trust YahooPartnersCollectible.Collection.borowYahooPartnersCollectible to get the correct itemID
        // (it checks it before returning it).
        return collection.borrowYahooPartnersCollectible(id: itemID)
    }

    // getMetadata
    // Get the metadata for a specific type of YahooPartnersCollectible
    //
    pub fun getMetadata(itemID: UInt64): Metadata? {
        return YahooPartnersCollectible.itemMetadata[itemID]
    }

    // checkCodeHashUsed
    // Check if a codeHash has been registered
    //
    pub fun checkCodeHashUsed(codeHash: String): Bool {
        var redeemedCodes = YahooPartnersCollectible.account.copy<{String: Bool}>(from: /storage/redeemedCodes)!
        return redeemedCodes[codeHash] ?? false
    }

    // initializer
    //
    init() {
        // Set our named paths
        self.CollectionStoragePath = /storage/yahooPartnersCollectibleCollection
        self.CollectionPublicPath = /public/yahooPartnersCollectibleCollection
        self.AdminStoragePath = /storage/yahooPartnersCollectibleAdmin

        // Initialize the total supply
        self.totalSupply = 0

        // Initialize predefined metadata
        self.itemMetadata = {}

        // Create a Admin resource and save it to storage
        let minter <- create Admin()
        self.account.save(<-minter, to: self.AdminStoragePath)

        emit ContractInitialized()
    }
}
