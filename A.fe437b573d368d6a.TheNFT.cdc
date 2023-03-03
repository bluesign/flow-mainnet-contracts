// What makes an NFT an NFT?

import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract TheNFT: NonFungibleToken {
    pub let CollectionPublicPath: PublicPath
    pub let CollectionStoragePath: StoragePath
    pub var totalSupply: UInt64
    pub var baseUrl: String

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Mint(id: UInt64)
    pub event Destroy(id: UInt64)

    pub struct TextPlain {
        pub let id: UInt64

        init(id: UInt64) {
            self.id = id
        }

        pub fun data(): String {
            return "data:text/plain,%23".concat(self.id.toString())
        }
    }

    pub struct TextHtml {
        pub let id: UInt64

        init(id: UInt64) {
            self.id = id
        }

        pub fun data(): String {
            return "data:text/html,%3C%21DOCTYPE%20html%3E%3Chtml%3E%3Cdiv%20style%3D%22display%3A%20flex%3B%20justify-content%3A%20center%3B%20align-items%3A%20center%3B%20height%3A%20100vh%3B%22%3E%3Ch1%3E%23"
                .concat(self.id.toString())
                .concat("%3C%2Fh1%3E%3C%2Fdiv%3E%3C%2Fhtml%3E")
        }
    }

    pub struct ImageSvg {
        pub let id: UInt64

        init(id: UInt64) {
            self.id = id
        }

        pub fun data(): String {
            return "data:image/svg+xml;charset=utf8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%20100%20100%22%3E%0D%0A%3Crect%20x%3D%220%22%20y%3D%220%22%20width%3D%22100%22%20height%3D%22100%22%20fill%3D%22%23000000%22%20%2F%3E%0D%0A%3Ctext%20x%3D%2250%25%22%20y%3D%2250%25%22%20text-anchor%3D%22middle%22%20dominant-baseline%3D%22central%22%20fill%3D%22%23ffffff%22%3E%0D%0A%23"
                .concat(self.id.toString())
                .concat("%0D%0A%3C%2Ftext%3E%3C%2Fsvg%3E%0D%0A")
        }
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64

        init(id: UInt64) {
            self.id = id
        }

        pub fun whatAreYou(): String {
            return self.id.toString()
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<TextPlain>(),
                Type<TextHtml>(),
                Type<ImageSvg>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: "#".concat(self.id.toString()),
                        description: "The NFT",
                        thumbnail: MetadataViews.HTTPFile(url: TheNFT.baseUrl.concat(self.id.toString())),
                    )
                case Type<TextPlain>():
                    return TextPlain(id: self.id).data()
                case Type<TextHtml>():
                    return TextHtml(id: self.id).data()
                case Type<ImageSvg>():
                    return ImageSvg(id: self.id).data()
            }
            return nil
        }

        destroy() {
            emit Destroy(id: self.id)
        }
    }

    pub resource interface TheNFTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowTheNFT(id: UInt64): &TheNFT.NFT? {
            post {
                (result == nil) || (result?.id == id): "Cannot borrow TheNFT reference"
            }
        }
    }

    pub resource Collection: TheNFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("Missing NFT")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <- token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @TheNFT.NFT
            let id: UInt64 = token.id
            self.ownedNFTs[id] <-! token
            emit Deposit(id: id, to: self.owner?.address)
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowTheNFT(id: UInt64): &TheNFT.NFT? {
            if self.ownedNFTs[id] != nil {
                return (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)! as! &TheNFT.NFT
            }
            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)! as! &TheNFT.NFT
            return nft as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    pub resource Maintainer {
        pub fun setBaseUrl(url: String) {
            TheNFT.baseUrl = url
        }
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub fun mintNFT(): @NFT {
        TheNFT.totalSupply = TheNFT.totalSupply + 1
        emit Mint(id: TheNFT.totalSupply)
        return <- create NFT(id: TheNFT.totalSupply)
    }

    init() {
        self.CollectionPublicPath = /public/TheNFTCollection
        self.CollectionStoragePath = /storage/TheNFTCollection
        self.totalSupply = 0
        self.baseUrl = ""

        self.account.save(<- create Maintainer(), to: /storage/TheNFTMaintainer)
        self.account.save(<- create Collection(), to: self.CollectionStoragePath)
        self.account.link<&TheNFT.Collection{NonFungibleToken.CollectionPublic, TheNFT.TheNFTCollectionPublic}>(self.CollectionPublicPath, target: self.CollectionStoragePath)

        emit ContractInitialized()
    }
}
