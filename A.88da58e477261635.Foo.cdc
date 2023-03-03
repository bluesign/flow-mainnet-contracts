import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe

pub contract Foo: NonFungibleToken {

    pub let version: String

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64)
    pub event Burned(id: UInt64)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let CollectionPrivatePath: PrivatePath
    pub let AdminStoragePath: StoragePath

    /// The total number of Foo NFTs that have been minted.
    ///
    pub var totalSupply: UInt64

    pub struct Metadata {

        pub let name: String
        pub let description: String
        pub let thumbnail: String
        pub let foo: String
        pub let bar: Int

        init(
            name: String,
            description: String,
            thumbnail: String,
            foo: String,
            bar: Int,
        ) {
            self.name = name
            self.description = description
            self.thumbnail = thumbnail
            self.foo = foo
            self.bar = bar
        }
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

        pub let id: UInt64
        pub let metadata: Metadata

        init(metadata: Metadata) {
            self.id = self.uuid
            self.metadata = metadata
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.NFTView>(),
                Type<MetadataViews.Display>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.Royalties>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.NFTView>():
                    return self.resolveNFTView(self.metadata)
                case Type<MetadataViews.Display>():
                    return self.resolveDisplay(self.metadata)
                case Type<MetadataViews.ExternalURL>():
                    return self.resolveExternalURL()
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return self.resolveNFTCollectionDisplay()
                case Type<MetadataViews.NFTCollectionData>():
                    return self.resolveNFTCollectionData()
                case Type<MetadataViews.Royalties>():
                    return self.resolveRoyalties()
            }

            return nil
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
        
        pub fun resolveDisplay(_ metadata: Metadata): MetadataViews.Display {
            return MetadataViews.Display(
                name: metadata.name,
                description: metadata.description,
                thumbnail: MetadataViews.IPFSFile(cid: metadata.thumbnail, path: nil)
            )
        }
        
        pub fun resolveExternalURL(): MetadataViews.ExternalURL {
            return MetadataViews.ExternalURL("http://foo.com/".concat(self.id.toString()))
        }
        
        pub fun resolveNFTCollectionDisplay(): MetadataViews.NFTCollectionDisplay {
            let media = MetadataViews.Media(
                file: MetadataViews.IPFSFile(
                    cid: "bafkreicrfbblmaduqg2kmeqbymdifawex7rxqq2743mitmeia4zdybmmre", 
                    path: nil
                ),
                mediaType: "image/jpeg"
            )
        
            return MetadataViews.NFTCollectionDisplay(
                name: "My Collection",
                description: "This is my collection.",
                externalURL: MetadataViews.ExternalURL("http://foo.com"),
                squareImage: media,
                bannerImage: media,
                socials: {}
            )
        }
        
        pub fun resolveNFTCollectionData(): MetadataViews.NFTCollectionData {
            return MetadataViews.NFTCollectionData(
                storagePath: Foo.CollectionStoragePath,
                publicPath: Foo.CollectionPublicPath,
                providerPath: Foo.CollectionPrivatePath,
                publicCollection: Type<&Foo.Collection{Foo.FooCollectionPublic}>(),
                publicLinkedType: Type<&Foo.Collection{Foo.FooCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
                providerLinkedType: Type<&Foo.Collection{Foo.FooCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(),
                createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                    return <-Foo.createEmptyCollection()
                })
            )
        }
        
        pub fun resolveRoyalties(): MetadataViews.Royalties {
            return MetadataViews.Royalties([])
        }
        
        destroy() {
            Foo.totalSupply = Foo.totalSupply - (1 as UInt64)

            emit Burned(id: self.id)
        }
    }

    pub resource interface FooCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowFoo(id: UInt64): &Foo.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow Foo reference: The ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: FooCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        
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
            let token <- token as! @Foo.NFT

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
        /// typed as Foo.NFT.
        ///
        /// This function returns nil if the NFT does not exist in this collection.
        ///
        pub fun borrowFoo(id: UInt64): &Foo.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &Foo.NFT
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
            let nftRef = nft as! &Foo.NFT
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

        /// Mint a new NFT.
        ///
        /// To mint an NFT, specify a value for each of its metadata fields.
        ///
        pub fun mintNFT(
            name: String,
            description: String,
            thumbnail: String,
            foo: String,
            bar: Int,
        ): @Foo.NFT {

            let metadata = Metadata(
                name: name,
                description: description,
                thumbnail: thumbnail,
                foo: foo,
                bar: bar,
            )

            let nft <- create Foo.NFT(metadata: metadata)

            emit Minted(id: nft.id)

            Foo.totalSupply = Foo.totalSupply + (1 as UInt64)

            return <- nft
        }
    }

    /// Return a public path that is scoped to this contract.
    ///
    pub fun getPublicPath(suffix: String): PublicPath {
        return PublicPath(identifier: "Foo_".concat(suffix))!
    }

    /// Return a private path that is scoped to this contract.
    ///
    pub fun getPrivatePath(suffix: String): PrivatePath {
        return PrivatePath(identifier: "Foo_".concat(suffix))!
    }

    /// Return a storage path that is scoped to this contract.
    ///
    pub fun getStoragePath(suffix: String): StoragePath {
        return StoragePath(identifier: "Foo_".concat(suffix))!
    }

    priv fun initAdmin(admin: AuthAccount) {
        // Create an empty collection and save it to storage
        let collection <- Foo.createEmptyCollection()

        admin.save(<- collection, to: Foo.CollectionStoragePath)

        admin.link<&Foo.Collection>(Foo.CollectionPrivatePath, target: Foo.CollectionStoragePath)

        admin.link<&Foo.Collection{NonFungibleToken.CollectionPublic, Foo.FooCollectionPublic, MetadataViews.ResolverCollection}>(Foo.CollectionPublicPath, target: Foo.CollectionStoragePath)
        
        // Create an admin resource and save it to storage
        let adminResource <- create Admin()

        admin.save(<- adminResource, to: self.AdminStoragePath)
    }

    init() {

        self.version = "0.0.24"

        self.CollectionPublicPath = Foo.getPublicPath(suffix: "Collection")
        self.CollectionStoragePath = Foo.getStoragePath(suffix: "Collection")
        self.CollectionPrivatePath = Foo.getPrivatePath(suffix: "Collection")

        self.AdminStoragePath = Foo.getStoragePath(suffix: "Admin")

        self.totalSupply = 0

        self.initAdmin(admin: self.account)

        emit ContractInitialized()
    }
}
