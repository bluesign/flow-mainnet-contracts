import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import FlowToken from 0x1654653399040a61
import NFTCatalog from 0x49a7cda3a1eecc29

pub contract SpaceTradeAssetCatalog {
    pub event ContractInitialized()
    pub let ManagerStoragePath: StoragePath
    priv let nfts: {String: NFTCollectionMetadata}
    priv let fts: {String: FTVaultMetadata}

    pub struct NFTCollectionMetadata {
        // Must be unique for this collection, e.g. ufcInt_NFT
        pub let identifier: String
        // Name is the collection name which we can display to the user, e.g. UFCStrike (corresponds to ufcInt_NFT)
        pub let contractName: String
        pub let publicPath: PublicPath
        pub let privatePath: PrivatePath
        pub let storagePath: StoragePath
        pub let nftType: Type
        pub let publicLinkedType: Type
        pub let privateLinkedType: Type
        pub var supported: Bool

        init(
            identifier: String,
            contractName: String,
            publicPath: PublicPath,
            storagePath: StoragePath,
            privatePath: PrivatePath,
            nftType: Type,
            publicLinkedType: Type,
            privateLinkedType: Type,
            supported: Bool
        ) {
            self.identifier = identifier
            self.contractName = contractName
            self.privatePath = privatePath
            self.publicPath = publicPath
            self.storagePath = storagePath
            self.nftType = nftType
            self.publicLinkedType = publicLinkedType
            self.privateLinkedType = privateLinkedType
            self.supported = supported
        }

        access(contract) fun setSupported(_ supported: Bool) {
            self.supported = supported
        }
    }

    pub struct FTVaultMetadata {
        pub let identifier: String
        pub let contractName: String
        pub let publicReceiverPath: PublicPath
        pub let publicBalancePath: PublicPath
        pub let privatePath: PrivatePath
        pub let storagePath: StoragePath
        pub let vaultType: Type
        pub let publicLinkedReceiverType: Type
        pub let publicLinkedBalanceType: Type
        pub let privateLinkedType: Type
        pub var supported: Bool

        init(
            identifier: String,
            contractName: String,
            publicReceiverPath: PublicPath,
            publicBalancePath: PublicPath,
            storagePath: StoragePath,
            privatePath: PrivatePath,
            vaultType: Type,
            publicLinkedReceiverType: Type,
            publicLinkedBalanceType: Type,
            privateLinkedType: Type,
            supported: Bool
        ) {
            self.identifier = identifier
            self.contractName = contractName
            self.publicReceiverPath = publicReceiverPath
            self.publicBalancePath = publicBalancePath
            self.storagePath = storagePath
            self.privatePath = privatePath
            self.vaultType = vaultType
            self.publicLinkedReceiverType = publicLinkedReceiverType
            self.publicLinkedBalanceType = publicLinkedBalanceType
            self.privateLinkedType = privateLinkedType
            self.supported = supported
        }

        access(contract) fun setSupported(_ supported: Bool) {
            self.supported = supported
        }
    }

    pub resource Manager {

        pub fun upsertNFT(_ nftCollection: NFTCollectionMetadata) {
            SpaceTradeAssetCatalog.nfts.insert(key: nftCollection.identifier, nftCollection)
        }

        pub fun upsertFT(_ ftVault: FTVaultMetadata) {
            SpaceTradeAssetCatalog.fts.insert(key: ftVault.identifier, ftVault)
        }

        pub fun toggleSupportedNFT(_ identifier: String, _ supported: Bool) {
            pre {
                SpaceTradeAssetCatalog.nfts[identifier] != nil
                   : "NFT Collection with given name does not exist"
            }
            let ref = &SpaceTradeAssetCatalog.nfts[identifier]! as &SpaceTradeAssetCatalog.NFTCollectionMetadata
            ref.setSupported(supported)
        }

        pub fun toggleSupportedFT(_ tokenKey: String, _ supported: Bool) {
            pre {
                SpaceTradeAssetCatalog.fts[tokenKey] != nil
                   : "Fungible token with given name does not exist"
            }
            let ref = &SpaceTradeAssetCatalog.fts[tokenKey]! as &SpaceTradeAssetCatalog.FTVaultMetadata
            ref.setSupported(supported)
        }

        pub fun removeFT(_ tokenKey: String) {
            pre {
                SpaceTradeAssetCatalog.fts[tokenKey] != nil
                   : "Fungible token with given name does not exist"
            }
            SpaceTradeAssetCatalog.fts.remove(key: tokenKey)
                    ?? panic("Unable to remove fungible token")
        }

        pub fun removeNFT(_ collectionName: String) {
            pre {
                SpaceTradeAssetCatalog.nfts[collectionName] != nil
                   : "NFT collection with given name does not exist"
            }
            SpaceTradeAssetCatalog.nfts.remove(key: collectionName)
                    ?? panic("Unable to remove NFT collection")
        }
    }

    pub fun isSupportedNFT(_ identifier: String): Bool {
        if let collection = self.nfts[identifier] {
            return collection.supported
        } else {
            // Collection is supported by default if we have not defined it explicitly in this contract
            return self.getNFTCollectionMetadataFromOfficialCatalog(identifier) != nil
        }
    }

    pub fun isSupportedFT(_ tokenKey: String): Bool {
        if let token = self.fts[tokenKey] {
            return token.supported
        } else {
            return false
        }
    }

    pub fun getNumberOfFTs(): Int {
        return self.fts.length
    }

    pub fun getNFTCollectionMetadatas(_ offset: Int, _ limit: Int): { String: NFTCollectionMetadata } {
        let nfts: { String: NFTCollectionMetadata } = {}
        let officialNFTs = NFTCatalog.getCatalog().keys
        var counter = offset
        var offsetTo = offset + limit

        while counter < offsetTo {
            if counter < self.nfts.keys.length {
                let key = self.nfts.keys[counter]
                nfts.insert(key: key, self.nfts[key]!)
            } else if counter - self.nfts.keys.length < officialNFTs.length {
                let identifier = officialNFTs[counter - self.nfts.keys.length]
                // Must use collectionFromOfficialCatalog.key as key because storage iteration also uses the contract name as key
                if !nfts.containsKey(identifier) {
                    let collectionFromOfficialCatalog = self.getNFTCollectionMetadataFromOfficialCatalog(identifier)!
                    nfts.insert(key: collectionFromOfficialCatalog.identifier, collectionFromOfficialCatalog)
                }
            } else {
                break
            }

            counter = counter + 1
        }

        return nfts
    }

    pub fun getFTMetadatas(): {String: FTVaultMetadata} {
        return self.fts
    }

    pub fun getNFTCollectionMetadata(_ identifier: String): NFTCollectionMetadata? {
        return self.nfts[identifier] ?? self.getNFTCollectionMetadataFromOfficialCatalog(identifier) 
    }

    pub fun getFTMetadata(_ tokenKey: String): FTVaultMetadata? {
        return self.fts[tokenKey]
    }

    pub fun getNFTCollectionMetadataFromOfficialCatalog(_ identifier: String): NFTCollectionMetadata? {
        if let collectionFromOfficialCatalog = NFTCatalog.getCatalogEntry(collectionIdentifier: identifier) {
            return NFTCollectionMetadata(
                    identifier: identifier,
                    contractName: collectionFromOfficialCatalog.contractName,
                    publicPath: collectionFromOfficialCatalog.collectionData.publicPath,
                    storagePath: collectionFromOfficialCatalog.collectionData.storagePath,
                    privatePath: collectionFromOfficialCatalog.collectionData.privatePath,
                    nftType: collectionFromOfficialCatalog.nftType,
                    publicLinkedType: collectionFromOfficialCatalog.collectionData.publicLinkedType,
                    privateLinkedType: collectionFromOfficialCatalog.collectionData.privateLinkedType,
                    supported: true
                )
        }
        return nil
    }

    init() {
        self.nfts = {}
        self.fts = {
            "flowToken": SpaceTradeAssetCatalog.FTVaultMetadata(
                identifier: "flowToken",
                contractName: "FlowToken",
                publicReceiverPath:  /public/flowTokenReceiver,
                publicBalancePath: /public/flowTokenBalance,
                storagePath: /storage/flowTokenVault,
                privatePath: /private/flowTokenVault,
                vaultType: Type<@FlowToken.Vault>(),
                publicLinkedReceiverType: Type<&FlowToken.Vault{FungibleToken.Receiver}>(),
                publicLinkedBalanceType: Type<&FlowToken.Vault{FungibleToken.Balance}>(),
                privateLinkedType: Type<@FlowToken.Vault>(),
                supported: true
            )
        }
        self.ManagerStoragePath = /storage/SpaceTradeAssetCatalogStoragePath
        self.account.save(<- create Manager(), to: self.ManagerStoragePath) 
        emit ContractInitialized()
    }
}
 