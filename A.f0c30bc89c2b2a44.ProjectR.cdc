import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe

pub contract ProjectR: NonFungibleToken {

    pub var totalSupply: UInt64

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let nftId: UInt64
        pub let nftType: String
        pub let name: String
        pub let description: String
        pub let thumbnail: String
        pub let endpoint: String
        access(self) let metadata: {String: AnyStruct}
    
        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Traits>(),
                Type<MetadataViews.Royalties>()
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
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                case Type<MetadataViews.Royalties>():
                    let royaltyReceiver: Capability<&{FungibleToken.Receiver}> = getAccount(0xf0c30bc89c2b2a44).getCapability<&AnyResource{FungibleToken.Receiver}>(MetadataViews.getRoyaltyReceiverPublicPath())
                    let royalty = MetadataViews.Royalty(
                            receiver: royaltyReceiver,
                            cut: 0.0,
                            description: "No Royalties",
                        )         
                        return MetadataViews.Royalties([royalty])

                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://market.raidersrumble.io")
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: ProjectR.CollectionStoragePath,
                        publicPath: ProjectR.CollectionPublicPath,
                        providerPath: /private/ProjectRCollection,
                        publicCollection: Type<&ProjectR.Collection{ProjectR.CollectionPublic}>(),
                        publicLinkedType: Type<&ProjectR.Collection{ProjectR.CollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&ProjectR.Collection{ProjectR.CollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-ProjectR.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let squareImage = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://dtz22sdwncfa9.cloudfront.net/NFT-Flow-Resource/AmSulRXn_400x400.jpg"
                        ),
                        mediaType: "image/jpg"
                    )
                    let bannerImage = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://dtz22sdwncfa9.cloudfront.net/NFT-Flow-Resource/1500x500.jpeg"
                        ),
                        mediaType: "image/jpg"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "ProjectR",
                        description: "This collection of Non-Fungible Tokens (NFTs) is the avatar for the Raiders Rumble game.",
                        externalURL: MetadataViews.ExternalURL("https://market.raidersrumble.io"),
                        squareImage: squareImage,
                        bannerImage: bannerImage,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/raidersrumble"),
                            "discord": MetadataViews.ExternalURL("https://discord.com/invite/raidersrumble")
                        }
                    )
                case Type<MetadataViews.Traits>():
                    let traitsView = MetadataViews.dictToTraits(dict: self.metadata, excludedNames: nil)
                    return traitsView

            }
            return nil
        }

        init(
            nftId: UInt64,
            nftType: String,
            name: String,
            description: String,
            thumbnail: String,
            endpoint: String,
            metadata: {String: AnyStruct},
        ) {
            self.id = ProjectR.totalSupply
            self.nftId = nftId
            self.nftType = nftType
            self.name = name
            self.description = description
            self.thumbnail = thumbnail
            self.endpoint = endpoint
            self.metadata = metadata

            ProjectR.totalSupply = ProjectR.totalSupply + 1
        }
    }

    pub resource interface CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowProjectR(id: UInt64): &ProjectR.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow ProjectR reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("This NFT does not exist")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @ProjectR.NFT
            let id: UInt64 = token.id
            self.ownedNFTs[id] <-! token
            emit Deposit(id: id, to: self.owner?.address)
        }

        pub fun burnNFT(id: UInt64) {
            let token <- self.ownedNFTs.remove(key: id) ?? panic("This NFT does not exist")
            emit Withdraw(id: token.id, from: Address(0x0))
            destroy token
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }
 
        pub fun borrowProjectR(id: UInt64): &ProjectR.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &ProjectR.NFT
            }
            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let ProjectR = nft as! &ProjectR.NFT
            return ProjectR as &AnyResource{MetadataViews.Resolver}
        }

        init () {
            self.ownedNFTs <- {}
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
            nftId: UInt64,
            nftType: String,
            name: String,
            description: String,
            thumbnail: String,
            endpoint: String
        ): @NFT {
            let metadata: {String: AnyStruct} = {}
            let currentBlock = getCurrentBlock()
            metadata["mintedBlock"] = currentBlock.height
            metadata["mintedTime"] = currentBlock.timestamp

            return <- create NFT(
                nftId: nftId,
                nftType: nftType,
                name: name,
                description: description,
                thumbnail: thumbnail,
                endpoint: endpoint,
                metadata: metadata
            )
        }
    }

    init() {
        self.totalSupply = 0

        self.CollectionStoragePath = /storage/ProjectRCollection
        self.CollectionPublicPath = /public/ProjectRCollection
        self.MinterStoragePath = /storage/ProjectRMinter

        self.account.save(<- create NFTMinter(), to: self.MinterStoragePath)

        emit ContractInitialized()
    }
}
 