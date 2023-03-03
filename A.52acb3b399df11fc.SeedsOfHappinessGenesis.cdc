import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import FreshmintEncoding from 0xad7ea9b6c112b937
import FreshmintMetadataViews from 0x0c82d33d4666f1f7

pub contract SeedsOfHappinessGenesis: NonFungibleToken {

    pub let version: String

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, hash: [UInt8])
    pub event Revealed(id: UInt64)
    pub event Burned(id: UInt64)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let CollectionPrivatePath: PrivatePath
    pub let AdminStoragePath: StoragePath

    /// The total number of SeedsOfHappinessGenesis NFTs that have been minted.
    ///
    pub var totalSupply: UInt64

    /// A placeholder image used to display NFTs that have not yet been revealed.
    ///
    pub let placeholderImage: String

    /// A list of royalty recipients that is attached to all NFTs
    /// minted by this contract.
    ///
    access(contract) let royalties: [MetadataViews.Royalty]
    
    /// Return the royalty recipients for this contract.
    ///
    pub fun getRoyalties(): [MetadataViews.Royalty] {
        return SeedsOfHappinessGenesis.royalties
    }

    /// The collection-level metadata for all NFTs minted by this contract.
    ///
    pub var collectionMetadata: MetadataViews.NFTCollectionDisplay

    pub struct Metadata {

        /// A salt that is published when the metadata is revealed.
        ///
        /// The salt is a byte array that is prepended to the 
        /// encoded metadata values before generating the metadata hash.
        ///
        pub let salt: [UInt8]

        pub let image: String
        pub let serialNumber: UInt64
        pub let name: String
        pub let description: String
        pub let shape: String
        pub let color: String
        pub let smile: String
        pub let emboss: String
        pub let outline: String
        pub let birthmark: String
        pub let redeemed: String

        init(
            salt: [UInt8],
            image: String,
            serialNumber: UInt64,
            name: String,
            description: String,
            shape: String,
            color: String,
            smile: String,
            emboss: String,
            outline: String,
            birthmark: String,
            redeemed: String,
        ) {
            self.salt = salt

            self.image = image
            self.serialNumber = serialNumber
            self.name = name
            self.description = description
            self.shape = shape
            self.color = color
            self.smile = smile
            self.emboss = emboss
            self.outline = outline
            self.birthmark = birthmark
            self.redeemed = redeemed
        }

        /// Encode this metadata object as a byte array.
        ///
        /// This can be used to hash the metadata and verify its integrity.
        ///
        pub fun encode(): [UInt8] {
            return self.salt
                .concat(FreshmintEncoding.encodeString(self.image))
                .concat(FreshmintEncoding.encodeUInt64(self.serialNumber))
                .concat(FreshmintEncoding.encodeString(self.name))
                .concat(FreshmintEncoding.encodeString(self.description))
                .concat(FreshmintEncoding.encodeString(self.shape))
                .concat(FreshmintEncoding.encodeString(self.color))
                .concat(FreshmintEncoding.encodeString(self.smile))
                .concat(FreshmintEncoding.encodeString(self.emboss))
                .concat(FreshmintEncoding.encodeString(self.outline))
                .concat(FreshmintEncoding.encodeString(self.birthmark))
                .concat(FreshmintEncoding.encodeString(self.redeemed))
        }

        pub fun hash(): [UInt8] {
            return HashAlgorithm.SHA3_256.hash(self.encode())
        }
    }

    /// This dictionary holds the metadata for all NFTs
    /// minted by this contract.
    ///
    /// When an NFT is revealed, its metadata is added to this 
    /// dictionary.
    ///
    access(contract) let metadata: {UInt64: Metadata}

    /// Return the metadata for an NFT.
    ///
    /// This function returns nil if the NFT has not yet been revealed.
    ///
    pub fun getMetadata(nftID: UInt64): Metadata? {
        return SeedsOfHappinessGenesis.metadata[nftID]
    }

    /// This dictionary stores all NFT IDs minted by this contract,
    /// indexed by their metadata hash.
    ///
    /// It is populated at mint time and later used to validate
    /// metadata hashes at reveal time.
    ///
    /// This dictionary is indexed by hash rather than by ID so that
    /// the contract (and client software) can prevent duplicate mints.
    ///
    access(contract) let nftsByHash: {String: UInt64}

    pub fun getNFTIDByHash(hash: String): UInt64? {
        return SeedsOfHappinessGenesis.nftsByHash[hash]
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {

        pub let id: UInt64

        /// A hash of the NFT's metadata.
        ///
        /// The metadata hash is known at mint time and 
        /// is generated by hashing the set of metadata fields
        /// for this NFT. The hash can later be used to verify
        /// that the correct metadata fields are revealed.
        ///
        pub let hash: [UInt8]

        init(hash: [UInt8]) {
            self.id = self.uuid
            self.hash = hash
        }

        /// Return the metadata for this NFT.
        ///
        /// This function returns nil if the NFT metadata has
        /// not yet been revealed.
        ///
        pub fun getMetadata(): Metadata? {
            return SeedsOfHappinessGenesis.metadata[self.id]
        }

        pub fun getViews(): [Type] {
            if self.getMetadata() != nil {
                return [
                    Type<MetadataViews.Display>(),
                    Type<MetadataViews.ExternalURL>(),
                    Type<MetadataViews.NFTCollectionDisplay>(),
                    Type<MetadataViews.NFTCollectionData>(),
                    Type<MetadataViews.Royalties>(),
                    Type<MetadataViews.Serial>()
                ]
            }

            return [
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Display>(),
                Type<FreshmintMetadataViews.BlindNFT>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            if let metadata = self.getMetadata() {
                switch view {
                    case Type<MetadataViews.Display>():
                        return self.resolveDisplay(metadata)
                    case Type<MetadataViews.ExternalURL>():
                        return self.resolveExternalURL()
                    case Type<MetadataViews.NFTCollectionDisplay>():
                        return self.resolveNFTCollectionDisplay()
                    case Type<MetadataViews.NFTCollectionData>():
                        return self.resolveNFTCollectionData()
                    case Type<MetadataViews.Royalties>():
                        return self.resolveRoyalties()
                    case Type<MetadataViews.Serial>():
                        return self.resolveSerial(metadata)
                }

                return nil
            }

            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: "SeedsOfHappinessGenesis",
                        description: "This NFT is not yet revealed.",
                        thumbnail: MetadataViews.IPFSFile(
                            cid: SeedsOfHappinessGenesis.placeholderImage, 
                            path: nil
                        )
                    )
                case Type<FreshmintMetadataViews.BlindNFT>():
                    return FreshmintMetadataViews.BlindNFT(hash: self.hash)
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

        pub fun resolveDisplay(_ metadata: Metadata): MetadataViews.Display {
            // The first 46 characters of the string are the IPFS CID (for v0 CIDs only)
            let cid = metadata.image.slice(from: 0, upTo: 46)

            // The remaining characters are the IPFS path (following a "/" character at index 46)
            let path = metadata.image.slice(from: 47, upTo: metadata.image.length)

            return MetadataViews.Display(
                name: metadata.name,
                description: metadata.description,
                thumbnail: MetadataViews.IPFSFile(cid: cid, path: path)
            )
        }
        
        pub fun resolveExternalURL(): MetadataViews.ExternalURL {
            let collectionURL = SeedsOfHappinessGenesis.collectionMetadata.externalURL.url
            let nftID = self.id.toString()
            return MetadataViews.ExternalURL(collectionURL.concat("/").concat(nftID))
        }
        
        pub fun resolveNFTCollectionDisplay(): MetadataViews.NFTCollectionDisplay {
            return SeedsOfHappinessGenesis.collectionMetadata
        }
        
        pub fun resolveNFTCollectionData(): MetadataViews.NFTCollectionData {
            return MetadataViews.NFTCollectionData(
                storagePath: SeedsOfHappinessGenesis.CollectionStoragePath,
                publicPath: SeedsOfHappinessGenesis.CollectionPublicPath,
                providerPath: SeedsOfHappinessGenesis.CollectionPrivatePath,
                publicCollection: Type<&SeedsOfHappinessGenesis.Collection{SeedsOfHappinessGenesis.SeedsOfHappinessGenesisCollectionPublic}>(),
                publicLinkedType: Type<&SeedsOfHappinessGenesis.Collection{SeedsOfHappinessGenesis.SeedsOfHappinessGenesisCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
                providerLinkedType: Type<&SeedsOfHappinessGenesis.Collection{SeedsOfHappinessGenesis.SeedsOfHappinessGenesisCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(),
                createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                    return <-SeedsOfHappinessGenesis.createEmptyCollection()
                })
            )
        }
        
        pub fun resolveRoyalties(): MetadataViews.Royalties {
            return MetadataViews.Royalties(SeedsOfHappinessGenesis.getRoyalties())
        }
        
        pub fun resolveSerial(_ metadata: Metadata): MetadataViews.Serial {
            return MetadataViews.Serial(metadata.serialNumber)
        }
        
        destroy() {
            SeedsOfHappinessGenesis.totalSupply = SeedsOfHappinessGenesis.totalSupply - (1 as UInt64)

            emit Burned(id: self.id)
        }
    }

    pub resource interface SeedsOfHappinessGenesisCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowSeedsOfHappinessGenesis(id: UInt64): &SeedsOfHappinessGenesis.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow SeedsOfHappinessGenesis reference: The ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: SeedsOfHappinessGenesisCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        
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
            let token <- token as! @SeedsOfHappinessGenesis.NFT

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
        /// typed as SeedsOfHappinessGenesis.NFT.
        ///
        /// This function returns nil if the NFT does not exist in this collection.
        ///
        pub fun borrowSeedsOfHappinessGenesis(id: UInt64): &SeedsOfHappinessGenesis.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &SeedsOfHappinessGenesis.NFT
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
            let nftRef = nft as! &SeedsOfHappinessGenesis.NFT
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
        /// To mint a blind NFT, specify its metadata hash
        /// that can later be used to verify the revealed NFT.
        ///
        pub fun mintNFT(hash: [UInt8]): @SeedsOfHappinessGenesis.NFT {
            let hexHash = String.encodeHex(hash)

            // Prevent multiple NFTs from being minted with the same metadata hash.
            assert(
                SeedsOfHappinessGenesis.nftsByHash[hexHash] == nil,
                message: "an NFT has already been minted with hash=".concat(hexHash)
            )

            let nft <- create SeedsOfHappinessGenesis.NFT(hash: hash)

            emit Minted(id: nft.id, hash: hash)

            // Save the metadata hash so that it can later be validated on reveal. 
            SeedsOfHappinessGenesis.nftsByHash[hexHash] = nft.id

            SeedsOfHappinessGenesis.totalSupply = SeedsOfHappinessGenesis.totalSupply + (1 as UInt64)

            return <- nft
        }

        /// Reveal a minted NFT.
        ///
        /// To reveal an NFT, publish its complete metadata and unique salt value.
        ///
        pub fun revealNFT(id: UInt64, metadata: Metadata) {
            pre {
                SeedsOfHappinessGenesis.metadata[id] == nil : "NFT has already been revealed"
            }

            // An NFT cannot be revealed unless the provided metadata values
            // match the hash that was specified at mint time.

            let hash = String.encodeHex(metadata.hash())

            if let mintedID = SeedsOfHappinessGenesis.getNFTIDByHash(hash: hash) {
                assert(
                    id == mintedID,
                    message: "the provided metadata hash matches NFT with ID="
                        .concat(mintedID.toString())
                        .concat(", but expected ID=")
                        .concat(id.toString())
                )
            } else {
                panic("the provided metadata hash does not match any minted NFTs")
            }

            SeedsOfHappinessGenesis.metadata[id] = metadata

            emit Revealed(id: id)
        }

        /// Update the collection metadata for this contract (e.g. website URL, icon, banner image).
        ///
        pub fun setCollectionMetadata(_ collectionMetadata: MetadataViews.NFTCollectionDisplay) {
            SeedsOfHappinessGenesis.collectionMetadata = collectionMetadata
        }
    }

    /// Return a public path that is scoped to this contract.
    ///
    pub fun getPublicPath(suffix: String): PublicPath {
        return PublicPath(identifier: "SeedsOfHappinessGenesis_".concat(suffix))!
    }

    /// Return a private path that is scoped to this contract.
    ///
    pub fun getPrivatePath(suffix: String): PrivatePath {
        return PrivatePath(identifier: "SeedsOfHappinessGenesis_".concat(suffix))!
    }

    /// Return a storage path that is scoped to this contract.
    ///
    pub fun getStoragePath(suffix: String): StoragePath {
        return StoragePath(identifier: "SeedsOfHappinessGenesis_".concat(suffix))!
    }

    /// Return a collection name with an optional bucket suffix.
    ///
    pub fun makeCollectionName(bucketName maybeBucketName: String?): String {
        if let bucketName = maybeBucketName {
            return "Collection_".concat(bucketName)
        }

        return "Collection"
    }

    /// Return a queue name with an optional bucket suffix.
    ///
    pub fun makeQueueName(bucketName maybeBucketName: String?): String {
        if let bucketName = maybeBucketName {
            return "Queue_".concat(bucketName)
        }

        return "Queue"
    }

    priv fun initAdmin(admin: AuthAccount) {
        // Create an empty collection and save it to storage
        let collection <- SeedsOfHappinessGenesis.createEmptyCollection()

        admin.save(<- collection, to: SeedsOfHappinessGenesis.CollectionStoragePath)

        admin.link<&SeedsOfHappinessGenesis.Collection>(SeedsOfHappinessGenesis.CollectionPrivatePath, target: SeedsOfHappinessGenesis.CollectionStoragePath)

        admin.link<&SeedsOfHappinessGenesis.Collection{NonFungibleToken.CollectionPublic, SeedsOfHappinessGenesis.SeedsOfHappinessGenesisCollectionPublic, MetadataViews.ResolverCollection}>(SeedsOfHappinessGenesis.CollectionPublicPath, target: SeedsOfHappinessGenesis.CollectionStoragePath)

        // Create an admin resource and save it to storage
        let adminResource <- create Admin()

        admin.save(<- adminResource, to: self.AdminStoragePath)
    }

    init(collectionMetadata: MetadataViews.NFTCollectionDisplay, royalties: [MetadataViews.Royalty], placeholderImage: String) {

        self.version = "0.2.2"

        self.CollectionPublicPath = SeedsOfHappinessGenesis.getPublicPath(suffix: "Collection")
        self.CollectionStoragePath = SeedsOfHappinessGenesis.getStoragePath(suffix: "Collection")
        self.CollectionPrivatePath = SeedsOfHappinessGenesis.getPrivatePath(suffix: "Collection")

        self.AdminStoragePath = SeedsOfHappinessGenesis.getStoragePath(suffix: "Admin")

        self.placeholderImage = placeholderImage

        self.royalties = royalties
        self.collectionMetadata = collectionMetadata

        self.totalSupply = 0

        self.metadata = {}
        self.nftsByHash = {}

        self.initAdmin(admin: self.account)

        emit ContractInitialized()
    }
}
