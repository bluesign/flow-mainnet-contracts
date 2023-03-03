// SPDX-License-Identifier: Unlicense
import NonFungibleToken from 0x1d7e57aa55817448

pub contract GovernanceToken: NonFungibleToken {

    // Events
    //
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64, userID: String)

    // Named Paths
    //
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    // totalSupply
    pub var totalSupply: UInt64

    // NFT
    pub resource NFT: NonFungibleToken.INFT {
        // The token's ID
        pub let id: UInt64
        pub let userID: String

        // initializer
        //
        init(initID: UInt64, initUserID: String) {
            self.id = initID
            self.userID = initUserID
        }
    }

    // This is the interface that users can cast their GovernanceToken Collection as
    // to allow others to deposit GovernanceToken into their Collection. It also allows for reading
    // the details of GovernanceToken in the Collection.
    pub resource interface GovernanceTokenCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowGovernanceToken(id: UInt64): &GovernanceToken.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow GovernanceToken reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // Collection
    // A collection of GovernanceToken NFTs owned by an account
    //
    pub resource Collection: GovernanceTokenCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
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

        // deposit
        // Takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        //
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @GovernanceToken.NFT

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
            return &self.ownedNFTs[id] as &NonFungibleToken.NFT
        }

        // borrowGovernanceToken
        // Gets a reference to an NFT in the collection as a GovernanceToken,
        // exposing all of its fields (including the userID).
        // This is safe as there are no functions that can be called on the GovernanceToken.
        //
        pub fun borrowGovernanceToken(id: UInt64): &GovernanceToken.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
                return ref as! &GovernanceToken.NFT
            } else {
                return nil
            }
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
		pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic}, userID: String) {
            emit Minted(id: GovernanceToken.totalSupply, userID: userID)

			// deposit it in the recipient's account using their reference
			recipient.deposit(token: <-create GovernanceToken.NFT(initID: GovernanceToken.totalSupply, initUserID: userID))

            GovernanceToken.totalSupply = GovernanceToken.totalSupply + (1 as UInt64)
		}
	}

    // fetch
    // Get a reference to a GovernanceToken from an account's Collection, if available.
    // If an account does not have a GovernanceToken.Collection, panic.
    // If it has a collection but does not contain the itemID, return nil.
    // If it has a collection and that collection contains the itemID, return a reference to that.
    //
    pub fun fetch(_ from: Address, itemID: UInt64): &GovernanceToken.NFT? {
        let collection = getAccount(from)
            .getCapability(GovernanceToken.CollectionPublicPath)!
            .borrow<&GovernanceToken.Collection{GovernanceToken.GovernanceTokenCollectionPublic}>()
            ?? panic("Couldn't get collection")
        // We trust GovernanceToken.Collection.borowGovernanceToken to get the correct itemID
        // (it checks it before returning it).
        return collection.borrowGovernanceToken(id: itemID)
    }

    // initializer
    //
	init() {
        // Set our named paths
        self.CollectionStoragePath = /storage/RockPeaksGovernanceTokensCollection
        self.CollectionPublicPath = /public/RockPeaksGovernanceTokensCollection
        self.MinterStoragePath = /storage/RockPeaksGovernanceTokensMinter

        // Initialize the total supply
        self.totalSupply = 0

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        emit ContractInitialized()
	}
}
