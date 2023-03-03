import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x6ed5aaee41c93941

pub contract LCubeNFT: NonFungibleToken {

  pub var totalSupply: UInt64

  pub let CollectionStoragePath: StoragePath
  pub let CollectionPublicPath: PublicPath
  pub let MinterStoragePath: StoragePath
  pub let MinterPublicPath: PublicPath

  //Events
  pub event ContractInitialized()
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event Mint(id: UInt64, creator: Address, ipfsHash: String, name:String, description:String,nftType:String,nftTypeDescription: String,contentType: String,power:UFix64,rarity:UFix64)
  pub event Destroy(id: UInt64)

  pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver {
    pub let id: UInt64

    pub let creator: Address
    pub let ipfsHash: String
    pub let name: String
    pub let description: String
    pub let nftType: String
    pub let nftTypeDescription: String
    pub let contentType: String
    pub let power: UFix64
    pub let rarity: UFix64

 init(
         creator: Address,
         ipfsHash: String,
         name: String,
         description: String,
         nftType: String,
         nftTypeDescription: String,
         contentType: String,
         power: UFix64,
         rarity: UFix64
    ) {
            self.id = LCubeNFT.totalSupply

            self.creator = creator
            self.ipfsHash = ipfsHash
            self.name = name
            self.description = description
            self.nftType = nftType
            self.nftTypeDescription = nftTypeDescription
            self.contentType = contentType
            self.power = power
            self.rarity = rarity
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
                    id: self.id,
                    ipfsHash: self.ipfsHash,
                    name: self.name,
                    description: self.description,
                    nftType: self.nftType,
                    nftTypeDescription: self.nftTypeDescription,
                    contentType:  self.contentType,
                    power : self.power,
                    rarity : self.rarity
                )
            }

            return nil
    }

   destroy() {
      emit Destroy(id: self.id)
   }

  }


    // This is the interface that users can cast their LCube Collection as
    // to allow others to deposit LCube into their Collection. It also allows for reading
    // the details of LCube in the Collection.
    pub resource interface LCubeCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowLCubeNFT(id: UInt64): &LCubeNFT.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow LCube reference: The ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: LCubeCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
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
            let token <- token as! @LCubeNFT.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            destroy oldToken

            emit Deposit(id: id, to: self.owner?.address)
        }

        // getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowLCubeNFT(id: UInt64): &LCubeNFT.NFT? {
          if self.ownedNFTs[id] != nil {
             let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
             return ref as! &LCubeNFT.NFT
          } else {
               return nil
           }
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let refItem = nft as! &LCubeNFT.NFT
            return refItem as &AnyResource{MetadataViews.Resolver}
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
            creator: Capability<&{NonFungibleToken.Receiver}>,
            recipient: &{NonFungibleToken.CollectionPublic},
            ipfsHash: String,
            name: String,
            description: String,
            nftType: String,
            nftTypeDescription: String,
            contentType: String,
            power: UFix64,
            rarity: UFix64
        ): &NonFungibleToken.NFT {
            // create a new NFT
            var token <- create NFT(
                creator: creator.address,
  ipfsHash: ipfsHash,
                name: name,
                description: description,
                nftType: nftType,
                nftTypeDescription: nftTypeDescription,
                contentType: contentType,
                power: power,
                rarity: rarity
            )

            LCubeNFT.totalSupply = LCubeNFT.totalSupply + 1
            let tokenRef = &token as &NonFungibleToken.NFT
            emit Mint(id: token.id, creator: creator.address,ipfsHash:ipfsHash,name:name,description:description,nftType:nftType,nftTypeDescription:nftTypeDescription,contentType:contentType,power:power,rarity:rarity)
            creator.borrow()!.deposit(token: <- token)
            return tokenRef
        }
    }

    pub fun minter(): Capability<&NFTMinter> {
        return self.account.getCapability<&NFTMinter>(self.MinterPublicPath)
    }

    init() {
        // Initialize the total supply
        self.totalSupply = 0

        // Set the named paths
        self.CollectionStoragePath = /storage/LCubeNFTCollection
        self.CollectionPublicPath = /public/LCubeNFTCollection
        self.MinterPublicPath = /public/LCubeNFTMinter
        self.MinterStoragePath = /storage/LCubeNFTMinter

        // Create a Collection resource and save it to storage
        let collection <- create Collection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // create a public capability for the collection
        self.account.link<&LCubeNFT.Collection{NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, LCubeNFT.LCubeCollectionPublic, MetadataViews.ResolverCollection}>(LCubeNFT.CollectionPublicPath, target: LCubeNFT.CollectionStoragePath)

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<- minter, to: self.MinterStoragePath)
        self.account.link<&NFTMinter>(self.MinterPublicPath, target: self.MinterStoragePath)

        emit ContractInitialized()
    }
}