import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448

pub contract interface StarVaultInterfaces {

    pub resource interface VaultPublic {
        pub fun vaultId(): Int

        pub fun base(): UFix64

        pub fun mint(nfts: @[NonFungibleToken.NFT], feeVault: @FungibleToken.Vault): @[AnyResource]

        pub fun redeem(
            amount: Int,
            vault: @FungibleToken.Vault,
            specificIds: [UInt64],
            feeVault: @FungibleToken.Vault
        ): @[AnyResource]

        pub fun swap(
            nfts: @[NonFungibleToken.NFT],
            specificIds: [UInt64],
            feeVault: @FungibleToken.Vault
        ): @[AnyResource]

        pub fun getVaultTokenType(): Type

        pub fun allHoldings(): [UInt64]

        pub fun totalHoldings(): Int

        pub fun createEmptyVault(): @FungibleToken.Vault

        pub fun vaultName(): String

        pub fun collectionKey(): String

        pub fun totalSupply(): UFix64
    }

    pub resource interface VaultAdmin {
        pub fun setVaultFeatures(
            enableMint: Bool,
            enableRandomRedeem: Bool,
            enableTargetRedeem: Bool,
            enableRandomSwap: Bool,
            enableTargetSwap: Bool
        )

        pub fun mint(amount: UFix64): @FungibleToken.Vault

        pub fun setVaultName(vaultName: String)
    }

    pub resource interface VaultTokenCollectionPublicv1 {
        pub fun deposit(vault: Address, tokenVault: @FungibleToken.Vault)
        pub fun getCollectionLength(): Int
        pub fun getTokenBalance(vault: Address): UFix64
        pub fun getAllTokens(): [Address]
        pub fun getSlicedTokens(from: UInt64, to: UInt64): [Address]
    }

    pub resource interface VaultTokenCollectionPublic {
        pub fun deposit(vault: Address, tokenVault: @FungibleToken.Vault)
        pub fun withdraw(vault: Address, amount: UFix64): @FungibleToken.Vault
        pub fun getCollectionLength(): Int
        pub fun getTokenBalance(vault: Address): UFix64
        pub fun getAllTokens(): [Address]
        pub fun getSlicedTokens(from: UInt64, to: UInt64): [Address]
    }

    pub resource interface PoolPublic {
        pub fun pid(): Int

        pub fun stakeToken(): Address

        pub fun duration(): UFix64

        pub fun periodFinish(): UFix64

        pub fun rewardRate(): UFix64

        pub fun lastUpdateTime(): UFix64

        pub fun rewardPerTokenStored(): UFix64

        pub fun queuedRewards(): UFix64

        pub fun currentRewards(): UFix64

        pub fun historicalRewards(): UFix64

        pub fun totalSupply(): UFix64

        pub fun balanceOf(account: Address): UFix64

        pub fun updateReward(account: Address?)

        pub fun lastTimeRewardApplicable(): UFix64

        pub fun rewardPerToken(): UFix64

        pub fun earned(account: Address): UFix64

        pub fun getReward(account: Address)

        pub fun queueNewRewards(vault: @FungibleToken.Vault)
    }

    pub resource interface LPStakingCollectionPublic {
        pub fun deposit(tokenAddress: Address, tokenVault: @FungibleToken.Vault)

        pub fun getCollectionLength(): Int

        pub fun getTokenBalance(tokenAddress: Address): UFix64

        pub fun getAllTokens(): [Address]
    }
}