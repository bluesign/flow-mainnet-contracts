import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import MetadataViews from 0x1d7e57aa55817448

pub contract Geeft: NonFungibleToken {

  pub var totalSupply: UInt64

  // Paths
  pub let CollectionPublicPath: PublicPath
  pub let CollectionStoragePath: StoragePath

  // Standard Events
  pub event ContractInitialized()
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)

  // Geeft Events
  pub event GeeftCreated(id: UInt64, message: String?, from: Address?, to: Address)

  pub struct GeeftInfo {
    pub let id: UInt64
    pub let from: Address?
    pub let message: String?
    pub let nfts: {String: Int}
    pub let tokens: [String]
    pub let extra: {String: AnyStruct}

    init(id: UInt64, from: Address?, message: String?, nfts: {String: Int}, tokens: [String], extra: {String: AnyStruct}) {
      self.id = id
      self.from = from
      self.message = message
      self.nfts = nfts
      self.tokens = tokens
      self.extra = extra
    }
  }

  // This represents a Geeft
  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64
    pub let from: Address?
    pub let message: String?
    // Maps NFT collection type (ex. String<@FLOAT.Collection>()) -> array of NFTs
    pub var storedNFTs: @{String: [NonFungibleToken.NFT]}
    // Maps token type (ex. String<@FlowToken.Vault>()) -> vault
    pub var storedTokens: @{String: FungibleToken.Vault}
    pub let extra: {String: AnyStruct}

    pub fun getGeeftInfo(): GeeftInfo {
      let nfts: {String: Int} = {}
      for nftString in self.storedNFTs.keys {
        nfts[nftString] = self.storedNFTs[nftString]?.length
      }

      let tokens: [String] = self.storedTokens.keys

      return GeeftInfo(id: self.id, from: self.from, message: self.message, nfts: nfts, tokens: tokens, extra: self.extra)
    }

    pub fun openNFTs(): @{String: [NonFungibleToken.NFT]} {
      var storedNFTs: @{String: [NonFungibleToken.NFT]} <- {}
      self.storedNFTs <-> storedNFTs
      return <- storedNFTs
    }

    pub fun openTokens(): @{String: FungibleToken.Vault} {
      var storedTokens: @{String: FungibleToken.Vault} <- {}
      self.storedTokens <-> storedTokens
      return <- storedTokens
    }

    pub fun getViews(): [Type] {
      return [
        Type<MetadataViews.Display>()
      ]
    }

    pub fun resolveView(_ view: Type): AnyStruct? {
      switch view {
        case Type<MetadataViews.Display>():
          return MetadataViews.Display(
            name: "Geeft #".concat(self.id.toString()),
            description: self.message ?? (self.from == nil ? "This is a Geeft." : "This is a Geeft from ".concat(self.from!.toString()).concat(".")),
            thumbnail: MetadataViews.HTTPFile(
              url: "https://i.imgur.com/dZxbOEa.png"
            )
          )
      }
      return nil
    }

    init(from: Address?, message: String?, nfts: @{String: [NonFungibleToken.NFT]}, tokens: @{String: FungibleToken.Vault}, extra: {String: AnyStruct}) {
      self.id = self.uuid
      self.from = from
      self.message = message
      self.storedNFTs <- nfts
      self.storedTokens <- tokens
      self.extra = extra
      Geeft.totalSupply = Geeft.totalSupply + 1
    }

    destroy() {
      pre {
        self.storedNFTs.keys.length == 0: "There are still NFTs left in this Geeft."
        self.storedTokens.length == 0: "There are still tokens left in this Geeft."
      }
      destroy self.storedNFTs
      destroy self.storedTokens
    }
  }

  pub fun sendGeeft(
    from: Address?,
    message: String?, 
    nfts: @{String: [NonFungibleToken.NFT]}, 
    tokens: @{String: FungibleToken.Vault}, 
    extra: {String: AnyStruct}, 
    recipient: Address
  ) {
    let geeft <- create NFT(from: from, message: message, nfts: <- nfts, tokens: <- tokens, extra: extra)
    let collection = getAccount(recipient).getCapability(Geeft.CollectionPublicPath)
                        .borrow<&Collection{NonFungibleToken.Receiver}>()
                        ?? panic("The recipient does not have a Geeft Collection")

    emit GeeftCreated(id: geeft.id, message: message, from: from, to: recipient)
    collection.deposit(token: <- geeft)
  }

  pub resource interface CollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    pub fun getGeeftInfo(geeftId: UInt64): GeeftInfo
  }

  pub resource Collection: CollectionPublic, NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection {
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    pub fun deposit(token: @NonFungibleToken.NFT) {
      let geeft <- token as! @NFT
      emit Deposit(id: geeft.id, to: self.owner?.address)
      self.ownedNFTs[geeft.id] <-! geeft
    }

    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let geeft <- self.ownedNFTs.remove(key: withdrawID) ?? panic("This Geeft does not exist in this collection.")
      emit Withdraw(id: geeft.id, from: self.owner?.address)
      return <- geeft
    }

    pub fun getIDs(): [UInt64] {
      return self.ownedNFTs.keys
    }

    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
      return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
    } 

    pub fun borrowGeeft(id: UInt64): &NFT? {
      if self.ownedNFTs[id] != nil {
        let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
        return ref as! &NFT
      }
      return nil
    }

    pub fun getGeeftInfo(geeftId: UInt64): GeeftInfo {
      let nft = (&self.ownedNFTs[geeftId] as auth &NonFungibleToken.NFT?)!
      let geeft = nft as! &NFT
      return geeft.getGeeftInfo()
    }

    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
      let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
      let geeft = nft as! &NFT
      return geeft as &{MetadataViews.Resolver}
    }

    init() {
      self.ownedNFTs <- {}
    }

    destroy() {
      destroy self.ownedNFTs
    }
  }

  pub fun createEmptyCollection(): @Collection {
    return <- create Collection()
  }

  init() {
    self.CollectionStoragePath = /storage/GeeftCollection
    self.CollectionPublicPath = /public/GeeftCollection

    self.totalSupply = 0

    emit ContractInitialized()
  }

}