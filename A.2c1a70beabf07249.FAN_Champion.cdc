// import NonFungibleToken from "./NonFungibleToken.cdc"
import NonFungibleToken from 0x1d7e57aa55817448

// FAN_Champion
// NFT items for MugenART!
//
pub contract FAN_Champion: NonFungibleToken {

    // Events
    //
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64)
    pub event MintFail(id: UInt64)
    pub event MintFailDuplicateId(id: UInt64)

    // Named Paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    pub let maxSupply: UInt64
    // totalSupply
    // The total number of NTFs that have been minted
    //
    pub var totalSupply: UInt64
    pub var mintedIds: {UInt64: Bool}
    

    // NFT
    // A Kitty Item as an NFT
    //
    pub resource NFT: NonFungibleToken.INFT {
        // The token's ID
        pub let id: UInt64

        // initializer
        //
        init(initID: UInt64) {
            self.id = initID
        }
    }

    // Collection
    // A collection of NFTs owned by an account
    //
    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        //
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        // withdraw
        // Removes an NFT from the collection and moves it to the caller
        //
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: withdrawID, from: self.owner?.address)

            return <-token
        }

        // deposit
        // Takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        //
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @FAN_Champion.NFT

            let id: UInt64 = token.id


            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
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

    // NFTMinter
    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    //
	pub resource NFTMinter {

		// mintNFT
        // Mints a new NFT with a new ID
		// and deposit it in the recipients collection using their collection reference
        //
		pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, mugenNFTID: UInt64) {

            if FAN_Champion.mintedIds[mugenNFTID] == true {
                emit MintFailDuplicateId(id: mugenNFTID)
                panic("Duplicate token id")
            }

            if FAN_Champion.totalSupply == FAN_Champion.maxSupply {
                emit MintFail(id: mugenNFTID)
                panic("Exceed the max supply")
            }

            emit Minted(id: mugenNFTID)

			// deposit it in the recipient's account using their reference
			recipient.deposit(token: <-create FAN_Champion.NFT(initID: mugenNFTID))

            FAN_Champion.mintedIds[mugenNFTID] = true

            FAN_Champion.totalSupply = FAN_Champion.totalSupply + (1 as UInt64)
		}
	}

    // initializer
    //
	init() {
        // Mugen contract name
        // Set our named paths
        self.CollectionStoragePath = /storage/FAN_ChampionCollection
        self.CollectionPublicPath = /public/FAN_ChampionCollection
        self.MinterStoragePath = /storage/FAN_Champion

        // Initialize the total supply
        self.totalSupply = 1
        self.maxSupply = 10000
        self.mintedIds = {}

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        emit ContractInitialized()
	}
}

 