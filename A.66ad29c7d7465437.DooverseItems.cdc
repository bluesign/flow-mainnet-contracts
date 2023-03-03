/**
  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
**/
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract DooverseItems: NonFungibleToken {
  pub event ContractInitialized()
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event Transfer(id: UInt64, mintedCardID: String?, from: Address?, to: Address?)
  pub event Minted(id: UInt64, initMeta: {String: String})
  pub event Burned(id: UInt64, address: Address?)

  // Deprecated:
  pub event TrxMeta(trxMeta: {String: String})

  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
  pub let MinterStoragePath: StoragePath

  pub var totalSupply: UInt64

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
            name: "Dooverse NFT",
            description: "Dooverse NFT #".concat(self.id.toString()),
            thumbnail: MetadataViews.HTTPFile(url: "https://ipfs.tenzingai.com/ipfs/QmbGZ97JuwLdqeew4HMG8HhQ5Vt5DMRU7pfe2SbTxMvm5S")
          )

        case Type<MetadataViews.Editions>():
          // There is no max number of NFTs that can be minted from this contract
          // so the max edition field value is set to nil
          return MetadataViews.Editions([
            MetadataViews.Edition(
              name: "Dooverse NFT Edition", 
              number: self.id, 
              max: nil
            )
          ])

        case Type<MetadataViews.Serial>():
          return MetadataViews.Serial(self.id)

        case Type<MetadataViews.Royalties>():
          return MetadataViews.Royalties([])

        case Type<MetadataViews.ExternalURL>():
          return MetadataViews.ExternalURL("https://dooverse.io/store")

        case Type<MetadataViews.NFTCollectionData>():
          return MetadataViews.NFTCollectionData(
            storagePath: DooverseItems.CollectionStoragePath,
            publicPath: DooverseItems.CollectionPublicPath,
            providerPath: /private/DooverseItemsCollection,
            publicCollection: Type<&DooverseItems.Collection{DooverseItems.DooverseItemsCollectionPublic,NonFungibleToken.CollectionPublic,MetadataViews.ResolverCollection}>(),
            publicLinkedType: Type<&DooverseItems.Collection{DooverseItems.DooverseItemsCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
            providerLinkedType: Type<&DooverseItems.Collection{DooverseItems.DooverseItemsCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
            createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
              return <-DooverseItems.createEmptyCollection()
            })
          )

        case Type<MetadataViews.NFTCollectionDisplay>():
          let media = MetadataViews.Media(
            file: MetadataViews.HTTPFile(url: "https://ipfs.tenzingai.com/ipfs/QmbGZ97JuwLdqeew4HMG8HhQ5Vt5DMRU7pfe2SbTxMvm5S"),
            mediaType: "image/png"
          )
          return MetadataViews.NFTCollectionDisplay(
            name: "The Dooverse NFT Collection",
            description: "",
            externalURL: MetadataViews.ExternalURL("https://dooverse.io/store"),
            squareImage: media,
            bannerImage: media,
            socials: {}
          )

        case Type<MetadataViews.Traits>():
          return MetadataViews.dictToTraits(dict: self.metadata, excludedNames: [])
      }
      return nil
    }

    destroy() {
      emit Burned(id: self.id, address: self.owner?.address)
    }
  }

  pub resource interface DooverseItemsCollectionPublic {
    pub fun deposit(token: @NonFungibleToken.NFT)
    pub fun getIDs(): [UInt64]
    pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver}
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
    pub fun borrowDooverseItem(id: UInt64): &DooverseItems.NFT? {
      // If the result isn't nil, the id of the returned reference
      // should be the same as the argument to the function
      post {
        (result == nil) || (result?.id == id):
          "Cannot borrow DooverseItem reference: The ID of the returned reference is incorrect"
      }
    }
  }

  pub resource Collection: DooverseItemsCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

      emit Withdraw(id: token.id, from: self.owner?.address)

      return <-token
    }

    pub fun deposit(token: @NonFungibleToken.NFT) {
      let token <- token as! @DooverseItems.NFT

      let id: UInt64 = token.id

      // add the new token to the dictionary which removes the old one
      let oldToken <- self.ownedNFTs[id] <- token

      emit Deposit(id: id, to: self.owner?.address)

      destroy oldToken
    }

    pub fun transfer(id: UInt64, recipient: &{NonFungibleToken.CollectionPublic}) {
      post {
        self.ownedNFTs[id] == nil: "The specified NFT was not transferred"
      }

      let nft = self.borrowDooverseItem(id: id)
      if nft == nil {
        panic("NFT with ID ".concat(id.toString()).concat(" does not exist in collection"))
      } 

      emit Transfer(
        id: id, 
        mintedCardID: nft!.getMetadata()["mintedCardId"],
        from: self.owner?.address, 
        to: recipient.owner?.address
      )
      
      recipient.deposit(token: <- self.withdraw(withdrawID: id))
    }    

    pub fun getIDs(): [UInt64] {
      return self.ownedNFTs.keys
    }

    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
      if let nft = &self.ownedNFTs[id] as &NonFungibleToken.NFT? {
        return nft
      }
      panic("NFT not found in collection.")
    }

    pub fun borrowDooverseItem(id: UInt64): &DooverseItems.NFT? {
      if let nft = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT? {
        return nft as! &DooverseItems.NFT
      }
      return nil
    }

    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
      if let nft = self.borrowDooverseItem(id: id) {
        return nft
      }
      panic("NFT not found in collection.")
    }

    destroy() {
      destroy self.ownedNFTs
    }

    init() {
      self.ownedNFTs <- {}
    }
  }

  pub fun createEmptyCollection(): @NonFungibleToken.Collection {
    return <- create Collection()
  }

	pub resource NFTMinter {
    pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, initMetadata: {String: String}) {
      emit Minted(id: DooverseItems.totalSupply, initMeta: initMetadata)

      // deposit it in the recipient's account using their reference
      recipient.deposit(token: <-create DooverseItems.NFT(initID: DooverseItems.totalSupply, initMeta: initMetadata))

      DooverseItems.totalSupply = DooverseItems.totalSupply + 1
    }
	}

  // fetch
  // Get a reference to a DooverseItem from an account's Collection, if available.
  // If an account does not have a DooverseItems.Collection, panic.
  // If it has a collection but does not contain the itemID, return nil.
  // If it has a collection and that collection contains the itemID, return a reference to that.
  //
  pub fun fetch(_ from: Address, itemID: UInt64): &DooverseItems.NFT? {
    let collection = getAccount(from)
      .getCapability(DooverseItems.CollectionPublicPath)
      .borrow<&DooverseItems.Collection{DooverseItems.DooverseItemsCollectionPublic}>()
      ?? panic("Couldn't get collection")

    // We trust DooverseItems.Collection.borowDooverseItem to get the correct itemID
    // (it checks it before returning it).
    return collection.borrowDooverseItem(id: itemID)
  }

	init() {
    self.CollectionStoragePath = /storage/DooverseItemsCollection
    self.CollectionPublicPath = /public/DooverseItemsCollection
    self.MinterStoragePath = /storage/DooverseItemsMinter

    self.totalSupply = 0

    let minter <- create NFTMinter()
    self.account.save(<-minter, to: self.MinterStoragePath)

    emit ContractInitialized()
	}
}
 