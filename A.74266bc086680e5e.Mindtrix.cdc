/*

============================================================
Name: NFT Contract for Mindtrix
Author: AS
============================================================

Mindtrix is a decentralized podcast community on Flow.
A community derives from podcasters, listeners, and collectors.

Mindtrix aims to provide a better revenue stream for podcasters
and build a value-oriented NFT for collectors to support their
favorite podcasters easily. :)

The contract represents the core functionalities of Mindtrix
NFTs. Podcasters can mint the two kinds of NFTs, Essence Audio
and Essence Image, based on their podcast episodes. Collectors
can buy the NFTs from podcasters' public sales or secondary
market on Flow.

Besides implementing the MetadataViews(thanks for the strong
community to build this standard), we also add some structure
to encapsulate the view objects. For example, the SerialGenus
categorize NFTs in a hierarchical genus structure, explaining
the NFT's origin from a specific episode under a show. You can
check the detailed definition in the resolveView function of
the SerialGenuses type.

Mindtrix's vision is to create long-term value for NFTs.
If more collectors are willing to get meaningful ones, it
would also bring a new revenue stream for creators.
Therefore, more people would embrace the crypto world!

To flow into the Mindtrix forest, please check:
https://www.mindtrix.xyz

============================================================

*/

import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import MindtrixViews from 0x74266bc086680e5e
import MindtrixEssence from 0x74266bc086680e5e

