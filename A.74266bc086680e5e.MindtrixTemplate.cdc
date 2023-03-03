/** 
============================================================
Name: Template Contract for Mindtrix NFT
Author: AS
============================================================

MindtrixTemplate.cdc is a generic version of MindtrixEssence.cdc. 
When creating a template, we do not have to bind an episodeGuid 
like what MindtrixEssence.cdc did, so it's more flexible.
For example, we can create a POAP or custom NFT template for events.

**/

import FungibleToken from 0xf233dcee88fe0abe
import MetadataViews from 0x1d7e57aa55817448
import DapperUtilityCoin from 0xead892083b3e2c6c
import FlowUtilityToken from 0xead892083b3e2c6c
import FlowToken from 0x1654653399040a61
import FiatToken from 0xb19436aae4d94622
import FUSD from 0x3c5959b568896393
import TokenForwarding from 0xe544175ee0461c4b
import Mindtrix from 0x74266bc086680e5e
import MindtrixViews from 0x74266bc086680e5e
import MindtrixEssence from 0x74266bc086680e5e

pub contract MindtrixTemplate {

    // ========================================================
    //                          PATH
    // ========================================================

    pub let MindtrixTemplateAdminStoragePath: StoragePath
    pub let MindtrixTemplateAdminPublicPath: PublicPath
    pub let DucReceiverPublicPath: PublicPath
    pub let FutReceiverPublicPath: PublicPath

    // ========================================================
    //                          EVENT
    // ========================================================
    
    pub event ContractInitialized()
    pub event MindtrixTemplateCreated(templateId: UInt64, paymentType: Type, strMetadata: {String: String}, intMetadata: {String: UInt64})
    pub event MindtrixTemplateLocked(showGuid: String, templateId: UInt64)

    // ========================================================
    //                       MUTABLE STATE
    // ========================================================

    // The dictionary of currency identities to royalties
    pub let MindtrixRoyaltyDic: {String: [MetadataViews.Royalty]}
    pub var nextTemplateId: UInt64
    // to get a list of templates from a creator's show.
    access(self) var showGuidToMindtrixTemplateIds: {String: {UInt64: Bool}}
    access(self) var MindtrixTemplates: {UInt64: MindtrixTemplateStruct}

    // ========================================================
    //               COMPOSITE TYPES: STRUCTURE
    // ========================================================
    pub struct MindtrixTemplateStruct {

        pub let templateId: UInt64
        pub let maxEdition: UInt64
        pub let createdTime: UFix64
        pub var name: String
        pub var description: String
        pub var locked: Bool
        pub var currentEdition: UInt64
        pub var socials: {String: String}
        pub var components: {String: UInt64}
        // default paymentType for secondary markets
        access(account) var paymentType: Type
        access(account) let verifiers: {String: [{MindtrixViews.IVerifier}]}
        // supported paymentType and their prices in Mindtrix primary market
        access(account) var mintPrice: {String: MindtrixViews.FT}
        access(self) let royalties: [MetadataViews.Royalty]
        access(self) var strMetadata: {String: String}
        access(self) var intMetadata: {String: UInt64}
        access(account) var minters: {Address: [MindtrixViews.NFTIdentifier]}

        access(account) fun verifyMintingConditions(recipient: &Mindtrix.Collection{Mindtrix.MindtrixCollectionPublic}, recipientMintQuantityPerTransaction: UInt64): Bool
        {
            var params: {String: AnyStruct} = {}
            let recipientAddress = recipient.owner!.address
            let currentEdition = self.currentEdition
            let identifiers = self.getMintingRecordsByAddress(address: recipientAddress)
            let recipientMaxMintTimesPerAddress =  UInt64(identifiers?.length ?? 0)

            params.insert(key: "currentEdition", currentEdition)
            params.insert(key: "recipientAddress", recipientAddress)
            params.insert(key: "recipientMaxMintTimesPerAddress", recipientMaxMintTimesPerAddress)
            params.insert(key: "recipientMintQuantityPerTransaction", recipientMintQuantityPerTransaction)

            for identifier in self.verifiers.keys {
                let typedModules = (&self.verifiers[identifier] as &[{MindtrixViews.IVerifier}]?)!
                var i = 0
                while i < typedModules.length {
                    let verifier = &typedModules[i] as &{MindtrixViews.IVerifier}
                    verifier.verify(params)
                    i = i + 1
                }
            }
            return true
        }

        access(account) fun updateMinters(nftIdentifier: MindtrixViews.NFTIdentifier) {
            let address = nftIdentifier.holder
            if self.minters[address] == nil {
                var newIdentifiers: [MindtrixViews.NFTIdentifier] = []
                newIdentifiers.append(nftIdentifier)
                self.minters.insert(key: address, newIdentifiers)
            } else {
                let oldIdentifiers: [MindtrixViews.NFTIdentifier] = self.minters[address]!
                oldIdentifiers.append(nftIdentifier)
                self.minters.insert(key: address, oldIdentifiers)
            }
        }

        access(account) fun updateCurrentEdition(newEdition: UInt64){
            self.currentEdition = newEdition
        }

        pub fun getMintingRecordsByAddress(address: Address): [MindtrixViews.NFTIdentifier]? {
            let identifiers: [MindtrixViews.NFTIdentifier]?  = self.minters[address];
            if self.minters[address] == nil {
                return nil
            }
            return identifiers
        }

        pub fun getStrMetadata(): {String: String} {
            return self.strMetadata
        }

        pub fun getIntMetadata(): {String: UInt64} {
            return self.intMetadata
        }

        pub fun lockTemplate() {
            self.locked = true
        }

        pub fun updateStrMetadata(newMetadata: {String: String}) {
            pre {
                newMetadata.length != 0: "New Template metadata cannot be empty"
            }
            self.strMetadata = newMetadata
        }

        pub fun updateIntMetadata(newMetadata: {String: UInt64}) {
            pre {
                newMetadata.length != 0: "New Template metadata cannot be empty"
            }
            self.intMetadata = newMetadata
        }

        pub fun getRoyalties(): [MetadataViews.Royalty]{
            return self.royalties
        }

        pub fun getVerifiers(): [{MindtrixViews.IVerifier}]{
            var verifiers: [{MindtrixViews.IVerifier}] = []
            for key in self.verifiers.keys {
                verifiers.concat(self.verifiers[key]!)
            }
            return verifiers
        }

        pub fun getPaymentType(): Type {
            return self.paymentType
        }

        pub fun getMintPrice(identifier: String): MindtrixViews.FT? {
            if self.mintPrice.keys.length > 0 {
                return self.mintPrice[identifier]
            } else {
                return nil
            }
            
        }

        init(templateId: UInt64, name: String, description: String, strMetadata: {String: String}, intMetadata: {String: UInt64}, maxEdition: UInt64, paymentType: Type, mintPrice: {String: MindtrixViews.FT},
            royalties: [MetadataViews.Royalty], socials: {String: String}, components: {String: UInt64}, verifiers: [{MindtrixViews.IVerifier}]){
            pre {
                strMetadata.length != 0: "New Template metadata cannot be empty"
            }

            let typeToVerifier: {String: [{MindtrixViews.IVerifier}]} = {}
            for verifier in verifiers {
                let identifier = verifier.getType().identifier
                if typeToVerifier[identifier] == nil {
                    typeToVerifier[identifier] = [verifier]
                } else {
                    typeToVerifier[identifier]!.append(verifier)
                }
            }

            royalties.append(MetadataViews.Royalty(
                receiver: MindtrixEssence.MindtrixDaoTreasuryRef,
                cut: 0.05,
                description: "Mindtrix 5% royalty from secondary sales."
                )
            )

            strMetadata.insert(key: "templateId", templateId.toString())
            intMetadata.insert(key: "templateId", templateId)

            self.templateId = templateId
            self.name = name
            self.description= description
            self.strMetadata = strMetadata
            self.intMetadata = intMetadata
            self.locked = false
            self.maxEdition = maxEdition
            self.royalties = royalties
            self.paymentType = paymentType
            self.mintPrice = mintPrice
            self.currentEdition = 0
            self.socials = socials
            self.components = components
            self.verifiers = typeToVerifier
            self.createdTime = getCurrentBlock().timestamp
            self.minters = {}

            let showGuid = strMetadata["showGuid"] ?? panic("Cannot create the template with a nil showGuid.")
            var templateDic: {UInt64: Bool} = MindtrixTemplate.showGuidToMindtrixTemplateIds[showGuid] ?? {}
            templateDic.insert(key: templateId, true)
            
            MindtrixTemplate.showGuidToMindtrixTemplateIds.insert(key: showGuid, templateDic)
            MindtrixTemplate.nextTemplateId = MindtrixTemplate.nextTemplateId + 1

            emit MindtrixTemplateCreated(templateId: self.templateId, paymentType: self.paymentType, strMetadata: self.strMetadata, intMetadata: self.intMetadata)

        } 
    }

    // ========================================================
    //               COMPOSITE TYPES: RESOURCE
    // ========================================================
    // Creators can perform important operations for their own templates.
    pub resource interface AdminPublic {
        pub fun createMindtrixTemplateStruct(name: String, description: String, strMetadata: {String: String}, intMetadata: {String: UInt64}, maxEdition: UInt64, paymentType: Type, mintPrice: {String: MindtrixViews.FT},
            royalties: [MetadataViews.Royalty], socials: {String: String}, components: {String: UInt64}, verifiers: [{MindtrixViews.IVerifier}]) 
        pub fun getOwnedMindtrixTemplateIds(): [UInt64]
        pub fun getLockedTemplateIds(): [UInt64]
        pub fun getAvailableTemplateIds(): [UInt64]
        pub fun lockTemplateById(templateId: UInt64)        
    }

    pub resource Admin : AdminPublic {

        access(account) var ownedTemplateIds: {UInt64: Bool}
        access(account) var lockedTemplateIds: {UInt64: Bool}

        pub fun createMindtrixTemplateStruct(name: String, description: String, strMetadata: {String: String}, intMetadata: {String: UInt64}, maxEdition: UInt64, paymentType: Type, mintPrice: {String: MindtrixViews.FT},
            royalties: [MetadataViews.Royalty], socials: {String: String}, components: {String: UInt64}, verifiers: [{MindtrixViews.IVerifier}]){
            let templateId = MindtrixTemplate.nextTemplateId
            MindtrixTemplate.MindtrixTemplates[templateId] = MindtrixTemplateStruct(
                templateId: templateId,
                name: name,
                description: description,
                strMetadata: strMetadata,
                intMetadata: intMetadata,
                maxEdition: maxEdition,
                paymentType: paymentType,
                mintPrice: mintPrice,
                royalties: royalties,
                socials: socials,
                components: components,
                verifiers: verifiers
            )
            self.ownedTemplateIds.insert(key: templateId, true)
            self.lockedTemplateIds.insert(key: templateId, false)
        }

        pub fun getOwnedMindtrixTemplateIds(): [UInt64] {
            var ids:[UInt64] = []
            for templateId in self.ownedTemplateIds.keys {
                if self.ownedTemplateIds[templateId] ?? false {
                    ids.append(templateId)
                }
            }
            return ids
        }

        pub fun getLockedTemplateIds(): [UInt64] {
            var templateIds: [UInt64] = []
            for id in self.lockedTemplateIds.keys {
                if self.lockedTemplateIds[id] == true {
                    templateIds.append(id)
                }
            }
            return templateIds
        }

        pub fun getAvailableTemplateIds(): [UInt64] {
            var templateIds: [UInt64] = []
            for id in self.lockedTemplateIds.keys {
                if self.lockedTemplateIds[id] == false {
                    templateIds.append(id)
                }
            }
            return templateIds
        }

        pub fun lockTemplateById(templateId: UInt64){
            pre {
                self.lockedTemplateIds[templateId] == nil || self.lockedTemplateIds[templateId] == false:
                    "Cannot lock the template: Template is locked already!"
                self.ownedTemplateIds.containsKey(templateId):
                    "Cannot lock a not yet minted template!"
            }
            let template = MindtrixTemplate.getMindtrixTemplateByTemplateId(templateId: templateId) ?? panic("Cannot get an empty template.")
            template.lockTemplate()
            MindtrixTemplate.updateTemplate(template: template)
            self.lockedTemplateIds.insert(key: templateId, true)
            let showGuid = template.getStrMetadata()["showGuid"] ?? ""

            emit MindtrixTemplateLocked(showGuid: showGuid, templateId: templateId)
            
        }

        init(){
            self.ownedTemplateIds = {}
            self.lockedTemplateIds = {}
        }
    }


    // ========================================================
    //                     PUBLIC FUNCTION
    // ========================================================

    pub fun createAdmin(): @Admin {
        return <- create Admin()
    }

    pub fun getAllMindtrixTemplates(): {UInt64: MindtrixTemplateStruct} {
        return self.MindtrixTemplates
    }

    pub fun getAllMindtrixTemplateIds(): [UInt64] {
        return self.MindtrixTemplates.keys
    }

    pub fun getMindtrixTemplateByTemplateId(templateId: UInt64): MindtrixTemplateStruct? {
        return self.MindtrixTemplates[templateId]
    }

    pub fun getMindtrixTemplatesByShowGuId(showGuid: String, templateTypes: [UInt64], templateStatus: [UInt64]): [MindtrixTemplateStruct] {
        let ids: [UInt64] = MindtrixTemplate.showGuidToMindtrixTemplateIds[showGuid]?.keys ?? []
        var templates: [MindtrixTemplateStruct] = []
        for id in ids {
            let template = 
                self.filterTemplateByTypeAndStatus(
                    template: self.getMindtrixTemplateByTemplateId(templateId: id), templateTypes: templateTypes, templateStatus: templateStatus
                )
            if template != nil {
                templates.append(template!)
            }
        }
        return templates
    }

    pub fun filterTemplateByTypeAndStatus(template: MindtrixTemplateStruct?, templateTypes: [UInt64], templateStatus: [UInt64]): MindtrixTemplateStruct? {
        if template == nil {
            return nil
        }
        let metadata: {String: UInt64} = template!.getIntMetadata()
        let type = metadata["templateType"] ?? 0
        let status = metadata["templateStatus"] ?? 0
        
        if templateTypes.contains(type) && templateStatus.contains(status) {
            return template
        }
        return nil
    }

    pub fun freeMintNFT(recipient: &Mindtrix.Collection{Mindtrix.MindtrixCollectionPublic}, templateId: UInt64){
        pre {
            MindtrixTemplate.MindtrixTemplates.containsKey(templateId): "The contract did not find the template."
            !MindtrixTemplate.MindtrixTemplates[templateId]!.locked : "The template is locked!"
            MindtrixTemplate.MindtrixTemplates[templateId]!.getMintPrice(identifier: DapperUtilityCoin.getType().identifier)!.price <= 0.0 : "You should pay for this NFT!"
        }
        let templateStruct = MindtrixTemplate.getMindtrixTemplateByTemplateId(templateId: templateId)!
        MindtrixTemplate.mintNFTFromTemplate(recipient: recipient, templateStruct: templateStruct)
    }

    // The fun supports USDC, FUSD, FLOW, FUT, DUC payment.
    pub fun buyNFT(recipient: &Mindtrix.Collection{Mindtrix.MindtrixCollectionPublic}, paymentVault: @FungibleToken.Vault, mintPriceUFix64: UFix64, templateId: UInt64, merchantAccount: Address?){
        pre {
            MindtrixTemplate.MindtrixTemplates.containsKey(templateId): "The contract did not find the template."
            !MindtrixTemplate.MindtrixTemplates[templateId]!.locked : "The template is locked!"
            paymentVault.balance >= mintPriceUFix64: "Insufficient payment amount."
            paymentVault.getType().isSubtype(of: Type<@FungibleToken.Vault>()): "The type of payment vault is not a subtype of FungibleToken.Vault.Vault."
        }
        let templateStruct = MindtrixTemplate.MindtrixTemplates[templateId] ?? panic("Cannot find the empty template.")
        let paymentType = paymentVault.getType()
        // default is USDC            
        var merchantReceiverCap: Capability<&{FungibleToken.Receiver}> = MindtrixTemplate.account.getCapability<&FiatToken.Vault{FungibleToken.Receiver}>(FiatToken.VaultReceiverPubPath)

        if paymentType == Type<@FiatToken.Vault>() {
            merchantReceiverCap = MindtrixTemplate.account.getCapability<&FiatToken.Vault{FungibleToken.Receiver}>(FiatToken.VaultReceiverPubPath)
        } else if paymentType == Type<@FUSD.Vault>() {
            merchantReceiverCap = MindtrixTemplate.account.getCapability<&FUSD.Vault{FungibleToken.Receiver}>(/public/fusdReceiver)
        } else if paymentType == Type<@FlowToken.Vault>(){
            merchantReceiverCap = MindtrixTemplate.account.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)                    
        }
        // The following below are Dapper Wallet Payments
        else if paymentType == Type<@FlowUtilityToken.Vault>() {            
            merchantReceiverCap = getAccount(merchantAccount!).getCapability<&{FungibleToken.Receiver}>(MindtrixTemplate.FutReceiverPublicPath)
            assert(merchantReceiverCap.borrow() != nil, message: "Missing or mis-typed merchant FUT receiver")
        } else {
            merchantReceiverCap = getAccount(merchantAccount!).getCapability<&{FungibleToken.Receiver}>(MindtrixTemplate.DucReceiverPublicPath)
            assert(merchantReceiverCap.borrow() != nil, message: "Missing or mis-typed merchant DUC receiver")
        }

        merchantReceiverCap.borrow()!.deposit(from: <- paymentVault)
        MindtrixTemplate.mintNFTFromTemplate(recipient: recipient, templateStruct: templateStruct)
    }

    access(self) fun updateTemplateEditionAndMinters(templateId: UInt64, newEdition: UInt64, nftIdentifier: MindtrixViews.NFTIdentifier){
        let template = MindtrixTemplate.getMindtrixTemplateByTemplateId(templateId: templateId)!
        template.updateCurrentEdition(newEdition: newEdition)
        template.updateMinters(nftIdentifier: nftIdentifier)    
        MindtrixTemplate.updateTemplate(template: template)
    }

    access(self) fun updateTemplate(template: MindtrixTemplateStruct){
        MindtrixTemplate.MindtrixTemplates.insert(key: template.templateId, template)
    }
    
    // should not be called by the public
    access(self) fun mintNFTFromTemplate(recipient: &Mindtrix.Collection{Mindtrix.MindtrixCollectionPublic}, templateStruct: MindtrixTemplateStruct){
        assert(templateStruct.verifyMintingConditions(recipient: recipient, recipientMintQuantityPerTransaction: 1) == true, message: "Cannot pass the minting conditions.");
        let essenceMetadata = templateStruct.getStrMetadata()
        let mintedEdition = templateStruct.currentEdition + 1
        let templateId = templateStruct.templateId
        let strMetadata: {String: String} = {
            "nftName": essenceMetadata["essenceName"] ?? "",
            "nftDescription": essenceMetadata["essenceDescription"] ?? "",
            "essenceId": "",
            "templateId": templateId.toString(),                
            "showGuid": essenceMetadata["showGuid"] ?? "",
            "collectionName": essenceMetadata["collectionName"] ?? "",
            "collectionDescription": essenceMetadata["collectionDescription"] ?? "",
            // collectionExternalURL is the Podcast link from the hosting platform.
            "collectionExternalURL": essenceMetadata["collectionExternalURL"] ?? "",
            "collectionSquareImageUrl": essenceMetadata["collectionSquareImageUrl"] ?? "",
            "collectionSquareImageType": essenceMetadata["collectionSquareImageType"] ?? "",
            "collectionBannerImageUrl": essenceMetadata["collectionBannerImageUrl"] ?? "",
            "collectionBannerImageType": essenceMetadata["collectionBannerImageType"] ?? "",
            // essenceExternalURL is the Essence page from Mindtrix Marketplace.
            "essenceExternalURL": essenceMetadata["essenceExternalURL"] ?? "",
            "episodeGuid": essenceMetadata["episodeGuid"] ?? "",
            "nftExternalURL": essenceMetadata["nftExternalURL"] ?? "",
            "nftFileIPFSCid": essenceMetadata["essenceFileIPFSCid"] ?? "",
            "nftFileIPFSDirectory": essenceMetadata["essenceFileIPFSDirectory"] ?? "",
            "nftFilePreviewUrl": essenceMetadata["essenceFilePreviewUrl"] ?? "",
            // need to pass nftAudioPreviewUrl
            "nftAudioPreviewUrl": essenceMetadata["nftAudioPreviewUrl"] ?? "",
            "nftImagePreviewUrl": essenceMetadata["essenceImagePreviewUrl"] ?? "",
            "nftVideoPreviewUrl": essenceMetadata["essenceVideoPreviewUrl"] ?? "",
            "essenceRealmSerial": essenceMetadata["essenceRealmSerial"] ?? "",
            "essenceTypeSerial": essenceMetadata["essenceTypeSerial"] ?? "",
            "showSerial": essenceMetadata["showSerial"] ?? "",
            "episodeSerial": essenceMetadata["episodeSerial"] ?? "",
            "audioEssenceSerial": essenceMetadata["audioEssenceSerial"] ?? "",
            "nftEditionSerial": mintedEdition.toString(),
            "licenseIdentifier": essenceMetadata["licenseIdentifier"] ?? "",
            "audioStartTime": essenceMetadata["audioStartTime"] ?? "",
            "audioEndTime": essenceMetadata["audioEndTime"] ?? "",
            "fullEpisodeDuration": essenceMetadata["fullEpisodeDuration"] ?? ""
        }

        let intMetadata: {String: UInt64} = {
            "templateId": templateId
        }

        var orgRoyalties = templateStruct.getRoyalties()
        var royaltiesDic: {Address: MetadataViews.Royalty} = {}
        // the royalties address should not be duplicated
        for royalty in orgRoyalties {
            let receipientAddress = royalty.receiver.address
            if !royaltiesDic.containsKey(receipientAddress) {
                royaltiesDic.insert(key: receipientAddress, royalty)
            }
        }
        let newRoyalties = royaltiesDic.values

        let data = Mindtrix.NFTStruct(
            nftId: nil,
            essenceId: templateStruct.templateId,
            nftEdition: mintedEdition,
            currentHolder: recipient.owner!.address,
            createdTime: getCurrentBlock().timestamp,
            royalties: newRoyalties,
            metadata: strMetadata,
            socials: templateStruct.socials,
            components: templateStruct.components
        )
        let nft <- Mindtrix.mintNFT(data: data) as! @Mindtrix.NFT
        let nftIdentifier = MindtrixViews.NFTIdentifier(
            uuid: nft.id,
            serial: nft.data.nftEdition ?? mintedEdition,
            holder: nft.data.currentHolder,
        )
        recipient.deposit(token: <- nft)
        MindtrixTemplate.updateTemplateEditionAndMinters(templateId: templateId, newEdition: mintedEdition, nftIdentifier: nftIdentifier)
    }


    init(){
        
        self.nextTemplateId = 1

        self.showGuidToMindtrixTemplateIds = {}
        self.MindtrixTemplates = {}    

        self.MindtrixTemplateAdminStoragePath = /storage/MindtrixTemplateAdmin
        self.MindtrixTemplateAdminPublicPath = /public/MindtrixTemplateAdmin
        self.DucReceiverPublicPath = /public/dapperUtilityCoinReceiver
        self.FutReceiverPublicPath = /public/flowUtilityTokenReceiver        
        self.MindtrixRoyaltyDic = {}

        var futRoyalties: [MetadataViews.Royalty] = []
        var ducRoyalties: [MetadataViews.Royalty] = []
        ducRoyalties.append(MetadataViews.Royalty(
            receiver: self.account.getCapability<&TokenForwarding.Forwarder{FungibleToken.Receiver}>(self.DucReceiverPublicPath),
            cut: 0.05,
            description: "Mindtrix 5% $DUC royalty from secondary sales."
        ))

        futRoyalties.append(MetadataViews.Royalty(
            receiver: self.account.getCapability<&TokenForwarding.Forwarder{FungibleToken.Receiver}>(self.FutReceiverPublicPath),
            cut: 0.05,
            description: "Mindtrix 5% $FUT royalty from secondary sales."
        ))

        self.MindtrixRoyaltyDic.insert(key: DapperUtilityCoin.getType().identifier, ducRoyalties)
        self.MindtrixRoyaltyDic.insert(key: FlowUtilityToken.getType().identifier, futRoyalties)

        emit ContractInitialized()
    }

}
 