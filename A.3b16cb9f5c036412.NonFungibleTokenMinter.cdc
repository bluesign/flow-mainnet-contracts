import NonFungibleToken from 0x1d7e57aa55817448

pub contract interface NonFungibleTokenMinter {

    pub event Minted(to: Address, id: UInt64, metadata: {String:String})

    pub resource interface MinterProvider {
        pub fun mintNFT(id: UInt64, recipient: &{NonFungibleToken.CollectionPublic}, metadata: {String:String})
    }

    pub resource NFTMinter: MinterProvider {
        pub fun mintNFT(id: UInt64, recipient: &{NonFungibleToken.CollectionPublic}, metadata: {String:String})
    }
}