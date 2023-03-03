//
//  _____         _            _
// /  ___|       | |          | |
// \ `--.   __ _ | | __ _   _ | |_   __ _  _ __   ___
//  `--. \ / _` || |/ /| | | || __| / _` || '__| / _ \
// /\__/ /| (_| ||   < | |_| || |_ | (_| || |   | (_) |
// \____/  \__,_||_|\_\ \__,_| \__| \__,_||_|    \___/
//
//
import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import SakutaroPoemContent from 0xe46c2c24053641e2

pub contract SakutaroPoem: NonFungibleToken {
    pub let CollectionPublicPath: PublicPath
    pub let CollectionStoragePath: StoragePath
    pub var totalSupply: UInt64
    priv var royalties: [MetadataViews.Royalty]

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Mint(id: UInt64)
    pub event Destroy(id: UInt64)

    pub struct SakutaroPoemMetadataView {
        pub let poemID: UInt32?
        pub let name: String?
        pub let description: String?
        pub let thumbnail: AnyStruct{MetadataViews.File}
        pub let svg: String?
        pub let svgBase64: String?
        pub let license: String
        pub let creator: String

        init(
            poemID: UInt32?,
            name: String?,
            description: String?,
            thumbnail: AnyStruct{MetadataViews.File},
            svg: String?,
            svgBase64: String?,
            license: String,
            creator: String
        ) {
            self.poemID = poemID
            self.name = name
            self.description = description
            self.thumbnail = thumbnail
            self.svg = svg
            self.svgBase64 = svgBase64
            self.license = license
            self.creator = creator
        }
    }

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64

        init(id: UInt64) {
            self.id = id
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<SakutaroPoemMetadataView>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    let poem = self.getPoem()
                    return MetadataViews.Display(
                        name: poem?.title ?? SakutaroPoemContent.name,
                        description: SakutaroPoemContent.description,
                        thumbnail: MetadataViews.IPFSFile(cid: poem?.ipfsCid ?? "", path: nil),
                    )
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(
                        SakutaroPoem.royalties
                    )
                case Type<SakutaroPoemMetadataView>():
                    let poem = self.getPoem()
                    return SakutaroPoemMetadataView(
                        poemID: self.getPoemID() ?? 0,
                        name: poem?.title ?? SakutaroPoemContent.name,
                        description: SakutaroPoemContent.description,
                        thumbnail: MetadataViews.IPFSFile(cid: poem?.ipfsCid ?? "", path: nil),
                        svg: poem?.getSvg(),
                        svgBase64: poem?.getSvgBase64(),
                        license: "CC-BY 4.0",
                        creator: "Ara"
                    )
            }
            return nil
        }

        pub fun getPoemID(): UInt32? {
            if self.owner == nil {
              return nil
            }
            var num: UInt32 = 0
            var val = self.owner!.address.toBytes()
            for v in val {
                num = num + UInt32(v)
            }
            return num % 39
        }

        pub fun getPoem(): SakutaroPoemContent.Poem? {
            let poemID = self.getPoemID()
            if poemID == nil {
              return nil
            }
            return SakutaroPoemContent.getPoem(poemID!)
        }

        destroy() {
            emit Destroy(id: self.id)
        }
    }

    pub resource interface SakutaroPoemCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowPoem(id: UInt64): &SakutaroPoem.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow Poem reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: SakutaroPoemCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
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
            let token <- token as! @SakutaroPoem.NFT
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
 
        pub fun borrowPoem(id: UInt64): &SakutaroPoem.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
                return ref as! &SakutaroPoem.NFT?
            }
            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
            return nft as! &SakutaroPoem.NFT
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub fun mintNFT() : @NFT {
        pre {
            SakutaroPoem.totalSupply < 39: "Can't mint any more"
        }
        SakutaroPoem.totalSupply = SakutaroPoem.totalSupply + 1
        let token <- create NFT(id: SakutaroPoem.totalSupply)
        emit Mint(id: token.id)
        return <- token
    }

    pub fun getRoyalties(): MetadataViews.Royalties {
        return MetadataViews.Royalties(SakutaroPoem.royalties)
    }

    init() {
        self.CollectionPublicPath = /public/SakutaroPoemCollection
        self.CollectionStoragePath = /storage/SakutaroPoemCollection
        self.totalSupply = 0

        let recepient = self.account.getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)!
        self.royalties = [MetadataViews.Royalty(recepient: recepient, cut: 0.1, description: "39")]

        self.account.save(<- create Collection(), to: self.CollectionStoragePath)
        self.account.link<&SakutaroPoem.Collection{NonFungibleToken.CollectionPublic, SakutaroPoem.SakutaroPoemCollectionPublic}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        emit ContractInitialized()
    }
}
