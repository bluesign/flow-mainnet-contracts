import FungibleToken from 0xf233dcee88fe0abe
import StarVaultFactory from 0x5c6dad1decebccb4
import StarVaultConfig from 0x5c6dad1decebccb4
import StarVaultInterfaces from 0x5c6dad1decebccb4

pub contract Migrator {

    pub let vaultAddress: Address
    pub let fromTokenKey: String

    pub fun migrate(from: @FungibleToken.Vault): @FungibleToken.Vault {
        pre {
            from.balance > 0.0: "from vault no balance"
            self.fromTokenKey == StarVaultConfig.SliceTokenTypeIdentifierFromVaultType(vaultTypeIdentifier: from.getType().identifier): "from vault type error"
        }

        let balance = from.balance
        destroy(from)

        let collectionRef = self.account.borrow<&StarVaultFactory.VaultTokenCollection>(from: StarVaultConfig.VaultTokenCollectionStoragePath)!
        return <- collectionRef.withdraw(vault: self.vaultAddress, amount: balance)
    }

    init(fromTokenKey: String, vaultAddress: Address) {
        self.fromTokenKey = fromTokenKey
        self.vaultAddress = vaultAddress

        let collection <- StarVaultFactory.createEmptyVaultTokenCollection()
        let storagePath = StarVaultConfig.VaultTokenCollectionStoragePath
        self.account.save(<-collection, to: storagePath)
        self.account.link<&StarVaultFactory.VaultTokenCollection{StarVaultInterfaces.VaultTokenCollectionPublic}>(
            StarVaultConfig.VaultTokenCollectionPublicPath,
            target: storagePath
        )
    }
}