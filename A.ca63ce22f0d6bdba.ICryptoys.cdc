import NonFungibleToken from 0x1d7e57aa55817448;

pub contract interface ICryptoys {
    pub struct Royalty {
        pub let name: String
        pub let address: Address
        pub let fee: UFix64
    }

    pub struct Display {
        pub let image: String
        pub let video: String
    }

    pub resource interface INFT {
        pub let id: UInt64
        access(account) let metadata: {String: String}
        access(account) let royalties: [String]
        access(account) let bucket: @{String: {UInt64: AnyResource{INFT}}}
        pub fun getMetadata(): {String: String}
        pub fun getDisplay(): Display
        pub fun getRoyalties(): [Royalty]
        access(account) fun withdrawBucketItem(_ key: String, _ itemUuid: UInt64): @AnyResource{ICryptoys.INFT} {
            pre {
                self.owner != nil : "withdrawBucketItem() failed: nft resource must be in a collection"
            }
            post {
                (result == nil) || (result.uuid == itemUuid):
                    "Cannot withdraw bucket Cryptoy reference: The ID of the returned reference is incorrect"
            }
        }
        pub fun addToBucket(_ key: String,_ nft: @AnyResource{INFT}) {
            pre {
                self.owner != nil : "addToBucket() failed: nft resource must be in a collection"
            }
        }
        pub fun getBucketKeys(): [String]
        pub fun getBucketResourceIdsByKey(_ key: String): [UInt64]
        pub fun borrowBucketResourcesByKey(_ key: String): &{UInt64: AnyResource{ICryptoys.INFT}}?
        pub fun borrowBucket(): &{String: {UInt64: AnyResource{ICryptoys.INFT}}}
        pub fun borrowBucketItem(_ key: String, _ itemUuid: UInt64): &AnyResource{INFT} {
            post {
                (result == nil) || (result.uuid == itemUuid):
                    "Cannot borrow bucket Cryptoy reference: The ID of the returned reference is incorrect"
            }
        }
        pub fun resolveView(_ view: Type): AnyStruct?
    }

    pub resource interface CryptoysCollectionPublic {
        pub fun borrowCryptoy(id: UInt64): &AnyResource{INFT} {
            // If the result isn't nil, the id of the returned reference
            // should be the same as the argument to the function
            post {
                (result == nil) || (result.id == id):
                    "Cannot borrow Cryptoy reference: The ID of the returned reference is incorrect"
            }
        }
        pub fun borrowBucketItem(_ id: UInt64, _ key: String, _ itemUuid: UInt64): &AnyResource{ICryptoys.INFT} {
            post {
                (result == nil) || (result.uuid == itemUuid):
                    "Cannot borrow bucket Cryptoy reference: The ID of the returned reference is incorrect"
            }
        }
    }

    pub resource Collection {
        pub fun withdrawBucketItem(parentId: UInt64, key: String, itemUuid: UInt64): @AnyResource{ICryptoys.INFT}
    }
}
