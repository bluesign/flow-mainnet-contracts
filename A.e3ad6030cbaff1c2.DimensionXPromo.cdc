// This is an example implementation of a Flow Non-Fungible Token
// It is not part of the official standard but it assumed to be
// very similar to how many NFTs would implement the core functionality.

import FlowToken from 0x1654653399040a61
import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import MetadataViews from 0x1d7e57aa55817448

pub contract DimensionXPromo: NonFungibleToken {

    pub var totalSupply: UInt64
    access(self) var metadataUrl: String

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64

        init(
            id: UInt64,
        ) {
            self.id = id
        }
    
        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL(
                        url: DimensionXPromo.metadataUrl.concat(self.id.toString())
                    )
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: ("DimensionX #").concat(self.id.toString()),
                        description: "A Promotional NFT for the DimensionX Game!",
                        thumbnail: MetadataViews.HTTPFile(
                        url: "https://dimensionxstorage.blob.core.windows.net/dmxgamepromos/dmx_placeholder_promo_image.png"
                        )
                    )
                 case Type<MetadataViews.Royalties>():
                    return [MetadataViews.Royalty(
                        receiver: DimensionXPromo.account.getCapability<&{FungibleToken.Receiver}>(MetadataViews.getRoyaltyReceiverPublicPath()),
                        cut: UFix64(0.10),
                        description: "Crypthulhu royalties",
                    )]
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: DimensionXPromo.CollectionStoragePath,
                        publicPath: DimensionXPromo.CollectionPublicPath,
                        providerPath: /private/dmxCollection,
                        publicCollection: Type<&DimensionXPromo.Collection{DimensionXPromo.DimensionXPromoCollectionPublic}>(),
                        publicLinkedType: Type<&DimensionXPromo.Collection{DimensionXPromo.DimensionXPromoCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&DimensionXPromo.Collection{DimensionXPromo.DimensionXPromoCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-DimensionXPromo.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return MetadataViews.NFTCollectionDisplay(
                        name: "Dimension X",
                        description: "Dimension X is a Free-to-Play, Play-to-Earn strategic role playing game on the Flow blockchain set in the Dimension X comic book universe, where a pan-dimensional explosion created super powered humans, aliens and monsters with radical and terrifying superpowers!",
                        externalURL: MetadataViews.ExternalURL("https://dimensionxnft.com"),
                        squareImage: MetadataViews.Media(
                            file: MetadataViews.HTTPFile(url: DimensionXPromo.metadataUrl.concat("collection_image.png")),
                            mediaType: "image/png"
                        ),
                        bannerImage: MetadataViews.Media(
                            file: MetadataViews.HTTPFile(url: DimensionXPromo.metadataUrl.concat("collection_banner.png")),
                            mediaType: "image/png"
                        ),
                        socials: {
                            "discord": MetadataViews.ExternalURL("https://discord.gg/BK5yAD6VQg"),
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/DimensionX_NFT")
                        }
                    )
            }

            return nil
        }
    }

    pub resource interface DimensionXPromoCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowDimensionXPromo(id: UInt64): &DimensionXPromo.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow DimensionXPromo reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: DimensionXPromoCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
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
            let token <- token as! @DimensionXPromo.NFT

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

        // borrowNFT gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }
 
        pub fun borrowDimensionXPromo(id: UInt64): &DimensionXPromo.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &DimensionXPromo.NFT
            }

            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let dimensionXPromo = nft as! &DimensionXPromo.NFT
            return dimensionXPromo as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // public function that anyone can call to create a new empty collection
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
    pub resource NFTMinter {

        // mintNFT mints a new NFT with a new ID
        // and deposit it in the recipients collection using their collection reference
        pub fun mintNFT(
            recipient: &Collection{NonFungibleToken.CollectionPublic},
        ) {

            // create a new NFT
            var newNFT <- create NFT(
                id: DimensionXPromo.totalSupply,
            )

            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-newNFT)

            DimensionXPromo.totalSupply = DimensionXPromo.totalSupply + UInt64(1)
        }
    }

    init() {
        // Initialize the total supply
        self.totalSupply = 0
        self.metadataUrl = "https://www.dimensionx.com/promo/"

        // Set the named paths
        self.CollectionStoragePath = /storage/dimensionXPromoCollection
        self.CollectionPublicPath = /public/dimensionXPromoCollection
        self.MinterStoragePath = /storage/dimensionXMinter

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // create a public capability for the collection
        self.account.link<&DimensionXPromo.Collection{NonFungibleToken.CollectionPublic, DimensionXPromo.DimensionXPromoCollectionPublic}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        emit ContractInitialized()
    }
}
