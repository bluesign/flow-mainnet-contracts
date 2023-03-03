 // SPDX-License-Identifier: MIT
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract KlktnVoucher: NonFungibleToken {

  pub event ContractInitialized()
  pub event VoucherTemplateCreated(templateID: UInt64)
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event Mint(id: UInt64, templateID: UInt64, serialNumber: UInt64)
  
  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
  pub let AdminStoragePath: StoragePath

  pub var totalSupply: UInt64
  pub var nextTemplateID: UInt64

  access(self) var KlktnVoucherTemplates: {UInt64: KlktnVoucherTemplate}

  pub resource interface KlktnVoucherCollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    pub fun borrowKlktnVoucher(id: UInt64): &KlktnVoucher.NFT? {
      post {
        (result == nil) || (result?.id == id):
          "Cannot borrow KlktnVoucher reference: The ID of the returned reference is incorrect"
      }
    }
  }

  pub struct KlktnVoucherTemplate {
    pub let templateID: UInt64
    pub var description: String
    pub var uri: String
    pub var mintLimit: UInt64
    pub var nextSerialNumber: UInt64

    pub fun updateUri(uri: String) {
      self.uri = uri
    }

    pub fun incrementNextSerialNumber() {
      self.nextSerialNumber = self.nextSerialNumber + UInt64(1)
    }

    init(templateID: UInt64, description: String, uri: String, mintLimit: UInt64){
      self.templateID = templateID
      self.description= description
      self.uri = uri
      self.mintLimit = mintLimit
      self.nextSerialNumber = 1

      KlktnVoucher.nextTemplateID = KlktnVoucher.nextTemplateID + 1

      emit VoucherTemplateCreated(templateID: self.templateID)
    }
  }

  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64
    pub let templateID: UInt64
    pub let serialNumber: UInt64
    
    pub fun getViews(): [Type] {
      return [
        Type<MetadataViews.Display>(),
        Type<MetadataViews.NFTCollectionData>(),
        Type<MetadataViews.NFTCollectionDisplay>(),
        Type<MetadataViews.ExternalURL>(),
        Type<MetadataViews.Royalties>()
      ]
    }

     pub fun resolveView(_ view: Type): AnyStruct? {
      switch view {
        case Type<MetadataViews.Display>():
          return MetadataViews.Display(
            name: "Klktn Voucher",
            description: self.getTemplate().description,
            thumbnail: MetadataViews.HTTPFile(
              url: self.getTemplate().uri
            )
          )

        case Type<MetadataViews.ExternalURL>():
          return MetadataViews.ExternalURL(
            url: "http://www.mangakollektion.xyz/"
          )

        case Type<MetadataViews.NFTCollectionData>():
          return MetadataViews.NFTCollectionData(
            storagePath: KlktnVoucher.CollectionStoragePath,
            publicPath: KlktnVoucher.CollectionPublicPath,
            providerPath: /private/KlktnVoucherPrivateProvider,
            publicCollection: Type<&KlktnVoucher.Collection{NonFungibleToken.CollectionPublic}>(),
            publicLinkedType: Type<&KlktnVoucher.Collection{NonFungibleToken.CollectionPublic, KlktnVoucher.KlktnVoucherCollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
            providerLinkedType: Type<&KlktnVoucher.Collection{NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
            createEmptyCollection: (fun (): @NonFungibleToken.Collection {
              return <-KlktnVoucher.createEmptyCollection()
            }),
          )

        case Type<MetadataViews.NFTCollectionDisplay>():
          let media = MetadataViews.Media(
            file: MetadataViews.HTTPFile(
              url: ""
            ),
            mediaType: "image/png"
          )
          return MetadataViews.NFTCollectionDisplay(
            name: "KlktnVoucher",
            description: "Building the largest community of manga and anime fans through a new web3 powered collectible brand.",
            externalURL: MetadataViews.ExternalURL("http://www.mangakollektion.xyz/"),
            squareImage: media,
            bannerImage: media,
            socials: {
              "twitter": MetadataViews.ExternalURL("https://twitter.com/MangaKollektion")
            }
          )

        case Type<MetadataViews.Royalties>():
          return MetadataViews.Royalties(cutInfos: [])
      }

      return nil
    }

    pub fun getTemplate(): KlktnVoucherTemplate {
      return KlktnVoucher.KlktnVoucherTemplates[self.templateID]!
    }

    init(initID: UInt64, initTemplateID: UInt64, serialNumber: UInt64) {
      self.id = initID
      self.templateID = initTemplateID
      self.serialNumber = serialNumber
    }
  }

  pub resource Collection: KlktnVoucherCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")
      emit Withdraw(id: token.id, from: self.owner?.address)
      return <-token
    }

    pub fun deposit(token: @NonFungibleToken.NFT) {
      let token <- token as! @KlktnVoucher.NFT
      let id: UInt64 = token.id
      let oldToken <- self.ownedNFTs[id] <- token
      emit Deposit(id: id, to: self.owner?.address)
      destroy oldToken
    }

    pub fun batchDeposit(collection: @Collection) {
      let keys = collection.getIDs()
      for key in keys {
        self.deposit(token: <-collection.withdraw(withdrawID: key))
      }
      destroy collection
    }

    pub fun getIDs(): [UInt64] {
      return self.ownedNFTs.keys
    }

    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
      return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
    }

    pub fun borrowKlktnVoucher(id: UInt64): &KlktnVoucher.NFT? {
      if self.ownedNFTs[id] != nil {
        let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
        return ref as! &KlktnVoucher.NFT
      } else {
        return nil
      }
    }

    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
      let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
      let exampleNFT = nft as! &KlktnVoucher.NFT
      return exampleNFT as &AnyResource{MetadataViews.Resolver}
    }

    destroy() {
      destroy self.ownedNFTs
    }

    init () {
      self.ownedNFTs <- {}
    }
  }
  
  pub fun createEmptyCollection(): @NonFungibleToken.Collection {
    return <- create Collection()
  }

  pub resource Admin {

    pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, templateID: UInt64) {
      pre {
        KlktnVoucher.KlktnVoucherTemplates[templateID] != nil: "Template does not exist"
        KlktnVoucher.KlktnVoucherTemplates[templateID]!.mintLimit >= KlktnVoucher.KlktnVoucherTemplates[templateID]!.nextSerialNumber: "Mint limit reached"
      }

      let KlktnVoucherTemplate = KlktnVoucher.KlktnVoucherTemplates[templateID]!

      let newNFT <- create KlktnVoucher.NFT(
        initID: KlktnVoucher.totalSupply,
        initTemplateID: templateID,
        serialNumber: KlktnVoucherTemplate.nextSerialNumber
      )

      emit Mint(id: newNFT.id, templateID: templateID, serialNumber: newNFT.serialNumber)
      recipient.deposit(token: <-newNFT)

      // Increment total supply & nextSerialNumber
      KlktnVoucher.totalSupply = KlktnVoucher.totalSupply + 1
      KlktnVoucher.KlktnVoucherTemplates[templateID]!.incrementNextSerialNumber()
    }

    pub fun createKlktnVoucherTemplate(description: String, uri: String, mintLimit: UInt64) {
      KlktnVoucher.KlktnVoucherTemplates[KlktnVoucher.nextTemplateID] = KlktnVoucherTemplate(
        templateID:KlktnVoucher.nextTemplateID,
        description: description,
        uri: uri,
        mintLimit: mintLimit
      )
    }

    pub fun updateKlktnVoucherUri(templateID: UInt64, uri: String) {
      pre {
        KlktnVoucher.KlktnVoucherTemplates.containsKey(templateID) != nil:
          "Template does not exits."
      }
      KlktnVoucher.KlktnVoucherTemplates[templateID]!.updateUri(uri: uri)
    }
  }

  pub fun getKlktnVoucherTemplateByID(templateID: UInt64): KlktnVoucher.KlktnVoucherTemplate {
    return KlktnVoucher.KlktnVoucherTemplates[templateID]!
  }

  pub fun getKlktnVoucherTemplates(): {UInt64: KlktnVoucher.KlktnVoucherTemplate} {
    return KlktnVoucher.KlktnVoucherTemplates
  }

  init() {
    self.CollectionStoragePath = /storage/KlktnVoucherCollection
    self.CollectionPublicPath = /public/KlktnVoucherCollection
    self.AdminStoragePath = /storage/KlktnVoucherAdmin

    self.totalSupply = 1
    self.nextTemplateID = 1
    self.KlktnVoucherTemplates = {}

    let admin <- create Admin()
    self.account.save(<-admin, to: self.AdminStoragePath)

    emit ContractInitialized()
  }
}
 