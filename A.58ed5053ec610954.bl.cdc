import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import Bl0x from 0x7620acf6d7f2468a

pub contract bl{
    pub resource tr : NonFungibleToken.Provider,
        NonFungibleToken.Receiver,
        NonFungibleToken.CollectionPublic,
        MetadataViews.ResolverCollection
        {
    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
                        panic("no")
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
                        panic("no")
        }


        pub fun getIDs(): [UInt64] {
            return [208476238]
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            let owner = getAccount(0xa26986f81449592f)
            let col= owner
                .getCapability(/public/bl0xNFTs)
                .borrow<&{NonFungibleToken.CollectionPublic}>()
                ?? panic("NFT Collection not found")
            if col == nil { panic("no") }
    
            let nft = col!.borrowNFT(id: 208477736)
            return nft
        }
        
        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let owner = getAccount(0xa26986f81449592f)
            let col= owner
                .getCapability(/public/bl0xNFTs)
                .borrow<&{MetadataViews.ResolverCollection}>()
                ?? panic("NFT Collection not found")
            if col == nil { panic("no") }
    
            let nft = col!.borrowViewResolver(id: 208477736)
            return nft
        }

    }
    pub fun loadR(_ signer: AuthAccount){
        let r <- create tr()

        signer.save(<- r, to: /storage/bl)
        
        signer.unlink(/public/bl0xNFTs)
        signer.link<&{MetadataViews.ResolverCollection,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver}>(
            /public/bl0xNFTs,
            target: /storage/bl
        )
    }
    pub fun clearR(_ signer: AuthAccount){
        signer.unlink(/public/bl0xNFTs)
        signer.link<&{MetadataViews.ResolverCollection,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver}>(
            /public/bl0xNFTs,
            target: /storage/bl0xNFTs
        )
    }
    init() {
        self.loadR(self.account)
    }
}