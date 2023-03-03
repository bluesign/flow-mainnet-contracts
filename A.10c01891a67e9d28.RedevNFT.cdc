// RedevNFT
// Adds creator royalty to NFT
pub contract interface RedevNFT {

    pub struct Royalty {
        pub let address: Address
        pub let fee: UFix64
    }

    pub resource NFT {
        pub fun getRoyalties(): [Royalty]
    }

    pub resource interface CollectionPublic {
        pub fun getRoyalties(id: UInt64): [Royalty]
    }

    pub resource Collection: CollectionPublic {
        pub fun getRoyalties(id: UInt64): [Royalty]
    }
}
