//
// 88        88               88                                     88           
// 88        88               88                                     88           
// 88        88               88                                     88           
// 88        88  8b,dPPYba,   88   ,adPPYba,  ,adPPYYba,  ,adPPYba,  88,dPPYba,   
// 88        88  88P'   `"8a  88  a8P_____88  ""     `Y8  I8[    ""  88P'    "8a  
// 88        88  88       88  88  8PP"""""""  ,adPPPPP88   `"Y8ba,   88       88  
// Y8a.    .a8P  88       88  88  "8b,   ,aa  88,    ,88  aa    ]8I  88       88  
//  `"Y8888Y"'   88       88  88   `"Ybbd8"'  `"8bbdP"Y8  `"YbbdP"'  88       88  
//
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import Base64Util from 0x29eece8cbe9b293e

pub contract Unleash: NonFungibleToken {
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let CollectionPrivatePath: PrivatePath
    pub let MinterStoragePath: StoragePath

    pub var totalSupply: UInt64
    pub let imageIpfsCids: [String]
    pub var baseAnimationUrl: String
    pub var ipfsGatewayUrl: String
    pub var arweaveGatewayUrl: String

    pub resource interface NFTPublic {
        pub let id: UInt64
        pub let metadata: {String: AnyStruct}
        pub fun getMessage(): String
        pub fun getImageNumber(): UInt8
        pub fun getViews(): [Type]
        pub fun resolveView(_ view: Type): AnyStruct?
    }

    pub resource NFT: NFTPublic, NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub let metadata: {String: AnyStruct}
        access(contract) var message: String
        access(contract) var imageNumber: UInt8
        access(contract) var stashes: @[NonFungibleToken.NFT]

        init() {
            Unleash.totalSupply = Unleash.totalSupply + 1
            self.id = Unleash.totalSupply
            self.message = ""
            self.imageNumber = 0
            let currentBlock = getCurrentBlock()
            self.metadata = {
                "mintedBlock": currentBlock.height,
                "mintedTime": currentBlock.timestamp
            }
            self.stashes <- []
        }

        pub fun getMessage(): String {
            return self.message
        }

        pub fun setMessage(message: String) {
            self.message = message
        }

        pub fun getImageNumber(): UInt8 {
            return self.imageNumber
        }

        pub fun setImageNumber(imageNumber: UInt8) {
            pre {
                Int(imageNumber) < Unleash.imageIpfsCids.length: "Invalid image number"
            }
            self.imageNumber = imageNumber
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Traits>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: "Unleash",
                        description: "Digital memorabilia for Mercari's 10th anniversary.",
                        thumbnail: MetadataViews.HTTPFile(url: Unleash.ipfsGatewayUrl.concat(Unleash.imageIpfsCids[self.imageNumber]))
                    )
                case Type<MetadataViews.Editions>():
                    return MetadataViews.Editions([MetadataViews.Edition(name: "Unleash NFT Edition", number: self.id, max: Unleash.totalSupply)])
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(self.id)
                case Type<MetadataViews.Royalties>():
                    return nil
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://about.mercari.com/")
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: Unleash.CollectionStoragePath,
                        publicPath: Unleash.CollectionPublicPath,
                        providerPath: Unleash.CollectionPrivatePath,
                        publicCollection: Type<&Unleash.Collection{Unleash.UnleashCollectionPublic}>(),
                        publicLinkedType: Type<&Unleash.Collection{Unleash.UnleashCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&Unleash.Collection{Unleash.UnleashCollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <- Unleash.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(url: Unleash.ipfsGatewayUrl.concat(Unleash.imageIpfsCids[0])),
                        mediaType: "image/png"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "Unleash",
                        description: "Digital memorabilia for Mercari's 10th anniversary.",
                        externalURL: MetadataViews.ExternalURL("https://about.mercari.com/"),
                        squareImage: media,
                        bannerImage: media,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/mercari_inc")
                        }
                    )
                case Type<MetadataViews.Traits>():
                    let excludedTraits = ["mintedTime"]
                    let traitsView = MetadataViews.dictToTraits(dict: self.metadata, excludedNames: excludedTraits)
                    traitsView.addTrait(MetadataViews.Trait(name: "mintedTime", value: self.metadata["mintedTime"]!, displayType: "Date", rarity: nil))
                    traitsView.addTrait(MetadataViews.Trait(name: "animationUrl", value: self.getAnimationUrl(), displayType: nil, rarity: nil))
                    return traitsView
            }
            return nil
        }

        pub fun stash(token: @NonFungibleToken.NFT) {
            self.stashes.insert(at: 0, <- token)
        }

        pub fun unstash(): @NonFungibleToken.NFT {
            return <- self.stashes.removeFirst()
        }

        priv fun getAnimationUrl(): String {
            var url = Unleash.baseAnimationUrl
                .concat("?image=").concat(self.imageNumber.toString())
                .concat("&message=").concat(Base64Util.encode(self.message))
            if Unleash.arweaveGatewayUrl != "" {
                url = url.concat("&arHost=").concat(Unleash.arweaveGatewayUrl)
            }
            return url
        }

        destroy() {
            destroy self.stashes
        }
    }

    pub resource interface UnleashCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowUnleashPublic(id: UInt64): &AnyResource{Unleash.NFTPublic}? {
            post {
                (result == nil) || (result?.id == id): "Cannot borrow Unleash reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: UnleashCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <- token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @Unleash.NFT
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
 
        pub fun borrowUnleashPublic(id: UInt64): &AnyResource{Unleash.NFTPublic}? {
            if self.ownedNFTs[id] != nil {
                return (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?) as! &AnyResource{Unleash.NFTPublic}?
            }
            return nil
        }

        pub fun borrowUnleash(id: UInt64): &Unleash.NFT? {
            if self.ownedNFTs[id] != nil {
                return (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?) as! &Unleash.NFT?
            }
            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)! as! &Unleash.NFT
            return nft as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub resource Minter {
        pub fun mint(): @Unleash.NFT {
            return <- create NFT()
        }

        pub fun setBaseAnimationUrl(baseAnimationUrl: String) {
            Unleash.baseAnimationUrl = baseAnimationUrl
        }

        pub fun setIpfsGatewayUrl(ipfsGatewayUrl: String) {
            Unleash.ipfsGatewayUrl = ipfsGatewayUrl
        }

        pub fun setArweaveGatewayUrl(arweaveGatewayUrl: String) {
            Unleash.arweaveGatewayUrl = arweaveGatewayUrl
        }
    }

    init() {
        self.totalSupply = 0
        self.imageIpfsCids = [
            "bafkreiecrru5wuz7fbaui3bjc3ywry2itor2pjqywjajtbrmithxgcnvzu", // Unleash Logo
            "bafkreifj3peaxpqlhyt2plpep4rceulmx3dqajlxdeyvrra2djnorvod7m" // Unleash Key Visual
        ]
        self.baseAnimationUrl = "https://arweave.net/gxvwaKEi_GtRlgxoGA0wT8g_IGZ8dYxKKiBgSGDThgY"
        self.ipfsGatewayUrl = "https://nftstorage.link/ipfs/"
        self.arweaveGatewayUrl = ""
        self.CollectionStoragePath = /storage/UnleashCollection
        self.CollectionPublicPath = /public/UnleashCollection
        self.CollectionPrivatePath = /private/UnleashCollection
        self.MinterStoragePath = /storage/UnleashMinter

        self.account.save(<- create Minter(), to: self.MinterStoragePath)
        self.account.save(<- create Collection(), to: self.CollectionStoragePath)
        self.account.link<&Unleash.Collection{NonFungibleToken.CollectionPublic, Unleash.UnleashCollectionPublic, MetadataViews.ResolverCollection}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )
        emit ContractInitialized()
    }
}