pub contract Mindtrix: NonFungibleToken {

 // ========================================================
 //                          PATH
 // ========================================================

    pub let RoyaltyReceiverPublicPath: PublicPath
    pub let MindtrixCollectionStoragePath: StoragePath
    pub let MindtrixCollectionPublicPath: PublicPath

 // ========================================================
 //                          EVENT
 // ========================================================

    pub event ContractInitialized()
    pub event NFTMinted(id: UInt64, essenceId: String, showGuid: String, episodeGuid: String, nftEdition: UInt64, name: String, nftFileIPFSUrl: String, serial: String, royaltyRecipient: [Address])
    pub event NFTFreeMinted(essenceId: UInt64, minter: Address, essenceName: String, essenceDescription: String, essenceFileIPFSCid: String, essenceFileIPFSDirectory: String)
    pub event NFTDestroyed(id: UInt64, essenceId: String, showGuid: String, episodeGuid: String, nftEdition: UInt64, name: String, serial: String)
    pub event Withdraw(id: UInt64, from: Address?)
    pub event Deposit(id: UInt64, to: Address?)

 // ========================================================
 //                       MUTABLE STATE
 // ========================================================

    pub var totalSupply: UInt64

 // ========================================================
 //               COMPOSITE TYPES: STRUCTURE
 // ========================================================

    pub struct NFTStruct {
        pub var nftId: UInt64?
        pub let essenceId: UInt64
        pub let createdTime: UFix64
        pub var nftEdition: UInt64?
        pub var currentHolder: Address
        access(self) let royalties: [MetadataViews.Royalty]
        access(account) let metadata: {String: String}
        pub let socials: {String: String}
        pub var components: {String: UInt64}

        init(
            nftId: UInt64?,
            essenceId: UInt64,
            nftEdition: UInt64?,
            currentHolder: Address,
            createdTime: UFix64,
            royalties: [MetadataViews.Royalty],
            metadata: {String: String},
            socials: {String: String},
            components: {String: UInt64},
        ){
            self.nftId = nftId
            self.essenceId = essenceId
            self.nftEdition = nftEdition
            self.currentHolder = currentHolder
            self.createdTime = createdTime
            self.royalties = royalties
            self.metadata = metadata
            self.socials = socials
            self.components = components
        }

        pub fun getMetadata(): {String: String}{
            return self.metadata
        }

        pub fun updateNFTId(nftId :UInt64){
            self.nftId = nftId
        }

        pub fun getRoyalties(): [MetadataViews.Royalty] {
            return self.royalties
        }

        pub fun getAudioEssence(): MindtrixViews.AudioEssence {
            return MindtrixViews.AudioEssence(
                startTime: self.metadata["audioStartTime"] ?? "0",
                endTime: self.metadata["audioEndTime"] ?? "0",
                fullEpisodeDuration: self.metadata["fullEpisodeDuration"] ?? "0"
            )
        }
    }


    // EssenceToNFTId is a helper struct and stores collector's all Mindtrix NFTs mapping to a specific collection
    pub struct EssenceToNFTId {
        access(account) var dic: {UInt64: {UInt64: Bool}}
        access(account) fun addNFT(collectionId:UInt64, nftId: UInt64): Void {
            self.dic.insert(key: collectionId, {nftId: true})
        }
        access(account) fun removeNFT(collectionId:UInt64, nftId: UInt64): Void {
            self.dic[collectionId]!.remove(key: nftId)
        }
        access(account) fun getOwnedNFTIdsFromCollection(collectionId: UInt64): [UInt64] {
            let nftIds: [UInt64] = []
            let nftIdsFromCollection = self.dic[collectionId]!
            if nftIdsFromCollection.length > 0 {
                for nftId in nftIdsFromCollection.keys {
                    if nftIdsFromCollection[nftId] != nil {
                        nftIds.append(nftId)
                    }
                }
            }
            return nftIds
        }

        init(){
            self.dic = {}
        }
    }

 // ========================================================
 //               COMPOSITE TYPES: RESOURCE
 // ========================================================

    pub resource NFT: NonFungibleToken.INFT, MetadataViews.Resolver, INFT {

        // Though the id exists in NFTStruct, it should not be removed to implement the INFT.
        pub let id: UInt64
        pub var data: NFTStruct

        init(data: NFTStruct) {
            // Assign the id a UUID, not the totalSupply.
            self.id = self.uuid
            data.updateNFTId(nftId: self.id)
            // Essence might be destroyed by some reasons, so it's nullable.
            let essence = MindtrixEssence.getOneEssenceRes(essenceId: data.essenceId)

            log("nft id:".concat(self.id.toString()))

            self.data = data
            let royalties = data.getRoyalties()

            var royaltyRecipient: [Address] = []
            for ele in royalties {
                royaltyRecipient.append(ele.receiver.address)

             }

            let nftFileIPFSUrl = data.metadata["nftFileIPFSDirectory"]?.concat("/")?.concat(data.metadata["nftFileIPFSCid"] ?? "")
            let templateId = self.data.metadata["templateId"] ?? nil
            let essenceId = templateId != nil ? templateId! : self.data.metadata["essenceId"] ?? ""

            emit NFTMinted(
                id: self.id,
                essenceId: essenceId,
                showGuid: self.data.metadata["showGuid"] ?? "",
                episodeGuid: self.data.metadata["episodeGuid"] ?? "",
                nftEdition: self.data.nftEdition ?? 0,
                name: data.metadata["nftName"] ?? "",
                nftFileIPFSUrl: nftFileIPFSUrl ?? "",
                serial: MindtrixViews.Serials(self.getSerialDic()).str,
                royaltyRecipient: royaltyRecipient,
            )
            let identifier = MindtrixViews.NFTIdentifier(
                uuid: self.id,
                serial: data.nftEdition ?? 0,
                holder: data.currentHolder,
            )
            if essence != nil {
                // MindtrixEssence is the template of Mindtrix NFT, and it updates the dictionary between holders and NFT data whenever an NFT is minted.
                essence?.updateMinters(address: data.currentHolder, nftIdentifier: identifier)
                essence?.increaseCurrentEditionByOne()
            }
            
            MindtrixEssence.updateEsenceIdsToCreationIds(essenceId: data.essenceId, nftId: self.id)
            Mindtrix.totalSupply = Mindtrix.totalSupply + 1

        }

        pub fun getViews(): [Type] {
            return [
                Type<MetadataViews.Display>(),
                Type<MetadataViews.Serial>(),
                Type<MetadataViews.ExternalURL>(),
                Type<MetadataViews.Editions>(),
                Type<MetadataViews.Royalties>(),
                Type<MetadataViews.License>(),
                Type<MetadataViews.NFTCollectionData>(),
                Type<MetadataViews.NFTCollectionDisplay>(),
                Type<MetadataViews.Traits>(),
                Type<MindtrixViews.Serials>(),
                Type<MindtrixViews.EssenceIdentifier>()
            ]
        }

        pub fun getSerialDic(): {String: String} {
            return {
                "essenceRealmSerial": self.data.metadata["essenceRealmSerial"] ?? "0",
                "essenceTypeSerial": self.data.metadata["essenceTypeSerial"] ?? "0",
                "showSerial": self.data.metadata["showSerial"] ?? "0",
                "audioEssenceSerial": self.data.metadata["audioEssenceSerial"] ?? "0",
                "nftEditionSerial": self.data.nftEdition?.toString() ?? "0"
            }
        }

        pub fun getTemplateIdStr(): String {
            let templateId = self.data.metadata["templateId"] ?? nil
            let essenceId = self.data.metadata["essenceId"] ?? ""
            return templateId != nil ? templateId! : essenceId
        }

        pub fun resolveView(_ view: Type): AnyStruct? {
            switch view {
                case Type<MetadataViews.Display>():
                    // Add different thumbnail
                    return MetadataViews.Display(
                        name: self.data.metadata["nftName"] ?? "",
                        description: self.data.metadata["nftDescription"] ?? "",
                        thumbnail: MetadataViews.HTTPFile(
                            url: self.data.metadata["nftImagePreviewUrl"] ?? ""
                        )
                    )
                case Type<MetadataViews.ExternalURL>():
                    let templateId = self.data.metadata["templateId"] ?? nil
                    let essenceId = templateId != nil ? templateId! : self.data.metadata["essenceId"] ?? ""
                    let nftName = self.data.metadata["nftName"] ?? ""
                    return MetadataViews.ExternalURL("https://app.mindtrix.xyz/essence/".concat(essenceId).concat("--").concat(nftName))
                case Type<MetadataViews.Editions>():
                    let editionInfo = MetadataViews.Edition(name: self.data.metadata["nftName"], number: self.data.nftEdition ?? 0, max: nil)
                    let editionList: [MetadataViews.Edition] = [editionInfo]
                    return MetadataViews.Editions(
                        editionList
                    )
                case Type<MindtrixViews.Serials>():
                    return MindtrixViews.Serials(self.getSerialDic())
                case Type<MindtrixViews.AudioEssence>():
                    return self.data.getAudioEssence()
                case Type<MetadataViews.Royalties>():
                    return MetadataViews.Royalties(self.data.getRoyalties())
                case Type<MetadataViews.IPFSFile>():
                    return MetadataViews.IPFSFile(
                        cid: self.data.metadata["nftFileIPFSCid"] ?? "",
                        path: self.data.metadata["nftFileIPFSDirectory"] ?? ""
                    )
                case Type<MetadataViews.License>():
                    return MetadataViews.License(self.data.metadata["licenseIdentifier"] ?? "CC-BY-NC-4.0")
                case Type<MetadataViews.NFTCollectionData>():
                    return MetadataViews.NFTCollectionData(
                        storagePath: Mindtrix.MindtrixCollectionStoragePath,
                        publicPath: Mindtrix.MindtrixCollectionPublicPath,
                        providerPath: /private/MindtrixCollection,
                        publicCollection: Type<&Mindtrix.Collection{Mindtrix.MindtrixCollectionPublic}>(),
                        publicLinkedType: Type<&Mindtrix.Collection{Mindtrix.MindtrixCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Receiver,MetadataViews.ResolverCollection}>(),
                        providerLinkedType: Type<&Mindtrix.Collection{Mindtrix.MindtrixCollectionPublic,NonFungibleToken.CollectionPublic,NonFungibleToken.Provider,MetadataViews.ResolverCollection}>(),
                        createEmptyCollectionFunction: (fun (): @NonFungibleToken.Collection {return <-Mindtrix.createEmptyCollection()})
                    )
                case Type<MetadataViews.NFTCollectionDisplay>():
                    let squareImage = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(url: self.data.metadata["collectionSquareImageUrl"] ?? ""),
                        mediaType: self.data.metadata["collectionSquareImageType"] ?? ""
                    )
                    let bannerImage = MetadataViews.Media(
                        file: MetadataViews.HTTPFile(url: "https://firebasestorage.googleapis.com/v0/b/mindtrix-pro.appspot.com/o/public%2Fmindtrix%2Fmindtrix_banner.svg?alt=media&token=34a09a8e-50ad-415c-8d65-a57e6ed9aef6"),
                        mediaType: self.data.metadata["collectionBannerImageType"] ?? ""
                    )
                    var socials = {
                            "discord": MetadataViews.ExternalURL("https://discord.com/invite/bNCwSUUmDG"),
                            "instagram": MetadataViews.ExternalURL("https://www.instagram.com/mindtrix_dao"),
                            "facebook": MetadataViews.ExternalURL("https://www.facebook.com/mindtrix.dao"),
                            "twitter": MetadataViews.ExternalURL("https://twitter.com/mindtrix_dao")
                        } as {String: MetadataViews.ExternalURL }

                    return MetadataViews.NFTCollectionDisplay(
                        name: self.data.metadata["collectionName"] ?? "",
                        description: self.data.metadata["collectionDescription"] ?? "",
                        externalURL: MetadataViews.ExternalURL(self.data.metadata["collectionExternalURL"] ?? ""),
                        squareImage: squareImage,
                        bannerImage: bannerImage,
                        socials: socials,
                    )
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
                case Type<MindtrixViews.EssenceIdentifier>():
                    return MindtrixViews.EssenceIdentifier(
                        uuid: self.data.essenceId,
                        serials: MindtrixViews.Serials(self.getSerialDic()).arr,
                        holder: Mindtrix.account.address,
                        showGuid: self.data.metadata["showGuid"] ?? "",
                        episodeGuid: self.data.metadata["episodeGuid"] ?? "",
                        createdTime: self.data.createdTime
                    )
            }
            return nil
        }

         destroy() {
            // The total supply records how many times an NFT is minted, so it doesn't need to be decreased by one
            // The accurate quantity of existing NFTs can be found in individual Mindtrix Essence.
            // pub event NFTDestroyed(id: UInt64, essenceId: String, showGuid: String, episodeGuid: String, name: String, serial: String)
            emit NFTDestroyed(
                id: self.id,
                essenceId: self.data.metadata["essenceId"] ?? "",
                showGuid: self.data.metadata["showGuid"] ?? "",
                episodeGuid: self.data.metadata["episodeGuid"] ?? "",
                nftEdition: self.data.nftEdition ?? 0,
                name: self.data.metadata["nftName"] ?? "",
                serial: MindtrixViews.Serials(self.getSerialDic()).str
            )
        }

    }

    pub resource interface MindtrixCollectionPublic {
        pub fun deposit(token: @NonFungibleToken.NFT)
        pub fun getIDs(): [UInt64]
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT
        pub fun borrowNFTStruct(id: UInt64): Mindtrix.NFTStruct
        pub fun borrowMindtrix(id: UInt64): &Mindtrix.NFT {
            post {
                (result == nil) || (result.id == id):
                    "Cannot borrow Mindtrix reference: the ID of the returned reference is incorrect"
            }
        }
    }

    pub resource interface INFT {
        pub fun getSerialDic(): {String: String}
    }

    // The Collection owns by each of user and stores all of their Mindtrix NFT
    pub resource Collection: MindtrixCollectionPublic, NonFungibleToken.Provider, NonFungibleToken.Receiver, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection {
        // dictionary of NFT conforming tokens
        pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}
        access(account) let essenceToNFTId: EssenceToNFTId

        init () {
            self.ownedNFTs <- {}
            self.essenceToNFTId = EssenceToNFTId()
        }

        // withdraw removes an NFT from the collection and moves it to the caller
        pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {

            let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("missing NFT")

            emit Withdraw(id: token.id, from: self.owner?.address)

            return <-token
        }

        // deposit takes a NFT and adds it to the collections dictionary
        // and adds the ID to the id array
        pub fun deposit(token: @NonFungibleToken.NFT) {
            let nft <- token as! @NFT
            let id: UInt64 = nft.id
            let templateId = nft.data.essenceId

            self.essenceToNFTId.addNFT(collectionId: templateId, nftId: id)

            let oldNFT <- self.ownedNFTs[id] <- nft
            emit Deposit(id: id, to: self.owner?.address)

            destroy oldNFT
        }

        pub fun burn(id: UInt64) {
            let token <- self.ownedNFTs.remove(key: id) ?? panic("Cannot find this NFT id:".concat(id.toString()))
            let nft <- token as! @NFT
            let templateId = nft.data.essenceId
            let nftId = nft.id
            
            if self.essenceToNFTId.dic.containsKey(templateId) {
                self.essenceToNFTId.removeNFT(collectionId: templateId, nftId: nftId)
            }

            destroy nft
        }

        // getIDs returns an array of the IDs that are in the collection
        pub fun getIDs(): [UInt64] {
            return self.ownedNFTs.keys
        }

        // borrowNFT gets a reference to an NFT in the collection
        // so that the caller can read its metadata and call its methods
        pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
            return (&self.ownedNFTs[id] as &NonFungibleToken.NFT?)!
        }

        pub fun borrowNFTStruct(id: UInt64): Mindtrix.NFTStruct {
            let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let mindtrixNFT = ref as! &Mindtrix.NFT
            return mindtrixNFT.data as Mindtrix.NFTStruct

        }

        pub fun borrowMindtrix(id: UInt64): &Mindtrix.NFT {
            let ref = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            return ref as! &Mindtrix.NFT
        }

        pub fun borrowViewResolver(id: UInt64): &AnyResource{MetadataViews.Resolver} {
            let nft = (&self.ownedNFTs[id] as auth &NonFungibleToken.NFT?)!
            let Mindtrix = nft as! &Mindtrix.NFT
            return Mindtrix as &AnyResource{MetadataViews.Resolver}
        }

        destroy() {
            destroy self.ownedNFTs
        }
    }


 // ========================================================
 //                         FUNCTION
 // ========================================================

    pub fun createEmptyCollection(): @Collection {
        return <- create Collection()
    }

    access(account) fun mintNFT(data: NFTStruct): @NFT {    
        return <- create NFT(data: data)
    }

    access(account) fun batchMintNFT(recipient: &Mindtrix.Collection{Mindtrix.MindtrixCollectionPublic}, data: NFTStruct, maxEdition: UInt64): @[NFT]  {
        var i: UInt64 = 0
        var nfts: @[NFT] <- []
        while i < maxEdition {
            nfts.append(<- self.mintNFT(data: data))
            i = i + 1
        }
        return <- nfts
    }

 // ========================================================
 //                       CONTRACT INIT
 // ========================================================

    init() {
        self.totalSupply = 0
        let royaltyReceiverPublicPath: PublicPath = /public/flowTokenReceiver
        self.RoyaltyReceiverPublicPath = /public/flowTokenReceiver
        self.MindtrixCollectionStoragePath = /storage/MindtrixNFTCollection
        self.MindtrixCollectionPublicPath = /public/MindtrixNFTCollection

        self.account.save(<-Mindtrix.createEmptyCollection(), to: self.MindtrixCollectionStoragePath)

        self.account.link<&Mindtrix.Collection{NonFungibleToken.CollectionPublic, Mindtrix.MindtrixCollectionPublic, MetadataViews.ResolverCollection}>(
            self.MindtrixCollectionPublicPath,
            target: self.MindtrixCollectionStoragePath
        )

        emit ContractInitialized()
    }
}
 