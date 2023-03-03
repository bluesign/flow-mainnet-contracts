import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import MetadataViews from 0x1d7e57aa55817448
import MemeToken from 0x4ba5947a0f1852c0

/// Meme 
/// Defines a non fungible token. 
///
pub contract Meme: NonFungibleToken {

    /// defines the total supply and also
    /// used to identify nft tokens 
    pub var totalSupply: UInt64

    /// event emitted when this contract is initialized
    pub event ContractInitialized()

    /// event is emitted when nft is created
    pub event NFTCreated(
        id: UInt64,
        title: String,
        description: String,
        hash: String,
        owner: Address,
        tags: String
    )

    /// event is emitted when a nft is moved away from collection
    pub event Withdraw(id: UInt64, from: Address?)

    /// event is emitted when a nft is moved to a collection
    pub event Deposit(id: UInt64, to: Address?)

    /// paths used to store collection, nfts and assign capabilities
    pub let CollectionStoragePath: StoragePath
    pub let CollectionAdminStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    /// the actual nft resource 
    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

        /// nft identifier - in that case total supply is used 
        pub let id: UInt64

        /// name oft the nft 
        pub let title: String

        /// descript of the nft 
        pub let description: String

        /// hash idfentifier 
        pub let hash: String

        /// struct of royalties
        access(self) let royalties: [MetadataViews.Royalty]

        /// addional expendable metadata to store addional information
        pub let metadata: {String: AnyStruct}
    
        init(
            id: UInt64,
            title: String,
            description: String,
            hash: String,
            royalties: [MetadataViews.Royalty],
            metadata: {String: AnyStruct},
        ) {
            self.id = id
            self.title = title
            self.description = description
            self.hash = hash
            self.royalties = royalties
            self.metadata = metadata

            emit NFTCreated(
                id: id,
                title: title,
                description: description,
                hash: hash,
                owner: self.metadata["minter"]! as! Address,
                tags: self.metadata["tags"]! as! String
            )
        }

        /// returns all possible view for nft type
        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Traits>()
            ]
        }

        /// resolves for a specific view type a struct of data
        /// e.g. if you want to display royalties - please use 
        /// resolve(Type<MetadataViews.Royalties>()) to display royalties
        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.title,
                        description: self.description,
                        hash: MetadataViews.HTTPFile(
                            url: self.hash
                        )
                    )
                case Type<MetadataViews.Editions>():
                    // There is no max number of NFTs that can be minted from this contract
                    // so the max edition field value is set to nil
                    let editionInfo = MetadataViews.Edition(name: "Meme NFT Edition", number: self.id, max: Meme.totalSupply)
                    let editionList: [MetadataViews.Edition] = [editionInfo]
                    return MetadataViews.Editions(
                        editionList
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(
                        self.royalties
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://example-nft.onflow.org/".concat(self.id.toString()))
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: Meme.CollectionStoragePath,
                        publicPath: Meme.CollectionPublicPath,
                        providerPath: /private/MemeCollection,
                        publicCollection: Type<&Meme.Collection{Meme.NFTCollectionPublic}>(),
                        publicLinkedType: Type<&Meme.Collection{Meme.NFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&Meme.Collection{Meme.NFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-Meme.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg"
                        ),
                        mediaType: "image/svg+xml"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "The Example Collection",
                        description: "This collection is used as an example to help you develop your next Flow NFT.",
                        externalURL: MetadataViews.ExternalURL("https://example-nft.onflow.org"),
                        squareImage: media,
                        bannerImage: media,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/flow_blockchain")
                        }
                    )
                case Type<MetadataViews.Traits>():                  
                    return MetadataViews.dictToTraits(dict: self.metadata, excludedNames: nil)
            }
            return nil
        }

        /// Update metadata
        /// Updates the metadata key by key and reassign the original one
        pub fun update(metadata: {String: AnyStruct}) {
            for key in metadata.keys {
                self.metadata[key] = metadata[key]
            }
        }
    }

    pub resource interface NFTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowMemeNFT(id: UInt64): &Meme.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow Meme NFT reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource interface NFTTemplate {
        pub fun template(id: UInt64, title: String, hash: String)
    }

    pub resource Collection: NFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        // withdraw removes an NFT from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @Meme.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // mintNFT mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        pub fun mintNFT(
            recipient: &{NonFungibleToken.CollectionPublic},
            title: String,
            description: String,
            hash: String,
            tags: String,
            payment: @FungibleToken.Vault?
        ) {
            // destroy payment for now
            destroy payment

            let metadata: {String: AnyStruct} = {}
            let currentBlock = getCurrentBlock()
            metadata["block"] = currentBlock.height
            metadata["timestamp"] = currentBlock.timestamp
            metadata["minter"] = recipient.owner!.address
            metadata["tags"] = tags

            // get recipient address by force 
            let address = recipient.owner!.address
      
            // construct royalties
            var royalties: [MetadataViews.Royalty] = []
            let creatorCapability = getAccount(recipient.owner!.address).getCapability<&{FungibleToken.Receiver}>(MetadataViews.getRoyaltyReceiverPublicPath())

            // Make sure the royalty capability is valid before minting the NFT
            if !creatorCapability.check() { panic("Beneficiary capability is not valid!") }

            // create a new NFT
            var nft <- create NFT(
                id: Meme.totalSupply,
                title: title,
                description: description,
                hash: hash,
                royalties: royalties,
                metadata: metadata
            )

            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-nft)

            Meme.totalSupply = Meme.totalSupply + UInt64(1)
        }

        // borrowNFT gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }
 
        pub fun borrowMemeNFT(id: UInt64): &Meme.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &Meme.NFT
            }

            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let meme = nft as! &Meme.NFT
            return meme as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    /// The function to create a new empty collection.
    /// Please be aware that only the contract admin can create a new collection.
    pub fun createEmptyCollection(): @Collection {
        panic("Please use the admin resource to create a new collection")
    }

    /// The administrator resource that can create new collection.
    pub resource Administrator {

        /// Create a new empty collection.
        pub fun createEmptyCollection(): @NonFungibleToken.Collection {
            return <- create Collection()
        }
    }

    init() {
        // Initialize the total supply
        self.totalSupply = 0

        // Set the named paths
        self.CollectionStoragePath = /storage/MemeCollection
        self.CollectionPublicPath = /public/MemeCollection
        self.CollectionAdminStoragePath = /storage/MemeCollectionAdmin

        // Create a administrator resource and save it to the admin account storage
        let admin <- create Administrator()
        self.account.save(<-admin, to: self.CollectionAdminStoragePath)

        emit ContractInitialized()
    }
}
 