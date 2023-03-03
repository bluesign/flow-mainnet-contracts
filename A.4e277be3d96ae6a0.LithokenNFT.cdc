//-------------- Mainnet -----------------------------
import NonFungibleToken from 0x1d7e57aa55817448
import RedevNFT from 0x4e277be3d96ae6a0
// -------------------------------------------------

// LithokenNFT token contract

pub contract LithokenNFT : NonFungibleToken, RedevNFT {

    pub var totalSupply: UInt64

    pub var collectionPublicPath: PublicPath
    pub var collectionStoragePath: StoragePath
    pub var minterPublicPath: PublicPath
    pub var minterStoragePath: StoragePath

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub event Mint(id: UInt64, creator: Address, metadata: Metadata, royalties: [RedevNFT.Royalty])
    pub event Destroy(id: UInt64)

    pub struct Royalty {
        pub let address: Address
        pub let fee: UFix64

        init(address: Address, fee: UFix64) {
            self.address = address
            self.fee = fee
        }
    }
    	pub struct Metadata {
            pub let name: String
            pub let artist: String
            pub let creatorAddress:Address
            pub let description: String
            pub let dedicace: String
            pub let type: String
            pub let ipfs: String
            pub let collection: String
            pub let nomSerie: String
            pub let edition: UInt64
            pub let nbrEdition: UInt64


            init(name: String, 
            artist: String,
            creatorAddress:Address, 
            description: String,
            dedicace: String, 
            type: String,
            ipfs: String,
            collection: String,
            nomSerie: String,
            edition: UInt64,
            nbrEdition: UInt64) {
                self.name=name
                self.artist=artist
                self.creatorAddress=creatorAddress
                self.description=description
                self.dedicace=dedicace
                self.type=type
                self.ipfs=ipfs
                self.collection=collection
                self.nomSerie=nomSerie
                self.edition=edition
                self.nbrEdition=nbrEdition
		    }

	    }

    pub resource NFT: NonFungibleToken.INFT {
        pub let id: UInt64
        pub let creator: Address
        access(self) let metadata: Metadata
        access(self) let royalties: [RedevNFT.Royalty]

        init(id: UInt64, creator: Address, metadata: Metadata, royalties: [RedevNFT.Royalty]) {
            self.id = id
            self.creator = creator
            self.metadata = metadata
            self.royalties = royalties
        }

        pub fun getMetadata(): Metadata {
            return self.metadata
        }

        pub fun getRoyalties(): [RedevNFT.Royalty] {
           return self.royalties
        }

        destroy() {
            emit Destroy(id: self.id)
        }
    }

    pub resource interface LithokenNFTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun getMetadata(id: UInt64): Metadata
        pub fun borrowLithokenItem(id: UInt64): &LithokenNFT.NFT? {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow LithokenItem reference: The ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection: LithokenNFTCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, RedevNFT.CollectionPublic {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        init() {
            self.ownedNFTs <- {}
        }

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("Missing NFT")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <- token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @LithokenNFT.NFT
            let id: UInt64 = token.id
            let dummy <- self.ownedNFTs[id] <- token
            destroy dummy
            emit Deposit(id: id, to: self.owner?.address)
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }
        
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return &self.ownedNFTs[id] as &NonFungibleToken.NFT
        }
        
    
        pub fun borrowLithokenItem(id: UInt64): &LithokenNFT.NFT? {
            if self.ownedNFTs[id] != nil {
                let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
                return ref as! &LithokenNFT.NFT
            } else {
                return nil
            }
        }

        pub fun getMetadata(id: UInt64): Metadata {
            let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
            return (ref as! &LithokenNFT.NFT).getMetadata()
        }

        pub fun getRoyalties(id: UInt64): [RedevNFT.Royalty] {
            let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
            return (ref as! &RedevNFT.NFT).getRoyalties()
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }


    pub resource Minter {
        pub fun mintTo(creator: Capability<&{NonFungibleToken.Receiver}>, name: String, artist: String, description: String, dedicace: String, type: String, ipfs: String, collection: String, nomSerie: String, edition: UInt64, nbrEdition: UInt64, royalties: [RedevNFT.Royalty]): &NonFungibleToken.NFT {
            let metadata=Metadata(name: name, artist: artist, creatorAddress: creator.address, description:description, dedicace: dedicace, type:type, ipfs:ipfs, collection:collection, nomSerie:nomSerie, edition:edition, nbrEdition:nbrEdition)
            let token <- create NFT(
                id: LithokenNFT.totalSupply,
                creator: creator.address,
                metadata: metadata,
                royalties: royalties
            )
            LithokenNFT.totalSupply = LithokenNFT.totalSupply + 1
            let tokenRef = &token as &NonFungibleToken.NFT
            emit Mint(id: token.id, creator: creator.address, metadata: metadata, royalties: royalties)
            creator.borrow()!.deposit(token: <- token)
            return tokenRef
        }
    }

    pub fun minter(): Capability<&Minter> {
        return self.account.getCapability<&Minter>(self.minterPublicPath)
    }

    init() {
        self.totalSupply = 0
        self.collectionPublicPath = /public/LithokenNFTCollection
        self.collectionStoragePath = /storage/LithokenNFTCollection
        self.minterPublicPath = /public/LithokenNFTMinter
        self.minterStoragePath = /storage/LithokenNFTMinter

        let minter <- create Minter()
        self.account.save(<- minter, to: self.minterStoragePath)
        self.account.link<&Minter>(self.minterPublicPath, target: self.minterStoragePath)

        let collection <- self.createEmptyCollection()
        self.account.save(<- collection, to: self.collectionStoragePath)
        self.account.link<&{NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver}>(self.collectionPublicPath, target: self.collectionStoragePath)

        emit ContractInitialized()
    }
}
