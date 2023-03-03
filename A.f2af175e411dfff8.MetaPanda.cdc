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
import AnchainUtils from 0x7ba45bdcac17806a

// MetaPanda
// NFT items for MetaPanda!
//
pub contract MetaPanda: NonFungibleToken {
  pub var totalSupply: UInt64

  pub event ContractInitialized()
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event Minted(id: UInt64, metadata: Metadata)
  pub event Burned(id: UInt64, address: Address?)

  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
  pub let MinterStoragePath: StoragePath

  pub struct Metadata {
    pub let clothesAccessories: String?
    pub let facialAccessories: String?
    pub let facialExpression: String?
    pub let headAccessories: String?
    pub let handAccessories: String?
    pub let clothesBody: String?
    pub let background: String?
    pub let foreground: String?
    pub let basePanda: String?
    init(
      clothesAccessories: String?,
      facialAccessories: String?,
      facialExpression: String?,
      headAccessories: String?,
      handAccessories: String?,
      clothesBody: String?,
      background: String?,
      foreground: String?,
      basePanda: String?
    ) {
      self.clothesAccessories = clothesAccessories
      self.facialAccessories = facialAccessories
      self.facialExpression = facialExpression
      self.headAccessories = headAccessories
      self.handAccessories = handAccessories
      self.clothesBody = clothesBody
      self.background = background
      self.foreground = foreground
      self.basePanda = basePanda
    }
  }

  pub struct MetaPandaView {
    pub let uuid: UInt64
    pub let id: UInt64
    pub let metadata: Metadata
    pub let file: AnchainUtils.File
    init(
      uuid: UInt64,
      id: UInt64,
      metadata: Metadata,
      file: AnchainUtils.File
    ) {
      self.uuid = uuid
      self.id = id
      self.metadata = metadata
      self.file = file
    }
  }

  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64
    pub let metadata: Metadata
    pub let file: AnchainUtils.File
    
    init(
      metadata: Metadata, 
      file: AnchainUtils.File
    ) {
      self.id = MetaPanda.totalSupply
      self.metadata = metadata
      self.file = file

      emit Minted(
        id: MetaPanda.totalSupply, 
        metadata: metadata
      )

      MetaPanda.totalSupply = MetaPanda.totalSupply + 1
    }

    pub fun getViews(): [Type] {
      return [
        Type<MetadataViews.Display>(),
        Type<MetaPandaView>(),
        Type<AnchainUtils.File>(),
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
          let file = self.file.thumbnail as! MetadataViews.IPFSFile
          return MetadataViews.Display(
            name: "Meta Panda Club NFT",
            description: "Meta Panda Club NFT #".concat(self.id.toString()),
            thumbnail: MetadataViews.HTTPFile(
              url: "https://ipfs.tenzingai.com/ipfs/".concat(file.cid)
            )
          )
        
        case Type<MetaPandaView>():
          return MetaPandaView(
            uuid: self.uuid,
            id: self.id,
            metadata: self.metadata,
            file: self.file
          )
        
        case Type<AnchainUtils.File>():
          return self.file

        case Type<MetadataViews.Editions>():
          // There is no max number of NFTs that can be minted from this contract
          // so the max edition field value is set to nil
          return MetadataViews.Editions([
            MetadataViews.Edition(
              name: "Meta Panda NFT Edition", 
              number: self.id, 
              max: nil
            )
          ])

        case Type<MetadataViews.Serial>():
          return MetadataViews.Serial(self.id)

        case Type<MetadataViews.Royalties>():
          return MetadataViews.Royalties([])

        case Type<MetadataViews.ExternalURL>():
          return MetadataViews.ExternalURL("https://s3.us-west-2.amazonaws.com/nft.pandas/".concat(self.id.toString()).concat(".png"))

        case Type<MetadataViews.NFTCollectionData>():
          return MetadataViews.NFTCollectionData(
            storagePath: MetaPanda.CollectionStoragePath,
            publicPath: MetaPanda.CollectionPublicPath,
            providerPath: /private/MetaPandaCollection,
            publicCollection: Type<&MetaPanda.Collection{AnchainUtils.ResolverCollection,NonFungibleToken.CollectionPublic,MetadataViews.ResolverCollection}>(),
            publicLinkedType: Type<&MetaPanda.Collection{AnchainUtils.ResolverCollection,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
            providerLinkedType: Type<&MetaPanda.Collection{AnchainUtils.ResolverCollection,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
            createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                return <-MetaPanda.createEmptyCollection()
            })
          )

        case Type<MetadataViews.NFTCollectionDisplay>():
          let media = MetadataViews.Media(
            file: MetadataViews.HTTPFile(url: "https://s3.us-west-2.amazonaws.com/nft.pandas/logo.png"),
            mediaType: "image/png"
          )
          return MetadataViews.NFTCollectionDisplay(
            name: "The Meta Panda NFT Collection",
            description: "",
            externalURL: MetadataViews.ExternalURL("https://metapandaclub.com/"),
            squareImage: media,
            bannerImage: media,
            socials: {}
          )

        case Type<MetadataViews.Traits>():
          return MetadataViews.Traits([
            MetadataViews.Trait(name: "Clothes Accessories", value: self.metadata.clothesAccessories, displayType: "String", rarity: nil),
            MetadataViews.Trait(name: "Facial Accessories", value: self.metadata.facialAccessories, displayType: "String", rarity: nil),
            MetadataViews.Trait(name: "Facial Expression", value: self.metadata.facialExpression, displayType: "String", rarity: nil),
            MetadataViews.Trait(name: "Head Accessories", value: self.metadata.headAccessories, displayType: "String", rarity: nil),
            MetadataViews.Trait(name: "Hand Accessories", value: self.metadata.handAccessories, displayType: "String", rarity: nil),
            MetadataViews.Trait(name: "Clothes Body", value: self.metadata.clothesBody, displayType: "String", rarity: nil),
            MetadataViews.Trait(name: "Background", value: self.metadata.background, displayType: "String", rarity: nil),
            MetadataViews.Trait(name: "Foreground", value: self.metadata.foreground, displayType: "String", rarity: nil),
            MetadataViews.Trait(name: "Base Panda", value: self.metadata.basePanda, displayType: "String", rarity: nil)
          ])
      }
      return nil
    }

    destroy() {
      emit Burned(id: self.id, address: self.owner?.address)
    }

  }

  // Collection
  // A collection of MetaPanda NFTs owned by an account
  //
  pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection, AnchainUtils.ResolverCollection {
    // dictionary of NFT conforming tokens
    // NFT is a resource type with an `UInt64` ID field
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    init () {
      self.ownedNFTs <- {}
    }

    // withdraw removes an NFT from the collection and moves it to the caller
    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

      emit Withdraw(id: token.id, from: self.owner?.address)

      return <-token
    }

    // deposit takes a NFT and adds it to the collections dictionary
    // and adds the ID to the id array
    pub fun deposit(token: @NonFungibleToken.NFT) {
      let token <- token as! @MetaPanda.NFT

      let id: UInt64 = token.id

      // add the new token to the dictionary which removes the old one
      let oldToken <- self.ownedNFTs[id] <- token

      emit Deposit(id: id, to: self.owner?.address)

      destroy oldToken
    }

    // burn destroys an NFT
    pub fun burn(id: UInt64) {
      post {
        self.ownedNFTs[id] == nil: "The specified NFT was not burned"
      }

      // This will emit a burn event
      destroy <- self.withdraw(withdrawID: id)
    }

    // getIDs returns an array of the IDs that are in the collection
    pub fun getIDs(): [UInt64] {
      return self.ownedNFTs.keys
    }

    // borrowNFT gets a reference to an NFT in the collection
    // so that the caller can read its metadata and call its methods
    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
      if let nft = &self.ownedNFTs[id] as &NonFungibleToken.NFT? {
        return nft
      }
      panic("NFT not found in collection.")
    }

    pub fun borrowViewResolverSafe(id: UInt64): &AnyResource{MetadataViews.Resolver}? {
      if let nft = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT? {
        return nft as! &MetaPanda.NFT
      }
      return nil
    }

    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
      if let nft = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT? {
        return nft as! &MetaPanda.NFT
      }
      panic("NFT not found in collection.")
    }

    destroy() {
      destroy self.ownedNFTs
    }
  }

  // public function that anyone can call to create a new empty collection
  pub fun createEmptyCollection(): @NonFungibleToken.Collection {
    return <- create Collection()
  }

  // Resource that an admin or something similar would own to be
  // able to mint new NFTs
  //
	pub resource NFTMinter {
    // mintNFT mints a new NFT with a new ID
    // and deposit it in the recipients collection using their collection reference
		pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, metadata: Metadata, file: AnchainUtils.File) {
      // create a new NFT
      let newNFT <- create MetaPanda.NFT(
        metadata: metadata, 
        file: file
      )

      // deposit it in the recipient's account using their reference
			recipient.deposit(token: <-newNFT)
		}
	}

	init() {
    // Initialize the total supply
    self.totalSupply = 0

    // Set the named paths
    self.CollectionStoragePath = /storage/MetaPandaCollection
    self.CollectionPublicPath = /public/MetaPandaCollection
    self.MinterStoragePath = /storage/MetaPandaMinter

    // Create a Minter resource and save it to storage
    let minter <- create NFTMinter()
    self.account.save(<-minter, to: self.MinterStoragePath)

    emit ContractInitialized()
	}
}