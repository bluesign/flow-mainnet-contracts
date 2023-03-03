
pub contract StarVaultConfig {
    pub let VaultPublicPath: PublicPath
    pub let VaultStoragePath: StoragePath
    pub let VaultNFTCollectionStoragePath: StoragePath
    pub let VaultAdminStoragePath: StoragePath
    pub let VaultTokenCollectionPublicPath: PublicPath
    pub let VaultTokenCollectionStoragePath: StoragePath
    pub let PoolPublicPath: PublicPath
    pub let PoolStoragePath: StoragePath
    pub let LPStakingCollectionStoragePath: StoragePath
    pub let LPStakingCollectionPublicPath: PublicPath
    pub let LPStakingAdminStoragePath: StoragePath
    pub let FactoryAdminStoragePath: StoragePath
    pub let ConfigAdminStoragePath: StoragePath

    pub var feeTo: Address?
    pub var feeRatio: UFix64

    pub struct VaultFees {
        pub var mintFee: UFix64
        pub var randomRedeemFee: UFix64
        pub var targetRedeemFee: UFix64
        pub var randomSwapFee: UFix64
        pub var targetSwapFee: UFix64

        init(
            mintFee: UFix64,
            randomRedeemFee: UFix64,
            targetRedeemFee: UFix64,
            randomSwapFee: UFix64,
            targetSwapFee: UFix64
        ) {
            self.mintFee = mintFee
            self.randomRedeemFee = randomRedeemFee
            self.targetRedeemFee = targetRedeemFee
            self.randomSwapFee = randomSwapFee
            self.targetSwapFee = targetSwapFee
        }
    }

    pub var globalVaultFees: VaultFees

    access(self) let vaultFees: { Int: VaultFees }

    pub event UpdateGlobalFees(mintFee: UFix64, randomRedeemFee: UFix64, targetRedeemFee: UFix64, randomSwapFee: UFix64, targetSwapFee: UFix64)
    pub event UpdateVaultFees(vaultId: Int, mintFee: UFix64, randomRedeemFee: UFix64, targetRedeemFee: UFix64, randomSwapFee: UFix64, targetSwapFee: UFix64)
    pub event DisableVaultFees(vaultId: Int)
    pub event FeeToAddressChanged(oldFeeTo: Address?, newFeeTo: Address?)
    pub event FeeRatioChanged(oldFeeRatio: UFix64, newFeeRatio: UFix64)

    pub fun SliceTokenTypeIdentifierFromVaultType(vaultTypeIdentifier: String): String {
        return vaultTypeIdentifier.slice(
            from: 0,
            upTo: vaultTypeIdentifier.length - 6
        )
    }

    pub fun sliceTokenTypeIdentifierFromCollectionType(collectionTypeIdentifier: String): String {
        return collectionTypeIdentifier.slice(
            from: 0,
            upTo: collectionTypeIdentifier.length - 11
        )
    }

    pub fun getVaultFees(vaultId: Int): VaultFees {
        if (self.vaultFees.containsKey(vaultId)) {
            return self.vaultFees[vaultId]!
        } else {
            return self.globalVaultFees
        }
    }

    pub resource Admin {
        pub fun setFactoryFees(
            mintFee: UFix64,
            randomRedeemFee: UFix64,
            targetRedeemFee: UFix64,
            randomSwapFee: UFix64,
            targetSwapFee: UFix64
        ) {
            StarVaultConfig.globalVaultFees = VaultFees(
                mintFee: mintFee,
                randomRedeemFee: randomRedeemFee,
                targetRedeemFee: targetRedeemFee,
                randomSwapFee: randomSwapFee,
                targetSwapFee: targetSwapFee
            )

            emit UpdateGlobalFees(
                mintFee: mintFee,
                randomRedeemFee: randomRedeemFee,
                targetRedeemFee: targetRedeemFee,
                randomSwapFee: randomSwapFee,
                targetSwapFee: targetSwapFee
            )
        }

        pub fun setVaultFees(
            vaultId: Int,
            mintFee: UFix64,
            randomRedeemFee: UFix64,
            targetRedeemFee: UFix64,
            randomSwapFee: UFix64,
            targetSwapFee: UFix64
        ) {
            let fees = VaultFees(
                mintFee: mintFee,
                randomRedeemFee: randomRedeemFee,
                targetRedeemFee: targetRedeemFee,
                randomSwapFee: randomSwapFee,
                targetSwapFee: targetSwapFee
            )
            StarVaultConfig.vaultFees.insert(key: vaultId, fees)

            emit UpdateVaultFees(
                vaultId: vaultId,
                mintFee: mintFee,
                randomRedeemFee: randomRedeemFee,
                targetRedeemFee: targetRedeemFee,
                randomSwapFee: randomSwapFee,
                targetSwapFee: targetSwapFee
            )
        }

        pub fun disableVaultFees(vaultId: Int) {
            pre {
                StarVaultConfig.vaultFees.containsKey(vaultId): "vault fee not set"
            }
            StarVaultConfig.vaultFees.remove(key: vaultId)
            emit DisableVaultFees(vaultId: vaultId)
        }

        pub fun setFeeTo(feeToAddr: Address) {
            emit FeeToAddressChanged(oldFeeTo: StarVaultConfig.feeTo, newFeeTo: feeToAddr)
            StarVaultConfig.feeTo = feeToAddr
        }

        pub fun setFeeRatio(feeRatio: UFix64) {
            pre {
                feeRatio <= 1.0: "setFeeRatio: feeRatio overflow"
            }
            emit FeeRatioChanged(oldFeeRatio: StarVaultConfig.feeRatio, newFeeRatio: feeRatio)
            StarVaultConfig.feeRatio = feeRatio
        }
    }

    init() {
        self.VaultPublicPath = /public/star_vault
        self.VaultStoragePath = /storage/star_vault
        self.VaultNFTCollectionStoragePath = /storage/star_vault_nft_collection
        self.VaultAdminStoragePath = /storage/star_vault_admin
        self.VaultTokenCollectionPublicPath = /public/star_vault_token_collection
        self.VaultTokenCollectionStoragePath = /storage/star_vault_token_collection
        self.PoolPublicPath = /public/star_vault_reward_pool
        self.PoolStoragePath = /storage/star_vault_reward_pool
        self.LPStakingCollectionStoragePath = /storage/star_vault_lpstaking_collection
        self.LPStakingCollectionPublicPath = /public/star_vault_lpstaking_collection
        self.LPStakingAdminStoragePath = /storage/star_vault_lpstaking_admin
        self.FactoryAdminStoragePath = /storage/star_vault_factory_admin
        self.ConfigAdminStoragePath = /storage/star_vault_config_admin

        self.globalVaultFees = VaultFees(
            mintFee: 0.0,
            randomRedeemFee: 0.0,
            targetRedeemFee: 0.0,
            randomSwapFee: 0.0,
            targetSwapFee: 0.0
        )
        self.vaultFees = {}
        self.feeTo = nil
        self.feeRatio = 0.0

        destroy <-self.account.load<@AnyResource>(from: self.ConfigAdminStoragePath)
        self.account.save(<-create Admin(), to: self.ConfigAdminStoragePath)
    }
}