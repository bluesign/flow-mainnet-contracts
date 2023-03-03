import FungibleToken from 0xf233dcee88fe0abe
import StarVaultFactory from 0x5c6dad1decebccb4
import StarVaultConfig from 0x5c6dad1decebccb4
import StarVaultInterfaces from 0x5c6dad1decebccb4

pub contract Migrator {

    pub let vaultAddress: Address
    pub let fromTokenKey: String

    access(self) let balanceMap: { Address: UFix64 }

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

    pub fun deposit(to: Address, vault: @FungibleToken.Vault) {
        pre {
            vault.balance > 0.0: "vault no balance"
            self.fromTokenKey == StarVaultConfig.SliceTokenTypeIdentifierFromVaultType(vaultTypeIdentifier: vault.getType().identifier): "from vault type error"
        }

        let balance = vault.balance
        destroy(vault)

        if self.balanceMap.containsKey(to) {
            self.balanceMap[to] = self.balanceMap[to]! + balance
        } else {
            self.balanceMap[to] = balance
        }
    }

    pub fun withdraw(to: Address) {
        pre {
            self.balanceMap.containsKey(to): "invalid balance"
        }
        let balance = self.balanceMap[to]!
        let collectionRef = self.account.borrow<&StarVaultFactory.VaultTokenCollection>(from: StarVaultConfig.VaultTokenCollectionStoragePath)!
        let vault <- collectionRef.withdraw(vault: self.vaultAddress, amount: balance)

        self.balanceMap[to] = 0.0

        var toCollectionRef = getAccount(to).getCapability<&{StarVaultInterfaces.VaultTokenCollectionPublic}>(StarVaultConfig.VaultTokenCollectionPublicPath).borrow()!
        toCollectionRef.deposit(vault: self.vaultAddress, tokenVault: <- vault)
    }

    pub fun getBalance(owner: Address): UFix64 {
        if self.balanceMap.containsKey(owner) {
            return self.balanceMap[owner]!
        } else {
            return 0.0
        }
    }

    init(fromTokenKey: String, vaultAddress: Address) {
        self.fromTokenKey = fromTokenKey
        self.vaultAddress = vaultAddress
        self.balanceMap = {}

        let collection <- StarVaultFactory.createEmptyVaultTokenCollection()
        let storagePath = StarVaultConfig.VaultTokenCollectionStoragePath
        self.account.save(<-collection, to: storagePath)
        self.account.link<&StarVaultFactory.VaultTokenCollection{StarVaultInterfaces.VaultTokenCollectionPublic}>(
            StarVaultConfig.VaultTokenCollectionPublicPath,
            target: storagePath
        )
    }
}