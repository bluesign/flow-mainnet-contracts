import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448
import MindtrixViews from 0x74266bc086680e5e
import Mindtrix from 0x74266bc086680e5e
import MindtrixEssence from 0x74266bc086680e5e

pub contract MindtrixDonation {

    // ========================================================
    //                          EVENT
    // ========================================================

    pub event Donate(nftId: UInt64, offChainedId: String, showGuid: String, episodeGuid: String, donorAddress: Address, nftName: String)

    // ========================================================
    //                       MUTABLE STATE
    // ========================================================

    // Store who donate which episode and the NFT uuid they owned.
    // eg: {"cl9ecksoc014i01v969ovftzy": { 0x739dbfea743996c3: [{uuid: 34, serial: 000011111, holder: 0x12345677, createdTime: 1667349560}]}}
    access(self) var episodeGuidToDonations: {String: {Address: [MindtrixViews.NFTIdentifier]}}

    // Store the royalties of each show.
    // eg: {"cl9ecksoc014i01v969ovftzy": {
    //   "primary": [
    //      {receiver: Capability<>, cut: 0.8, description: "creator's primary royalty"},
    //      {receiver: Capability<>, cut: 0.2, description: "Mindtrix's primary royalty"}
    //    ],
    //   "secondary": [
    //      {receiver: Capability<>, cut: 0.1, description: "creator's secondary royalty"},
    //      {receiver: Capability<>, cut: 0.05, description: "Mindtrix's secondary royalty"}
    //    ]
    //  }
    //}
    access(self) var showGuidToRoyalties: {String: {String: [MetadataViews.Royalty]}};

    access(self) var metadata: {String: AnyStruct}

    // ========================================================
    //                         FUNCTION
    // ========================================================

    access(account) fun updateDonorDic(donorAddress: Address, episodeGuid: String, nftIdentifier: MindtrixViews.NFTIdentifier) {

        if self.episodeGuidToDonations[episodeGuid] == nil {
            var newDonationDic: {Address: [MindtrixViews.NFTIdentifier]} =  {}
            newDonationDic.insert(key: donorAddress, [nftIdentifier])
            self.episodeGuidToDonations.insert(key: episodeGuid, newDonationDic)
        } else {
            let oldEpisodeGuidDic: {Address: [MindtrixViews.NFTIdentifier]} = self.episodeGuidToDonations[episodeGuid]!
            if self.episodeGuidToDonations[episodeGuid]![donorAddress] == nil {
                self.episodeGuidToDonations[episodeGuid]!.insert(key: donorAddress, [nftIdentifier])
            } else {
                self.episodeGuidToDonations[episodeGuid]![donorAddress]!.append(nftIdentifier)
            }
        }
    }

    access(account) fun getNFTEditionFromDonationDicByEpisodeGuid(episodeGuid: String): UInt64{
        if self.episodeGuidToDonations[episodeGuid] == nil {
            return 0
        } else {
            return UInt64(self.episodeGuidToDonations[episodeGuid]?.keys?.length ?? 0)
        }
    }

    access(account) fun replaceShowGuidToRoyalties(showGuid: String, primaryRoyalties: [MetadataViews.Royalty], secondaryRoyalties: [MetadataViews.Royalty]){

        var showGuidToRoyaltiesTmp: {String: {String: [MetadataViews.Royalty]}}  = {}
        var primaryRoyaltiesTmp: {String: [MetadataViews.Royalty]} = {}
        var secondaryRoyaltiesTmp: {String: [MetadataViews.Royalty]} = {}

        primaryRoyaltiesTmp.insert(key: "primary", primaryRoyalties)
        secondaryRoyaltiesTmp.insert(key: "secondary", secondaryRoyalties)
        showGuidToRoyaltiesTmp.insert(key: showGuid, primaryRoyaltiesTmp)
        showGuidToRoyaltiesTmp[showGuid]!.insert(key: "secondary", secondaryRoyalties)

        if self.showGuidToRoyalties[showGuid] == nil {
            self.showGuidToRoyalties.insert(key: showGuid, primaryRoyaltiesTmp)
            self.showGuidToRoyalties[showGuid]!.insert(key: "secondary", secondaryRoyalties)
        } else {
            self.showGuidToRoyalties[showGuid] = primaryRoyaltiesTmp
            self.showGuidToRoyalties[showGuid]!.insert(key: "secondary", secondaryRoyalties)
        }

    }

    // the frontend will directly pass the essenceStruct without generating an Essence on-chain.
    pub fun mintNFTFromDonation(
        creatorAddress: Address,
        offChainedId: String,
        donorNFTCollection: &{NonFungibleToken.CollectionPublic},
        payment: @FungibleToken.Vault,
        essenceStruct: MindtrixEssence.EssenceStruct ) {

        pre {
            essenceStruct.getMintPrice() != nil: "The donation price should not be nil."
            essenceStruct.getMintPrice()!.containsKey("A.1654653399040a61.FlowToken.Vault"): "The the token address from the price is incorrect."
            essenceStruct.getMintPrice()!["A.1654653399040a61.FlowToken.Vault"]!.price > UFix64(0): "The donation price should not be free."
        }

        let mindtrixTreasuryAddress: Address = MindtrixDonation.account.address
        let essenceMetadata = essenceStruct.getMetadata()
        let showGuid = essenceMetadata["showGuid"] ?? ""

        let royaltiesFromShowGuid = MindtrixDonation.showGuidToRoyalties[showGuid] !as {String: [MetadataViews.Royalty]}

        var mindtrixPrimaryCut = 0.2
        var MindtrixVault: &AnyResource{FungibleToken.Receiver}? = nil
        var CreatorVault: &AnyResource{FungibleToken.Receiver}? = nil

        for primaryRoyalty in royaltiesFromShowGuid["primary"]! {
            let address = primaryRoyalty!.receiver!.address
            if address == mindtrixTreasuryAddress {
                mindtrixPrimaryCut = primaryRoyalty!.cut
                MindtrixVault = primaryRoyalty.receiver.borrow()
                    ?? panic("Could not borrow the &{FungibleToken.Receiver} from Mindtrix's Vault.");
            } else if address == creatorAddress {
                CreatorVault = primaryRoyalty.receiver.borrow()
                    ?? panic("Could not borrow the &{FungibleToken.Receiver} from the creator.");
            }
        }

        let mindtrixFlow <- payment.withdraw(amount: payment.balance * mindtrixPrimaryCut)

        MindtrixVault!.deposit(from: <- mindtrixFlow)
        CreatorVault!.deposit(from: <- payment)

        let episodeGuid = essenceMetadata["episodeGuid"] ?? ""

        let nftName = essenceMetadata["nftName"] ?? ""

        let donorAddress = donorNFTCollection.owner!.address
        let mintedEdition = self.getNFTEditionFromDonationDicByEpisodeGuid(episodeGuid: episodeGuid) + 1
        let nftMetadata: {String: String} = {
            "nftName": nftName,
            // donor fields-start
            "donorName": essenceMetadata["donorName"] ?? "",
            "donorMessage": essenceMetadata["donorMessage"] ?? "",
            // donor fields-end
            "nftDescription": essenceMetadata["essenceDescription"] ?? "",
            "essenceId": "",
            "showGuid": showGuid,
            "collectionName": essenceMetadata["collectionName"] ?? "",
            "collectionDescription": essenceMetadata["collectionDescription"] ?? "",
            // collectionExternalURL is the Podcast link from the hosting platform.
            "collectionExternalURL": essenceMetadata["collectionExternalURL"] ?? "",
            "collectionSquareImageUrl": essenceMetadata["collectionSquareImageUrl"] ?? "",
            "collectionSquareImageType": essenceMetadata["collectionSquareImageType"] ?? "",
            // essenceExternalURL is the Donation page from Mindtrix Marketplace
            "essenceExternalURL": essenceMetadata["essenceExternalURL"] ?? "",
            "episodeGuid": episodeGuid,
            "nftExternalURL": essenceMetadata["nftExternalURL"] ?? "",
            "nftFileIPFSCid": essenceMetadata["essenceFileIPFSCid"] ?? "",
            "nftFileIPFSDirectory": essenceMetadata["essenceFileIPFSDirectory"] ?? "",
            "nftFilePreviewUrl": essenceMetadata["essenceFilePreviewUrl"] ?? "",
            "nftImagePreviewUrl": essenceMetadata["essenceImagePreviewUrl"] ?? "",
            "nftVideoPreviewUrl": essenceMetadata["essenceVideoPreviewUrl"] ?? "",
            "essenceRealmSerial": essenceMetadata["essenceRealmSerial"] ?? "",
            "essenceTypeSerial": essenceMetadata["essenceTypeSerial"] ?? "",
            "showSerial": essenceMetadata["showSerial"] ?? "",
            "episodeSerial": essenceMetadata["episodeSerial"] ?? "",
            "audioEssenceSerial": "0",
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
            essenceId: 0,
            nftEdition: mintedEdition,
            currentHolder: donorAddress,
            createdTime: getCurrentBlock().timestamp,
            royalties: newRoyalties,
            metadata: nftMetadata,
            socials: essenceStruct.socials,
            components: essenceStruct.components
        )

        log("donation mint data:")
        log(data)

        let nft <- Mindtrix.mintNFT(data: data)
        let nftId = nft.id


        let nftIdentifier = MindtrixViews.NFTIdentifier(
            uuid: nftId,
            serial: mintedEdition,
            holder: donorAddress
        )

        self.updateDonorDic(donorAddress: donorAddress, episodeGuid: episodeGuid, nftIdentifier: nftIdentifier)
        donorNFTCollection.deposit(token: <- nft )
        emit Donate(
            nftId: nftId,
            offChainedId: offChainedId,
            showGuid: showGuid,
            episodeGuid: episodeGuid,
            donorAddress: donorAddress,
            nftName: nftName
        )

    }

    init() {
        self.episodeGuidToDonations = {}
        self.showGuidToRoyalties = {}
        self.metadata = {}
    }
}
