/* */
import MetadataViews from 0x1d7e57aa55817448
import NonFungibleToken from 0x1d7e57aa55817448
import TiblesApp from 0x5cdeb067561defcb
import TiblesNFT from 0x5cdeb067561defcb
import TiblesProducer from 0x5cdeb067561defcb

pub contract Seussibles:
  NonFungibleToken,
  TiblesApp,
  TiblesNFT,
  TiblesProducer
{
  pub let appId: String
  pub let title: String
  pub let description: String
  pub let ProducerStoragePath: StoragePath
  pub let ProducerPath: PrivatePath
  pub let ContentPath: PublicPath
  pub let contentCapability: Capability
  pub let CollectionStoragePath: StoragePath
  pub let PublicCollectionPath: PublicPath

  pub event ContractInitialized()
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event MinterCreated(minterId: String)
  pub event TibleMinted(minterId: String, mintNumber: UInt32, id: UInt64)
  pub event PackMinterCreated(minterId: String)
  pub event PackMinted(id: UInt64, printedPackId: String)

  pub var totalSupply: UInt64

  pub resource NFT: NonFungibleToken.INFT, TiblesNFT.INFT, MetadataViews.Resolver {
    pub let id: UInt64
    pub let mintNumber: UInt32

    access(self) let contentCapability: Capability
    access(self) let contentId: String

    init(id: UInt64, mintNumber: UInt32, contentCapability: Capability, contentId: String) {
      self.id = id
      self.mintNumber = mintNumber
      self.contentId = contentId
      self.contentCapability = contentCapability
    }

    pub fun metadata(): {String: AnyStruct}? {
      let content = self.contentCapability.borrow<&{TiblesProducer.IContent}>() ?? panic("Failed to borrow content provider")
      return content.getMetadata(contentId: self.contentId)
    }

    pub fun displayData(): {String: String} {
      let metadata = self.metadata() ?? panic("Missing NFT metadata")

      if (metadata.containsKey("pack")) {
        return {
          "name": "Seussibles pack",
          "description": "A Seussibles pack",
          "imageUrl": "https://i.tibles.com/m/seussibles-flow-icon.png"
        }
      }

      let set = metadata["set"]! as! &Seussibles.Set
      let item = metadata["item"]! as! &Seussibles.Item
      let variant = metadata["variant"]! as! &Seussibles.Variant

      var edition: String = ""
      var serialInfo: String = ""
      if let maxCount = variant.maxCount() {
        edition = "Limited Edition"
        serialInfo = "LE | "
          .concat(variant.title())
          .concat(" #")
          .concat(self.mintNumber.toString())
          .concat("/")
          .concat(maxCount.toString())
      } else if let batchSize = variant.batchSize() {
        edition = "Standard Edition"
        let mintSeries = (self.mintNumber - 1) / batchSize + 1
        serialInfo = "S".concat(mintSeries.toString())
          .concat(" | ")
          .concat(variant.title())
          .concat(" #")
          .concat(self.mintNumber.toString())
      } else {
        panic("Missing batch size and max count")
      }

      let description = serialInfo
        .concat("\n")
        .concat(edition)
        .concat("\n")
        .concat(set.title())

      let imageUrl = item.imageUrl(variantId: variant.id)

      return {
        "name": item.title(),
        "description": description,
        "imageUrl": imageUrl,
        "edition": edition,
        "serialInfo": serialInfo
      }
    }

    pub fun display(): MetadataViews.Display {
      let nftData = self.displayData()

      return MetadataViews.Display(
        name: nftData["name"] ?? "",
        description: nftData["description"] ?? "",
        thumbnail: MetadataViews.HTTPFile(url: nftData["imageUrl"] ?? "")
      )
    }

    pub fun editions(): MetadataViews.Editions {
      let nftData = self.displayData()
      let metadata = self.metadata() ?? panic("Missing NFT metadata")
      let variant = metadata["variant"]! as! &Seussibles.Variant

      var maxCount: UInt64? = nil
      if let count = variant.maxCount() {
        maxCount = UInt64(count)
      }

      let editionInfo = MetadataViews.Edition(
        name: nftData["edition"] ?? "",
        number: UInt64(self.mintNumber),
        max: maxCount
      )

      let editionList: [MetadataViews.Edition] = [editionInfo]
      return MetadataViews.Editions(editionList)
    }

    pub fun serial(): MetadataViews.Serial {
      return MetadataViews.Serial(UInt64(self.mintNumber))
    }

    pub fun royalties(): MetadataViews.Royalties {
      let royalties : [MetadataViews.Royalty] = []
      return MetadataViews.Royalties(royalties: royalties)
    }

    pub fun externalURL(): MetadataViews.ExternalURL {
      return MetadataViews.ExternalURL("https://app.seussibles.com/collection/".concat(self.id.toString()))
    }

    pub fun nftCollectionData(): MetadataViews.NFTCollectionData {
      return MetadataViews.NFTCollectionData(
        storagePath: Seussibles.CollectionStoragePath,
        publicPath: Seussibles.PublicCollectionPath,
        providerPath: /private/SeussiblesCollection,
        publicCollection: Type<&Seussibles.Collection{TiblesNFT.CollectionPublic}>(),
        publicLinkedType:   Type<&Seussibles.Collection{TiblesNFT.CollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
        providerLinkedType: Type<&Seussibles.Collection{TiblesNFT.CollectionPublic,NonFungibleToken.Provider,NonFungibleToken.CollectionPublic,MetadataViews.ResolverCollection}>(),
        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
            return <-Seussibles.createEmptyCollection()
        })
      )
    }

    pub fun nftCollectionDisplay(): MetadataViews.NFTCollectionDisplay {
      let squareMedia = MetadataViews.Media(
        file: MetadataViews.HTTPFile(url: "https://i.tibles.com/m/seussibles-flow-icon.png"),
        mediaType: "image/svg+xml"
      )
      let bannerMedia = MetadataViews.Media(
        file: MetadataViews.HTTPFile(url: "https://i.tibles.com/m/seussibles-flow-collection-banner.png"),
        mediaType: "image/png"
      )

      let socialsData: {String: String} = {"twitter": "https://twitter.com/seussibles", "discord": "https://discord.gg/WXCrzeVwvp"}
      let socials:{String: MetadataViews.ExternalURL } = {}
      for key in socialsData.keys {
        socials[key] = MetadataViews.ExternalURL(socialsData[key]!)
      }

      return MetadataViews.NFTCollectionDisplay(
        name: "Seussibles! Dr. Seuss Collection by Tibles",
        description: "An officially licensed Dr. Seuss digital collecting experience by Tibles. Available on iOS and web, Seussibles! is super accessible, engaging, and fun!",
        externalURL: MetadataViews.ExternalURL("https://seussibles.com"),
        squareImage: squareMedia,
        bannerImage: bannerMedia,
        socials: socials
      )
    }

    pub fun traits(): MetadataViews.Traits {
      let traits : [MetadataViews.Trait] = []
      return MetadataViews.Traits(traits: traits)
    }

    pub fun getViews(): [Type] {
      return [
        Type<MetadataViews.Display>(),
        Type<MetadataViews.Editions>(),
        Type<MetadataViews.Royalties>(),
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
          return self.display()
        case Type<MetadataViews.Editions>():
          return self.editions()
        case Type<MetadataViews.Serial>():
          return self.serial()
        case Type<MetadataViews.Royalties>():
          return self.royalties()
        case Type<MetadataViews.ExternalURL>():
          return self.externalURL()
        case Type<MetadataViews.NFTCollectionData>():
          return self.nftCollectionData()
        case Type<MetadataViews.NFTCollectionDisplay>():
          return self.nftCollectionDisplay()
        case Type<MetadataViews.Traits>():
          return self.traits()
        default: return nil
      }
    }
  }

  pub resource Collection:
    NonFungibleToken.Provider,
    NonFungibleToken.Receiver,
    NonFungibleToken.CollectionPublic,
    TiblesNFT.CollectionPublic,
    MetadataViews.ResolverCollection
  {
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    pub fun deposit(token: @NonFungibleToken.NFT) {
      let tible <- token as! @Seussibles.NFT
      self.depositTible(tible: <- tible)
    }

    pub fun depositTible(tible: @AnyResource{TiblesNFT.INFT}) {
      pre {
        self.ownedNFTs[tible.id] == nil: "tible with this id already exists"
      }
      let token <- tible as! @Seussibles.NFT
      let id = token.id
      self.ownedNFTs[id] <-! token

      if self.owner?.address != nil {
        emit Deposit(id: id, to: self.owner?.address)
      }
    }

    pub fun getIDs(): [UInt64] {
      return self.ownedNFTs.keys
    }

    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
      if let nft = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT? {
        return nft
      }
      panic("Failed to borrow NFT with ID: ".concat(id.toString()))
    }

    pub fun borrowTible(id: UInt64): &AnyResource{TiblesNFT.INFT} {
      if let nft = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT? {
        return nft as! &Seussibles.NFT
      }
      panic("Failed to borrow NFT with ID: ".concat(id.toString()))
    }

    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("Cannot withdraw: tible does not exist in the collection")
      emit Withdraw(id: token.id, from: self.owner?.address)
      return <-token
    }

    pub fun withdrawTible(id: UInt64): @AnyResource{TiblesNFT.INFT} {
      let token <- self.ownedNFTs.remove(key: id) ?? panic("Cannot withdraw: tible does not exist in the collection")
      let tible <- token as! @Seussibles.NFT
      emit Withdraw(id: tible.id, from: self.owner?.address)
      return <-tible
    }

    pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver} {
      if let nft = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT? {
        return nft as! &Seussibles.NFT
      }
      panic("Failed to borrow NFT with ID: ".concat(id.toString()))
    }

    pub fun tibleDescriptions(): {UInt64: {String: AnyStruct}} {
      var descriptions: {UInt64: {String: AnyStruct}} = {}

      for id in self.ownedNFTs.keys {
        let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT?
        let nft = ref as! &NFT
        var description: {String: AnyStruct} = {}
        description["mintNumber"] = nft.mintNumber
        description["metadata"] = nft.metadata()
        descriptions[id] = description
      }

      return descriptions
    }

    init () {
      self.ownedNFTs <- {}
    }

    destroy() {
      destroy self.ownedNFTs
    }
  }

  pub fun createEmptyCollection(): @NonFungibleToken.Collection {
    return <- create Collection()
  }

  pub struct ContentLocation {
    pub let setId: String
    pub let itemId: String
    pub let variantId: String

    init(setId: String, itemId: String, variantId: String) {
      self.setId = setId
      self.itemId = itemId
      self.variantId = variantId
    }
  }

  pub struct interface IContentLocation {}

  pub resource Producer: TiblesProducer.IProducer, TiblesProducer.IContent {
    access(contract) let minters: @{String: TiblesProducer.Minter}
    access(contract) let contentIdsToPaths: {String: TiblesProducer.ContentLocation}
    access(contract) let sets: {String: Set}

    pub fun minter(id: String): &Minter? {
      let ref = &self.minters[id] as auth &{TiblesProducer.IMinter}?
      return ref as! &Minter?
    }

    pub fun set(id: String): &Set? {
      return &self.sets[id] as &Set?
    }

    pub fun addSet(_ set: Set, contentCapability: Capability) {
      pre {
        self.sets[set.id] == nil: "Set with id: ".concat(set.id).concat(" already exists")
      }

      self.sets[set.id] = set

      for item in set.items.values {
        for variant in set.variants.values {
          let limit: UInt32? = variant.maxCount()

          let minterId: String = set.id.concat(":").concat(item.id).concat(":").concat(variant.id)
          let minter <- create Minter(id: minterId, limit: limit, contentCapability: contentCapability)

          if self.minters.keys.contains(minterId) {
            panic("Minter ID ".concat(minterId).concat(" already exists."))
          }

          self.minters[minterId] <-! minter

          let path = ContentLocation(setId: set.id, itemId: item.id, variantId: variant.id)
          self.contentIdsToPaths[minterId] = path

          emit MinterCreated(minterId: minterId)
        }
      }
    }

    pub fun getMetadata(contentId: String): {String: AnyStruct}? {
      let path = self.contentIdsToPaths[contentId] ?? panic("Failed to get content path")
      let location = path as! ContentLocation
      let set = self.set(id: location.setId) ?? panic("The set does not exist!")
      let item = set.item(location.itemId) ?? panic("Item metadata is nil")
      let variant = set.variant(location.variantId) ?? panic("Variant metadata is nil")

      var metadata: {String: AnyStruct} = {}
      metadata["set"] = set
      metadata["item"] = item
      metadata["variant"] = variant
      return metadata
    }

    init() {
      self.sets = {}
      self.contentIdsToPaths = {}
      self.minters <- {}
    }

    destroy() {
      destroy self.minters
    }
  }

  pub struct Set {
    pub let id: String
    access(contract) let items: {String: Item}
    access(contract) let variants: {String: Variant}
    access(contract) var metadata: {String: AnyStruct}?

    pub fun title(): String {
      return self.metadata!["title"]! as! String
    }

    pub fun item(_ id: String): &Item? {
      return &self.items[id] as &Item?
    }

    pub fun variant(_ id: String): &Variant? {
      return &self.variants[id] as &Variant?
    }

    pub fun update(title: String) {
      self.metadata = {
        "title": title
      }
    }

    init(id: String, title: String, items: {String: Item}, variants: {String: Variant}) {
      self.id = id
      self.items = items
      self.variants = variants
      self.metadata = nil
      self.update(title: title)
    }
  }

  pub struct Item {
    pub let id: String
    access(contract) var metadata: {String: AnyStruct}?

    pub fun title(): String {
      return self.metadata!["title"]! as! String
    }

    pub fun imageUrl(variantId: String): String {
      let imageUrls = self.metadata!["imageUrls"]! as! {String: String}
      return imageUrls[variantId]!
    }

    pub fun update(title: String, imageUrls: {String: String}) {
      self.metadata = {
        "title": title,
        "imageUrls": imageUrls
      }
    }

    init(id: String, title: String, imageUrls: {String: String}) {
      self.id = id
      self.metadata = nil
      self.update(title: title, imageUrls: imageUrls)
    }
  }

  pub struct Variant {
    pub let id: String
    access(contract) var metadata: {String: AnyStruct}?

    pub fun title(): String {
      return self.metadata!["title"]! as! String
    }

    pub fun batchSize(): UInt32? {
      return self.metadata!["batchSize"] as! UInt32?
    }

    pub fun maxCount(): UInt32? {
      return self.metadata!["maxCount"] as! UInt32?
    }

    pub fun update(title: String, batchSize: UInt32?, maxCount: UInt32?) {
      assert((batchSize == nil) != (maxCount == nil), message: "batch size or max count can be used, not both")
      let metadata: {String: AnyStruct} = {
        "title": title
      }
      let previousBatchSize = (self.metadata ?? {})["batchSize"] as! UInt32?
      let previousMaxCount = (self.metadata ?? {})["maxCount"] as! UInt32?
      if let batchSize = batchSize {
        assert(previousMaxCount == nil, message: "Cannot change from max count to batch size")
        assert(previousBatchSize == nil || previousBatchSize == batchSize, message: "batch size cannot be changed once set")
        metadata["batchSize"] = batchSize
      }
      if let maxCount = maxCount {
        assert(previousBatchSize == nil, message: "Cannot change from batch size to max count")
        assert(previousMaxCount == nil || previousMaxCount == maxCount, message: "max count cannot be changed once set")
        metadata["maxCount"] = maxCount
      }
      self.metadata = metadata
    }

    init(id: String, title: String, batchSize: UInt32?, maxCount: UInt32?) {
      self.id = id
      self.metadata = nil
      self.update(title: title, batchSize: batchSize, maxCount: maxCount)
    }
  }

  pub resource Minter: TiblesProducer.IMinter {
    pub let id: String
    pub var lastMintNumber: UInt32
    access(contract) let tibles: @{UInt32: AnyResource{TiblesNFT.INFT}}
    pub let limit: UInt32?
    pub let contentCapability: Capability

    pub fun withdraw(mintNumber: UInt32): @AnyResource{TiblesNFT.INFT} {
      pre {
        self.tibles[mintNumber] != nil: "The tible does not exist in this minter."
      }
      return <- self.tibles.remove(key: mintNumber)!
    }

    pub fun mintNext() {
      if let limit = self.limit {
        if self.lastMintNumber >= limit {
          panic("You've hit the limit for number of tokens in this minter!")
        }
      }

      let id = Seussibles.totalSupply + 1
      let mintNumber = self.lastMintNumber + 1
      let tible <- create NFT(id: id, mintNumber: mintNumber, contentCapability: self.contentCapability, contentId: self.id)
      self.tibles[mintNumber] <-! tible
      self.lastMintNumber = mintNumber
      Seussibles.totalSupply = id

      emit TibleMinted(minterId: self.id, mintNumber: mintNumber, id: id)
    }

    init(id: String, limit: UInt32?, contentCapability: Capability) {
      self.id = id
      self.lastMintNumber = 0
      self.tibles <- {}
      self.limit = limit
      self.contentCapability = contentCapability
    }

    destroy() {
      destroy self.tibles
    }
  }

  pub resource PackMinter: TiblesProducer.IContent{
      pub let id: String
      pub var lastMintNumber: UInt32
      access(contract) let packs: @{UInt64: AnyResource{TiblesNFT.INFT}}
      access(contract) let contentIdsToPaths: {String: TiblesProducer.ContentLocation}
      pub let contentCapability: Capability

      pub fun getMetadata(contentId: String): {String: AnyStruct}? {
        return {
          "pack": "Seussibles"
        }
      }

      pub fun withdraw(id: UInt64): @AnyResource{TiblesNFT.INFT} {
        pre {
          self.packs[id] != nil: "The pack does not exist in this minter."
        }
        return <- self.packs.remove(key: id)!
      }

      pub fun mintNext(printedPackId: String) {
        let id = Seussibles.totalSupply + 1
        let mintNumber = self.lastMintNumber + 1
        let pack <- create NFT(id: id, mintNumber: mintNumber, contentCapability: self.contentCapability, contentId: self.id)
        self.packs[id] <-! pack
        self.lastMintNumber = mintNumber
        Seussibles.totalSupply = id
        emit PackMinted(id: id, printedPackId: printedPackId)
      }

      init(id: String, contentCapability: Capability) {
        self.id = id
        self.lastMintNumber = 0
        self.packs <- {}
        self.contentCapability = contentCapability
        self.contentIdsToPaths = {}
        emit PackMinterCreated(minterId: self.id)
      }

      destroy() {
        destroy self.packs
      }
    }

    pub fun createNewPackMinter(id: String, contentCapability: Capability, acctAddress: Address): @PackMinter {
      assert(self.account.address == acctAddress, message: "wrong address")
      return <- create PackMinter(id: id, contentCapability: contentCapability)
    }

  init() {
    self.totalSupply = 0

    self.appId = "com.tibles.seussibles"
    self.title = "Seussibles"
    self.description = "Dr. Seuss officially licensed digital collectibles"

    self.ProducerStoragePath = /storage/TiblesSeussiblesProducer
    self.ProducerPath = /private/TiblesSeussiblesProducer
    self.ContentPath = /public/TiblesSeussiblesContent
    self.CollectionStoragePath = /storage/TiblesSeussiblesCollection
    self.PublicCollectionPath = /public/TiblesSeussiblesCollection

    let producer <- create Producer()
    self.account.save<@Producer>(<-producer, to: self.ProducerStoragePath)
    self.account.link<&Producer>(self.ProducerPath, target: self.ProducerStoragePath)

    self.account.link<&{TiblesProducer.IContent}>(self.ContentPath, target: self.ProducerStoragePath)
    self.contentCapability = self.account.getCapability(self.ContentPath)

    emit ContractInitialized()
  }
}
