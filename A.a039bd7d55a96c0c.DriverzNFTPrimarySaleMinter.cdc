import NonFungibleToken from 0x1d7e57aa55817448
import GaiaPrimarySale from 0x01ddf82c652e36ef
import DriverzNFT from 0xa039bd7d55a96c0c

pub contract DriverzNFTPrimarySaleMinter {
    pub resource Minter: GaiaPrimarySale.IMinter {
        access(self) let setMinter: @DriverzNFT.SetMinter

        pub fun mint(assetID: UInt64, creator: Address): @NonFungibleToken.NFT {
            return <- self.setMinter.mint(templateID: assetID, creator: creator)
        }

        init(setMinter: @DriverzNFT.SetMinter) {
            self.setMinter <- setMinter
        }

        destroy() {
            destroy self.setMinter
        }
    }

    pub fun createMinter(setMinter: @DriverzNFT.SetMinter): @Minter {
        return <- create Minter(setMinter: <- setMinter)
    }
}
