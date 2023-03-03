import NonFungibleToken from 0x1d7e57aa55817448

pub contract Mintix: NonFungibleToken {
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    pub var totalSupply: UInt64
    pub event ContractInitialized()
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

    pub resource NFT: NonFungibleToken.INFT {
        pub let id: UInt64 
        pub let eventId: UInt64
        pub let supplyId: UInt64

        init(_eventId: UInt64, _supplyId: UInt64) {
            self.id = Mintix.totalSupply
            Mintix.totalSupply = Mintix.totalSupply + 1

            self.eventId = _eventId
            self.supplyId = _supplyId
        }
    }

    pub resource interface NFTReceiver {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowEntireNFT(id: UInt64): &NFT
    }

    pub resource Collection: NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, NFTReceiver {
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("This NFT does not exist")
        
            emit Withdraw(id: token.id, from: self.owner?.address)

            return <- token
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
            let token <- token as! @Mintix.NFT

            emit Deposit(id: token.id, to: self.owner?.address)

            self.ownedNFTs[token.id] <-! token
        }

        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?) ?? panic("We couldn't borrow this NFT")
        }

        pub fun borrowEntireNFT(id: UInt64): &NFT {
            let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            return ref as! &NFT 
        }

        init() {
            self.ownedNFTs <- {}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }

    pub resource NFTMinter {
        pub fun mintNFT(eventId: UInt64, supplyId: UInt64): @NFT {
            return <- create NFT(_eventId: eventId, _supplyId: supplyId)
        }
    }
    
    
    pub fun createEmptyCollection(): @NonFungibleToken.Collection {
        return <- create Collection()
    }

init() {
        self.CollectionStoragePath = /storage/MintixCollection
        self.CollectionPublicPath = /public/MintixCollection
        self.MinterStoragePath = /storage/MintixMinter

        self.totalSupply = 0

        self.account.save(<-create NFTMinter(), to: self.MinterStoragePath)     
	}
}