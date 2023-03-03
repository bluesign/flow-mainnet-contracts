import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract RCRDSHPNFT: NonFungibleToken {
    pub var totalSupply: UInt64
    pub let minterStoragePath: StoragePath
    pub let collectionStoragePath: StoragePath
    pub let collectionPublicPath: PublicPath

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Burn(id: UInt64, from: Address?)
    pub event Sale(id: UInt64, price: UInt64)

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
        pub let id: UInt64
        pub var metadata: {String: String}

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.Display>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Traits>()
            ]
        }



        pub fun resolveView(_ view: Type): AnyStruct? {

            let metadata = self.metadata

            fun getMetaValue(_ key: String, _ defaultVal: String) : String {
                return metadata[key] ?? defaultVal
            }

            fun getThumbnail(): MetadataViews.HTTPFile {
                let url = metadata["uri"] == nil ? "https://rcrdshp-happyfox-assets.s3.amazonaws.com/Purple.svg" : metadata["uri"]!.concat("/thumbnail")
                return MetadataViews.HTTPFile(url: url)
            }

            fun createGenericDisplay(): MetadataViews.Display {
                let name = getMetaValue("name", "?RCRDSHP NFT?")
                let serial = getMetaValue("serial_number", "?")
                return MetadataViews.Display(
                    name: name,
                    description: getMetaValue("description", "An unknown RCRDSHP Collection NFT"),
                    thumbnail: getThumbnail()
                )
            }

            fun createVoucherDisplay(): MetadataViews.Display {
                let name = getMetaValue("name", "?RCRDSHP Voucher NFT?")
                let serial = getMetaValue("voucher_serial_number", "?")
                let isFlowFest = name.slice(from: 0, upTo: 9) == "Flow fest"
                return MetadataViews.Display(
                    name: name.concat(" #").concat(serial),
                    description: getMetaValue("description", "An unknown RCRDSHP Collection Vouncher NFT"),
                    thumbnail: isFlowFest ? MetadataViews.HTTPFile(url: "https://rcrdshp-happyfox-assets.s3.amazonaws.com/flowfest-pack.png") : getThumbnail()
                )
            }

            fun createTraits(): MetadataViews.Traits {
                let rarity = metadata["rarity"]
                if rarity == nil{
                    return MetadataViews.Traits(traits: [])
                } else {
                    let rarityTrait = MetadataViews.Trait(
                        name: "Rarity",
                        value: rarity!,
                        rarity: nil,
                        displayType: nil
                    )
                    return MetadataViews.Traits(traits: [rarityTrait])
                }
            }

            fun createExternalURL(): MetadataViews.ExternalURL {
                return MetadataViews.ExternalURL(url: metadata["uri"] ?? "https://app.rcrdshp.com")
            }

            fun createCollectionData(): MetadataViews.NFTCollectionData {
                return MetadataViews.NFTCollectionData(
                                                storagePath: RCRDSHPNFT.collectionStoragePath,
                                                publicPath: RCRDSHPNFT.collectionPublicPath,
                                                providerPath: /private/RCRDSHPNFTCollection,
                                                publicCollection: Type<&RCRDSHPNFT.Collection{RCRDSHPNFT.RCRDSHPNFTCollectionPublic}>(),
                                                publicLinkedType: Type<&RCRDSHPNFT.Collection{RCRDSHPNFT.RCRDSHPNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                                                providerLinkedType: Type<&RCRDSHPNFT.Collection{RCRDSHPNFT.RCRDSHPNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                                                createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                                                    return <-RCRDSHPNFT.createEmptyCollection()
                                                })
                )
            }

            fun createCollectionDisplay(): MetadataViews.NFTCollectionDisplay {
                    let squareMedia = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://rcrdshp-happyfox-assets.s3.amazonaws.com/Purple.svg"
                        ),
                        mediaType: "image/svg+xml"
                    )
                    let bannerMedia = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://rcrdshp-happyfox-assets.s3.amazonaws.com/banner.png"
                        ),
                        mediaType: "image/png"
                    )

                    return MetadataViews.NFTCollectionDisplay(
                        name: "The RCRDSHP Collection",
                        description: "Here comes the drop!",
                        externalURL: MetadataViews.ExternalURL("https://app.rcrdshp.com"),
                        squareImage: squareMedia,
                        bannerImage: bannerMedia,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/rcrdshp"),
                            "instagram": MetadataViews.ExternalURL("https://www.instagram.com/rcrdshp"),
                            "discord": MetadataViews.ExternalURL("https://discord.gg/rcrdshp"),
                            "facebook": MetadataViews.ExternalURL("https://www.facebook.com/rcrdshp")
                        }
                    )
            }

            fun createRoyalties(): MetadataViews.Royalties {
               let royalties : [MetadataViews.Royalty] = []
               return MetadataViews.Royalties(royalties: royalties)
            }

            fun parseUInt64(_ string: String) : UInt64? {
                let chars : {Character : UInt64} = {
                    "0" : 0 ,
                    "1" : 1 ,
                    "2" : 2 ,
                    "3" : 3 ,
                    "4" : 4 ,
                    "5" : 5 ,
                    "6" : 6 ,
                    "7" : 7 ,
                    "8" : 8 ,
                    "9" : 9
                }
                var number : UInt64 = 0
                var i = 0
                while i < string.length {
                    if let n = chars[string[i]] {
                            number = number * 10 + n
                    } else {
                        return nil
                    }
                    i = i + 1
                }
                return number
            }


            switch view {
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(parseUInt64(getMetaValue("serial_number", "0")) ?? 0)
                case Type<MetadataViews.Display>():
                    return metadata["type"] == "Voucher" ? createVoucherDisplay() : createGenericDisplay()
                case Type<MetadataViews.ExternalURL>():
                    return createExternalURL()
                case Type<MetadataViews.NFTCollectionData>():
                    return createCollectionData()
                case Type<MetadataViews.NFTCollectionDisplay>():
                    return createCollectionDisplay()
                case Type<MetadataViews.Royalties>():
                    return createRoyalties()
                case Type<MetadataViews.Traits>():
                    return createTraits()
            }
            return nil
        }

        init(initID: UInt64, metadata: {String : String}) {
            self.id = initID
            self.metadata = metadata
        }
    }

    pub resource interface RCRDSHPNFTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowRCRDSHPNFT(id: UInt64): &RCRDSHPNFT.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow RCRDSHPNFT reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: RCRDSHPNFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init () {
            self.ownedNFTs <- {}
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("withdraw - missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)
            return <-token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @RCRDSHPNFT.NFT
            let id: UInt64 = token.id
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)
            destroy oldToken
        }

        pub fun sale(id: UInt64, price: UInt64): @NonFungibleToken.NFT {
            emit Sale(id: id, price: price)
            return <-self.withdraw(withdrawID: id)
        }

        pub fun burn(burnID: UInt64){
            let token <- self.ownedNFTs.remove(key: burnID) ?? panic("burn - missing NFT")

            emit Burn(id: token.id, from: self.owner?.address)
            destroy token
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowRCRDSHPNFT(id: UInt64): &RCRDSHPNFT.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
                return ref as! &RCRDSHPNFT.NFT?
            }

            return nil
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let rcrdshpNFT = nft as! &RCRDSHPNFT.NFT
            return rcrdshpNFT as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    pub resource NFTMinter {
        pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, meta: {String : String}) {
            var newNFT <- create NFT(initID: RCRDSHPNFT.totalSupply, metadata: meta)
            recipient.deposit(token: <-newNFT)
            RCRDSHPNFT.totalSupply = RCRDSHPNFT.totalSupply + UInt64(1)
        }
    }

    init() {
        self.totalSupply = 0

        self.minterStoragePath = /storage/RCRDSHPNFTMinter
        self.collectionStoragePath = /storage/RCRDSHPNFTCollection
        self.collectionPublicPath  = /public/RCRDSHPNFTCollection

        let collection <- create Collection()
        self.account.save(<-collection, to: self.collectionStoragePath)

        self.account.link<&RCRDSHPNFT.Collection{NonFungibleToken.CollectionPublic, RCRDSHPNFT.RCRDSHPNFTCollectionPublic}>(
            self.collectionPublicPath,
            target: self.collectionStoragePath
        )

        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.minterStoragePath)

        emit ContractInitialized()
    }
}
