// import FungibleToken from 0x9a0766d93b6608b7
// import NonFungibleToken from 0x631e88ae7f1d7c20
// import MetadataViews from 0x631e88ae7f1d7c20

import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract GroundWork29: NonFungibleToken {
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
                        description: "The life of a student athlete competing in the NCAA is a lifestyle that is glorified by many, but only truly known by few.On the surface, the life of a student athlete may look easy, but underneath the exterior many tough and demanding experiences are endured.Although some will get the opportunity to play professionally in their respective sports, the reality is that 98% of student athletes who graduate from these prestigious institutions will transition out of sports -- making a very difficult transition at times -- and become a professional in a totally different field. \n\n Registration group element - USA \n Registrant element - Published NFT \n Publication element - Edition #1 \n ISBN - (13-Digit): 978-1-932450-28-6 \n",
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
                        storagePath: GroundWork29.CollectionStoragePath,
                        publicPath: GroundWork29.CollectionPublicPath,
                        providerPath: /private/GroundWork29Collection,
                        publicCollection: Type<&GroundWork29.Collection{GroundWork29.GroundWork29CollectionPublic}>(),
                        publicLinkedType: Type<&GroundWork29.Collection{GroundWork29.GroundWork29CollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&GroundWork29.Collection{GroundWork29.GroundWork29CollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-GroundWork29.createEmptyCollection()
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

    pub resource interface GroundWork29CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowGroundWork29(id: UInt64): &GroundWork29.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow GroundWork29 reference: The ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: GroundWork29CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
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
            let token <- token as! @GroundWork29.NFT

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

        pub fun borrowGroundWork29(id: UInt64): &GroundWork29.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &GroundWork29.NFT
            } else {
                return nil
            }
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let publishedNFT = nft as! &GroundWork29.NFT
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
        pub fun mintLibraryPass(_name: String, _ipfsLink: String): @GroundWork29.NFT?{          
          
          if GroundWork29.libraryPassTotalSupply == 9999 {return nil}
          
          let libraryPassNft <- create GroundWork29.NFT(
            serialId: GroundWork29.libraryPassTotalSupply,
            initID: GroundWork29.totalSupply,
            name: _name,
            ipfsLink: _ipfsLink,
            type: 1
          )

          emit PublishedMinted(id: GroundWork29.totalSupply, name: _name, ipfsLink: _ipfsLink, type: 1)

          GroundWork29.totalSupply = GroundWork29.totalSupply + (1 as UInt64)
          GroundWork29.libraryPassTotalSupply = GroundWork29.libraryPassTotalSupply + (1 as UInt64)

          return <- libraryPassNft
        }

         pub fun mintWillo(_name: String, _ipfsLink: String): @GroundWork29.NFT?{
          
          if GroundWork29.willoTotalSupply == 100 {return nil}
          
          let willoNft <- create GroundWork29.NFT(
            serialId: GroundWork29.willoTotalSupply,
            initID: GroundWork29.totalSupply,   
            name: _name,
            ipfsLink: _ipfsLink,
            type: 1
          )
          
          emit PublishedMinted(id: GroundWork29.totalSupply, name: _name, ipfsLink: _ipfsLink, type: 2)

          GroundWork29.totalSupply = GroundWork29.totalSupply + (1 as UInt64)
          GroundWork29.willoTotalSupply = GroundWork29.willoTotalSupply + (1 as UInt64)

          return <- willoNft
        }
    } 

    init() {
        self.CollectionStoragePath = /storage/groundwork29Collection
        self.CollectionPublicPath = /public/groundwork29Collection
        self.MinterPublishedPath = /storage/minterGroundWork29Path

        self.totalSupply = 0
        self.libraryPassTotalSupply = 0
        self.willoTotalSupply = 0

        self.account.save(<- create PublishedMinter(), to: self.MinterPublishedPath)
        
        self.account.save(<- create Collection(), to: self.CollectionStoragePath)
        self.account.link<&GroundWork29.Collection{NonFungibleToken.CollectionPublic, GroundWork29.GroundWork29CollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath, 
            target: self.CollectionStoragePath
        )

        emit ContractInitialized()
    }
}
