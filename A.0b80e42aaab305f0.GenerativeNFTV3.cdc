import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract GenerativeNFTV3: NonFungibleToken {

  pub var totalSupply: UInt64
  pub var maxSupply: UInt64
  pub let nftData: {UInt64: {String:String}}

  //------------------------------------------------------------
  // Events
  //------------------------------------------------------------
  pub event ContractInitialized()
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event Minted(id: UInt64, initMeta: {String: String})

  //------------------------------------------------------------
  // Storage Path
  //------------------------------------------------------------
  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
  pub let MinterStoragePath: StoragePath

  // idToAddress
  // Maps each item ID to its current owner
  access(self) let idToAddress: {UInt64: Address}


  //------------------------------------------------------------
  // NFT Resource
  //------------------------------------------------------------
  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64
    access(self) let metadata: {String: String}

    init(initID: UInt64, initMeta: {String: String}) {
      self.id = initID
      self.metadata = initMeta
    }

    pub fun getMetadata(): {String: String} {
        return self.metadata
    }

    pub fun getImage() : String {
        return self.getMetadata()["image"] ?? ""
    }

    pub fun getTitle() : String {
        return self.getMetadata()["title"] ?? ""
    }

    pub fun getDescription() : String {
        return self.getMetadata()["description"] ?? ""
    }

    // receiver: Capability<&AnyResource{FungibleToken.Receiver}>, cut: UFix64, description: String
    pub fun getRoyalties():MetadataViews.Royalties {
      return MetadataViews.Royalties([

      ])
    }

    /// Function that returns all the Metadata Views implemented by a Non Fungible Token
    ///
    /// @return An array of Types defining the implemented views. This value will be used by
    ///         developers to know which parameter to pass to the resolveView() method.
    ///
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
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.getTitle(),
                        description: self.getDescription(),
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.getImage()
                        )
                  )
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(
                        self.id
                )
                case Type<MetadataViews.Royalties>():
                    return self.getRoyalties()
                case Type<MetadataViews.ExternalURL>():
                    return MetadataViews.ExternalURL("https://mikosea.io/")
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: GenerativeNFTV3.CollectionStoragePath,
                        publicPath: GenerativeNFTV3.CollectionPublicPath,
                        providerPath: /private/MiKoSeaNFTCollection,
                        publicCollection: Type<&GenerativeNFTV3.Collection{GenerativeNFTV3.GenerativeNFTCollectionPublic}>(),
                        publicLinkedType: Type<&GenerativeNFTV3.Collection{GenerativeNFTV3.GenerativeNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&GenerativeNFTV3.Collection{GenerativeNFTV3.GenerativeNFTCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                            return <-GenerativeNFTV3.createEmptyCollection()
                        })
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let bannerImage = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://storage.googleapis.com/studio-design-asset-files/projects/1pqD36e6Oj/s-300x50_aa59a692-741b-408b-aea3-bcd25d29c6bd.svg"
                        ),
                        mediaType: "image/svg+xml"
                    )
                    let squareImage = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                            url: "https://app.mikosea.io/mikosea_1.png"
                        ),
                        mediaType: "image/png"
                    )
                    return MetadataViews.NFTCollectionDisplay(
                        name: "あらゆる事業者の思いを載せて神輿を担ぐNFTクラウドファンディングマーケット",
                        description: "MikoSeaはアーティスト、企業、インフルエンサーといったクリエイターや、あたらしく何かを始めたい人のためのクラウドファンディングサービスです。プロジェクトの発起人は、NFTを販売することで商品を販売するという一方向の取引を超え、プロジェクトの想いに共感した”熱狂的なファン”から資金を調達し、夢の実現へと近づけます。プロジェクト支援者は、プロジェクトを支援する目的でNFTを購入し、共創･協働のプロセスに参加することで、プロジェクトから特別な体験価値やメリットを得ることができます。",
                        externalURL: MetadataViews.ExternalURL("https://app.mikosea.io/"),
                        squareImage: squareImage,
                        bannerImage: bannerImage,
                        socials: {
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/MikoSea_io")
                        }
                    )
            }
            return nil
        }
  }

  //------------------------------------------------------------
  // Collection Public Interface
  //------------------------------------------------------------

  pub resource interface GenerativeNFTCollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver}
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    pub fun borrowItem(id: UInt64): &GenerativeNFTV3.NFT? {
      post {
        (result == nil) || (result?.id == id):
          "Cannot borrow reference: The ID of the returned reference is incorrect"
      }
    }
  }

  //------------------------------------------------------------
  // Collection Resource
  //------------------------------------------------------------

  pub resource Collection: GenerativeNFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {

    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    init () {
      self.ownedNFTs <- {}
    }

    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
      emit Withdraw(id: token.id, from: self.owner!.address)
      return <-token
    }

    pub fun deposit(token: @NonFungibleToken.NFT) {
      let token <- token as! @GenerativeNFTV3.NFT
      let id: UInt64 = token.id
      let oldToken <- self.ownedNFTs[id] <- token
      // update owner

      if self.owner?.address != nil {
        GenerativeNFTV3.idToAddress[id] = self.owner!.address
        emit Deposit(id: id, to: self.owner!.address)
      }
      destroy oldToken
    }

    pub fun transfer(id: UInt64, recipient: &{NonFungibleToken.CollectionPublic}) {
      post {
        self.ownedNFTs[id] == nil: "The specified NFT was not transferred"
        recipient.borrowNFT(id: id) != nil: "Recipient did not receive the intended NFT"
      }
      let nft <- self.withdraw(withdrawID: id)
      recipient.deposit(token: <- nft)
    }

    pub fun burn(id: UInt64) {
      post {
        self.ownedNFTs[id] == nil: "The specified NFT was not burned"
      }
      destroy <- self.withdraw(withdrawID: id)
    }

    pub fun getIDs(): [UInt64] {
      return self.ownedNFTs.keys
    }

    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
      if self.ownedNFTs[id] != nil {
        return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
      }
      panic("NFT not found in collection.")
    }

    pub fun borrowItem(id: UInt64): &GenerativeNFTV3.NFT? {
      if self.ownedNFTs[id] != nil {
        let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
        if ref != nil {
          return ref! as! &GenerativeNFTV3.NFT
        }
      }
      return nil
    }

    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let mikoseaNFT = nft as! &GenerativeNFTV3.NFT
            return mikoseaNFT as &AnyResource{MetadataViews.Resolver}
        }

    /// Safe way to borrow a reference to an NFT that does not panic
    ///
    /// @param id: The ID of the NFT that want to be borrowed
    /// @return An optional reference to the desired NFT, will be nil if the passed id does not exist
    ///
    pub fun borrowNFTSafe(id: UInt64): &GenerativeNFTV3.NFT? {
      return self.borrowItem(id: id)
    }

    destroy() {
      destroy self.ownedNFTs
    }
  }

  // createEmptyCollection
  pub fun createEmptyCollection(): @NonFungibleToken.Collection {
      return <- create Collection()
  }

  //------------------------------------------------------------
  // NFT Minter
  //------------------------------------------------------------
	pub resource NFTMinter {

    pub fun mintNFTs(initMetadata: {String: String}): @GenerativeNFTV3.NFT{
      pre{
        GenerativeNFTV3.totalSupply < GenerativeNFTV3.maxSupply : "NFT Sold Out!!!"
      }
      GenerativeNFTV3.totalSupply = GenerativeNFTV3.totalSupply  + 1
      let nftID = GenerativeNFTV3.totalSupply
      var newNFT <- create GenerativeNFTV3.NFT(
                initID: nftID, initMeta: initMetadata
            )
      GenerativeNFTV3.nftData[nftID] = initMetadata
      emit Minted(id: nftID, initMeta: initMetadata)
      return <- newNFT
    }

    pub fun mintNFT(initMetadata: {String: String}, address: Address): @GenerativeNFTV3.NFT {
      let newNFT <- self.mintNFTs(initMetadata: initMetadata)
      GenerativeNFTV3.idToAddress[newNFT.id] = address
      return <- newNFT
    }

    pub fun addSuply(num: UInt64) {
      GenerativeNFTV3.maxSupply = GenerativeNFTV3.maxSupply + num
    }
	}

  // getOwner
  // Gets the current owner of the given item
  //
  pub fun getOwner(itemID: UInt64): Address? {
    if itemID >= 0 && itemID < self.maxSupply {
      if (itemID < GenerativeNFTV3.totalSupply) {
        return GenerativeNFTV3.idToAddress[itemID]
      } else {
        return nil
      }
    }
    return nil
  }

  //------------------------------------------------------------
  // Initializer
  //------------------------------------------------------------
	init() {
    // Set our named paths
    self.CollectionStoragePath = /storage/GenerativeNFTV3Collections
    self.CollectionPublicPath = /public/GenerativeNFTV3Collections
    self.MinterStoragePath = /storage/GenerativeNFTV3Minters

    // Initialize the total supply
    self.totalSupply = 0

    // Initialize the max supply
    self.maxSupply = 10000

    // Initalize mapping from ID to address
    self.idToAddress = {}

    self.nftData = {}

    // Create a Minter resource and save it to storage
    let minter <- create NFTMinter()
    self.account.save(<-minter, to: self.MinterStoragePath)
    emit ContractInitialized()
	}
}
