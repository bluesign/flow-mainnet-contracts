import NonFungibleToken from 0x1d7e57aa55817448
import FlowverseTreasures from 0x9212a87501a8a6a2
import FlowversePrimarySale from 0x9212a87501a8a6a2

pub contract FlowverseTreasuresPrimarySaleMinter {
    pub resource Minter: FlowversePrimarySale.IMinter {
        access(self) let setMinter: @FlowverseTreasures.SetMinter

        pub fun mint(entityID: UInt64, minterAddress: Address): @NonFungibleToken.NFT {
            return <- self.setMinter.mint(entityID: entityID, minterAddress: minterAddress)
        }

        init(setMinter: @FlowverseTreasures.SetMinter) {
            self.setMinter <- setMinter
        }

        destroy() {
            destroy self.setMinter
        }
    }

    pub fun createMinter(setMinter: @FlowverseTreasures.SetMinter): @Minter {
        return <- create Minter(setMinter: <- setMinter)
    }

    pub fun getPrivatePath(setID: UInt64): PrivatePath {
        let pathIdentifier = "FlowverseTreasuresPrimarySaleMinter"
        return PrivatePath(identifier: pathIdentifier.concat(setID.toString()))!
    }

    pub fun getStoragePath(setID: UInt64): StoragePath {
        let pathIdentifier = "FlowverseTreasuresPrimarySaleMinter"
        return StoragePath(identifier: pathIdentifier.concat(setID.toString()))!
    }
}