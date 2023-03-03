import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract Boast: NonFungibleToken {
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event PublishedMinted(id: UInt64, name: String, ipfsLink: String, type: UInt64)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterPublishedPath: StoragePath

    pub var totalSupply: UInt64
    pub var libraryPassTotalSupply: UInt64
    pub var willoTotalSupply: UInt64

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let serialId: UInt64
        pub let id: UInt64
        pub let name: String
        pub let ipfsLink: String
        pub let type: UInt64

        init(serialId: UInt64, initID: UInt64, name: String, ipfsLink: String, type: UInt64) {
            self.serialId = serialId
            self.id = initID
            self.name = name
            self.ipfsLink = ipfsLink
            self.type= type
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            let url = "https://ipfs.io/ipfs/".concat(self.ipfsLink)
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.name,
                        description: "With a mission to recall the days of glamour, Mancave Playbabes brings the perfect lifestyle to your fingertips. Combining the charm of the man's world and the alluring pleasures of entertainment, Mancave Playbabes has a unique approach to refuge, here you will find all your advice, and style. \n Registration group element - USA \n Registrant element - Published NFT \n Publication element - ISSUE #6 \n",
                        thumbnail: MetadataViews.IPFSFile(
                            cid: self.ipfsLink,
                            path: nil
                        )
                    )
                case Type<MetadataViews.Royalties>():
                    var royalties: [MetadataViews.Royalty] = []
                    return MetadataViews.Royalties(royalties)
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.serialId
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL(url)

                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: Boast.CollectionStoragePath,
                        publicPath: Boast.CollectionPublicPath,
                        providerPath: /private/BoastCollection,
                        publicCollection: Type<&Boast.Collection{Boast.BoastCollectionPublic}>(),
                        publicLinkedType: Type<&Boast.Collection{Boast.BoastCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&Boast.Collection{Boast.BoastCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-Boast.createEmptyCollection()
                        })
                    )

                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://publishednft.io/logo-desktop.png"
                        ),
                        mediaType: "image/png"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "The Published NFT Collection",
                        description: "Published NFT is a blockchain eBook publishing platform built on the Flow blockchain, where authors can publish eBooks, Lyrics, Comics, Magazines, Articles, Poems, Recipes, Movie Scripts, Computer Language, etc.",
                        externalURL: MetadataViews.ExternalURL("https://publishednft.io/"),
                        squareImage: media,
                        bannerImage: media,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/publishednft/"),
                            "discord": MetadataViews.ExternalURL("https://discord.gg/ct5RPudqpG"),
                            "instagram": MetadataViews.ExternalURL("https://www.instagram.com/publishednft/"),
                            "telegram": MetadataViews.ExternalURL("https://t.me/published_nft"),
                            "reddit": MetadataViews.ExternalURL("https://www.reddit.com/user/PublishedNFT")
                        }
                    )
            }
            return nil
        }
    }

    pub resource interface BoastCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowBoast(id: UInt64): &Boast.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow Boast reference: The ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: BoastCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
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
            let token <- token as! @Boast.NFT

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

        pub fun borrowBoast(id: UInt64): &Boast.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &Boast.NFT
            } else {
                return nil
            }
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let publishedNFT = nft as! &Boast.NFT
            return publishedNFT as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }        
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub resource PublishedMinter{
        pub fun mintLibraryPass(_name: String, _ipfsLink: String): @Boast.NFT?{          
          
          if Boast.libraryPassTotalSupply == 9999 {return nil}
          
          let libraryPassNft <- create Boast.NFT(
            serialId: Boast.libraryPassTotalSupply,
            initID: Boast.totalSupply,
            name: _name,
            ipfsLink: _ipfsLink,
            type: 1
          )

          emit PublishedMinted(id: Boast.totalSupply, name: _name, ipfsLink: _ipfsLink, type: 1)

          Boast.totalSupply = Boast.totalSupply + (1 as UInt64)
          Boast.libraryPassTotalSupply = Boast.libraryPassTotalSupply + (1 as UInt64)

          return <- libraryPassNft
        }

         pub fun mintWillo(_name: String, _ipfsLink: String): @Boast.NFT?{
          
          if Boast.willoTotalSupply == 100 {return nil}
          
          let willoNft <- create Boast.NFT(
            serialId: Boast.willoTotalSupply,
            initID: Boast.totalSupply,   
            name: _name,
            ipfsLink: _ipfsLink,
            type: 1
          )
          
          emit PublishedMinted(id: Boast.totalSupply, name: _name, ipfsLink: _ipfsLink, type: 2)

          Boast.totalSupply = Boast.totalSupply + (1 as UInt64)
          Boast.willoTotalSupply = Boast.willoTotalSupply + (1 as UInt64)

          return <- willoNft
        }
    } 

    init() {
        self.CollectionStoragePath = /storage/boastCollection
        self.CollectionPublicPath = /public/boastCollection
        self.MinterPublishedPath = /storage/minterBoastPath

        self.totalSupply = 0
        self.libraryPassTotalSupply = 0
        self.willoTotalSupply = 0

        self.account.save(<- create PublishedMinter(), to: self.MinterPublishedPath)
        
        self.account.save(<- create Collection(), to: self.CollectionStoragePath)
        self.account.link<&Boast.Collection{NonFungibleToken.CollectionPublic, Boast.BoastCollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath, 
            target: self.CollectionStoragePath
        )

        emit ContractInitialized()
    }
}
