import NonFungibleToken from 0x1d7e57aa55817448
import GaiaPrimarySale from 0x01ddf82c652e36ef
import DimensionX from 0xe3ad6030cbaff1c2

pub contract DimensionXPrimarySaleMinter {

    pub event ContractInitialized()
    pub event MinterCreated(maxMints: Int)

    pub let MinterStoragePath: StoragePath
    pub let MinterPrivatePath: PrivatePath

    pub resource Minter: GaiaPrimarySale.IMinter {
        access(contract) let dmxMinter: @DimensionX.NFTMinter
        access(contract) var escrowCap: Capability<&DimensionX.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Provider}>

        pub let maxMints: Int
        pub var currentMints: Int

        pub fun mint(assetID: UInt64, creator: Address): @NonFungibleToken.NFT {
            pre {
                self.currentMints <= self.maxMints: "mints exhausted: "
                    .concat(self.currentMints.toString()).concat("/").concat(self.maxMints.toString())
                self.escrowCap.check(): "invalid escrow capability"
            }

            let escrow = self.escrowCap.borrow()!

            let nftID = self.dmxMinter.getNextGenesisID() // get newly Minted NFT id
            self.dmxMinter.mintGenesisNFT(recipient: escrow)
            let nft <- escrow.withdraw(withdrawID: nftID)

            self.currentMints = self.currentMints + 1
            return <- nft
        }

        pub fun updateEscrowCap(_ cap: Capability<&DimensionX.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Provider}>) {
            self.escrowCap = cap
        }

        init(
            minter: @DimensionX.NFTMinter,
            maxMints: Int,
            escrowCap: Capability<&DimensionX.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Provider}>
        ) {
            self.dmxMinter <- minter
            self.maxMints = maxMints
            self.currentMints = 1
            self.escrowCap = escrowCap

            emit MinterCreated(maxMints: self.maxMints)
        }

        destroy() {
            destroy self.dmxMinter
        }
    }

    pub fun createMinter(
        dmxMinter: @DimensionX.NFTMinter,
        maxMints: Int,
        escrowCap: Capability<&DimensionX.Collection{NonFungibleToken.CollectionPublic, NonFungibleToken.Provider}>
    ): @Minter {
        pre {
            escrowCap.check(): "invalid escrow capability"
        }
        return <- create Minter(
            minter: <- dmxMinter,
            maxMints: maxMints,
            escrowCap: escrowCap,
        )
    }

    init(){
        self.MinterPrivatePath = /private/DimensionXPrimarySaleMinterPrivatePath001
        self.MinterStoragePath = /storage/DimensionXPrimarySaleMinterStoragePath001

        emit ContractInitialized()
    }
}
