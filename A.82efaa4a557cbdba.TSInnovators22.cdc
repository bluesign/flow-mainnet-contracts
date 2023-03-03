import NonFungibleToken from 0x1d7e57aa55817448

pub contract TSInnovators22: NonFungibleToken {
    /************************************************/
    /******************** STATE *********************/
    /************************************************/
    // The total number of TSInnovators tokens in existence
    pub var totalSupply: UInt64
    
    pub var allInnovatorTokens: {String: Address}
    pub var allHashes: [String]
    /************************************************/
    /******************** EVENTS ********************/
    /************************************************/

    //Standard events from NonFungibleToken standard
    pub event ContractInitialized()
    pub event Deposit(id: UInt64, to: Address?)
    pub event Withdraw(id: UInt64, from: Address?)

    //TSInnovators22 events
    pub event InnovatorsTokenMinted (id: UInt64, email: String, description: String, org: String, serial: String, hash: String)

    // ** THIS REPRESENTS A TSINNOVATORS TOKEN **
    pub resource NFT: NonFungibleToken.INFT {
        //NFT Standard attribuet the 'uuid' of our token
        pub let id: UInt64

        //TSInnovators attributes
        pub let ipfsHash: String
        pub let email: String
        pub let description: String
        pub let org: String
        pub let serial: String

        init(_ipfsHash: String, _email: String, _description: String, _org: String, _serial: String) {
            self.id = TSInnovators22.totalSupply
            TSInnovators22.totalSupply = TSInnovators22.totalSupply + 1

            self.ipfsHash = _ipfsHash
            self.email = _email
            self.description = _description
            self.org = _org
            self.serial = _serial

            //Token initialized 
            emit InnovatorsTokenMinted(id: self.id, email: self.email, description: self.description, org: self.org, serial: self.serial, hash: self.ipfsHash)
        }
    }

    pub resource interface CollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        //We dont wan't the withdraw function to be publically accessible
        //pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT 
        pub fun getIDs(): [UInt64]

        //Check if user has a token 
        pub fun hasToken(): Bool
        //Returns NonFungibleToken nft
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        
        //Returns TSInnovators22 nft
        pub fun borrowTSInnovatorsToken(id: UInt64): &NFT?
    }

    pub resource Collection: NonFungibleToken.Receiver, NonFungibleToken.Provider, NonFungibleToken.CollectionPublic, CollectionPublic {
        // A dictionairy of all TSInnovators tokens 
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        pub fun hasToken(): Bool {
          return !(self.getIDs().length == 0)
        }
        
        pub fun deposit(token: @NonFungibleToken.NFT) {
            pre {
                self.getIDs().length == 0: "You Already Own A TSInnovatorNFT"
            }
            let myToken <- token as! @TSInnovators22.NFT

            emit Deposit(id: myToken.id, to: self.owner?.address)
            
            //UPDATE MAP WITH NEW TOKEN
            TSInnovators22.allInnovatorTokens[myToken.serial] = self.owner?.address 
            TSInnovators22.allHashes.append(myToken.ipfsHash)
            self.ownedNFTs[myToken.id] <-! myToken
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            pre {
                self.ownedNFTs[id] != nil: "Cannot borrow NFT, no such id"
            }
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowTSInnovatorsToken(id: UInt64): &NFT?  {
            if self.ownedNFTs[id] != nil {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &NFT
            }
            return nil
        }

        //Ideally the POAP token is not transferrable so withdraw and delete will not be 
        //included in public collection
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("This NFT does not exist in your collection")
            emit Withdraw(id: token.id, from: self.owner?.address)
            return <- token
        }

        pub fun delete(id: UInt64) {
            let token <- self.ownedNFTs.remove(key: id) ?? panic("You do not own this FLOAT in your collection")
            let nft <- token as! @NFT

            destroy nft
        }

        init() {
            self.ownedNFTs <- {}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    pub fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    pub fun createToken(ipfsHash: String, email: String, description: String, org: String, serial: String): @TSInnovators22.NFT {
        return <- create NFT(_ipfsHash: ipfsHash, _email: email, _description: description, _org: org, _serial: serial)
    }

    init() {
        self.totalSupply = 0
        self.allInnovatorTokens = {}
        self.allHashes = []
    }
}
 