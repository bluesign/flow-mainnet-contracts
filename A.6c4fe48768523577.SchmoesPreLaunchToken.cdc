/*
    Description: This is an NFT that will be issued to anyone who visits the Schmoes website before 
    the official launch of the Shmoes NFT
*/

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448


pub contract SchmoesPreLaunchToken: NonFungibleToken {
    // -----------------------------------------------------------------------
    // NonFungibleToken Standard Events
    // -----------------------------------------------------------------------

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

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
    // SchmoesPreLaunchToken Fields
    // -----------------------------------------------------------------------
    
    // NFT level metadata
    pub var name: String
    pub var imageUrl: String
    pub var isSaleActive: Bool

    pub resource NFT : NonFungibleToken.INFT,  MetadataViews.Resolver {
        pub let id: UInt64

        init(initID: UInt64) {
            self.id = initID
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: "Schmoes Pre Launch Token #".concat(self.id.toString()),
                        description: "",
                        thumbnail: MetadataViews.HTTPFile(
                            url: SchmoesPreLaunchToken.imageUrl
                        )
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(
                        []
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://schmoes.io")
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: SchmoesPreLaunchToken.CollectionStoragePath,
                        publicPath: SchmoesPreLaunchToken.CollectionPublicPath,
                        providerPath: /private/SchmoesPreLaunchTokenCollection,
                        publicCollection: Type<&SchmoesPreLaunchToken.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver}>(),
                        publicLinkedType: Type<&SchmoesPreLaunchToken.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&SchmoesPreLaunchToken.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-SchmoesPreLaunchToken.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: SchmoesPreLaunchToken.imageUrl
                        ),
                        mediaType: "image"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "Schmoes Pre Launch Token",
                        description: "",
                        externalURL: MetadataViews.ExternalURL("https://schmoes.io"),
                        squareImage: media,
                        bannerImage: media,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/SchmoesNFT")
                        }
                    )
            }
            return nil
        }
    }

    /*
        This collection only allows the storage of a single NFT
     */
    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
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
            let token <- token as! @SchmoesPreLaunchToken.NFT
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

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let launchTokenNFT = nft as! &SchmoesPreLaunchToken.NFT
            return launchTokenNFT as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    // -----------------------------------------------------------------------
    // Admin Functions
    // -----------------------------------------------------------------------
    access(account) fun setImageUrl(_ newImageUrl: String) {
        self.imageUrl = newImageUrl
    }

    access(account) fun setIsSaleActive(_ newIsSaleActive: Bool) {
        self.isSaleActive = newIsSaleActive
    }

    // -----------------------------------------------------------------------
    // Public Functions
    // -----------------------------------------------------------------------
    pub fun mint() : @SchmoesPreLaunchToken.NFT {
        pre {
            self.isSaleActive : "Sale is not active"
        }
        let id = SchmoesPreLaunchToken.totalSupply + (1 as UInt64)
        let newNFT: @SchmoesPreLaunchToken.NFT <- create SchmoesPreLaunchToken.NFT(id: id)
        SchmoesPreLaunchToken.totalSupply = id
        return <-newNFT
    }

    // -----------------------------------------------------------------------
    // NonFungibleToken Standard Functions
    // -----------------------------------------------------------------------
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    init() {
        self.name = "SchmoesPreLaunchToken"
        self.imageUrl = ""

        self.isSaleActive = false
        self.totalSupply = 0

        self.CollectionStoragePath = /storage/SchmoesPreLaunchTokenCollection
        self.CollectionPublicPath = /public/SchmoesPreLaunchTokenCollection

        emit ContractInitialized()
    }
}