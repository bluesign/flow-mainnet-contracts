import NonFungibleToken from 0x1d7e57aa55817448

/// FreshmintQueue defines an interface for distributing NFTs in a queue.
///
/// The queue interface can be implemented in a variety of ways.
/// For example, a queue implementation can be backed by a fixed supply of 
/// pre-minted NFTs or can mint NFTs on demand. 
///
pub contract FreshmintQueue {

    /// Queue is the interface that all NFT queue implementations follow.
    ///
    pub resource interface Queue {

        /// Return the next available NFT in the queue.
        ///
        /// This function returns nil if there are no NFTs remaining in the queue.
        ///
        pub fun getNextNFT(): @NonFungibleToken.NFT?

        /// Return the number of NFTs remaining in this queue.
        ///
        /// This function returns nil if there is no defined limit.
        ///
        pub fun remaining(): Int?
    }

    /// CollectionQueue is an NFT queue that is backed by a NonFungibleToken.Collection.
    ///
    /// All NFTs in the queue are stored in the underlying collection.
    ///
    /// NFTs removed from the underlying collection will be skipped 
    /// when withdrawing from the queue.
    ///
    pub resource CollectionQueue: Queue, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic {

        /// The IDs array contains the NFT IDs in order of insertion.
        ///
        pub let ids: [UInt64]

        /// The collection containing the NFTs to be distributed by this queue.
        ///
        access(self) let collection: Capability<&NonFungibleToken.Collection>

        init(
            collection: Capability<&NonFungibleToken.Collection>
        ) {
            self.ids = []

            self.collection = collection
        }

        /// Deposit an NFT into this queue.
        ///
        /// This function adds the NFT ID to the end of the queue
        /// and deposits the ID into the underlying collection.
        ///
        pub fun deposit(token: @NonFungibleToken.NFT) {

            let collection = self.collection.borrow() 
                ?? panic("CollectionQueue.deposit: failed to borrow collection capability")

            self.ids.append(token.id)

            collection.deposit(token: <- token)
        }

        /// Return the NFT IDs in this queue.
        ///
        pub fun getIDs(): [UInt64] {
            return self.ids
        }

        /// Borrow a reference to an NFT in this queue.
        ///
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            let collection = self.collection.borrow() 
                ?? panic("CollectionQueue.borrowNFT: failed to borrow collection capability")

            return collection.borrowNFT(id: id)
        }

        /// Insert an ID into this queue.
        ///
        /// This function should only be used to insert IDs that are
        /// already in the underlying collection.
        ///
        pub fun insertID(id: UInt64) {
            self.ids.append(id)
        }

        /// Return the next available NFT in the queue.
        ///
        /// This function returns nil if there are no NFTs remaining in the queue.
        ///
        pub fun getNextNFT(): @NonFungibleToken.NFT? {

            // Return nil if the queue is empty
            if self.ids.length == 0 {
                return nil
            }

            let collection = self.collection.borrow() 
                ?? panic("CollectionQueue.getNextNFT: failed to borrow collection capability")

            // Withdraw the next available NFT from the collection,
            // skipping over NFTs that exist in the ID list but have
            // been removed from the underlying collection
            //
            while self.ids.length > 0 {
                let id = self.ids.removeFirst()

                // This is the only efficient way to check if the collection
                // contains an NFT without triggering a panic
                //
                if collection.ownedNFTs.containsKey(id) {
                    return <- collection.withdraw(withdrawID: id)
                }
            }

            return nil
        }

        /// Return the number of NFTs remaining in this queue.
        ///
        pub fun remaining(): Int? {
            return self.ids.length
        }
    }

    pub fun createCollectionQueue(
        collection: Capability<&NonFungibleToken.Collection>
    ): @CollectionQueue {
        return <- create CollectionQueue(collection: collection)
    }
}
