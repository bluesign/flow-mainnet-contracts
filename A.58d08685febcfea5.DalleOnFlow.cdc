import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import MetadataViews from 0x1d7e57aa55817448
import FlowToken from 0x1654653399040a61

pub contract DalleOnFlow: NonFungibleToken {

  pub var totalSupply: UInt64
  pub var price: UFix64
  pub var mintingEnabled: Bool
    
  pub event ContractInitialized()
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event Minted(id: UInt64, metadata: {String: String})
  pub event CreatedCollection()

  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
  pub let AdminStoragePath: StoragePath

  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64 
    pub let name: String
    pub let description: String
    pub let thumbnailCID: String
    pub var flagged: Bool
    pub var metadata: {String: String}

    init(_description: String, _thumbnailCID: String, _metadata: {String: String}) {
      self.id = DalleOnFlow.totalSupply
      DalleOnFlow.totalSupply = DalleOnFlow.totalSupply + 1

      self.name = "DOF #".concat(self.id.toString())
      self.description = _description
      self.thumbnailCID = _thumbnailCID
      self.flagged = false
      self.metadata = _metadata

      emit Minted(id: self.id, metadata: _metadata)
    }

    access(contract) fun flagNFT() {
      self.flagged = true
    }

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
                  name: self.name,
                  description: self.description,
                  thumbnail: MetadataViews.IPFSFile(cid: self.thumbnailCID, path: ""),
                )
        case Type<MetadataViews.NFTCollectionData>():
          return MetadataViews.NFTCollectionData(
            storagePath: DalleOnFlow.CollectionStoragePath,
            publicPath: DalleOnFlow.CollectionPublicPath,
            providerPath: /private/DalleOnFlowCollection,
            publicCollection: Type<&DalleOnFlow.Collection{DalleOnFlow.CollectionPublic, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(),
            publicLinkedType: Type<&DalleOnFlow.Collection{DalleOnFlow.CollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Receiver, MetadataViews.ResolverCollection}>(),
            providerLinkedType: Type<&DalleOnFlow.Collection{DalleOnFlow.CollectionPublic, NonFungibleToken.CollectionPublic, NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(),
            createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                return <-DalleOnFlow.createEmptyCollection()
            })
          )
        case Type<MetadataViews.NFTCollectionDisplay>():
          let media = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(
                          url: "https://www.dalleonflow.art/logo.webp"
                        ),
                        mediaType: "image/svg+xml",
                      )
          return MetadataViews.NFTCollectionDisplay(
                  name: "DalleOnFlow",
                  description: "DalleOnFlow",
                  externalURL: MetadataViews.ExternalURL("https://www.dalleonflow.art/"),
                  squareImage: media,
                  bannerImage: media,
                  socials: {
                    "twitter": MetadataViews.ExternalURL("https://twitter.com/dalleonflow")
                  }
                )
        case Type<MetadataViews.ExternalURL>():
              return MetadataViews.ExternalURL(
                "https://www.dalleonflow.art/"
              )
        case Type<MetadataViews.Royalties>():
                    let royaltyReceiver = getAccount(0x18deb5b8e5393198).getCapability<&{FungibleToken.Receiver}>(/public/flowTokenReceiver)

                    return MetadataViews.Royalties(
                        [MetadataViews.Royalty(recepient: royaltyReceiver, cut: 0.05, description: "This is the royalty receiver for DalleOnFlow")]
                    )
      }
      return nil
    }
  }

  pub resource interface CollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    pub fun borrowDalleOnFlowNFT(id: UInt64): &DalleOnFlow.NFT
    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver}
  }

  pub resource Collection: NonFungibleToken.Receiver, NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection, CollectionPublic {
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    pub fun deposit(token: @NonFungibleToken.NFT) {
      let myToken <- token as! @DalleOnFlow.NFT
      emit Deposit(id: myToken.id, to: self.owner?.address)
      self.ownedNFTs[myToken.id] <-! myToken
    }

    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("This NFT does not exist")
      emit Withdraw(id: token.id, from: self.owner?.address)
      return <- token
    }

    pub fun getIDs(): [UInt64] {
      return self.ownedNFTs.keys
    }

    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
		  return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
	  }

    pub fun borrowDalleOnFlowNFT(id: UInt64): &DalleOnFlow.NFT {
		  let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
		  return ref as! &DalleOnFlow.NFT
	  }

    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
      let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
      let nft = ref as! &DalleOnFlow.NFT
      return nft as &AnyResource{MetadataViews.Resolver}
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

  pub resource Admin {
    pub fun mintNFT(description: String, thumbnailCID: String, metadata: {String: String}, recepient: Capability<&DalleOnFlow.Collection{DalleOnFlow.CollectionPublic}>, payment: @FlowToken.Vault) {
        pre {
            DalleOnFlow.mintingEnabled == true: "Minting is not enabled"
            DalleOnFlow.totalSupply < 9999: "The maximum number of DalleOnFlow NFTs has been reached"
            payment.balance == 10.24: "Payment does not match the price."
        }

        let dofWallet = getAccount(0x18deb5b8e5393198).getCapability(/public/flowTokenReceiver)
                            .borrow<&FlowToken.Vault{FungibleToken.Receiver}>()!
        dofWallet.deposit(from: <- payment)
            
        let nft <- create NFT(_description: description, _thumbnailCID: thumbnailCID, _metadata: metadata)
            
        let recepientCollection = recepient.borrow()!
        recepientCollection.deposit(token: <- nft)
    }

    pub fun flagNFT(id: UInt64, recepient: Capability<&DalleOnFlow.Collection{DalleOnFlow.CollectionPublic}>): &DalleOnFlow.NFT {
        let nft = recepient.borrow()!.borrowDalleOnFlowNFT(id: id)
        nft.flagNFT()
        return nft
    }

    pub fun changePrice(newPrice: UFix64) {
        DalleOnFlow.price = newPrice
    }

    pub fun changeMintingEnabled(isEnabled: Bool) {
        DalleOnFlow.mintingEnabled = isEnabled
    }
  }

  init() {
    self.totalSupply = 0
    self.price = 10.24
    self.mintingEnabled = false

    self.CollectionStoragePath = /storage/DalleOnFlowCollection
    self.CollectionPublicPath = /public/DalleOnFlowCollection
    self.AdminStoragePath = /storage/DalleOnFlowAdmin

    let admin <- create Admin()
    self.account.save(<-admin, to: self.AdminStoragePath)

    emit ContractInitialized()
  }
}