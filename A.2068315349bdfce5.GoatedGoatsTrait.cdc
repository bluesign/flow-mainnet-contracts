/*
    A NFT contract for the Goated Goats individual traits.
    
    Key Callouts: 
    * Unlimited supply of traits
    * Created via GoatedGoatsTrait only by admin on back-end
    * Store collection id from pack metadata
    * Store pack id that created this trait (specified by Admin at Trait creation time)
    * Main id for a trait is auto-increment
    * Collection-level metadata
    * Edition-level metadata (ipfs link, trait name, etc)
*/

import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import MetadataViews from 0x1d7e57aa55817448

pub contract GoatedGoatsTrait: NonFungibleToken {
    // -----------------------------------------------------------------------
    // NonFungibleToken Standard Events
    // -----------------------------------------------------------------------

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    // -----------------------------------------------------------------------
    // GoatedGoatsTrait Events
    // -----------------------------------------------------------------------

    pub event Mint(id: UInt64)
    pub event Burn(id: UInt64)

    // -----------------------------------------------------------------------
    // Named Paths
    // -----------------------------------------------------------------------

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    // -----------------------------------------------------------------------
    // NonFungibleToken Standard Fields
    // -----------------------------------------------------------------------

    pub var totalSupply: UInt64

    // -----------------------------------------------------------------------
    // GoatedGoatsTrait Fields
    // -----------------------------------------------------------------------

    pub var name: String

    access(self) var collectionMetadata: { String: String }
    access(self) let idToTraitMetadata: { UInt64: TraitMetadata }

    pub struct TraitMetadata {
        pub let metadata: { String: String }

        init(metadata: { String: String }) {
            self.metadata = metadata
        }
    }

    pub resource NFT : NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let packID: UInt64

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.Royalties>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            let metadata: {String: String} = self.getMetadata()
            switch view {
                case Type<MetadataViews.Trait>():
                    if let skinFileName: String = metadata["skinFilename"] {
                        let skin: String = GoatedGoatsTrait.formatFileName(value: skinFileName, prefix: "skin")
                        let skinRarity: String = metadata["skinRarity"]!
                    }
                    return MetadataViews.Trait(
                        name: metadata["traitSlot"]!,
                        value: GoatedGoatsTrait.formatFileName(value: metadata["fileName"]!, prefix: metadata["traitSlot"]!),
                        displayType: "String",
                        rarity:MetadataViews.Rarity(score: nil, max: nil, description: metadata["rarity"]!)
                    )

                case Type<MetadataViews.Traits>():
                    return MetadataViews.Traits(
                        [
                            MetadataViews.Trait(
                                name: metadata["traitSlot"]!,
                                value: GoatedGoatsTrait.formatFileName(value: metadata["fileName"]!, prefix: metadata["traitSlot"]!),
                                displayType: "String",
                                rarity:MetadataViews.Rarity(score: nil, max: nil, description: metadata["rarity"]!)
                            ) 
                        ]
                    )

                
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: GoatedGoatsTrait.CollectionStoragePath,
                        publicPath: GoatedGoatsTrait.CollectionPublicPath,
                        providerPath: /private/GoatTraitCollection,
                        publicCollection: Type<&GoatedGoatsTrait.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, GoatedGoatsTrait.TraitCollectionPublic, MetadataViews.ResolverCollection}>(),
                        publicLinkedType: Type<&GoatedGoatsTrait.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, GoatedGoatsTrait.TraitCollectionPublic, MetadataViews.ResolverCollection}>(), 
                        providerLinkedType: Type<&GoatedGoatsTrait.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, GoatedGoatsTrait.TraitCollectionPublic, MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: fun(): @NonFungibleToken.Collection {return <- GoatedGoatsTrait.createEmptyCollection()}
                    )

                case Type<MetadataViews.NFTCollectionDisplay>():
                    let externalURL: MetadataViews.ExternalURL = MetadataViews.ExternalURL("https://GoatedGoats.com")
                    let squareImage = MetadataViews.Media(file: MetadataViews.HTTPFile(url: "https://goatedgoats.com/_ipx/w_32,q_75/%2FLogo.png?url=%2FLogo.png&w=32&q=75"), mediaType: "image/png")

                    let bannerImage = MetadataViews.Media(file: MetadataViews.HTTPFile(url: "https://goatedgoats.com/_ipx/w_32,q_75/%2FLogo.png?url=%2FLogo.png&w=32&q=75"), mediaType: "image/png")

                    let socialMap : {String : MetadataViews.ExternalURL} = {
                        "twitter" : MetadataViews.ExternalURL("https://twitter.com/goatedgoats")
                    }

                    return MetadataViews.NFTCollectionDisplay(
                         name: "Goated Goats Traits",
                         description: "This is the collection of Traits that can be equipped onto Goated Goats",
                         externalURL: externalURL,
                         squareImage: squareImage,
                         bannerImage: bannerImage,
                         socials: socialMap
                    )
                
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL(
                        "https://GoatedGoats.com"
                    )
                
                case Type<MetadataViews.Royalties>():
                    let royaltyReceiver = getAccount(0xd7081a5c66dc3e7f).getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)

                    return MetadataViews.Royalties(
                        [MetadataViews.Royalty(recepient: royaltyReceiver, cut: 0.05, description: "This is the royalty receiver for traits")]
                    )

                case Type<MetadataViews.Display>():
                    var ipfsImage = MetadataViews.IPFSFile(cid: "No thumbnail cid set", path: "No thumbnail pat set")
                    if (self.getMetadata().containsKey("thumbnailCID")) {
                        ipfsImage = MetadataViews.IPFSFile(cid: self.getMetadata()["thumbnailCID"]!, path: self.getMetadata()["thumbnailPath"])
                    }
                    return MetadataViews.Display(
                        name: self.getMetadata()["name"] ?? "Goated Goat Trait ".concat(self.id.toString()),
                        description: self.getMetadata()["description"] ?? "No description set",
                        thumbnail: ipfsImage
                    )
            }

            return nil
        }

        pub fun getMetadata(): {String: String} {
            if (GoatedGoatsTrait.idToTraitMetadata[self.id] != nil) {
                return GoatedGoatsTrait.idToTraitMetadata[self.id]!.metadata
            } else {
                return {}
            }
        }

        init(id: UInt64, packID: UInt64) {
            self.id = id
            self.packID = packID
            emit Mint(id: self.id)
        }

        destroy() {
            emit Burn(id: self.id)
        }
    }

    pub resource interface TraitCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowTrait(id: UInt64): &GoatedGoatsTrait.NFT? {
            post {
                (result == nil) || (result?.id == id): 
                    "Cannot borrow GoatedGoatsTrait reference: The ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: TraitCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <-token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @GoatedGoatsTrait.NFT
            let id: UInt64 = token.id
            let oldToken <- self.ownedNFTs[id] <- token
            emit Deposit(id: id, to: self.owner?.address)
            destroy oldToken
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowTrait(id: UInt64): &GoatedGoatsTrait.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &GoatedGoatsTrait.NFT
            } else {
                return nil
            }
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let trait = nft as! &GoatedGoatsTrait.NFT
            return trait as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // -----------------------------------------------------------------------
    // Admin Functions
    // -----------------------------------------------------------------------
    access(account) fun setEditionMetadata(editionNumber: UInt64, metadata: {String: String}) {
        self.idToTraitMetadata[editionNumber] = TraitMetadata(metadata: metadata)
    }

    access(account) fun setCollectionMetadata(metadata: {String: String}) {
        self.collectionMetadata = metadata
    }

    access(account) fun mint(nftID: UInt64, packID: UInt64) : @NonFungibleToken.NFT {
        self.totalSupply = self.totalSupply + 1
        return <-create NFT(id: nftID, packID: packID)
    }

    // -----------------------------------------------------------------------
    // Public Functions
    // -----------------------------------------------------------------------
    pub fun getTotalSupply(): UInt64 {
        return self.totalSupply
    }

    pub fun getName(): String {
        return self.name
    }

    pub fun getCollectionMetadata(): {String: String} {
        return self.collectionMetadata
    }

    pub fun getEditionMetadata(_ edition: UInt64): {String: String} {
        if (self.idToTraitMetadata[edition] != nil) {
            return self.idToTraitMetadata[edition]!.metadata
        } else {
            return {}
        }
    }

        access(contract) fun formatFileName(value:String, prefix:String):String {
        let length= value.length
        let start=prefix.length+1
        let trimmed = value.slice(from:start, upTo: length-4)
        return  trimmed
    }

    // -----------------------------------------------------------------------
    // NonFungibleToken Standard Functions
    // -----------------------------------------------------------------------
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    init() {
        self.name = "Goated Goats Traits"
        self.totalSupply = 0

        self.collectionMetadata = {}
        self.idToTraitMetadata = {}

        self.CollectionStoragePath = /storage/GoatTraitCollection
        self.CollectionPublicPath = /public/GoatTraitCollection

        emit ContractInitialized()
    }
}
 
