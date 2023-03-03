import NonFungibleToken from  0x1d7e57aa55817448
import MetadataViews from  0x1d7e57aa55817448
//BlockAnime
// NFT items for Anime!
//
pub contract Blockanime: NonFungibleToken {

    // Events
    //
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, charName: String, animeName : String,thumbnail : String)
    

    // Named Paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    pub let MinterStoragePath: StoragePath



    // totalSupply
    // The total number of Anime Characters that have been minted
    //
    pub var totalSupply: UInt64

    // NFT
    // A Card as an NFT
    //
    pub resource NFT: NonFungibleToken.INFT,MetadataViews.Resolver {

        pub let id: UInt64
    
        pub let charName : String

        pub let animeName : String

        pub let thumbnail : String

        // initializer
        //
        init(initID: UInt64, initCharName: String, initAnimeName : String,initThumbnail : String) {
            self.id = initID
            self.charName = initCharName
            self.animeName= initAnimeName
            self.thumbnail = initThumbnail
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
                        name: self.charName,
                        description: self.animeName,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.thumbnail
                        )
                    )
            }

            return nil
        }

       
    }

    // This is the interface that users can cast their Anime Collection as
    // to allow others to deposit Anime into their Collection. It also allows for reading
    // the details of Anime in the Collection.
    pub resource interface BlockanimeCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun batchDeposit(tokens : @NonFungibleToken.Collection)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowBlockanime(id: UInt64): &Blockanime.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow BlockAnime reference: The ID of the returned reference is incorrect"
            }
        }
    }

    
    // Collection
    // A collection of Anime NFTs owned by an account
    //
    pub resource Collection: BlockanimeCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        //
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        // withdraw
        // Removes an NFT from the collection and moves it to the caller
        //
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        pub fun batchWithdraw(ids: [UInt64]): @NonFungibleToken.Collection {
            // Create a new empty Collection
            var batchCollection <- create Collection()
            
            // Iterate through the ids and withdraw them from the Collection
            for id in ids {
                batchCollection.deposit(token: <-self.withdraw(withdrawID: id))
            }
            
            // Return the withdrawn tokens
            return <-batchCollection
        }



        // deposit
        // Takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        //
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @Blockanime.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }

        // batchDeposit takes a Collection object as an argument
        // and deposits each contained NFT into this Collection

        pub fun batchDeposit(tokens: @NonFungibleToken.Collection) {

            // Get an array of the IDs to be deposited
            let keys = tokens.getIDs()

            // Iterate through the keys in the collection and deposit each one
            for key in keys {
                self.deposit(token: <-tokens.withdraw(withdrawID: key))
            }

            // Destroy the empty Collection
            destroy tokens
        }

        // getIDs
        // Returns an array of the IDs that are in the collection
        //
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

    

        // borrowNFT
        // Gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        //
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        // borrowSportsCard
        // Gets a reference to an NFT in the collection as a BlockAnime,
        // exposing all of its fields (including the typeID).
        // This is safe as there are no functions that can be called on the BlockAnime.
        //
        pub fun borrowBlockanime(id: UInt64): &Blockanime.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &Blockanime.NFT
            } else {
                return nil
            }
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let blockanimeNFT = nft as! &Blockanime.NFT
            return blockanimeNFT as &AnyResource{MetadataViews.Resolver}
        }

        // destructor
        destroy() {
            destroy self.ownedNFTs
        }

        // initializer
        //
        init () {
            self.ownedNFTs <- {}
        }
    }

    // createEmptyCollection
    // public function that anyone can call to create a new empty collection
    //
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

    // NFTMinter aka Admin
    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
    
	pub resource NFTMinter {

       // mintNFT
        // Mints a new NFT with a new ID
		// and deposit it in the recipients collection using their collection reference
        //
		pub fun mintNFT(charName : String, animeName : String,thumbnail : String): @NFT{
            emit Minted(id: Blockanime.totalSupply, charName : charName, animeName : animeName,thumbnail : thumbnail)

            let newNFT : @NFT <-create Blockanime.NFT(initID: Blockanime.totalSupply, initCharName: charName, initAnimeName : animeName,initThumbnail : thumbnail)

            Blockanime.totalSupply = Blockanime.totalSupply + 1

            return <-newNFT
		}

        pub fun batchMint(charName : String,animeName : String,thumbnail :String, quantity : UInt64): @Collection {
            let newCollection <- create Collection()

            var i: UInt64 = 0
            while i < quantity {
                newCollection.deposit(token: <-self.mintNFT(charName : charName,animeName : animeName,thumbnail : thumbnail))
                i = i + 1
            }

            return <-newCollection
        }


	}
    
    

    // initializer
    //
	init() {
        // Set our named paths
        self.CollectionStoragePath = /storage/BlockanimeCollection
        self.CollectionPublicPath = /public/BlockanimeCollection
        
        
        self.MinterStoragePath = /storage/BlockanimeMinter



        // Initialize the total supply
        self.totalSupply = 0 

        // save it to the account
        self.account.save(<-create Collection(), to: self.CollectionStoragePath)
        self.account.link<&Blockanime.Collection{NonFungibleToken.CollectionPublic,Blockanime.BlockanimeCollectionPublic,MetadataViews.ResolverCollection}>(self.CollectionPublicPath ,target : self.CollectionStoragePath)

        // Put the Minter in storage
        self.account.save<@NFTMinter>(<- create NFTMinter(), to: self.MinterStoragePath)
        

        emit ContractInitialized()
	}
}