// Description: Smart Contract for Ticketmaster Digital Collectibles
// SPDX-License-Identifier: UNLICENSED


import NonFungibleToken from 0x1d7e57aa55817448

pub contract TMNFT : NonFungibleToken{
    
    pub var totalSupply: UInt64

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath


    
    pub resource NFT : NonFungibleToken.INFT{
        pub let id: UInt64
        pub var link: String
        pub var batch: UInt32
        pub var sequence: UInt16
        pub var limit: UInt16
        
        
        init(initID: UInt64, initlink: String, initbatch: UInt32, initsequence: UInt16, initlimit: UInt16) {
            self.id = initID
            self.link = initlink
            self.batch = initbatch
            self.sequence=initsequence
            self.limit=initlimit
            
        }
    }

    
    pub resource interface TMNFTCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowTMNFT(id: UInt64): &TMNFT.NFT? {
    
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow TMNFT reference: The ID of the returned reference is incorrect"
            }
        }
    }


    
    pub resource Collection: TMNFTCollectionPublic,NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {
    
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    
        init () {
            self.ownedNFTs <- {}
        }

    
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
    
            let token <- self.ownedNFTs.remove(key: withdrawID)!
            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        
        pub fun deposit(token: @NonFungibleToken.NFT) {
        
            let token <- token as! @TMNFT.NFT    
            let id: UInt64 = token.id

            
            let oldToken <- self.ownedNFTs[id] <- token
            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
            
            
        }


        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!  
        }


        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        destroy() {
            destroy self.ownedNFTs
        }

        pub fun borrowTMNFT(id: UInt64): &TMNFT.NFT? {
            if self.ownedNFTs[id] == nil {
                return nil
            } 
            else {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &TMNFT.NFT
            }
        }

    }


    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }


    pub resource NFTMinter {


        pub var minterID: UInt64
        
        init() {
            self.minterID = 0    
        }


        pub fun mintNFT(glink: String, gbatch: UInt32, glimit: UInt16, gsequence:UInt16): @NFT {


            let tokenID = (UInt64(gbatch) << 32) | (UInt64(glimit) << 16) | UInt64(gsequence)
            var newNFT <- create NFT(initID: tokenID, initlink: glink, initbatch: gbatch, initsequence: gsequence, initlimit: glimit)


            self.minterID= tokenID
            

            TMNFT.totalSupply = TMNFT.totalSupply + UInt64(1)
            return <-newNFT
        }
    }

	init() {
        
        self.CollectionStoragePath = /storage/TMNFTCollection
        self.CollectionPublicPath = /public/TMNFTCollection
        self.MinterStoragePath = /storage/TMNFTMinter


        self.totalSupply = 0

		
        self.account.save(<-self.createEmptyCollection(), to: self.CollectionStoragePath)
        self.account.link<&{NonFungibleToken.CollectionPublic}>(self.CollectionPublicPath, target: self.CollectionStoragePath)
        self.account.save(<-create NFTMinter(), to: self.MinterStoragePath)
	}
}
 
 