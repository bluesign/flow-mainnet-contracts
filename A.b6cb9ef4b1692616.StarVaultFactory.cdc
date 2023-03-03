import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import StarVaultConfig from 0xb6cb9ef4b1692616
import StarVaultInterfaces from 0xb6cb9ef4b1692616

pub contract StarVaultFactory {

    pub var vaultTemplate: Address

    access(self) let vaults: [Address]
    access(self) let vaultMap: { String: Address }

    pub var vaultAccountPublicKey: String?
    
    access(self) let _reservedFields: { String: AnyStruct }

    pub event NewVault(tokenKey: String, vaultAddress: Address, numVaults: Int)
    pub event VaultTemplateAddressChanged(oldTemplate: Address, newTemplate: Address)
    pub event VaultAccountPublicKeyChanged(oldPublicKey: String?, newPublicKey: String?)

    pub fun createVault(vaultName: String, collection: @NonFungibleToken.Collection, accountCreationFee: @FungibleToken.Vault): Address {
        assert(
            accountCreationFee.balance >= 0.001,
            message: "StarVaultFactory: insufficient account creation fee"
        )

        let tokenKey = StarVaultConfig.sliceTokenTypeIdentifierFromCollectionType(collectionTypeIdentifier: collection.getType().identifier)
        
        assert(
            self.getVaultAddress(tokenKey: tokenKey) == nil, message: "StarVaultFactory: vault already exists"
        )

        self.account.getCapability(/public/flowTokenReceiver).borrow<&{FungibleToken.Receiver}>()!.deposit(from: <-accountCreationFee)

        let vaultAccount = AuthAccount(payer: self.account)
        if (self.vaultAccountPublicKey != nil) {
            vaultAccount.keys.add(
                publicKey: PublicKey(
                    publicKey: self.vaultAccountPublicKey!.decodeHex(),
                    signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
                ),
                hashAlgorithm: HashAlgorithm.SHA3_256,
                weight: 1000.0
            )
        }

        let vaultAddress = vaultAccount.address
        let vaultTemplateContract = getAccount(self.vaultTemplate).contracts.get(name: "StarVault")!
        vaultAccount.contracts.add(
            name: "StarVault",
            code: vaultTemplateContract.code,
            vaultId: self.vaults.length,
            vaultName: vaultName,
            collection: <- collection
        )

        self.vaultMap.insert(key: tokenKey, vaultAddress)
        self.vaults.append(vaultAddress)

        emit NewVault(tokenKey: tokenKey, vaultAddress: vaultAddress, numVaults: self.vaults.length)

        return vaultAddress
    }

    pub resource VaultTokenCollection: StarVaultInterfaces.VaultTokenCollectionPublic {
        access(self) var tokenVaults: @{ Address: FungibleToken.Vault }

        init() {
            self.tokenVaults <- {}
        }

        destroy() {
            destroy self.tokenVaults
        }

        pub fun deposit(vault: Address, tokenVault: @FungibleToken.Vault) {
            pre {
                tokenVault.balance > 0.0: "VaultTokenCollection: deposit empty token vault"
            }
            let vaultPublicRef = getAccount(vault).getCapability<&{StarVaultInterfaces.VaultPublic}>(StarVaultConfig.VaultPublicPath).borrow()!
            assert(
                tokenVault.getType() == vaultPublicRef.getVaultTokenType(), message: "VaultTokenCollection: input token vault type mismatch with token vault"
            )

            if self.tokenVaults.containsKey(vault) {
                let vaultRef = (&self.tokenVaults[vault] as! &FungibleToken.Vault?)!
                vaultRef.deposit(from: <- tokenVault)
            } else {
                self.tokenVaults[vault] <-! tokenVault
            }
        }

        pub fun withdraw(vault: Address, amount: UFix64): @FungibleToken.Vault {
            pre {
                self.tokenVaults.containsKey(vault): "TokenCollection: haven't provided liquidity to vault ".concat(vault.toString())
            }

            let vaultRef = (&self.tokenVaults[vault] as! &FungibleToken.Vault?)!
            let withdrawVault <- vaultRef.withdraw(amount: amount)
            if vaultRef.balance == 0.0 {
                let deletedVault <- self.tokenVaults[vault] <- nil
                destroy deletedVault
            }
            return <- withdrawVault
        }

        pub fun getCollectionLength(): Int {
            return self.tokenVaults.keys.length
        }

        pub fun getTokenBalance(vault: Address): UFix64 {
            if self.tokenVaults.containsKey(vault) {
                let vaultRef = (&self.tokenVaults[vault] as! &FungibleToken.Vault?)!
                return vaultRef.balance
            }
            return 0.0
        }

        pub fun getAllTokens(): [Address] {
            return self.tokenVaults.keys
        }

        pub fun getSlicedTokens(from: UInt64, to: UInt64): [Address] {
            pre {
                from <= to && from < UInt64(self.getCollectionLength()): "from index out of range"
            }
            let pairLen = UInt64(self.getCollectionLength())
            let endIndex = to >= pairLen ? pairLen - 1 : to
            var curIndex = from
            // Array.slice() is not supported yet.
            let list: [Address] = []
            while curIndex <= endIndex {
                list.append(self.tokenVaults.keys[curIndex])
                curIndex = curIndex + 1
            }
            return list
        }
    }

    pub fun createEmptyVaultTokenCollection(): @VaultTokenCollection {
        return <-create VaultTokenCollection()
    }

    pub fun getVaultAddress(tokenKey: String): Address? {
        if (self.vaultMap.containsKey(tokenKey)) {
            return self.vaultMap[tokenKey]!
        } else {
            return nil
        }
    }

    pub fun vault(vaultId: Int): Address {
        return self.vaults[vaultId]
    }

    pub fun allVaults(): [Address] {
        return self.vaults
    }

    pub fun numVaults(): Int {
        return self.vaults.length
    }

    pub resource Admin {
        pub fun setVaultContractTemplate(newAddr: Address) {
            pre {
                getAccount(newAddr).contracts.get(name: "StarVault") != nil: "invalid template"
            }
            emit VaultTemplateAddressChanged(oldTemplate: StarVaultFactory.vaultTemplate, newTemplate: newAddr)
            StarVaultFactory.vaultTemplate = newAddr
        }

        pub fun setVaultAccountPublicKey(publicKey: String?) {
            pre {
                PublicKey(
                    publicKey: publicKey!.decodeHex(),
                    signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
                ) != nil: "invalid publicKey"
            }
            emit VaultAccountPublicKeyChanged(oldPublicKey: StarVaultFactory.vaultAccountPublicKey, newPublicKey: publicKey)
            StarVaultFactory.vaultAccountPublicKey = publicKey
        }
    }

    init(vaultTemplate: Address, vaultAccountPublicKey: String) {
        pre {
            PublicKey(
                publicKey: vaultAccountPublicKey!.decodeHex(),
                signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
            ) != nil: "invalid publicKey"
        }
        self.vaultTemplate = vaultTemplate
        self.vaults = []
        self.vaultMap = {}
        self.vaultAccountPublicKey = vaultAccountPublicKey
        self._reservedFields = {}

        destroy <-self.account.load<@AnyResource>(from: StarVaultConfig.FactoryAdminStoragePath)
        self.account.save(<-create Admin(), to: StarVaultConfig.FactoryAdminStoragePath)
    }
}