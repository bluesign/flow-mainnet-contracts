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
import FungibleToken from 0xf233dcee88fe0abe

pub contract Asoba: NonFungibleToken {
  pub var totalSupply: UInt64

  pub event ContractInitialized()
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event Minted(id: UInt64, file: MetadataViews.IPFSFile, metadata: {String:String})
  pub event Burned(id: UInt64, address: Address?)

  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
  pub let MinterStoragePath: StoragePath

  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64
    pub let file: MetadataViews.IPFSFile
    access(self) let royalties: [MetadataViews.Royalty]
    access(self) let metadata: {String:String}

    init(
      file: MetadataViews.IPFSFile,
      royalties: [MetadataViews.Royalty],
      metadata: {String:String}
    ) {
      self.id = Asoba.totalSupply
      self.file = file
      self.royalties = royalties
      self.metadata = metadata

      emit Minted(
        id: self.id,
        file: self.file,
        metadata: self.metadata
      )

      Asoba.totalSupply = Asoba.totalSupply + 1
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
            name: "Asoba NFT",
            description: "Asoba NFT #".concat(self.id.toString()),
            thumbnail: MetadataViews.HTTPFile(
              url: "https://ipfs.tenzingai.com/ipfs/".concat(self.file.cid)
            )
          )

        case Type<MetadataViews.Editions>():
          // There is no max number of NFTs that can be minted from this contract
          // so the max edition field value is set to nil
          return MetadataViews.Editions([
            MetadataViews.Edition(
              name: "Asoba NFT Edition", 
              number: self.id, 
              max: nil
            )
          ])

        case Type<MetadataViews.Serial>():
          return MetadataViews.Serial(self.id)

        case Type<MetadataViews.Royalties>():
          let receivers: {Address:UFix64} = {
            0x5e68a4af8dc85f62: 0.025, 
            0x9eafd89fa6abb1d3: 0.005
          }

          let royalties: [MetadataViews.Royalty] = []
          for address in receivers.keys {
            let receiver = getAccount(address)
              .getCapability<&{FungibleToken.Receiver}>(
                MetadataViews.getRoyaltyReceiverPublicPath()
              )
            if receiver.check() {
              royalties.append(
                MetadataViews.Royalty(
                  receiver: receiver, 
                  cut: receivers[address]!, 
                  description: ""
                )
              )
            }
          }

          return MetadataViews.Royalties(royalties)

        case Type<MetadataViews.ExternalURL>():
          return MetadataViews.ExternalURL("https://ipfs.tenzingai.com/ipfs/".concat(self.file.cid))

        case Type<MetadataViews.NFTCollectionData>():
          return MetadataViews.NFTCollectionData(
            storagePath: Asoba.CollectionStoragePath,
            publicPath: Asoba.CollectionPublicPath,
            providerPath: /private/AsobaCollection,
            publicCollection: Type<&Asoba.Collection{NonFungibleToken.CollectionPublic,MetadataViews.ResolverCollection}>(),
            publicLinkedType: Type<&Asoba.Collection{NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
            providerLinkedType: Type<&Asoba.Collection{NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
            createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {
                return <-Asoba.createEmptyCollection()
            })
          )

        case Type<MetadataViews.NFTCollectionDisplay>():
          let media = MetadataViews.Media(
            file: MetadataViews.HTTPFile(url: "https://ipfs.tenzingai.com/ipfs/QmQe8cNrCLYALnMz91Atyzzoa81iofH9gmUJmh42ypLkPn"),
            mediaType: "image/png"
          )
          return MetadataViews.NFTCollectionDisplay(
            name: "The Asoba NFT Collection",
            description: "",
            externalURL: MetadataViews.ExternalURL("https://app.asoba.finance/"),
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

  pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
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
      let token <- token as! @Asoba.NFT

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

    pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
      if let nft = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT? {
        return nft as! &Asoba.NFT
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
    // transformMetadata ensures that the NFT metadata follows a particular
    // schema. At the moment, it is much more convenient to use functions
    // rather than structs to enforce a metadata schema because functions 
    // are much more flexible, easier to maintain, and safer to update.
    access(self) fun transformMetadata(_ metadata: {String:String}): {String:String} {
      pre {
        metadata.containsKey("name")
        && metadata.containsKey("background")
        && metadata.containsKey("accessory_1")
        && metadata.containsKey("accessory_2")
        && metadata.containsKey("tier")
        : "Metadata does not conform to schema"
      }
      return {
        "name": metadata["name"]!,
        "background": metadata["background"]!,
        "accessory_1": metadata["accessory_1"]!,
        "accessory_2": metadata["accessory_2"]!,
        "tier": metadata["tier"]!
      }
    }

    // mintNFT mints a new NFT with a new ID
    // and deposit it in the recipients collection using their collection reference
    pub fun mintNFT(
      recipient: &{NonFungibleToken.CollectionPublic},
      file: MetadataViews.IPFSFile,
      royalties: [MetadataViews.Royalty],
      metadata: {String:String},
    ) {
      // create a new NFT
      let newNFT <- create NFT(
        file: file,
        royalties: royalties,
        metadata: self.transformMetadata(metadata)
      )

      // deposit it in the recipient's account using their reference
      recipient.deposit(token: <-newNFT)
    }
  }

  init() {
    // Initialize the total supply
    self.totalSupply = 0

    // Set the named paths
    self.CollectionStoragePath = /storage/AsobaCollection
    self.CollectionPublicPath = /public/AsobaCollection
    self.MinterStoragePath = /storage/AsobaMinter

    // Create a Collection resource and save it to storage
    let collection <- create Collection()
    self.account.save(<-collection, to: self.CollectionStoragePath)

    // create a public capability for the collection
    self.account.link<&Asoba.Collection{NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(
      self.CollectionPublicPath, 
      target: self.CollectionStoragePath
    )

    // Create a Minter resource and save it to storage
    let minter <- create NFTMinter()
    self.account.save(<-minter, to: self.MinterStoragePath)

    emit ContractInitialized()
  }
}
 