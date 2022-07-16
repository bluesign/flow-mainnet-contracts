import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import Evergreen from 0x3cb7ceeb625a600a

// DigitalArt defines NFTs that represent digital art in Sequel.
// See https://sequel.space for more details.
//
// DigitalArt tokens support Evergreen token standard.
//
// Source: https://github.com/piprate/sequel-flow-contracts
//
pub contract DigitalArt: NonFungibleToken {

    // Events
    //
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, asset: String, edition: UInt64, modID: UInt64)

    // Named Paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath
    pub let AdminPrivatePath: PrivatePath

    // The total number of DigitalArt NFTs that have been minted
    //
    pub var totalSupply: UInt64

    // Variable size dictionary of Master resources
    access(self) var masters: {String: Master}

    // Master enables mint-on-demand functionality and defines a master copy of a token
    // that is used to mint a number of editions (limited by metadata.maxEditions).
    // Once all editions are minted, the master is 'closed' but remains on-chain
    // to prevent re-minting NFTs with the same asset ID.
    //
    pub struct Master {
        pub var metadata: Metadata?
        pub var evergreenProfile: Evergreen.Profile?
        pub var nextEdition: UInt64
        pub var closed: Bool

        init(metadata: Metadata, evergreenProfile: Evergreen.Profile)  {
            self.metadata = metadata
            self.evergreenProfile = evergreenProfile
            self.nextEdition = 1
            self.closed = false
        }

        pub fun newEditionID() : UInt64 {
            let val = self.nextEdition
            self.nextEdition = self.nextEdition + UInt64(1)
            return val
        }

        pub fun availableEditions() : UInt64 {
            if !self.closed && self.metadata!.maxEdition >= self.nextEdition {
                return self.metadata!.maxEdition - self.nextEdition + UInt64(1)
            } else {
                return 0
            }
        }

        // We close masters after all editions are minted instead of deleting master records
        // This process ensures nobody can ever mint tokens with the same asset ID.
        pub fun close() {
            self.metadata = nil
            self.evergreenProfile = nil
            self.nextEdition = 0
            self.closed = true
        }
    }

    // Metadata defines Digital Art's metadata.
    //
    pub struct Metadata {
        // Name
        pub let name: String
        // Artist name
        pub let artist: String
        // Description
        pub let description: String
        // Media type: Image, Audio, Video
        pub let type: String
        // A URI of the original digital art content.
        pub let contentURI: String
        // A URI of the digital art preview content (i.e. a thumbnail).
        pub let contentPreviewURI: String
        // MIME type (e.g. 'image/jpeg')
        pub let mimetype: String
        // Edition number of the given NFT. Editions are unique for the same master,
        // identified by the asset ID.
        pub var edition: UInt64
        // The number of editions that may have been produced for the given master.
        // This number can't be exceeded by the contract, but there is no obligation
        // to mint all the declared editions.
        // If maxEdition == 1, the given NFT is one-of-a-kind.
        pub let maxEdition: UInt64
        // The DID of the master's asset. This ID is the same
        // for all editions of a particular Digital Art NFT.
        pub let asset: String
        // A URI of the full digital art's metadata JSON
        // as it existed at the time the master was sealed.
        pub let metadataURI: String
        // The ChainLocker record ID of the full metadata JSON
        // as it existed at the time the master was sealed.
        pub let record: String
        // The ChainLocker asset head ID of the full metadata JSON.
        // It can be used to retrieve the current metadata JSON (if changed).
		pub let assetHead: String

        init(
            name: String,
            artist: String,
            description: String,
            type: String,
            contentURI: String,
            contentPreviewURI: String,
            mimetype: String,
            edition: UInt64,
            maxEdition: UInt64,
            asset: String,
            metadataURI: String,
            record: String,
            assetHead: String
    )  {
            self.name = name
            self.artist = artist
            self.description = description
            self.type = type
            self.contentURI = contentURI
            self.contentPreviewURI = contentPreviewURI
            self.mimetype = mimetype
            self.edition = edition
            self.maxEdition = maxEdition
            self.asset = asset
            self.metadataURI = metadataURI
            self.record = record
            self.assetHead = assetHead
        }

        pub fun setEdition(edition: UInt64) {
            self.edition = edition
        }
    }

    // NFT
    // DigitalArt as an NFT
    //
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver, Evergreen.Token {
        // The token's ID
        pub let id: UInt64

        pub let metadata: Metadata
        pub let evergreenProfile: Evergreen.Profile

        // initializer
        //
        init(initID: UInt64, metadata: Metadata, evergreenProfile: Evergreen.Profile) {
            self.id = initID
            self.metadata = metadata
            self.evergreenProfile = evergreenProfile
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<DigitalArt.Metadata>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    let thumbnailUri = self.metadata.contentPreviewURI
                    if thumbnailUri.slice(from: 0, upTo: 4) == "ipfs" {
                        return MetadataViews.Display(
                            name: self.metadata.name,
                            description: self.metadata.description,
                            thumbnail: MetadataViews.IPFSFile(
                               cid: thumbnailUri.slice(from: 7, upTo: thumbnailUri.length),
                               ""
                            )
                        )
                    } else {
                        return MetadataViews.Display(
                            name: self.metadata.name,
                            description: self.metadata.description,
                            thumbnail: MetadataViews.HTTPFile(
                                url: thumbnailUri
                            )
                        )
                    }
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(
                        self.evergreenProfile.buildRoyalties(defaultReceiverPath: MetadataViews.getRoyaltyReceiverPublicPath())
                    )
                case Type<DigitalArt.Metadata>():
                    return self.metadata
            }

            return nil
        }

        pub fun getAssetID(): String {
            return self.metadata.asset
        }

        pub fun getEvergreenProfile(): Evergreen.Profile {
            return self.evergreenProfile
        }
    }

    // This is the interface that users can cast their DigitalArt Collection as
    // to allow others to deposit DigitalArt into their Collection. It also allows for reading
    // the details of DigitalArt in the Collection.
    pub resource interface CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowDigitalArt(id: UInt64): &DigitalArt.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow DigitalArt reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // Collection
    // A collection of DigitalArt NFTs owned by an account
    //
    pub resource Collection:
            CollectionPublic,
            Evergreen.CollectionPublic,
            NonFungibleToken.Provider,
            NonFungibleToken.Receiver,
            NonFungibleToken.CollectionPublic,
            MetadataViews.ResolverCollection {

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
            let token <- token as! @DigitalArt.NFT

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

        // borrowDigitalArt
        // Gets a reference to an NFT in the collection as a DigitalArt,
        // exposing all of its fields (including the typeID).
        // This is safe as there are no functions that can be called on the DigitalArt.
        //
        pub fun borrowDigitalArt(id: UInt64): &DigitalArt.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &DigitalArt.NFT
            } else {
                return nil
            }
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            return nft as! &DigitalArt.NFT
        }

        pub fun borrowEvergreenToken(id: UInt64): &AnyResource{Evergreen.Token}? {
            return self.borrowDigitalArt(id: id)
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

    pub fun getMetadata(address:Address, tokenId:UInt64) : Metadata? {
        let acct = getAccount(address)
        let collectionRef = acct.getCapability(self.CollectionPublicPath)!.borrow<&{DigitalArt.CollectionPublic}>()
			?? panic("Could not borrow capability from public collection")

        return collectionRef.borrowDigitalArt(id: tokenId)!.metadata
    }

    pub fun isClosed(masterId: String): Bool {
        if DigitalArt.masters.containsKey(masterId) {
            let master = &DigitalArt.masters[masterId]! as &Master
            return master.closed
        } else {
            return false
        }
    }

    // Admin
    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
    pub resource Admin {

        // sealMaster saves and freezes the master copy that then can be used
        // to mint NFT editions.
        pub fun sealMaster(metadata: Metadata, evergreenProfile: Evergreen.Profile) {
            pre {
               metadata.asset != "" : "Empty asset ID"
               metadata.edition == UInt64(0) : "Edition should be zero"
               metadata.maxEdition >= UInt64(1) : "MaxEdition should be positive"
               !DigitalArt.masters.containsKey(metadata.asset) : "Master already sealed"
            }
            DigitalArt.masters[metadata.asset] = Master(
                metadata: metadata,
                evergreenProfile: evergreenProfile
            )
        }

        pub fun isSealed(masterId: String) : Bool {
            return DigitalArt.masters.containsKey(masterId)
        }

        pub fun availableEditions(masterId: String) : UInt64 {
            pre {
               DigitalArt.masters.containsKey(masterId) : "Master not found"
            }

            let master = &DigitalArt.masters[masterId]! as &Master

            return master.availableEditions()
        }

        pub fun evergreenProfile(masterId: String) : Evergreen.Profile {
            pre {
               DigitalArt.masters.containsKey(masterId) : "Master not found"
            }

            let master = &DigitalArt.masters[masterId]! as &Master

            return master.evergreenProfile!
        }

        // mintEditionNFT mints a token from master with the given ID.
        // If it's a mint-on-demand, provide MOD ID to link it with the Marketplace database.
        // Otherwise, set modID to 0.
        pub fun mintEditionNFT(masterId: String, modID: UInt64) : @DigitalArt.NFT {
            pre {
               DigitalArt.masters.containsKey(masterId) : "Master not found"
            }

            let master = &DigitalArt.masters[masterId]! as &Master

            assert(master.availableEditions() > 0, message: "No more tokens to mint")

            let metadata = master.metadata!
            let edition = master.newEditionID()
            metadata.setEdition(edition: edition)

            // create a new NFT
            var newNFT <- create NFT(
                initID: DigitalArt.totalSupply,
                metadata: metadata,
                evergreenProfile: master.evergreenProfile!
            )

            emit Minted(id: DigitalArt.totalSupply, asset: metadata.asset, edition: edition, modID: modID)

            DigitalArt.totalSupply = DigitalArt.totalSupply + UInt64(1)

            if master.availableEditions() == 0 {
                master.close()
            }

            return <- newNFT
        }
    }

    // initializer
    //
    init() {
        // Set our named paths
        self.CollectionStoragePath = /storage/sequelDigitalArtCollection
        self.CollectionPublicPath = /public/sequelDigitalArtCollection
        self.AdminStoragePath = /storage/digitalArtAdmin
        self.AdminPrivatePath = /private/digitalArtAdmin

        // Initialize the total supply
        self.totalSupply = 0

        self.masters = {}

        // Create a Admin resource and save it to storage
        let admin <- create Admin()
        self.account.save(<-admin, to: self.AdminStoragePath)

        emit ContractInitialized()
    }
}