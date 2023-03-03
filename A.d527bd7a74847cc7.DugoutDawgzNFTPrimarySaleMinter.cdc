import NonFungibleToken from 0x1d7e57aa55817448
import GaiaPrimarySale from 0x01ddf82c652e36ef
import DugoutDawgzNFT from 0xd527bd7a74847cc7

pub contract DugoutDawgzNFTPrimarySaleMinter {
    pub resource Minter: GaiaPrimarySale.IMinter {
        access(self) let setMinter: @DugoutDawgzNFT.SetMinter

        pub fun mint(assetID: UInt64, creator: Address): @NonFungibleToken.NFT {
            return <- self.setMinter.mint(templateID: assetID, creator: creator)
        }

        init(setMinter: @DugoutDawgzNFT.SetMinter) {
            self.setMinter <- setMinter
        }

        destroy() {
            destroy self.setMinter
        }
    }

    pub fun createMinter(setMinter: @DugoutDawgzNFT.SetMinter): @Minter {
        return <- create Minter(setMinter: <- setMinter)
    }
}
