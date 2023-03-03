import MonoCat from 0x8529aaf64c168952
import NonFungibleToken from 0x1d7e57aa55817448

pub contract Migrate {
    // save monocats owners address
    pub struct StroedMonoCats {
        pub let tokenId: UInt64
        pub let lastFlowOwner: Address
        pub let firstEthOwner: String

        init(
            tokenId: UInt64,
            lastFlowOwner: Address,
            firstEthOwner: String
        ) {
            self.tokenId = tokenId
            self.lastFlowOwner = lastFlowOwner
            self.firstEthOwner = firstEthOwner
        }
    }

    access(self) let collection: @NonFungibleToken.Collection
    // store
    access(self) let storedMonoCats: [StroedMonoCats]

    pub event Migrated(tokenId: UInt64, lastFlowOwner: Address, firstEthOwner: String)
    pub event ContractInitialized()

    pub fun recycleMonoCats(tokenIds: [UInt64], acct: AuthAccount, ethAddress: String) {
        // get user's collection
        let col = acct.borrow<&MonoCat.Collection>(from: MonoCat.CollectionStoragePath)
        if (col == nil) {
            panic("You don't have a MonoCats collection.")
        }
        
        // transfer to contract's collection
        for id in tokenIds {
            let nft <- col!.withdraw(withdrawID: id)
            self.collection.deposit(token: <- nft)
            // save to store
            self.storedMonoCats.append(StroedMonoCats(
                tokenId: id,
                lastFlowOwner: acct.address,
                firstEthOwner: ethAddress
            ))
            // emit event
            emit Migrated(tokenId: id, lastFlowOwner: acct.address, firstEthOwner: ethAddress)
        }
    }

    pub fun getAllRetrievableMonoCatsIds(ethAddress: String): [UInt64] {
        let ret: [UInt64] = []
        for cat in self.storedMonoCats {
            if (cat.firstEthOwner == ethAddress) {
                ret.append(cat.tokenId)
            }
        }

        return ret
    }

    init() {
        self.collection <- MonoCat.createEmptyCollection()
        self.storedMonoCats = []
        emit ContractInitialized()
    }
}