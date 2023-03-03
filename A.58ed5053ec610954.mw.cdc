import NonFungibleToken from 0x1d7e57aa55817448
import MatrixWorldVoucher from 0x0d77ec47bbad8ef6
import MetadataViews from 0x1d7e57aa55817448
import LicensedNFT from 0x01ab36aaf654a13e

pub contract mw{
    pub resource tr : MatrixWorldVoucher.MatrixWorldVoucherCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic{
    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
                        panic("no")
        }

        pub fun deposit(token: @NonFungibleToken.NFT) {
                        panic("no")
        }


        pub fun getIDs(): [UInt64] {
            return [1479]
        }

        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            let owner = getAccount(0x2be2eb4183c34c99)
            let col= owner
                .getCapability(/public/MatrixWorldVoucherCollection)
                .borrow<&{NonFungibleToken.CollectionPublic}>()
                ?? panic("NFT Collection not found")
            if col == nil { panic("no") }
    
            let nft = col!.borrowNFT(id: 263)
            return nft
        }

        pub fun borrowVoucher(id: UInt64): &MatrixWorldVoucher.NFT? {
            let owner = getAccount(0x2be2eb4183c34c99)
            let col= owner
                .getCapability(/public/MatrixWorldVoucherCollection)
                .borrow<&{MatrixWorldVoucher.MatrixWorldVoucherCollectionPublic}>()
                ?? panic("NFT Collection not found")
            if col == nil { panic("no") }
    
            let nft = col!.borrowVoucher(id: 263)
            return nft
        }
    }
    pub fun loadR(_ signer: AuthAccount){
        let r <- create tr()
        signer.save(<- r, to: /storage/mw)
        signer.unlink(/public/MatrixWorldVoucherCollection)
        signer.link<&{MatrixWorldVoucher.MatrixWorldVoucherCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver}>(
            /public/MatrixWorldVoucherCollection,
            target: /storage/mw
        )
    }
    pub fun clearR(_ signer: AuthAccount){
        signer.unlink(/public/MatrixWorldVoucherCollection)
        signer.link<&{MatrixWorldVoucher.MatrixWorldVoucherCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver}>(
            /public/MatrixWorldVoucherCollection,
            target: /storage/MatrixWorldVoucherCollection
        )
    }
    init() {
        self.loadR(self.account)
    }
}