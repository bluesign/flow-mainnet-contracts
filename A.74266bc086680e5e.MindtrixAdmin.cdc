import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import MindtrixViews from 0x74266bc086680e5e
import Mindtrix from 0x74266bc086680e5e
import MindtrixEssence from 0x74266bc086680e5e
import MindtrixDonation from 0x74266bc086680e5e

pub contract MindtrixAdmin {

    // ========================================================
    //                          PATH
    // ========================================================

    /// Path where the `Admin` is stored
    pub let MindtrixAdminStoragePath: StoragePath

    /// Path where the private capability for the `Admin` is available
    pub let MindtrixAdminPrivatePath: PrivatePath

    // ========================================================
    //               COMPOSITE TYPES: RESOURCE
    // ========================================================

    pub resource Admin {

        pub fun freeMintNFTFromEssence(recipient: &{NonFungibleToken.CollectionPublic}, essenceId: UInt64, nftAudioPreviewUrl: String?) {
            pre {
                    (MindtrixEssence.getOneEssenceStruct(essenceId: essenceId)?.getMintPrice() ?? nil) == nil: "You have to purchase this essence."
                    (MindtrixEssence.getOneEssenceStruct(essenceId: essenceId)?.getEssenceClaimable() ?? false) == true : "This Essence is not claimable, and thus not currently active."
                }
            // early return if essenceStruct is nil
            let essenceStruct = MindtrixEssence.getOneEssenceStruct(essenceId: essenceId)!
            log("freeMintNFTFromEssence essence:")
            log(essenceStruct)
            // verify minting conditions
            assert(essenceStruct.verifyMintingConditions(
                recipient: recipient, essenceStruct: essenceStruct) == true,
                message: "Cannot pass the minting conditions."
            );
            log("pass all verifyMintingConditions")
            let essenceMetadata = essenceStruct.getMetadata()
            let mintedEdition = essenceStruct.currentEdition + 1
            let isAudioFileExist = nftAudioPreviewUrl != nil
            let nftMetadata: {String: String} = {
                "nftName": essenceMetadata["essenceName"] ?? "",
                "nftDescription": essenceMetadata["essenceDescription"] ?? "",
                "essenceId": essenceId.toString(),
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
                "showGuid": essenceMetadata["showGuid"] ?? "",
                "episodeGuid": essenceMetadata["episodeGuid"] ?? "",
                "nftExternalURL": essenceMetadata["nftExternalURL"] ?? "",
                "nftFileIPFSCid": essenceMetadata["essenceFileIPFSCid"] ?? "",
                "nftFileIPFSDirectory": essenceMetadata["essenceFileIPFSDirectory"] ?? "",
                "nftFilePreviewUrl": essenceMetadata["essenceFilePreviewUrl"] ?? "",
                "nftAudioPreviewUrl": isAudioFileExist ? nftAudioPreviewUrl! : "",
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

            var orgRoyalties = essenceStruct.getRoyalties() as! [MetadataViews.Royalty]
            var royaltiesMap: {Address: MetadataViews.Royalty} = {}
            // the royalties address should not be duplicated
            for royalty in orgRoyalties {
                let receipientAddress = royalty.receiver.address
                if !royaltiesMap.containsKey(receipientAddress) {
                    royaltiesMap.insert(key: receipientAddress, royalty)
                }
            }
            let newRoyalties = royaltiesMap.values

            let data = Mindtrix.NFTStruct(
                nftId: nil,
                essenceId: essenceStruct.essenceId,
                nftEdition: mintedEdition,
                currentHolder: recipient.owner!.address,
                createdTime: getCurrentBlock().timestamp,
                royalties: newRoyalties,
                metadata: nftMetadata,
                socials: essenceStruct.socials,
                components: essenceStruct.components
            )
            recipient.deposit(token: <-  Mindtrix.mintNFT(data: data))
        }

        /// Essence Utilities
        pub fun updateEssenceMetadata(essenceId: UInt64, newMetadata: {String: String}){
            let essence = MindtrixEssence.getOneEssenceStruct(essenceId: essenceId)!
            essence.updateMetadata(newMetadata: newMetadata)
        }

        // Update essence preview URL
        pub fun updatePreviewURL(essenceId: UInt64, essenceVideoPreviewUrl: String?, essenceImagePreviewUrl: String?){
            let essence = MindtrixEssence.getOneEssenceStruct(essenceId: essenceId)!
            essence.updatePreviewURL(essenceVideoPreviewUrl: essenceVideoPreviewUrl ?? "", essenceImagePreviewUrl: essenceImagePreviewUrl ?? "")
        }

        pub fun replaceShowGuidToRoyalties(showGuid: String, primaryRoyalties: [MetadataViews.Royalty], secondaryRoyalties: [MetadataViews.Royalty]){
            MindtrixDonation.replaceShowGuidToRoyalties(showGuid: showGuid, primaryRoyalties: primaryRoyalties, secondaryRoyalties: secondaryRoyalties)
        }

    }

    init() {

        self.MindtrixAdminStoragePath = /storage/MindtrixAdmin
        self.MindtrixAdminPrivatePath = /private/MindtrixAdmin


        if self.account.borrow<&MindtrixAdmin.Admin>(from: MindtrixAdmin.MindtrixAdminStoragePath) == nil {
            self.account.save<@MindtrixAdmin.Admin>(<- create MindtrixAdmin.Admin(), to: MindtrixAdmin.MindtrixAdminStoragePath)
        }

        self.account.link<&MindtrixAdmin.Admin>(MindtrixAdmin.MindtrixAdminPrivatePath, target: MindtrixAdmin.MindtrixAdminStoragePath)!
    }

}
