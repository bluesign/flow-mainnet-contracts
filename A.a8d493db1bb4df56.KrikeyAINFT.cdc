import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import MetadataViews from 0x1d7e57aa55817448

/**
 * This contract defines the structure and behaviour of Solarpups NFT assets.
 * By using the KrikeyAINFT contract, assets can be registered in the AssetRegistry
 * so that NFTs, belonging to that asset can be minted. Assets and NFT tokens can
 * also be locked by this contract.
 */
pub contract KrikeyAINFT: NonFungibleToken {

    pub let KrikeyAINFTPublicPath:   PublicPath
    pub let KrikeyAINFTPrivatePath:  PrivatePath
    pub let KrikeyAINFTStoragePath:  StoragePath
    pub let CollectionStoragePath: StoragePath
    pub let AssetRegistryStoragePath: StoragePath
    pub let MinterFactoryStoragePath: StoragePath

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event MintAsset(id: UInt64, assetId: String)
    pub event BurnAsset(id: UInt64, assetId: String)
    pub event CollectionDeleted(from: Address?)

    pub var totalSupply:  UInt64
    access(self) let assets:       {String: Asset}

    // Common interface for the NFT data.
    pub resource interface TokenDataAware {
        pub let data: TokenData
    }

    /**
     * This resource represents a specific Solarpups NFT which can be
     * minted and transferred. Each NFT belongs to an asset id and has
     * an edition information. In addition to that each NFT can have other
     * NFTs which makes it composable.
     */
    pub resource NFT: NonFungibleToken.INFT, TokenDataAware, MetadataViews.Resolver {
        pub let id: UInt64
        pub let data: TokenData
        access(self) let items: @{String:{TokenDataAware, NonFungibleToken.INFT}}

        init(id: UInt64, data: TokenData, items: @{String:{TokenDataAware, NonFungibleToken.INFT}}) {
            self.id = id
            self.data = data
            self.items <- items
        }

        destroy() {
          emit BurnAsset(id: self.id, assetId: self.data.assetId)
          destroy self.items
        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Serial>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            let asset = KrikeyAINFT.getAsset(assetId: self.data.assetId)
            let url = "https://cdn.krikeyapp.com/nft_web/nft_images/".concat(self.data.assetId).concat(".png")
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: "Solarpups NFT",
                        description: "The world's most adorable and sensitive pup.",
                        thumbnail: MetadataViews.HTTPFile(
                            url: url,
                        )
                    )
                case Type<MetadataViews.Editions>():
                    // There is no max number of NFTs that can be minted from this contract
                    // so the max edition field value is set to nil
                    let editionInfo = MetadataViews.Edition(name: "Solarpups NFT Edition", number: self.data.edition as! UInt64, max: nil)
                    let editionList: [MetadataViews.Edition] = [editionInfo]
                    return MetadataViews.Editions(
                        editionList
                    )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                    )
                case Type<MetadataViews.Royalties>():
                    let RECEIVER_PATH = /public/flowTokenReceiver
                    // Address Hardcoded for testing
                    var royaltyReceiver = getAccount(0xff338e9d95c0bb8c).getCapability<&{FungibleToken.Receiver}>(RECEIVER_PATH)
                    let royalty = MetadataViews.Royalty(receiver: royaltyReceiver, cut: asset!.royalty, description: "Solarpups Krikey Creator Royalty")
                    return MetadataViews.Royalties(
                        [royalty]
                    )
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL(url)
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: KrikeyAINFT.KrikeyAINFTStoragePath,
                        publicPath: KrikeyAINFT.KrikeyAINFTPublicPath,
                        providerPath: KrikeyAINFT.KrikeyAINFTPrivatePath,
                        publicCollection: Type<&KrikeyAINFT.Collection{KrikeyAINFT.CollectionPublic}>(),
                        publicLinkedType: Type<&KrikeyAINFT.Collection{KrikeyAINFT.CollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&KrikeyAINFT.Collection{KrikeyAINFT.CollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-KrikeyAINFT.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let media= MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://cdn.krikeyapp.com/web/assets/img/solar-pups/logo.png"
                        ),
                        mediaType: "image/png"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "The Krikey Solarpups Collection",
                        description: "The world's most adorable and sensitive pups.",
                        externalURL: MetadataViews.ExternalURL("https://www.solarpups.com/marketplace"),
                        squareImage: media,
                        bannerImage: media,
                        socials: {
                            "discord": MetadataViews.ExternalURL("https://discord.com/invite/krikey"),
                            "facebook": MetadataViews.ExternalURL("https://www.facebook.com/krikeyappAR/"),
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/SolarPupsNFTs"),
                            "instagram": MetadataViews.ExternalURL("https://www.instagram.com/krikeyapp/?hl=en"),
                            "youtube": MetadataViews.ExternalURL("https://www.youtube.com/channel/UCdTV4cmkQwWgaZ89ITMO-bg")
                        }
                    )
            }
            return nil
        }
    }

    /**
     * The data of a NFT token. The asset id references to the asset in the
     * asset registry which holds all the information the NFT is about.
     */
    pub struct TokenData {
      pub let assetId: String
      pub let edition: UInt16

      init(assetId: String, edition: UInt16) {
        self.assetId = assetId
        self.edition = edition
      }
    }

    /**
     * This resource is used to register an asset in order to mint NFT tokens of it.
     * The asset registry manages the supply of the asset and is also able to lock it.
     */
    pub resource AssetRegistry {

      pub fun store(asset: Asset) {
          pre { KrikeyAINFT.assets[asset.assetId] == nil: "asset id already registered" }

          KrikeyAINFT.assets[asset.assetId] = asset
      }

      access(contract) fun setMaxSupply(assetId: String) {
        pre { KrikeyAINFT.assets[assetId] != nil: "asset not found" }
        KrikeyAINFT.assets[assetId]!.setMaxSupply()
      }

    }

    /**
     * This structure defines all the information an asset has. The content
     * attribute is a IPFS link to a data structure which contains all
     * the data the NFT asset is about.
     *
     */
    pub struct Asset {
        pub let assetId: String
        pub let creators: {Address:UFix64}
        pub var content: String
        pub let royalty: UFix64
        pub let supply: Supply

        access(contract) fun setMaxSupply() {
            self.supply.setMax(supply: 1)
        }

        access(contract) fun setCurSupply(supply: UInt16) {
            self.supply.setCur(supply: supply)
        }

        init(creators: {Address:UFix64}, assetId: String, content: String) {
            pre {
                creators.length > 0: "no address found"
            }

            var sum:UFix64 = 0.0
            for value in creators.values {
                sum = sum + value
            }
            assert(sum == 1.0, message: "invalid creator shares")

            self.creators = creators
            self.assetId  = assetId
            self.content  = content
            self.royalty  = 0.05
            self.supply   = Supply(max: 1)
        }
    }

    /**
     * This structure defines all information about the asset supply.
     */
    pub struct Supply {
        pub var max: UInt16
        pub var cur: UInt16

        access(contract) fun setMax(supply: UInt16) {
            pre {
                supply <= self.max: "supply must be lower or equal than current max supply"
                supply >= self.cur: "supply must be greater or equal than current supply"
            }
            self.max = supply
        }

        access(contract) fun setCur(supply: UInt16) {
            pre {
                supply <= self.max: "max supply limit reached"
                supply > self.cur: "supply must be greater than current supply"
            }
            self.cur = supply
        }

        init(max: UInt16) {
            self.max = max
            self.cur = 0
        }
    }

    /**
     * This resource is used by an account to collect Solarpups NFTs.
     */
    pub resource Collection: CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        pub var ownedNFTs:   @{UInt64: NonFungibleToken.NFT}
        pub var ownedAssets: {String: {UInt16:UInt64}}

        init () {
            self.ownedNFTs <- {}
            self.ownedAssets = {}
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- (self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")) as! @KrikeyAINFT.NFT
            self.ownedAssets[token.data.assetId]?.remove(key: token.data.edition)
            if (self.ownedAssets[token.data.assetId]?.length == 0) {
                self.ownedAssets.remove(key: token.data.assetId)
            }

            if (self.owner?.address != nil) {
                emit Withdraw(id: token.id, from: self.owner?.address!)
            }
            return <-token
        }

        pub fun batchWithdraw(ids: [UInt64]): @NonFungibleToken.Collection {
            var batchCollection <- create Collection()
            for id in ids {
                batchCollection.deposit(token: <-self.withdraw(withdrawID: id))
            }
            return <-batchCollection
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @KrikeyAINFT.NFT
            let id: UInt64 = token.id

            if (self.ownedAssets[token.data.assetId] == nil) {
                self.ownedAssets[token.data.assetId] = {}
            }
            self.ownedAssets[token.data.assetId]!.insert(key: token.data.edition, token.id)

            let oldToken <- self.ownedNFTs[id] <- token
            if (self.owner?.address != nil) {
                emit Deposit(id: id, to: self.owner?.address!)
            }
            destroy oldToken
        }

        pub fun batchDeposit(tokens: @NonFungibleToken.Collection) {
            for key in tokens.getIDs() {
                self.deposit(token: <-tokens.withdraw(withdrawID: key))
            }
            destroy tokens
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun getAssetIDs(): [String] {
            return self.ownedAssets.keys
        }

        pub fun getTokenIDs(assetId: String): [UInt64] {
            return (self.ownedAssets[assetId] ?? {}).values
        }

        pub fun getEditions(assetId: String): {UInt16:UInt64} {
            return self.ownedAssets[assetId] ?? {}
        }

        pub fun getOwnedAssets(): {String: {UInt16:UInt64}} {
            return self.ownedAssets
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            pre {
                self.ownedNFTs[id] != nil: "this NFT is nil"
            }
            let ref = &self.ownedNFTs[id] as &NonFungibleToken.NFT?
            return ref! as! &NonFungibleToken.NFT
        }

        pub fun borrowKrikeyAINFT(id: UInt64): &KrikeyAINFT.NFT {
            pre {
                self.ownedNFTs[id] != nil: "this NFT is nil"
            }
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let solarpupsNFT = nft as! &KrikeyAINFT.NFT
            return solarpupsNFT as &KrikeyAINFT.NFT
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let solarpupsNFT = nft as! &KrikeyAINFT.NFT
            return solarpupsNFT as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
            self.ownedAssets = {}
            if (self.owner?.address != nil) {
                emit CollectionDeleted(from: self.owner?.address!)
            }
        }
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // This is the interface that users can cast their KrikeyAINFT Collection as
    // to allow others to deposit KrikeyAINFTs into their Collection. It also allows for reading
    // the details of KrikeyAINFTs in the Collection.
    pub resource interface CollectionPublic {
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun getAssetIDs(): [String]
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun batchDeposit(tokens: @NonFungibleToken.Collection)
        pub fun getTokenIDs(assetId: String): [UInt64]
        pub fun getEditions(assetId: String): {UInt16:UInt64}
        pub fun getOwnedAssets(): {String: {UInt16:UInt64}}
        pub fun borrowKrikeyAINFT(id: UInt64): &NonFungibleToken.NFT? {
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow KrikeyAINFT reference: the ID of the returned reference is incorrect"
            }
        }
        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver}
    }

    pub resource MinterFactory {
        pub fun createMinter(): @Minter {
            return <- create Minter()
        }
    }

    // This resource is used to mint Solarpups NFTs.
	pub resource Minter {

		pub fun mint(assetId: String): @NonFungibleToken.Collection {
            pre {
                KrikeyAINFT.assets[assetId] != nil: "asset not found"
            }

            let collection <- create Collection()
            let supply = KrikeyAINFT.assets[assetId]!.supply

            supply.setCur(supply: supply.cur + (1 as UInt16))

            let data = TokenData(assetId: assetId, edition: supply.cur)
            let token <- create NFT(id: KrikeyAINFT.totalSupply, data: data, items: <- {})
                    collection.deposit(token: <- token)

            KrikeyAINFT.totalSupply = KrikeyAINFT.totalSupply + (1 as UInt64)
            emit MintAsset(id: KrikeyAINFT.totalSupply, assetId: assetId)
            KrikeyAINFT.assets[assetId]!.setCurSupply(supply: supply.cur)
            return <- collection
		}
	}

	access(account) fun getAsset(assetId: String): &KrikeyAINFT.Asset? {
	    pre { self.assets[assetId] != nil: "asset not found" }
	    return &self.assets[assetId] as &KrikeyAINFT.Asset?
	}

	pub fun getAssetIds(): [String] {
	    return self.assets.keys
	}

	init() {
        self.totalSupply  = 0
        self.assets       = {}

        self.KrikeyAINFTPublicPath     = /public/KrikeyAINFTsProd03
        self.KrikeyAINFTPrivatePath    = /private/KrikeyAINFTsProd03
        self.KrikeyAINFTStoragePath    = /storage/KrikeyAINFTsProd03
        self.CollectionStoragePath      = /storage/KrikeyAINFTsProd03
        self.AssetRegistryStoragePath   = /storage/SolarpupsAssetRegistryProd03
        self.MinterFactoryStoragePath   = /storage/SolarpupsMinterFactoryProd03

        self.account.save(<- create AssetRegistry(), to: self.AssetRegistryStoragePath)
        self.account.save(<- create MinterFactory(), to: self.MinterFactoryStoragePath)
        self.account.save(<- create Collection(),    to: self.KrikeyAINFTStoragePath)

        // create a public capability for the collection
        self.account.link<&KrikeyAINFT.Collection{NonFungibleToken.CollectionPublic, KrikeyAINFT.CollectionPublic, MetadataViews.ResolverCollection}>(
            self.KrikeyAINFTPublicPath,
            target: self.KrikeyAINFTStoragePath
        )

        emit ContractInitialized()
	}

}
 