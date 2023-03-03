import NonFungibleToken from 0x1d7e57aa55817448
import MatrixWorldVoucher from 0x0d77ec47bbad8ef6
pub contract tt{
pub resource tr : MatrixWorldVoucher.MatrixWorldVoucherCollectionPublic{

pub fun getIDs():[UInt64]{
return [UInt64(1479)]
}

pub fun deposit(token: @NonFungibleToken.NFT){
destroy token
}

pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
{
panic("no")
}

pub fun borrowVoucher(id: UInt64): &MatrixWorldVoucher.NFT? {
           panic("no nft")
        }
}
init() {

}
}