import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe

pub contract Mayer: NonFungibleToken {

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

    /// The total number of Mayer NFTs that have been minted.
    ///
    pub var totalSupply: UInt64

    /// A list of royalty recipients that is attached to all NFTs
    /// minted by this contract.
    ///
    access(contract) var royalties: [MetadataViews.Royalty]
    
    /// Return the royalty recipients for this contract.
    ///
    pub fun getRoyalties(): [MetadataViews.Royalty] {
        return Mayer.royalties
    }

    pub struct Metadata {

        pub let image: String
        pub let serialNumber: UInt64
        pub let name: String
        pub let description: String

        init(
            image: String,
            serialNumber: UInt64,
            name: String,
            description: String,
        ) {
            self.image = image
            self.serialNumber = serialNumber
            self.name = name
            self.description = description
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
                Type<MetadataViews.Display>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Serial>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
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
                case Type<MetadataViews.Serial>():
                    return self.resolveSerial(self.metadata)
            }

            return nil
        }

        pub fun resolveDisplay(_ metadata: Metadata): MetadataViews.Display {
            return MetadataViews.Display(
                name: metadata.name,
                description: metadata.description,
                thumbnail: MetadataViews.IPFSFile(cid: metadata.image, path: nil)
            )
        }
        
        pub fun resolveExternalURL(): MetadataViews.ExternalURL {
            return MetadataViews.ExternalURL("https://flute-app.vercel.app/".concat(self.id.toString()))
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
                name: "mayer",
                description: "a",
                externalURL: MetadataViews.ExternalURL("https://flute-app.vercel.app"),
                squareImage: media,
                bannerImage: media,
                socials: {}
            )
        }
        
        pub fun resolveNFTCollectionData(): MetadataViews.NFTCollectionData {
            return MetadataViews.NFTCollectionData(
                storagePath: Mayer.CollectionStoragePath,
                publicPath: Mayer.CollectionPublicPath,
                providerPath: Mayer.CollectionPrivatePath,
                publicCollection: Type<&Mayer.Collection{Mayer.MayerCollectionPublic}>(),
                publicLinkedType: Type<&Mayer.Collection{Mayer.MayerCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
                providerLinkedType: Type<&Mayer.Collection{Mayer.MayerCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(),
                createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                    return <-Mayer.createEmptyCollection()
                })
            )
        }
        
        pub fun resolveRoyalties(): MetadataViews.Royalties {
            return MetadataViews.Royalties(Mayer.royalties)
        }
        
        pub fun resolveSerial(_ metadata: Metadata): MetadataViews.Serial {
            return MetadataViews.Serial(metadata.serialNumber)
        }
        
        destroy() {
            Mayer.totalSupply = Mayer.totalSupply - (1 as UInt64)

            emit Burned(id: self.id)
        }
    }

    pub resource interface MayerCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowMayer(id: UInt64): &Mayer.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow Mayer reference: The ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: MayerCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        
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
            let token <- token as! @Mayer.NFT

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
        /// typed as Mayer.NFT.
        ///
        /// This function returns nil if the NFT does not exist in this collection.
        ///
        pub fun borrowMayer(id: UInt64): &Mayer.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &Mayer.NFT
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
            let nftRef = nft as! &Mayer.NFT
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
            image: String,
            serialNumber: UInt64,
            name: String,
            description: String,
        ): @Mayer.NFT {

            let metadata = Metadata(
                image: image,
                serialNumber: serialNumber,
                name: name,
                description: description,
            )

            let nft <- create Mayer.NFT(metadata: metadata)

            emit Minted(id: nft.id)

            Mayer.totalSupply = Mayer.totalSupply + (1 as UInt64)

            return <- nft
        }

        /// Set the royalty recipients for this contract.
        ///
        /// This function updates the royalty recipients for all NFTs
        /// minted by this contract.
        ///
        pub fun setRoyalties(_ royalties: [MetadataViews.Royalty]) {
            Mayer.royalties = royalties
        }
    }

    /// Return a public path that is scoped to this contract.
    ///
    pub fun getPublicPath(suffix: String): PublicPath {
        return PublicPath(identifier: "Mayer_".concat(suffix))!
    }

    /// Return a private path that is scoped to this contract.
    ///
    pub fun getPrivatePath(suffix: String): PrivatePath {
        return PrivatePath(identifier: "Mayer_".concat(suffix))!
    }

    /// Return a storage path that is scoped to this contract.
    ///
    pub fun getStoragePath(suffix: String): StoragePath {
        return StoragePath(identifier: "Mayer_".concat(suffix))!
    }

    priv fun initAdmin(admin: AuthAccount) {
        // Create an empty collection and save it to storage
        let collection <- Mayer.createEmptyCollection()

        admin.save(<- collection, to: Mayer.CollectionStoragePath)

        admin.link<&Mayer.Collection>(Mayer.CollectionPrivatePath, target: Mayer.CollectionStoragePath)

        admin.link<&Mayer.Collection{NonFungibleToken.CollectionPublic, Mayer.MayerCollectionPublic, MetadataViews.ResolverCollection}>(Mayer.CollectionPublicPath, target: Mayer.CollectionStoragePath)
        
        // Create an admin resource and save it to storage
        let adminResource <- create Admin()

        admin.save(<- adminResource, to: self.AdminStoragePath)
    }

    init() {

        self.version = "0.0.32"

        self.CollectionPublicPath = Mayer.getPublicPath(suffix: "Collection")
        self.CollectionStoragePath = Mayer.getStoragePath(suffix: "Collection")
        self.CollectionPrivatePath = Mayer.getPrivatePath(suffix: "Collection")

        self.AdminStoragePath = Mayer.getStoragePath(suffix: "Admin")

        self.royalties = []

        self.totalSupply = 0

        self.initAdmin(admin: self.account)

        emit ContractInitialized()
    }
}
