import FungibleToken from 0xf233dcee88fe0abe
import FlowToken from 0x1654653399040a61
import SwapConfig from 0xb78ef7afa52ff906
import SwapInterfaces from 0xb78ef7afa52ff906
import SwapFactory from 0xb063c16cac85dbd1
import StarVaultFactory from 0xb6cb9ef4b1692616
import StarVaultConfig from 0xb6cb9ef4b1692616
import StarVaultInterfaces from 0xb6cb9ef4b1692616

pub contract LPStaking {
    
    pub var poolTemplate: Address

    access(self) let pools: [Address]
    access(self) let poolMap: { Int: Address } // vaultId -> pool
    access(self) let pairMap: { Address: Address } // pair -> pool

    pub var poolAccountPublicKey: String?

    access(self) let _reservedFields: { String: AnyStruct }

    pub event NewPool(poolAddress: Address, numPools: Int)
    pub event PoolTemplateAddressChanged(oldTemplate: Address, newTemplate: Address)
    pub event PoolAccountPublicKeyChanged(oldPublicKey: String?, newPublicKey: String?)

    pub fun createPool(vaultAddress: Address, accountCreationFee: @FungibleToken.Vault): Address {
        assert(
            accountCreationFee.balance >= 0.001,
            message: "LPStaking: insufficient account creation fee"
        )

        let vaultRef = getAccount(vaultAddress).getCapability<&AnyResource{StarVaultInterfaces.VaultPublic}>(StarVaultConfig.VaultPublicPath)
            .borrow() ??
            panic("Vault Reference was not created correctly")

        let vaultId = vaultRef.vaultId()
        assert(
            StarVaultFactory.vault(vaultId: vaultId) == vaultAddress, message: "LPStaking: invalid vaultAddress",
            self.getPoolAddress(vaultId: vaultId) == nil, message: "LPStaking: pool already exists"
        )

        let token0Key = StarVaultConfig.SliceTokenTypeIdentifierFromVaultType(vaultTypeIdentifier: Type<@FlowToken.Vault>().identifier)
        let token1Key = StarVaultConfig.SliceTokenTypeIdentifierFromVaultType(vaultTypeIdentifier: vaultRef.getVaultTokenType().identifier)
        let pairAddr = SwapFactory.getPairAddress(token0Key: token0Key, token1Key: token1Key)
            ?? panic("createPool: nonexistent pair ".concat(token0Key).concat(" <-> ").concat(token1Key).concat(", create pair first"))

        assert(
            !self.pairMap.containsKey(pairAddr), message: "LPStaking: pairAddr already exists"
        )

        self.account.getCapability(/public/flowTokenReceiver).borrow<&{FungibleToken.Receiver}>()!.deposit(from: <-accountCreationFee)

        let poolAccount = AuthAccount(payer: self.account)
        if (self.poolAccountPublicKey != nil) {
            poolAccount.keys.add(
                publicKey: PublicKey(
                    publicKey: self.poolAccountPublicKey!.decodeHex(),
                    signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
                ),
                hashAlgorithm: HashAlgorithm.SHA3_256,
                weight: 1000.0
            )
        }

        let poolAddress = poolAccount.address
        let poolTemplateContract = getAccount(self.poolTemplate).contracts.get(name: "RewardPool")!
        poolAccount.contracts.add(
            name: "RewardPool",
            code: poolTemplateContract.code,
            pid: self.pools.length,
            stakeToken: pairAddr
        )

        self.poolMap.insert(key: vaultId, poolAddress)
        self.pairMap.insert(key: pairAddr, poolAddress)
        self.pools.append(poolAddress)

        emit NewPool(poolAddress: poolAddress, numPools: self.pools.length)

        return poolAddress
    }

    pub fun distributeFees(vaultId: Int, vault: @FungibleToken.Vault) {
        pre {
            self.poolMap.containsKey(vaultId): "distributeFees: pool not exists"
        }
        let pool = self.poolMap[vaultId]!
        let poolRef = getAccount(pool).getCapability<&{StarVaultInterfaces.PoolPublic}>(StarVaultConfig.PoolPublicPath).borrow()!
        poolRef.queueNewRewards(vault: <-vault)
    }

    pub resource LPStakingCollection: StarVaultInterfaces.LPStakingCollectionPublic {
        access(self) var tokenVaults: @{ Address: FungibleToken.Vault }

        init() {
            self.tokenVaults <- {}
        }

        destroy() {
            destroy self.tokenVaults
        }

        pub fun deposit(tokenAddress: Address, tokenVault: @FungibleToken.Vault) {
            pre {
                LPStaking.pairMap.containsKey(tokenAddress): "LPStakingCollection: invalid pair address"
                tokenVault.balance > 0.0: "LPStakingCollection: deposit empty token vault"
            }

            let pairRef = getAccount(tokenAddress).getCapability<&{SwapInterfaces.PairPublic}>(SwapConfig.PairPublicPath).borrow()!
            assert(
                tokenVault.getType() == pairRef.getLpTokenVaultType(), message: "LPStakingCollection: input token vault type mismatch with token vault"
            )

            if self.tokenVaults.containsKey(tokenAddress) {
                let vaultRef = (&self.tokenVaults[tokenAddress] as! &FungibleToken.Vault?)!
                vaultRef.deposit(from: <- tokenVault)
            } else {
                self.tokenVaults[tokenAddress] <-! tokenVault
            }

            self.updateReward(tokenAddress: tokenAddress)
        }

        pub fun withdraw(tokenAddress: Address, amount: UFix64): @FungibleToken.Vault {
            pre {
                LPStaking.pairMap.containsKey(tokenAddress): "LPStakingCollection: invalid pair address"
                self.tokenVaults.containsKey(tokenAddress): "LPStakingCollection: haven't provided liquidity to vault"
            }

            let vaultRef = (&self.tokenVaults[tokenAddress] as! &FungibleToken.Vault?)!
            let withdrawVault <- vaultRef.withdraw(amount: amount)
            if vaultRef.balance == 0.0 {
                let deletedVault <- self.tokenVaults[tokenAddress] <- nil
                destroy deletedVault
            }

            self.updateReward(tokenAddress: tokenAddress)
            return <- withdrawVault
        }

        pub fun getCollectionLength(): Int {
            return self.tokenVaults.keys.length
        }

        pub fun getTokenBalance(tokenAddress: Address): UFix64 {
            if self.tokenVaults.containsKey(tokenAddress) {
                let vaultRef = (&self.tokenVaults[tokenAddress] as! &FungibleToken.Vault?)!
                return vaultRef.balance
            }
            return 0.0
        }

        pub fun getAllTokens(): [Address] {
            return self.tokenVaults.keys
        }

        access(self) fun updateReward(tokenAddress: Address) {
            let pool = LPStaking.pairMap[tokenAddress]!
            let poolRef = getAccount(pool).getCapability<&{StarVaultInterfaces.PoolPublic}>(StarVaultConfig.PoolPublicPath).borrow()!
            poolRef.updateReward(account: self.owner!.address)
        }
    }

    pub fun createEmptyLPStakingCollection(): @LPStakingCollection {
        return <-create LPStakingCollection()
    }

    pub fun getPoolAddress(vaultId: Int): Address? {
        if self.poolMap.containsKey(vaultId) {
            return self.poolMap[vaultId]!
        } else {
            return nil
        }
    }

    pub fun pool(pid: Int): Address {
        return self.pools[pid]
    }

    pub fun allPools(): [Address] {
        return self.pools
    }

    pub fun numPools(): Int {
        return self.pools.length
    }

    pub fun getRewards(account: Address, poolIds: [Int]) {
        for pid in poolIds {
            let poolAddress = self.pools[pid]
            let poolRef = getAccount(poolAddress).getCapability<&{StarVaultInterfaces.PoolPublic}>(StarVaultConfig.PoolPublicPath).borrow()!
            poolRef.getReward(account: account)
        }
    }

    pub fun earned(account: Address, poolIds: [Int]): [UFix64] {
        let ret: [UFix64] = []
        for pid in poolIds {
            let poolAddress = self.pools[pid]
            let poolRef = getAccount(poolAddress).getCapability<&{StarVaultInterfaces.PoolPublic}>(StarVaultConfig.PoolPublicPath).borrow()!
            ret.append(poolRef.earned(account: account))
        }
        return ret
    }

    pub resource Admin {
        pub fun setPoolContractTemplate(newAddr: Address) {
            pre {
                getAccount(newAddr).contracts.get(name: "RewardPool") != nil: "invalid template"
            }
            emit PoolTemplateAddressChanged(oldTemplate: LPStaking.poolTemplate, newTemplate: newAddr)
            LPStaking.poolTemplate = newAddr
        }

        pub fun setPoolAccountPublicKey(publicKey: String?) {
            pre {
                PublicKey(
                    publicKey: publicKey!.decodeHex(),
                    signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
                ) != nil: "invalid publicKey"
            }
            emit PoolAccountPublicKeyChanged(oldPublicKey: LPStaking.poolAccountPublicKey, newPublicKey: publicKey)
            LPStaking.poolAccountPublicKey = publicKey
        }
    }

    init(poolTemplate: Address, poolAccountPublicKey: String) {
        pre {
            PublicKey(
                publicKey: poolAccountPublicKey!.decodeHex(),
                signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
            ) != nil: "invalid publicKey"
        }
        self.poolTemplate = poolTemplate
        self.pools = []
        self.poolAccountPublicKey = poolAccountPublicKey
        self.poolMap = {}
        self.pairMap = {}
        self._reservedFields = {}

        destroy <-self.account.load<@AnyResource>(from: StarVaultConfig.LPStakingAdminStoragePath)
        self.account.save(<-create Admin(), to: StarVaultConfig.LPStakingAdminStoragePath)
    }
}