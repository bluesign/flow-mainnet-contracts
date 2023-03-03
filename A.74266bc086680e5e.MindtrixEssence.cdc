import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import MindtrixViews from 0x74266bc086680e5e

pub contract MindtrixEssence {

    // ========================================================
    //                          PATH
    // ========================================================

    pub let MindtrixEssenceV2CollectionStoragePath: StoragePath
    pub let MindtrixEssenceV2CollectionPublicPath: PublicPath

    // ========================================================
    //                          EVENT
    // ========================================================

    pub event EssenceCreated(offChainedId: String, essenceId: UInt64, essenceName: String, essenceDescription: String, showGuid: String, episodeGuid: String, audioStartTime: String, audioEndTime: String, fullEpisodeDuration: String, essenceFileIPFSUrl: String, externalURL: String)
    pub event NFTFreeMinted(essenceId: UInt64, minter: Address, essenceName: String, essenceDescription: String, essenceFileIPFSCid: String, essenceFileIPFSDirectory: String)

    // ========================================================
    //                       MUTABLE STATE
    // ========================================================
     pub var totalSupply: UInt64
    access(self) var showGuidToEssenceIds: {String: {UInt64: Bool}}
    access(self) var episodeGuidToEssenceIds: {String: {UInt64: Bool}}
    access(self) var essenceDic: @{UInt64: EssenceRes}
    access(self) var essenceIdsToCreationIds: {UInt64: {UInt64: Bool}}

    // ========================================================
    //                      IMMUTABLE STATE
    // ========================================================
    pub let MindtrixDaoTreasuryRef: Capability<&AnyResource{FungibleToken.Receiver}>

    // ========================================================
    //               COMPOSITE TYPES: STRUCTURE
    // ========================================================

    pub struct EssenceStruct {
         // Store who minted NFT from this essence.
        access(account) var minters: {Address: [MindtrixViews.NFTIdentifier]}

        pub let essenceId: UInt64
        pub let essenceOffChainId: String

        pub let maxEdition: UInt64
        pub var currentEdition: UInt64
        access(account) var essenceClaimable: Bool
        pub let createdTime: UFix64

        access(account) var mintPrices: {String: MindtrixViews.FT}?

        access(self) let royalties: [MetadataViews.Royalty]
        access(account) var metadata: {String: String}
        pub var socials: {String: String}

        pub var components: {String: UInt64}
        access(account) let verifiers: {String: [{MindtrixViews.IVerifier}]}

        pub fun getMetadata(): {String: String} {
            return self.metadata
        }

        pub fun getMintPrice(): {String: MindtrixViews.FT}? {
            if let mintPrices = self.mintPrices {
                return mintPrices
            }
            return nil
        }

        pub fun getRoyalties(): [MetadataViews.Royalty]{
            return self.royalties
        }

        pub fun getVerifiers(): {String: [{MindtrixViews.IVerifier}]} {
            return self.verifiers
        }

        pub fun getEssenceClaimable(): Bool{
            return self.essenceClaimable
        }

        pub fun getAudioEssence(): MindtrixViews.AudioEssence {
            return MindtrixViews.AudioEssence(
                startTime: self.metadata["audioStartTime"] ?? "0",
                endTime: self.metadata["audioEndTime"] ?? "0",
                fullEpisodeDuration: self.metadata["fullEpisodeDuration"] ?? "0"
            )
        }

        pub fun getMintingRecordsByAddress(address: Address): [MindtrixViews.NFTIdentifier]? {
            let identifiers: [MindtrixViews.NFTIdentifier]?  = self.minters[address];
            if self.minters[address] == nil {
                return nil
            }
            return identifiers
        }

        access(account) fun updateMetadata(newMetadata: {String: String}) {
            log("EssenceStruct -> newMetadata:")
            log(newMetadata)
            for key in newMetadata.keys {
                log("key:".concat(key))
                let data = newMetadata[key] ?? ""
                log("data:".concat(data))
                if self.metadata.containsKey(key) {
                    self.metadata[key] = data
                } else {
                    self.metadata.insert(key: key, data)
                }
            }
            log("after metadata:")
            log(self.metadata)
        }

        access(account) fun updateMinters(address: Address, nftIdentifier: MindtrixViews.NFTIdentifier) {

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

        access(account) fun updatePreviewURL(essenceVideoPreviewUrl: String, essenceImagePreviewUrl: String){
            self.metadata["essenceVideoPreviewUrl"] = essenceVideoPreviewUrl
            self.metadata["essenceImagePreviewUrl"] = essenceImagePreviewUrl
        }

        access(account) fun updateEssenceClaimable(claimable: Bool) {
            self.essenceClaimable = claimable
        }

        // whenever minting a NFT, the currentEdition should be added by one
        access(account) fun increaseCurrentEditionByOne() {
            self.currentEdition = self.currentEdition + 1
        }

        access(account) fun verifyMintingConditions(
            recipient: &{NonFungibleToken.CollectionPublic},
            essenceStruct: MindtrixEssence.EssenceStruct): Bool
        {
            var params: {String: AnyStruct} = {}
            let recipientAddress = recipient.owner!.address
            let currentEdition = essenceStruct.currentEdition
            let identifiers = essenceStruct.getMintingRecordsByAddress(address: recipientAddress)
            let recipientMintTimes =  UInt64(identifiers?.length ?? 0)

            params.insert(key: "currentEdition", currentEdition)
            params.insert(key: "recipientAddress", recipientAddress)
            params.insert(key: "recipientMintTimes", recipientMintTimes)

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

        init(
            essenceId: UInt64,
            essenceOffChainId: String,
            essenceClaimable: Bool,
            maxEdition: UInt64,
            currentEdition: UInt64,
            createdTime: UFix64,
            mintPrices: {String: MindtrixViews.FT}?,
            royalties: [MetadataViews.Royalty],
            metadata: {String: String},
            socials: {String: String},
            components: {String: UInt64},
            verifiers: {String: [{MindtrixViews.IVerifier}]}
            ) {
            royalties.append(MetadataViews.Royalty(
                receiver: MindtrixEssence.MindtrixDaoTreasuryRef,
                cut: 0.05,
                description: "Mindtrix 5% royalty from secondary sales."
                )
            )

            log("create essence royalties:")
            log(royalties)

            self.minters = {}
            self.essenceId = essenceId
            self.essenceOffChainId = essenceOffChainId
            self.essenceClaimable = essenceClaimable
            self.maxEdition = maxEdition
            self.currentEdition = currentEdition
            self.createdTime = createdTime
            self.mintPrices = mintPrices
            self.royalties = royalties
            self.metadata = metadata
            self.socials = socials
            self.components = components
            self.verifiers = verifiers
        }
    }

    // ========================================================
    //               COMPOSITE TYPES: RESOURCE
    // ========================================================

    // EssencePublic is only for public usage, and it should not be authorized to change any metadata
    pub resource interface EssencePublic {
        pub var data: EssenceStruct

        access(account) fun updateMetadata(newMetadata: {String: String})
        access(account) fun updatePreviewURL(essenceVideoPreviewUrl: String?, essenceImagePreviewUrl: String?)
        access(account) fun updateMinters(address: Address, nftIdentifier: MindtrixViews.NFTIdentifier)

        pub fun getPrices(): {String: MindtrixViews.FT}?
        pub fun resolveView(_ view: Type): AnyStruct?
        pub fun increaseCurrentEditionByOne()
    }

    pub resource EssenceRes: EssencePublic, MetadataViews.Resolver {

        pub var data: EssenceStruct

        access(account) fun updateMetadata(newMetadata: {String: String}) {
            self.data.updateMetadata(newMetadata: newMetadata)
        }

        access(account) fun updateMinters(address: Address, nftIdentifier: MindtrixViews.NFTIdentifier) {
            self.data.updateMinters(address: address, nftIdentifier: nftIdentifier)
        }

        access(account) fun updatePreviewURL(essenceVideoPreviewUrl: String?, essenceImagePreviewUrl: String?){
            self.data.updatePreviewURL(
                essenceVideoPreviewUrl: essenceVideoPreviewUrl ?? "",
                essenceImagePreviewUrl: essenceImagePreviewUrl ?? ""
            );
        }

        access(account) fun updateEssenceClaimable(claimable: Bool) {
            self.data.updateEssenceClaimable(claimable: claimable)
        }

        pub fun getEssenceClaimable(): Bool {
            return self.data.getEssenceClaimable()
        }

        pub fun getPrices(): {String: MindtrixViews.FT}? {
            if let prices = self.data.mintPrices {
                return prices
            }
            return nil
        }

        pub fun getViews(): [Type] {
             return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.IPFSFile>(),
                Type<MetadataViews.License>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Medias>(),
                Type<MetadataViews.Traits>(),
                Type<MindtrixViews.AudioEssence>(),
                Type<MindtrixViews.Serials>(),
                Type<MindtrixViews.EssenceIdentifier>()
            ]
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    return MetadataViews.Display(
                        name: self.data.metadata["essenceName"]!,
                        description: self.data.metadata["essenceDescription"]!,
                        thumbnail: MetadataViews.IPFSFile(cid: self.data.metadata["essenceImagePreviewUrl"]!, path: nil)
                    )
                case Type<MetadataViews.ExternalURL>():
                    // the URL will be replaced with a gallery link in the future.
                    return MetadataViews.ExternalURL(self.data.metadata["essenceExternalURL"]!)
                case Type<MetadataViews.Editions>():
                    // There is no max number of NFTs that can be minted from this contract
                    // so the max edition field value is set to nil
                    let editionInfo = MetadataViews.Edition(
                        name: self.data.metadata["essenceName"],
                        number: self.data.currentEdition,
                        max: self.data.maxEdition
                    )
                    let editionList: [MetadataViews.Edition] = [editionInfo]
                    return MetadataViews.Editions(editionList)
                case Type<MindtrixViews.AudioEssence>():
                    return self.data.getAudioEssence()
                case Type<MetadataViews.Serial>():
                    return MetadataViews.Serial(self.data.currentEdition)
                case Type<MindtrixViews.Serials>():
                    return MindtrixViews.Serials(self.getSerialDic())
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(self.data.getRoyalties())
                case Type<MetadataViews.IPFSFile>():
                    return MetadataViews.IPFSFile(
                        cid: self.data.metadata["essenceFileIPFSCid"] ?? "",
                        path: self.data.metadata["essenceFileIPFSDirectory"] ?? ""
                    )
                case Type<MetadataViews.License>():
                    return MetadataViews.License(self.data.metadata["licenseIdentifier"] ?? "CC-BY-NC-4.0")
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let squareImage = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(url: self.data.metadata["collectionSquareImageUrl"] ?? ""),
                        mediaType: self.data.metadata["collectionSquareImageType"] ?? ""
                    )
                    let bannerImage = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(url: self.data.metadata["collectionBannerImageUrl"] ?? ""),
                        mediaType: self.data.metadata["collectionBannerImageType"] ?? ""
                    )
                    var socials = {} as {String: MetadataViews.ExternalURL }
                    for key in self.data.socials.keys {
                        let socialUrl = self.data.socials[key]!
                        socials.insert(key: key, MetadataViews.ExternalURL(socialUrl))
                    }
                    return MetadataViews.NFTCollectionDisplay(
                        name: self.data.metadata["collectionName"] ?? "",
                        description: self.data.metadata["collectionDescription"] ?? "",
                        externalURL: MetadataViews.ExternalURL(self.data.metadata["collectionExternalURL"] ?? ""),
                        squareImage: squareImage,
                        bannerImage: bannerImage,
                        socials: socials
                    )
                case Type<MindtrixViews.EssenceIdentifier>():
                    return MindtrixViews.EssenceIdentifier(
                            uuid: self.uuid,
                            serials: MindtrixViews.Serials(self.getSerialDic()).arr,
                            holder: MindtrixEssence.account.address,
                            showGuid: self.data.metadata["showGuid"] ?? "",
                            episodeGuid: self.data.metadata["episodeGuid"] ?? "",
                            createdTime: self.data.createdTime
                        )
                case Type<MindtrixViews.Prices>():
                    return self.getPrices()
                case Type<MetadataViews.Medias>():
                    let videoPreviewMedia = MetadataViews.Media(
                            file: MetadataViews.HTTPFile(
                                url: self.data.metadata["essenceVideoPreviewUrl"] ?? ""),
                                mediaType: "video/mp4")
                    let imagePreviewMedia = MetadataViews.Media(
                            file: MetadataViews.HTTPFile(
                                url: self.data.metadata["essenceImagePreviewUrl"] ?? ""),
                                mediaType: "image/jpg")
                    let medias: [MetadataViews.Media] = [videoPreviewMedia, imagePreviewMedia]
                    return MetadataViews.Medias(medias)
                case Type<MetadataViews.Traits>():
                    let traitsView = MetadataViews.Traits([])

                    // mintedTime is a unix timestamp, we mark it with a Date displayType so platforms know how to show it.
                    let audioEssence = self.data.getAudioEssence()

                    let mintedTimeTrait = MetadataViews.Trait(name: "mintedTime", value: self.data.createdTime, displayType: "Date", rarity: nil)
                    let audioEssenceStartTimeTrait = MetadataViews.Trait(name: "audioEssenceStartTime", value: audioEssence.startTime, displayType: "Time", rarity: nil)
                    let audioEssenceEndTimeTrait = MetadataViews.Trait(name: "audioEssenceEndTime", value: audioEssence.endTime, displayType: "Time", rarity: nil)
                    let fullEpisodeDurationTrait = MetadataViews.Trait(name: "fullEpisodeDuration", value: audioEssence.fullEpisodeDuration, displayType: "Time", rarity: nil)

                    traitsView.addTrait(mintedTimeTrait)
                    traitsView.addTrait(audioEssenceStartTimeTrait)
                    traitsView.addTrait(audioEssenceEndTimeTrait)
                    traitsView.addTrait(fullEpisodeDurationTrait)

                    return traitsView
            }

            return nil
        }

        pub fun getSerialDic(): {String: String} {
            return {
                "essenceRealmSerial": self.data.metadata["essenceRealmSerial"] ?? "0",
                "essenceTypeSerial": self.data.metadata["essenceTypeSerial"] ?? "0",
                "showSerial": self.data.metadata["showSerial"] ?? "0",
                "episodeSerial": self.data.metadata["episodeSerial"] ?? "0", // the index from the minted episode
                "audioEssenceSerial": self.data.metadata["audioEssenceSerial"] ?? "0",
                "nftEditionSerial": self.data.currentEdition.toString()
            }
        }

        pub fun increaseCurrentEditionByOne(){
            self.data.increaseCurrentEditionByOne()
        }

        init(
            essenceOffChainId: String,
            maxEdition: UInt64,
            mintPrices: {String: MindtrixViews.FT}?,
            royalties: [MetadataViews.Royalty],
            metadata: {String: String},
            socials: {String: String},
            verifiers: {String: [{MindtrixViews.IVerifier}]},
            components: {String: UInt64},
        ) {

            let essenceId = self.uuid

            let essenceStruct = EssenceStruct(
                essenceId: essenceId,
                essenceOffChainId: essenceOffChainId,
                essenceClaimable: true,
                maxEdition: maxEdition,
                currentEdition: 0,
                createdTime: getCurrentBlock().timestamp,
                mintPrices: mintPrices,
                royalties: royalties,
                metadata: metadata,
                socials: socials,
                components: components,
                verifiers: verifiers
            )

            self.data = essenceStruct

            // update global records

            var essenceIdDic =  {} as {UInt64: Bool}
            essenceIdDic.insert(key: essenceId, true)

            let showGuid = metadata["showGuid"]!
            let episodeGuid = metadata["showGuid"]!

            if MindtrixEssence.showGuidToEssenceIds[showGuid] == nil {
                MindtrixEssence.showGuidToEssenceIds.insert(key: showGuid, essenceIdDic)
            } else {
                MindtrixEssence.showGuidToEssenceIds[showGuid]!.insert(key: essenceId, true)
            }

            if MindtrixEssence.episodeGuidToEssenceIds[episodeGuid] == nil {
                MindtrixEssence.episodeGuidToEssenceIds.insert(key: episodeGuid, essenceIdDic)
            } else {
                MindtrixEssence.episodeGuidToEssenceIds[episodeGuid]!.insert(key: essenceId, true)
            }

            log("MindtrixEssence.showGuidToEssenceIds:")
            log(MindtrixEssence.showGuidToEssenceIds)

            log("MindtrixEssence.episodeGuidToEssenceIds:")
            log(MindtrixEssence.episodeGuidToEssenceIds)


            MindtrixEssence.totalSupply = MindtrixEssence.totalSupply + 1

        }
	}

    // EssenceCollection owns by each creator
    pub resource EssenceCollection {

        // TODO: creators can own their Essence

        pub fun batchCreateEssence(
            essenceOffChainIds:[String],
            maxEditions: [UInt64],
            mintPrices: [{String: MindtrixViews.FT}?],
            royalties: [MetadataViews.Royalty],
            metadatas: [{String: String}],
            socials: [{String: String}],
            verifiers: [[{MindtrixViews.IVerifier}]]){
            var i: UInt64 = 0
            let len = UInt64(maxEditions.length)
            log("batchCreateEssence len:".concat(len.toString()))

            let verifierLen = UInt64(verifiers.length)
            let socialsLen = socials.length
            while(i < len) {
                var verifier: [{MindtrixViews.IVerifier}] = []
                if(verifierLen > i) {
                    verifier = verifiers[i]
                }
                let social: {String: String} = (i+1) > UInt64(socialsLen) ? {} : socials[i]
                self.createEssence(
                    essenceOffChainId: essenceOffChainIds[i],
                    maxEdition: maxEditions[i],
                    mintPrices: mintPrices[i],
                    royalties: royalties,
                    metadata: metadatas[i],
                    socials: social,
                    verifiers: verifiers[i],
                    components: {}
                )
                i = i + 1
            }
        }

        pub fun createEssence(
            essenceOffChainId: String,
            maxEdition: UInt64,
            mintPrices: {String: MindtrixViews.FT}?,
            royalties: [MetadataViews.Royalty],
            metadata: {String: String},
            socials: {String: String},
            verifiers: [{MindtrixViews.IVerifier}],
            components: {String: UInt64},
        ): UInt64 {

            let typeToVerifier: {String: [{MindtrixViews.IVerifier}]} = {}
            for verifier in verifiers {
                let identifier = verifier.getType().identifier
                if typeToVerifier[identifier] == nil {
                    typeToVerifier[identifier] = [verifier]
                } else {
                    typeToVerifier[identifier]!.append(verifier)
                }
            }

            let essence <- create EssenceRes(
                essenceOffChainId: essenceOffChainId,
                maxEdition: maxEdition,
                mintPrices: mintPrices,
                royalties: royalties,
                metadata: metadata,
                socials: socials,
                verifiers: typeToVerifier,
                components: {},
            )

            let essenceId = essence.data.essenceId
            MindtrixEssence.essenceDic[essenceId] <-! essence

            let showGuid = metadata["showGuid"]!
            let episodeGuid = metadata["episodeGuid"]!

            log("created essenceId:".concat(essenceId.toString()))
            let audioEssence = metadata["audioEssence"] as? MindtrixViews.AudioEssence
            let audioStartTime = metadata["audioStartTime"] ?? "0"
            log("audioStartTime:".concat(audioStartTime))
            let audioEndTime = metadata["audioEndTime"] ?? "0"
            log("audioEndTime:".concat(audioEndTime))
            let fullEpisodeDuration = metadata["fullEpisodeDuration"] ?? "0"
            log("fullEpisodeDuration:".concat(fullEpisodeDuration))

            let essenceFileIPFSUrl = metadata["essenceFileIPFSDirectory"]?.concat("/")?.concat(metadata["essenceFileIPFSCid"] ?? "")

            emit EssenceCreated(
                offChainedId: essenceOffChainId,
                essenceId: essenceId,
                essenceName: metadata["essenceName"]!,
                essenceDescription: metadata["essenceDescription"]!,
                showGuid: showGuid,
                episodeGuid: episodeGuid,
                audioStartTime: audioStartTime,
                audioEndTime: audioEndTime,
                fullEpisodeDuration: fullEpisodeDuration,
                essenceFileIPFSUrl: essenceFileIPFSUrl!,
                externalURL: metadata["essenceExternalURL"]!
            )

            return essenceId
        }

        init(){

        }

        destroy(){

        }

        pub fun removeEssences(showGuid: String, episodeGuid: String, essenceUuids: [UInt64]){
            pre {
                showGuid != nil : "Cannot remove essences by nil show_guid."
                episodeGuid != nil : "Cannot remove essences by nil episode_guid."
                essenceUuids.length > 0 : "Cannot remove empty essences."
            }
            for essenceUuid in essenceUuids {
                self.removeEssence(showGuid: showGuid, episodeGuid: episodeGuid, essenceUuid: essenceUuid)
            }
        }

        pub fun removeEssence(showGuid: String, episodeGuid: String, essenceUuid: UInt64){
            pre {
                showGuid != nil : "Cannot remove essences by nil show_guid."
                episodeGuid != nil : "Cannot remove essences by nil episode_guid."
                essenceUuid != nil : "Cannot remove the empty essence."
            }
            let essence <- MindtrixEssence.essenceDic.remove(key: essenceUuid)
            if(essence != nil) {
                MindtrixEssence.showGuidToEssenceIds[showGuid]?.remove(key: essenceUuid)
                MindtrixEssence.episodeGuidToEssenceIds[episodeGuid]?.remove(key: essenceUuid)
                MindtrixEssence.essenceIdsToCreationIds.remove(key: essenceUuid)
            }
            destroy essence

        }

    }

    // ========================================================
    //                         FUNCTION
    // ========================================================

    // helper functions

    pub fun createEmptyEssenceCollection(): @EssenceCollection {
        // TODO: In the future, only creators can create Empty Essence. For now, the essence list controlled by off-chain data
        return <- create EssenceCollection()
    }

    pub fun getAllEssenceIds(): [UInt64] {
        return MindtrixEssence.essenceDic.keys
    }

    pub fun getEssencesByShowGuid(showGuid: String): {UInt64: Bool}? {
        return MindtrixEssence.showGuidToEssenceIds[showGuid]
    }

    // The creators can destroy an Essence, so it's nullable.
    pub fun getOneEssenceRes(essenceId: UInt64): &EssenceRes{EssencePublic}? {
        return &MindtrixEssence.essenceDic[essenceId] as &EssenceRes{EssencePublic}?
    }

    pub fun getOneEssenceStruct(essenceId: UInt64): EssenceStruct? {
        let essence = &MindtrixEssence.essenceDic[essenceId] as &EssenceRes{EssencePublic}?
        return essence?.data ?? nil
    }

    pub fun borrowEssenceViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
        let essence = (&MindtrixEssence.essenceDic[id] as &MindtrixEssence.EssenceRes?)!
        return essence as &AnyResource{MetadataViews.Resolver}
    }

    access(account) fun updateEsenceIdsToCreationIds(essenceId: UInt64, nftId: UInt64) {
        if self.essenceIdsToCreationIds.containsKey(essenceId) {
            self.essenceIdsToCreationIds[essenceId]!.insert(key: nftId, true)
        } else {
            var map: {UInt64: Bool} = {}
            map.insert(key: nftId, true)
            self.essenceIdsToCreationIds.insert(key: essenceId, map)
        }
    }

	init() {
        let royaltyReceiverPublicPath: PublicPath = /public/flowTokenReceiver
        self.essenceDic <- {}
        self.totalSupply = 0
        self.showGuidToEssenceIds = {}
        self.episodeGuidToEssenceIds = {}
        self.essenceIdsToCreationIds = {}
        self.MindtrixDaoTreasuryRef = self.account.getCapability<&{FungibleToken.Receiver}>(royaltyReceiverPublicPath)

        self.MindtrixEssenceV2CollectionStoragePath = /storage/MindtrixEssenceV2CollectionStoragePath
        self.MindtrixEssenceV2CollectionPublicPath = /public/MindtrixEssenceV2CollectionPublicPath

	}
}
 