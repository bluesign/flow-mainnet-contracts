// This is an qrl implementation of a Flow Non-Fungible Token
// It is not part of the official standard but it assumed to be
// very similar to how many NFTs would implement the core functionality.

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract QRLNFT: NonFungibleToken {

     pub var totalSupply: UInt64

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64

        pub let name: String
        pub let description: String
        pub let thumbnail: String

        access(self) let attributes: {String: String}
        pub fun getAttributes(): {String: String} {
            return self.attributes
        }
        access(self) let metadata: {String: String}
        pub fun getMetadata(): {String: String} {
            return self.attributes
        }

        access(self) let royalties: [MetadataViews.Royalty]

        init(
            id: UInt64,
            name: String,
            description: String,
            thumbnail: String,
            royalties: [MetadataViews.Royalty],
            attributes: {String: String},
            metadata: {String: String}
        ) {
            self.id = id
            self.name = name
            self.description = description
            self.thumbnail = thumbnail
            self.royalties = royalties
            self.attributes = attributes;
            self.metadata = metadata;
        }
    
        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.thumbnail
                        )
                    )
                case Type<MetadataViews.Editions>():
                    // There is no max number of NFTs that can be minted from this contract
                    // so the max edition field value is set to nil
                    let editionInfo = MetadataViews.Edition(name: "QRL", number: self.id, max: nil)
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
                    return MetadataViews.ExternalURL("https://qldernft.com/lands".concat(self.id.toString()))
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: QRLNFT.CollectionStoragePath,
                        publicPath: QRLNFT.CollectionPublicPath,
                        providerPath: /private/QRLNFTCollection,
                        publicCollection: Type<&QRLNFT.Collection{QRLNFT.QRLNFTCollectionPublic}>(),
                        publicLinkedType: Type<&QRLNFT.Collection{QRLNFT.QRLNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&QRLNFT.Collection{QRLNFT.QRLNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-QRLNFT.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://images.ctfassets.net/q6b7xnxzylaw/7mCJkTtu6ZOjqOrhWM1rz/18a37147ca46602c66fa522a2c796ab9/logo--qrl.png?w=800"
                        ),
                        mediaType: "image/png"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "The Ultimate Queenslander NFT",
                        description: "In search of the best postcode in the Metaverse, we have dreamt of the quintessential experience.",
                        externalURL: MetadataViews.ExternalURL("https://qldernft.com/"),
                        squareImage: media,
                        bannerImage: media,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/nftqlder")
                        }
                    )
            }
            return nil
        }
    }

    pub resource interface QRLNFTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowQRLNFT(id: UInt64): &QRLNFT.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow QRLNFT reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: QRLNFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
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
            let token <- token as! @QRLNFT.NFT

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
 
        pub fun borrowQRLNFT(id: UInt64): &QRLNFT.NFT? {
            if self.ownedNFTs[id] != nil {
                // Create an authorized reference to allow downcasting
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &QRLNFT.NFT
            }

            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let QRLNFT = nft as! &QRLNFT.NFT
            return QRLNFT as &AnyResource{MetadataViews.Resolver}
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
            recipient: &{NonFungibleToken.CollectionPublic},
            name: String,
            description: String,
            thumbnail: String,
            royalties: [MetadataViews.Royalty],
            attributes: {String: String},
            metadata: {String: String}
        ) {

            // create a new NFT
            var newNFT <- create NFT(
                id: QRLNFT.totalSupply,
                name: name,
                description: description,
                thumbnail: thumbnail,
                royalties: royalties,
                attributes: attributes,
                metadata: metadata,
            )

            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-newNFT)

            QRLNFT.totalSupply = QRLNFT.totalSupply + UInt64(1)
        }
    }

    init() {
        // Initialize the total supply
        self.totalSupply = 0

        // Set the named paths
        self.CollectionStoragePath = /storage/QRLNFTCollection
        self.CollectionPublicPath = /public/QRLNFTCollection
        self.MinterStoragePath = /storage/QRLNFTMinter

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // create a public capability for the collection
        self.account.link<&QRLNFT.Collection{NonFungibleToken.CollectionPublic, QRLNFT.QRLNFTCollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        emit ContractInitialized()
    }
}
