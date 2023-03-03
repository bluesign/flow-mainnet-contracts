// Description: Smart Contract for St. Louis Blues Digital Collectibles
// SPDX-License-Identifier: UNLICENSED


import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

pub contract BLUES : NonFungibleToken{
    
    pub var totalSupply: UInt64

    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath


    pub resource NFT : NonFungibleToken.INFT, MetadataViews.Resolver{
        
        pub let id: UInt64
        pub var link: String
        pub var batch: UInt32
        pub var sequence: UInt16
        pub var limit: UInt16
        pub(set) var attended: Bool

        pub let name: String
        pub let description: String
        pub let thumbnail: String

        
        
        init(initID: UInt64, initlink: String, initbatch: UInt32, initsequence: UInt16, initlimit: UInt16) {
            self.id = initID
            self.link = initlink
            self.batch = initbatch
            self.sequence=initsequence
            self.limit=initlimit
            self.attended = false

            self.name = "St Louis Blues"
            self.description = "St Louis Blues NFTs"
            self.thumbnail = initlink
            
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
                        name: self.name,
                        description: self.description,
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.thumbnail
                        )
                    )
            }

            return nil
        }
    }

    pub resource interface BLUESCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun markAttendance(id: UInt64, attendance:Bool) : Bool
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT        
        pub fun borrowBLUES(id: UInt64): &BLUES.NFT? {
    
            post {
                (result == nil) || (result?.id == id):
                    "Cannot borrow BLUES reference: The ID of the returned reference is incorrect"
            }
        }
    }


    
    pub resource Collection: BLUESCollectionPublic,NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
    
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

            let token <- token as! @BLUES.NFT            
            let id: UInt64 = token.id

            
            let oldToken <- self.ownedNFTs[id] <- token
            emit Deposit(id: id, to: self.owner?.address)

            destroy oldToken
            
            
        }


        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!  
        }


        pub fun markAttendance(id: UInt64, attendance:Bool) : Bool {
            let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let ref2 =  ref as! &BLUES.NFT
            ref2.attended = attendance
            log("Attendance is set to: ")
            log(ref2.attended)
            return ref2.attended
        }

        
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        destroy() {
            destroy self.ownedNFTs
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let exampleNFT = nft as! &BLUES.NFT
            return exampleNFT as &AnyResource{MetadataViews.Resolver}
        }

        pub fun borrowBLUES(id: UInt64): &BLUES.NFT? {
            if self.ownedNFTs[id] == nil {
                return nil
            }
            else {
                let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
                return ref as! &BLUES.NFT
            }
        }

    }

    
    pub fun createEmptyCollection(): @BLUES.Collection {
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
            BLUES.totalSupply = BLUES.totalSupply + UInt64(1)
            return <-newNFT
        }
    }
	init() {


        self.CollectionStoragePath = /storage/BLUESCollection
        self.CollectionPublicPath = /public/BLUESCollection
        self.MinterStoragePath = /storage/BLUESMinter


        self.totalSupply = 0

        self.account.save(<-self.createEmptyCollection(), to: self.CollectionStoragePath)
        self.account.link<&{BLUES.BLUESCollectionPublic}>(self.CollectionPublicPath, target: self.CollectionStoragePath)
        self.account.save(<-create NFTMinter(), to: self.MinterStoragePath)

        emit ContractInitialized()
	}
}
 
 