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
        pub let name: String
        pub let publicPath: PublicPath
        pub let privatePath: PrivatePath
        pub let storagePath: StoragePath
        pub let nftType: Type
        pub let publicLinkedType: Type
        pub let privateLinkedType: Type
        pub var supported: Bool

        init(
            name: String,
            publicPath: PublicPath,
            storagePath: StoragePath,
            privatePath: PrivatePath,
            nftType: Type,
            publicLinkedType: Type,
            privateLinkedType: Type,
            supported: Bool
        ) {
            self.name = name
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
        pub let name: String
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
            name: String,
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
            self.name = name
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
            SpaceTradeAssetCatalog.nfts.insert(key: nftCollection.name, nftCollection)
        }

        pub fun upsertFT(_ ftVault: FTVaultMetadata) {
            SpaceTradeAssetCatalog.fts.insert(key: ftVault.name, ftVault)
        }

        pub fun toggleSupportedNFT(_ collectionName: String, _ supported: Bool) {
            pre {
                SpaceTradeAssetCatalog.nfts[collectionName] != nil
                   : "NFT Collection with given name does not exist"
            }
            let ref = &SpaceTradeAssetCatalog.nfts[collectionName]! as &SpaceTradeAssetCatalog.NFTCollectionMetadata
            ref.setSupported(supported)
        }

        pub fun toggleSupportedFT(_ tokenName: String, _ supported: Bool) {
            pre {
                SpaceTradeAssetCatalog.fts[tokenName] != nil
                   : "Fungible token with given name does not exist"
            }
            let ref = &SpaceTradeAssetCatalog.fts[tokenName]! as &SpaceTradeAssetCatalog.FTVaultMetadata
            ref.setSupported(supported)
        }

        pub fun removeFT(_ tokenName: String) {
            pre {
                SpaceTradeAssetCatalog.fts[tokenName] != nil
                   : "Fungible token with given name does not exist"
            }
            SpaceTradeAssetCatalog.fts.remove(key: tokenName)
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

    pub fun isSupportedNFT(_ collectionName: String): Bool {
        if let collection = self.nfts[collectionName] {
            return collection.supported
        } else {
            // Collection is supported by default if we have not defined it explicitly in this contract
            return self.getNFTCollectionMetadataFromOfficialCatalog(collectionName) != nil
        }
    }

    pub fun isSupportedFT(_ tokenName: String): Bool {
        if let token = self.fts[tokenName] {
            return token.supported
        } else {
            return false
        }
    }

    pub fun getNumberOfNFTCollections(): Int {
        let ourNFTs = self.nfts.keys
        let officialNFTs = NFTCatalog.getCatalog().keys
        return ourNFTs.length + officialNFTs.length
    }

    pub fun getNumberOfFTs(): Int {
        return self.fts.length
    }

    pub fun getNFTCollectionMetadatas(_ offset: Int, _ limit: Int): { String: NFTCollectionMetadata } {
        let nfts: { String: NFTCollectionMetadata } = {}

        let ourNFTs = self.nfts
        let officialNFTs = NFTCatalog.getCatalog().keys


        var counter = offset
        var offsetTo = offset + limit

        while counter < offsetTo {
            if counter < ourNFTs.keys.length {
                let key = ourNFTs.keys[counter]
                nfts.insert(key: key, ourNFTs[key]!)
            } else if counter - ourNFTs.keys.length < officialNFTs.length {
                let key = officialNFTs[counter - ourNFTs.keys.length]
                if nfts[key] == nil {
                    nfts.insert(key: key, self.getNFTCollectionMetadataFromOfficialCatalog(key)!)
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

    pub fun getNFTCollectionMetadata(_ collectionName: String): NFTCollectionMetadata? {
        return self.nfts[collectionName] ?? self.getNFTCollectionMetadataFromOfficialCatalog(collectionName) 
    }

    pub fun getFTMetadata(_ tokenName: String): FTVaultMetadata? {
        return self.fts[tokenName]
    }

    priv fun getNFTCollectionMetadataFromOfficialCatalog(_ collectionName: String): NFTCollectionMetadata? {
        if let collectionFromOfficialCatalog = NFTCatalog.getCatalogEntry(collectionIdentifier: collectionName) {
            return NFTCollectionMetadata(
                    name: collectionFromOfficialCatalog.contractName,
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
            "FlowToken": SpaceTradeAssetCatalog.FTVaultMetadata(
                name: "FlowToken",
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
 