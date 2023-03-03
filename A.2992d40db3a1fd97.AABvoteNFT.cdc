import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract AABvoteNFT: NonFungibleToken {
    pub let mintedNFTs: {UInt64: MintedNFT}
    pub var totalSupply: UInt64

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, candidateId: String, name: String, description: String, thumbnail: String, rarity: UInt8, metadata: {String:String}, to: Address)
    pub event Destroy(id: UInt64)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath
    pub let AdminStoragePath: StoragePath

    pub enum Rarity: UInt8 {
        pub case common
        pub case iconic
    }

    pub struct MintedNFT {
        pub let used: Bool
        pub let ownerMinted: Address

        init(used: Bool, ownerMinted: Address) {
            self.used = used
            self.ownerMinted = ownerMinted
        }
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64

        pub let candidateId: String
        pub let name: String
        pub let description: String
        pub let thumbnail: String
        pub let rarity: UInt8
        pub let metadata: {String: String}

        init(
            id: UInt64,
            candidateId: String,
            name: String,
            description: String,
            thumbnail: String,
            rarity: UInt8,
            metadata: {String: String},
        ) {
            self.id = id
            self.candidateId = candidateId
            self.name = name
            self.description = description
            self.thumbnail = thumbnail
            self.rarity = rarity
            self.metadata = metadata
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.HTTPFile(url: self.thumbnail),
                    )
            }
            return nil
        }

        pub fun getMetadata(): {String:String} {
            return self.metadata
        }
    }

    pub resource interface AABvoteNFTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowAABvoteNFT(id: UInt64): &AABvoteNFT.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow AABvoteNFT reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: AABvoteNFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
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
            let token <- token as! @AABvoteNFT.NFT
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

        pub fun borrowAABvoteNFT(id: UInt64): &AABvoteNFT.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &AABvoteNFT.NFT
            }

            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let AABvoteNFT = nft as! &AABvoteNFT.NFT
            return AABvoteNFT as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub resource NFTMinter {
        pub fun mintNFT(
            recipient: &{NonFungibleToken.CollectionPublic},
            candidateId: String,
            name: String,
            description: String,
            thumbnail: String,
            rarity: UInt8,
            metadata: {String:String}
        ) {
            var newNFT <- create NFT(
                id: AABvoteNFT.totalSupply,
                candidateId: candidateId,
                name: name,
                description: description,
                thumbnail: thumbnail,
                rarity: rarity,
                metadata: metadata,
            )

            recipient.deposit(token: <-newNFT)

            AABvoteNFT.mintedNFTs[AABvoteNFT.totalSupply] = MintedNFT(used: false, ownerMinted: recipient.owner!.address)
            emit Minted(id: AABvoteNFT.totalSupply, candidateId: candidateId, name: name, description: description, thumbnail: thumbnail, rarity: rarity, metadata: metadata, to: recipient.owner!.address)

            AABvoteNFT.totalSupply = AABvoteNFT.totalSupply + UInt64(1)
        }
    }

    pub fun getCollection(_ from: Address): &Collection{AABvoteNFTCollectionPublic} {
        let collection = getAccount(from)
            .getCapability(AABvoteNFT.CollectionPublicPath)!
            .borrow<&AABvoteNFT.Collection{AABvoteNFT.AABvoteNFTCollectionPublic}>()
            ?? panic("Could not borrow capability from public collection")

        return collection
    }

    pub fun getNFT(_ from: Address, id: UInt64): &AABvoteNFT.NFT? {
        let collection = self.getCollection(from)

        return collection.borrowAABvoteNFT(id: id)
    }

    access(account) fun setUsedNFT(id: UInt64, used: Bool) {
        pre {
            AABvoteNFT.mintedNFTs.containsKey(id): "NFT does not exist"
        }

        AABvoteNFT.mintedNFTs[id] = MintedNFT(used: used, ownerMinted: AABvoteNFT.mintedNFTs[id]!.ownerMinted)
    }

    pub resource Administrator {
        pub fun createNFTMinter(): @NFTMinter {
            return <- create NFTMinter()
        }
    }

    init() {
        self.mintedNFTs = {}
        self.totalSupply = 0

        self.CollectionStoragePath = /storage/AABvoteNFTCollectionV1
        self.CollectionPublicPath = /public/AABvoteNFTCollectionV1
        self.MinterStoragePath = /storage/AABvoteNFTMinterV1
        self.AdminStoragePath = /storage/AABvoteNFTAdminV1

        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        self.account.link<&AABvoteNFT.Collection{NonFungibleToken.CollectionPublic, AABvoteNFT.AABvoteNFTCollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        let admin <- create Administrator()
        self.account.save<@Administrator>(<-admin, to: self.AdminStoragePath)

        emit ContractInitialized()
    }
}
