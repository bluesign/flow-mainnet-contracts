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

pub contract MetaPandaAirdropNFT: NonFungibleToken {
  access(contract) var collectionBannerURL: String
  access(contract) var websiteURL: String
  access(contract) var nftURL: String
  pub var totalSupply: UInt64

  pub event ContractInitialized()
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event Minted(id: UInt64, nftType: String, metadata: {String:String})
  pub event Transfer(id: UInt64, from: Address?, to: Address?)
  pub event Burned(id: UInt64, address: Address?)

  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
  pub let MinterStoragePath: StoragePath

  pub struct MetaPandaAirdropView {
    pub let uuid: UInt64
    pub let id: UInt64
    pub let nftType: String
    pub let file: AnyStruct{MetadataViews.File}
    access(self) let metadata: {String:String}

    init(
      uuid: UInt64,
      id: UInt64,
      nftType: String,
      metadata: {String:String},
      file: AnyStruct{MetadataViews.File}
    ) {
      self.uuid = uuid
      self.id = id
      self.nftType = nftType
      self.metadata = metadata
      self.file = file
    }

    pub fun getMetadata(): {String:String} {
      return self.metadata
    }
  }

  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64
    pub let nftType: String
    pub let file: AnyStruct{MetadataViews.File}
    access(self) let metadata: {String:String}
    access(self) let royalties: [MetadataViews.Royalty]

    init(
      nftType: String,
      metadata: {String:String},
      file: AnyStruct{MetadataViews.File},
      royalties: [MetadataViews.Royalty]
    ) {
      self.id = MetaPandaAirdropNFT.totalSupply
      self.nftType = nftType
      self.metadata = metadata
      self.file = file
      self.royalties = royalties

      emit Minted(
        id: self.id,
        nftType: self.nftType,
        metadata: self.metadata
      )

      MetaPandaAirdropNFT.totalSupply = MetaPandaAirdropNFT.totalSupply + 1
    }
  
    pub fun getViews(): [Type] {
      return [
        Type<MetaPandaAirdropView>(),
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
        case Type<MetaPandaAirdropView>():
          return MetaPandaAirdropView(
            uuid: self.uuid,
            id: self.id,
            nftType: self.nftType,
            metadata: self.metadata,
            file: self.file
          )

        case Type<MetadataViews.Display>():
          let file = self.file as! MetadataViews.IPFSFile
          return MetadataViews.Display(
            name: self.metadata["name"] ?? "Meta Panda Collectible NFT",
            description: self.metadata["description"] ?? "Meta Panda Collectible NFT #".concat(self.id.toString()),
            thumbnail: MetadataViews.HTTPFile(
              url: "https://ipfs.tenzingai.com/ipfs/".concat(file.cid)
            )
          )

        case Type<MetadataViews.Editions>():
          // There is no max number of NFTs that can be minted from this contract
          // so the max edition field value is set to nil
          return MetadataViews.Editions([
            MetadataViews.Edition(
              name: "Meta Panda Airdrop NFT Edition", 
              number: self.id, 
              max: nil
            )
          ])

        case Type<MetadataViews.Serial>():
          return MetadataViews.Serial(self.id)

        case Type<MetadataViews.Royalties>():
          return MetadataViews.Royalties(self.royalties)

        case Type<MetadataViews.ExternalURL>():
          return MetadataViews.ExternalURL(MetaPandaAirdropNFT.nftURL.concat("/").concat(self.id.toString()))

        case Type<MetadataViews.NFTCollectionData>():
          return MetadataViews.NFTCollectionData(
            storagePath: MetaPandaAirdropNFT.CollectionStoragePath,
            publicPath: MetaPandaAirdropNFT.CollectionPublicPath,
            providerPath: /private/MetaPandaAirdropNFTCollection,
            publicCollection: Type<&MetaPandaAirdropNFT.Collection{AnchainUtils.ResolverCollection,NonFungibleToken.CollectionPublic,MetadataViews.ResolverCollection}>(),
            publicLinkedType: Type<&MetaPandaAirdropNFT.Collection{AnchainUtils.ResolverCollection,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
            providerLinkedType: Type<&MetaPandaAirdropNFT.Collection{AnchainUtils.ResolverCollection,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
            createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
              return <-MetaPandaAirdropNFT.createEmptyCollection()
            })
          )

        case Type<MetadataViews.NFTCollectionDisplay>():
          let media = MetadataViews.Media(
            file: MetadataViews.HTTPFile(url: MetaPandaAirdropNFT.collectionBannerURL),
            mediaType: "image/png"
          )
          return MetadataViews.NFTCollectionDisplay(
            name: "The Meta Panda Airdrop NFT Collection",
            description: "",
            externalURL: MetadataViews.ExternalURL(MetaPandaAirdropNFT.websiteURL),
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

  pub resource Collection: AnchainUtils.ResolverCollection, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
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
      let token <- token as! @MetaPandaAirdropNFT.NFT

      let id: UInt64 = token.id

      // add the new token to the dictionary which removes the old one
      let oldToken <- self.ownedNFTs[id] <- token

      emit Deposit(id: id, to: self.owner?.address)

      destroy oldToken
    }

    // transfer takes an NFT ID and a reference to a recipient's collection
    // and transfers the NFT corresponding to that ID to the recipient
    pub fun transfer(id: UInt64, recipient: &{NonFungibleToken.CollectionPublic}) {
      post {
        self.ownedNFTs[id] == nil: "The specified NFT was not transferred"
        recipient.borrowNFT(id: id) != nil: "Recipient did not receive the intended NFT"
      }

      let nft <- self.withdraw(withdrawID: id)
      
      recipient.deposit(token: <- nft)
      
      emit Transfer(id: id, from: self.owner?.address, to: recipient.owner?.address)
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
        return nft as! &MetaPandaAirdropNFT.NFT
      }
      return nil
    }

    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
      if let nft = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT? {
        return nft as! &MetaPandaAirdropNFT.NFT
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
    pub fun mintNFT(
      recipient: &{NonFungibleToken.CollectionPublic},
      nftType: String,
      metadata: {String:String},
      file: AnyStruct{MetadataViews.File},
      royalties: [MetadataViews.Royalty]
    ) {
      // create a new NFT
      let newNFT <- create NFT(
        nftType: nftType,
        metadata: metadata,
        file: file,
        royalties: royalties
      )

      // deposit it in the recipient's account using their reference
      recipient.deposit(token: <-newNFT)
    }

    pub fun updateURLs(collectionBannerURL: String?, websiteURL: String?, nftURL: String?) {
      if collectionBannerURL != nil {
        MetaPandaAirdropNFT.collectionBannerURL = collectionBannerURL!
      }
      if websiteURL != nil {
        MetaPandaAirdropNFT.websiteURL = websiteURL!
      }
      if nftURL != nil {
        MetaPandaAirdropNFT.nftURL = nftURL!
      }
    }
  }

  init() {
    // Initialize the total supply
    self.totalSupply = 0

    // Set the named paths
    self.CollectionStoragePath = /storage/MetaPandaAirdropNFTCollection
    self.CollectionPublicPath = /public/MetaPandaAirdropNFTCollection
    self.MinterStoragePath = /storage/MetaPandaAirdropNFTMinter

    // External URLs
    self.collectionBannerURL = "http://ipfs.io/ipfs/QmTPNGKfBHJUWXaAjHr2S98QbGeB9LmNSrLfLp6AyjNixf"
    self.websiteURL = "https://metapandaclub.com/"
    self.nftURL = "https://s3.us-west-2.amazonaws.com/nft.pandas"

    // Create a Collection resource and save it to storage
    let collection <- create Collection()
    self.account.save(<-collection, to: self.CollectionStoragePath)

    // create a public capability for the collection
    self.account.link<&MetaPandaAirdropNFT.Collection{AnchainUtils.ResolverCollection,NonFungibleToken.CollectionPublic,MetadataViews.ResolverCollection}>(
      self.CollectionPublicPath, 
      target: self.CollectionStoragePath
    )

    // Create a Minter resource and save it to storage
    let minter <- create NFTMinter()
    self.account.save(<-minter, to: self.MinterStoragePath)

    emit ContractInitialized()
  }
}
 