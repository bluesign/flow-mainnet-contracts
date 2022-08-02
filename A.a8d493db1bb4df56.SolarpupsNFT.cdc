import NonFungibleToken from 0xa8d493db1bb4df56
import FungibleToken from 0xf233dcee88fe0abe

/**
 * This contract defines the structure and behaviour of Solarpups NFT assets.
 * By using the SolarpupsNFT contract, assets can be registered in the AssetRegistry
 * so that NFTs, belonging to that asset can be minted. Assets and NFT tokens can
 * also be locked by this contract.
 */
pub contract SolarpupsNFT: NonFungibleToken {

    pub let SolarpupsNFTPublicPath:   PublicPath
    pub let SolarpupsNFTPrivatePath:  PrivatePath
    pub let SolarpupsNFTStoragePath:  StoragePath
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
    pub resource NFT: NonFungibleToken.INFT, TokenDataAware {
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
          pre { SolarpupsNFT.assets[asset.assetId] == nil: "asset id already registered" }

          SolarpupsNFT.assets[asset.assetId] = asset
      }

      access(contract) fun setMaxSupply(assetId: String) {
        pre { SolarpupsNFT.assets[assetId] != nil: "asset not found" }
        SolarpupsNFT.assets[assetId]!.setMaxSupply()
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
        pub let content: String
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
    pub resource Collection: CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
        pub var ownedNFTs:   @{UInt64: NonFungibleToken.NFT}
        pub var ownedAssets: {String: {UInt16:UInt64}}

        init () {
            self.ownedNFTs <- {}
            self.ownedAssets = {}
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- (self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")) as! @SolarpupsNFT.NFT
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
            let token <- token as! @SolarpupsNFT.NFT
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

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT? {
            return &self.ownedNFTs[id] as &NonFungibleToken.NFT?
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

        pub fun borrowSolarpupsNFT(tokenId: UInt64): &SolarpupsNFT.NFT? {
            if self.ownedNFTs[tokenId] != nil {
                let ref = &self.ownedNFTs[tokenId] as auth &NonFungibleToken.NFT?
                return ref as! &SolarpupsNFT.NFT
            } else {
                return nil
            }
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

    // This is the interface that users can cast their SolarpupsNFT Collection as
    // to allow others to deposit SolarpupsNFTs into their Collection. It also allows for reading
    // the details of SolarpupsNFTs in the Collection.
    pub resource interface CollectionPublic {
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT?
        pub fun getAssetIDs(): [String]
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun batchDeposit(tokens: @NonFungibleToken.Collection)
        pub fun getTokenIDs(assetId: String): [UInt64]
        pub fun getEditions(assetId: String): {UInt16:UInt64}
        pub fun getOwnedAssets(): {String: {UInt16:UInt64}}
        pub fun borrowSolarpupsNFT(tokenId: UInt64): &NFT? {
          post {
            (result == nil) || result?.id == tokenId:
            "Cannot borrow SolarpupsNFT reference: The ID of the returned reference is incorrect"
          }
        }
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
                SolarpupsNFT.assets[assetId] != nil: "asset not found"
            }

            let collection <- create Collection()
            let supply = SolarpupsNFT.assets[assetId]!.supply

            supply.setCur(supply: supply.cur + (1 as UInt16))

            let data = TokenData(assetId: assetId, edition: supply.cur)
            let token <- create NFT(id: SolarpupsNFT.totalSupply, data: data, items: <- {})
                    collection.deposit(token: <- token)

            SolarpupsNFT.totalSupply = SolarpupsNFT.totalSupply + (1 as UInt64)
            emit MintAsset(id: SolarpupsNFT.totalSupply, assetId: assetId)
            SolarpupsNFT.assets[assetId]!.setCurSupply(supply: supply.cur)
            return <- collection
		}
	}

	access(account) fun getAsset(assetId: String): &SolarpupsNFT.Asset? {
	    pre { self.assets[assetId] != nil: "asset not found" }
	    return &self.assets[assetId] as &SolarpupsNFT.Asset?
	}

	pub fun getAssetIds(): [String] {
	    return self.assets.keys
	}

	init() {
        self.totalSupply  = 0
        self.assets       = {}

        self.SolarpupsNFTPublicPath     = /public/SolarpupsNFTsProd01
        self.SolarpupsNFTPrivatePath    = /private/SolarpupsNFTsProd01
        self.SolarpupsNFTStoragePath    = /storage/SolarpupsNFTsProd01
        self.AssetRegistryStoragePath   = /storage/SolarpupsAssetRegistryProd01
        self.MinterFactoryStoragePath   = /storage/SolarpupsMinterFactoryProd01

        self.account.save(<- create AssetRegistry(), to: self.AssetRegistryStoragePath)
        self.account.save(<- create MinterFactory(), to: self.MinterFactoryStoragePath)
        self.account.save(<- create Collection(),    to: self.SolarpupsNFTStoragePath)

        emit ContractInitialized()
	}

}
