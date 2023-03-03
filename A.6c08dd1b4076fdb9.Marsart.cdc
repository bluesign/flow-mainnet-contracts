import NonFungibleToken from 0x1d7e57aa55817448

// Marsart
// NFT items for Marsart!
pub contract Marsart: NonFungibleToken {
    // Events
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)
    pub event Minted(id: UInt64,
                     name: String,
                     artist: String,
                     artistIntroduction: String,
                     artworkIntroduction: String,
                     typeId: UInt64,
                     type: String,
                     description: String,
                     ipfsLink: String,
                     MD5Hash: String,
                     serialNumber: UInt32,
                     totalNumber: UInt32)

    // Named Paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    // The total number of tokens of this type in existence
    pub var totalSupply: UInt64

    pub resource interface NFTPublic {
        pub let id: UInt64
        pub let data: NFTData
    }

    pub struct NFTData {
        pub let name: String
        pub let artist: String
        pub let artistIntroduction: String
        pub let artworkIntroduction: String
        pub let typeId: UInt64
        pub let type: String
        pub let description: String
        pub let ipfsLink: String
        pub let MD5Hash: String
        pub let serialNumber: UInt32
        pub let totalNumber: UInt32

        init(name: String,
            artist: String,
            artistIntroduction: String,
            artworkIntroduction: String,
            typeId: UInt64,
            type: String,
            description: String,
            ipfsLink: String,
            MD5Hash: String,
            serialNumber: UInt32,
            totalNumber: UInt32){
            self.name=name
            self.artist=artist
            self.artistIntroduction=artistIntroduction
            self.artworkIntroduction=artworkIntroduction
            self.typeId=typeId
            self.type=type
            self.description=description
            self.ipfsLink=ipfsLink
            self.MD5Hash=MD5Hash
            self.serialNumber=serialNumber
            self.totalNumber=totalNumber
        }
    }

    pub resource NFT: NonFungibleToken.INFT , NFTPublic {
        // global unique NFT ID
        pub let id: UInt64

        pub let data: NFTData

        init(initID: UInt64,nftData: NFTData) {
            self.id = initID
            self.data = nftData
        }
    }

    // This is the interface that users can cast their Marsart Collection as
    // to allow others to deposit Marsart into their Collection. It also allows for reading
    // the details of Marsart in the Collection.
    pub resource interface MarsartCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun depositBatch(cardCollection: @NonFungibleToken.Collection)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowMarsart(id: UInt64): &Marsart.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow Marsart reference: The ID of the returned reference is incorrect"
            }
        }
    }

    // Collection
    // A collection of Marsart NFTs owned by an account
    pub resource Collection: MarsartCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
        // dictionary of NFT conforming tokens
        // NFT is a resource type with an `UInt64` ID field
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        // withdraw
        // Removes an NFT from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit
        // Takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @Marsart.NFT

            let id: UInt64 = token.id

            // add the new token to the dictionary which removes the old one
            let oldToken <- self.ownedNFTs[id] <- token

            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
        }
        // depositBatch
        // This is primarily called by an Admin to
        // deposit newly minted Cards into this Collection.
        pub fun depositBatch(cardCollection: @NonFungibleToken.Collection) {
            pre {
                cardCollection.getIDs().length <= 100:
                    "Too many cards being deposited. Must be less than or equal to 100"
            }
            // Get an array of the IDs to be deposited
            let keys = cardCollection.getIDs()
            // Iterate through the keys in the collection and deposit each one
            for key in keys {
                self.deposit(token: <-cardCollection.withdraw(withdrawID: key))
            }
            // Destroy the empty Collection
            destroy cardCollection
        }
        // getIDs
        // Returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT
        // Gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        // borrowMarsart
        // Gets a reference to an NFT in the collection as a Marsart,
        // exposing all of its fields (including the typeID).
        // This is safe as there are no functions that can be called on the Marsart.
        pub fun borrowMarsart(id: UInt64): &Marsart.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &Marsart.NFT
            }
            return nil
        }
        // destructor
        destroy() {
            destroy self.ownedNFTs
        }
        // initializer
        init () {
            self.ownedNFTs <- {}
        }
    }

    // createEmptyCollection
    // public function that anyone can call to create a new empty collection
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }
    // NFTMinter
    // Resource that an admin or something similar would own to be
    // able to mint new NFTs
    pub resource NFTMinter {
        // mintNFT
        // Mints a new NFT with a new ID
		// and deposit it in the recipients collection using their collection reference
		pub fun mintNFT(recipient: &{NonFungibleToken.CollectionPublic},
		name: String,
		artist: String,
        artistIntroduction: String,
        artworkIntroduction: String,
        typeId: UInt64,
        type: String,
        description: String,
        ipfsLink: String,
        MD5Hash: String,
        serialNumber: UInt32,
        totalNumber: UInt32 ) {
            Marsart.totalSupply = Marsart.totalSupply + (1 as UInt64)
            emit Minted(id: Marsart.totalSupply,
                         name: name,
                         artist: artist,
                         artistIntroduction: artistIntroduction,
                         artworkIntroduction: artworkIntroduction,
                         typeId: typeId,
                         type: type,
                         description: description,
                         ipfsLink: ipfsLink,
                         MD5Hash: MD5Hash,
                         serialNumber: serialNumber,
                         totalNumber: totalNumber)
			// deposit it in the recipient's account using their reference
			recipient.deposit(token: <-create Marsart.NFT(
			    initID: Marsart.totalSupply,
			    data: NFTData(
                     name: name,
                     artist: artist,
                     artistIntroduction: artistIntroduction,
                     artworkIntroduction: artworkIntroduction,
                     typeId: typeId,
                     type: type,
                     description: description,
                     ipfsLink: ipfsLink,
                     MD5Hash: MD5Hash,
                     serialNumber: serialNumber,
                     totalNumber: totalNumber
            )))
        }
    }
    
    // initializer
    init() {
        // Initialize the total supply
        self.totalSupply = 0
        // Set our named paths
        self.CollectionStoragePath = /storage/MarsartCollection
        self.CollectionPublicPath = /public/MarsartCollection
        self.MinterStoragePath = /storage/MarsartMinter

        // Create a Minter resource and save it to storage
        let minter <- create NFTMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        emit ContractInitialized()
    }
}