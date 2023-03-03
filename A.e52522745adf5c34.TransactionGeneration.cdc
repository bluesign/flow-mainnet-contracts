import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import NFTCatalog from 0x49a7cda3a1eecc29
import StringUtils from 0xe52522745adf5c34
import ArrayUtils from 0xe52522745adf5c34
import NFTStorefrontV2 from 0x4eb8a10cb9f87357
import TransactionGenerationUtils from 0xe52522745adf5c34
import TransactionTemplates from 0xe52522745adf5c34
import TokenForwarding from 0xe544175ee0461c4b

// TransactionGeneration
//
// An entrance point to generating transactions with the nft and ft
// catalog related collections
//
// To add a new transaction, add to the `getSupportedTx()` returned list
// and add a new switch case for your template within the `getTx` function
//

pub contract TransactionGeneration {

    pub fun createTxFromSchemas(
        nftSchema: TransactionGenerationUtils.NFTSchema?,
        ftSchema: TransactionGenerationUtils.FTSchemaV2?,
        createTxCode: ((TransactionGenerationUtils.NFTSchema?,TransactionGenerationUtils.FTSchemaV2?): String),
        importTypes: [Type]
    ) : String? {
        let imports = TransactionGenerationUtils.createImports(imports: importTypes)
        let tx = createTxCode(nftSchema, ftSchema)
        return StringUtils.join([imports, tx!], "\n")
    }

    pub fun getSupportedTx(): [String] {
        return [
            "CollectionInitialization",
            "StorefrontListItem",
            "StorefrontBuyItem",
            "StorefrontRemoveItem",
            "DapperBuyNFTMarketplace",
            "DapperCreateListing",
            "DapperBuyNFTDirect"
        ]
    }

    pub fun getSupportedScripts(): [String] {
        return [
            "DapperGetPrimaryListingMetadata",
            "DapperGetSecondaryListingMetadata"
        ]
    }

    pub fun getTx(tx: String, params: {String: String}): String? {
        let collectionIdentifier = params["collectionIdentifier"]
        let vaultIdentifier = params["vaultIdentifier"]
        
        var nftSchema: TransactionGenerationUtils.NFTSchema? = nil
        var ftSchema: TransactionGenerationUtils.FTSchemaV2? = nil
        
        // Composition of all imports that are needed for the given transaction
        var importTypes: [Type] = []

        var nftImportTypes: [Type] = []
        var ftImportTypes: [Type] = []
        var storefrontTypes: [Type] = [ Type<NFTStorefrontV2>() ]
        var tokenForwardingTypes: [Type] = [ Type<TokenForwarding>() ]

        // This createTxCode function will get overrode, and utilized towards the end.
        // If we're unable to override this function due to not having a relevant template,
        // the function will not continue, and will just return nil
        var createTxCode: ((TransactionGenerationUtils.NFTSchema?,TransactionGenerationUtils.FTSchemaV2?): String) = (
            fun (nftSchema: TransactionGenerationUtils.NFTSchema?,ftSchema: TransactionGenerationUtils.FTSchemaV2?): String {
                return ""
            }
        )

        if (collectionIdentifier != nil) {
            nftSchema = TransactionGenerationUtils.getNftSchema(collectionIdentifier: collectionIdentifier!)
            nftImportTypes = [
                nftSchema!.type,
                nftSchema!.publicLinkedType,
                nftSchema!.privateLinkedType,
                Type<NonFungibleToken>(),
                Type<MetadataViews>()
            ]
        }
        if (vaultIdentifier != nil) {
            ftSchema = TransactionGenerationUtils.getFtSchema(vaultIdentifier: vaultIdentifier!)
            ftImportTypes = [
                ftSchema!.type,
                ftSchema!.publicLinkedType,
                ftSchema!.privateLinkedType,
                Type<FungibleToken>()
            ]
        }

        switch tx {
            case "CollectionInitialization":
                createTxCode = (fun (nftSchema: TransactionGenerationUtils.NFTSchema?,ftSchema: TransactionGenerationUtils.FTSchemaV2?): String {
                    return TransactionTemplates.NFTInitTemplate(nftSchema: nftSchema, ftSchema: nil)
                })
                importTypes = nftImportTypes
            case "StorefrontListItem":
                createTxCode = (fun (nftSchema: TransactionGenerationUtils.NFTSchema?,ftSchema: TransactionGenerationUtils.FTSchemaV2?): String {
                    return TransactionTemplates.StorefrontListItemTemplate(nftSchema: nftSchema, ftSchema: ftSchema)
                })
                importTypes = nftImportTypes.concat(ftImportTypes).concat(storefrontTypes)
            case "StorefrontBuyItem":
                createTxCode = (fun (nftSchema: TransactionGenerationUtils.NFTSchema?,ftSchema: TransactionGenerationUtils.FTSchemaV2?): String {
                    return TransactionTemplates.StorefrontBuyItemTemplate(nftSchema: nftSchema, ftSchema: ftSchema)
                })
                importTypes = nftImportTypes.concat(ftImportTypes).concat(storefrontTypes)
            case "StorefrontRemoveItem":
                createTxCode = (fun (nftSchema: TransactionGenerationUtils.NFTSchema?,ftSchema: TransactionGenerationUtils.FTSchemaV2?): String {
                    return TransactionTemplates.StorefrontRemoveItemTemplate(nftSchema: nftSchema, ftSchema: ftSchema)
                })
                importTypes = storefrontTypes
            case "DapperBuyNFTMarketplace":
                createTxCode = (fun (nftSchema: TransactionGenerationUtils.NFTSchema?,ftSchema: TransactionGenerationUtils.FTSchemaV2?): String {
                    return TransactionTemplates.DapperBuyNFTMarketplaceTemplate(nftSchema: nftSchema, ftSchema: ftSchema)
                })
                importTypes = nftImportTypes.concat(ftImportTypes).concat(storefrontTypes)
            case "DapperCreateListing":
                createTxCode = (fun (nftSchema: TransactionGenerationUtils.NFTSchema?,ftSchema: TransactionGenerationUtils.FTSchemaV2?): String {
                    return TransactionTemplates.DapperCreateListingTemplate(nftSchema: nftSchema, ftSchema: ftSchema)
                })
                importTypes = nftImportTypes.concat(ftImportTypes).concat(storefrontTypes).concat(tokenForwardingTypes)
            case "DapperBuyNFTDirect":
                createTxCode = (fun (nftSchema: TransactionGenerationUtils.NFTSchema?,ftSchema: TransactionGenerationUtils.FTSchemaV2?): String {
                    return TransactionTemplates.DapperBuyNFTDirectTemplate(nftSchema: nftSchema, ftSchema: ftSchema)
                })
                importTypes = nftImportTypes.concat(ftImportTypes).concat(storefrontTypes)
            case "DapperGetPrimaryListingMetadata":
                createTxCode = (fun (nftSchema: TransactionGenerationUtils.NFTSchema?,ftSchema: TransactionGenerationUtils.FTSchemaV2?): String {
                    return TransactionTemplates.DapperGetPrimaryListingMetadataTemplate(nftSchema: nftSchema, ftSchema: ftSchema)
                })
                importTypes = nftImportTypes.concat(storefrontTypes)
            case "DapperGetSecondaryListingMetadata":
                createTxCode = (fun (nftSchema: TransactionGenerationUtils.NFTSchema?,ftSchema: TransactionGenerationUtils.FTSchemaV2?): String {
                    return TransactionTemplates.DapperGetSecondaryListingMetadataTemplate(nftSchema: nftSchema, ftSchema: ftSchema)
                })
                importTypes = nftImportTypes.concat(storefrontTypes)
            default:
                return nil
        }

        return self.createTxFromSchemas(
            nftSchema: nftSchema,
            ftSchema: ftSchema,
            createTxCode: createTxCode,
            importTypes: importTypes
        )
    }

    init() {}
}