/*
    Description: The Marketplace Helper Contract for TheFabricant NFTs
   
    the purpose of this contract is to enforce the SaleCut array when a listing is created or an offer is made for a nft
    the main problem with the marketplace contract is the SaleCut is made during the transaction, and not enforced in the contract
    currently only enforces ItemNFT and TheFabricantS1ItemNFT nfts
    uses FlowToken as payment method
*/

import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import FlowToken from 0x1654653399040a61
import GarmentNFT from 0xfc91de5e6566cc7c
import MaterialNFT from 0xfc91de5e6566cc7c
import ItemNFT from 0xfc91de5e6566cc7c
import TheFabricantS1GarmentNFT from 0x09e03b1f871b3513
import TheFabricantS1MaterialNFT from 0x09e03b1f871b3513
import TheFabricantS1ItemNFT from 0x09e03b1f871b3513
import TheFabricantS2GarmentNFT from 0x7752ea736384322f
import TheFabricantS2MaterialNFT from 0x7752ea736384322f
import TheFabricantS2ItemNFT from 0x7752ea736384322f
import TheFabricantMarketplace from 0x09e03b1f871b3513
import MetadataViews from 0x1d7e57aa55817448
import TheFabricantAccessPass from 0x7752ea736384322f
import TheFabricantXXories from 0x7752ea736384322f
import TheFabricantNFTStandard from 0x7752ea736384322f

pub contract TheFabricantMarketplaceHelper {

    // events emitted when an nft is listed or an offer is made for an nft
    pub event S0ItemListed(
        name: String,
        mainImage: String,
        images: [String],
        listingID: String, 
        nftType: Type, 
        nftID: UInt64, 
        ftVaultType: Type, 
        price: UFix64, 
        seller: Address?, 
        season: String
    )
    pub event S1ItemListed(
        name: String,
        mainImage: String,
        images: [String],
        listingID: String, 
        nftType: Type, 
        nftID: UInt64, 
        ftVaultType: Type, 
        price: UFix64, 
        seller: Address?, 
        season: String
    )
    pub event S2ItemListed(
        name: String,
        mainImage: String,
        images: [String],
        listingID: String, 
        nftType: Type, 
        nftID: UInt64, 
        ftVaultType: Type, 
        price: UFix64, 
        seller: Address?, 
        season: String, 
        edition: String?
    )
    pub event XXoryListed(
        name: String,
        mainImage: String,
        images: [String],
        listingID: String, 
        nftType: Type, 
        nftID: UInt64, 
        ftVaultType: Type, 
        price: UFix64, 
        seller: Address?, 
        season: String, 
        edition: String?
    )
    pub event AccessPassListed(listingID: String, nftType: Type, nftID: UInt64, serial: UInt64, ftVaultType: Type, price: UFix64, seller: Address?, variant: String, promotionId: UInt64, promotionHost: Address, accessUnits: UInt8, initialAccessUnits: UInt8, season: String)
    pub event S0ItemOfferMade(offerID: String, nftType: Type, nftID: UInt64, ftVaultType: Type, price: UFix64, offerer: Address?, initialNFTOwner: Address, season: String)
    pub event S1ItemOfferMade(offerID: String, nftType: Type, nftID: UInt64, ftVaultType: Type, price: UFix64, offerer: Address?, initialNFTOwner: Address, season: String)
    pub event S2ItemOfferMade(offerID: String, nftType: Type, nftID: UInt64, ftVaultType: Type, price: UFix64, offerer: Address?, initialNFTOwner: Address, season: String, edition: String?)
    pub event AccessPassOfferMade(offerID: String, nftType: Type, nftID: UInt64, ftVaultType: Type, price: UFix64, offerer: Address?, initialNFTOwner: Address, season: String)
    
    pub let AdminStoragePath: StoragePath

    // dictionary of name of royalty recipient to their salecut amounts
    access(self) var saleCuts: {String: SaleCutValues}

    pub struct SaleCutValues {
        pub var initialAmount: UFix64
        pub var amount: UFix64
        init (initialAmount: UFix64, amount: UFix64) {
            self.initialAmount = initialAmount
            self.amount = amount
        }        
    }

    // list an s0Item from ItemNFT contract, calling TheFabricantMarketplace's Listings' createListing function
    pub fun s0ListItem(        
        itemRef: &ItemNFT.NFT,
        listingRef: &TheFabricantMarketplace.Listings,
        nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
        nftType: Type,
        nftID: UInt64,
        paymentCapability: Capability<&{FungibleToken.Receiver}>,
        salePaymentVaultType: Type,
        price: UFix64) {

        //get the flowToken capabilities for each component of the item (garment, item, material)
        let itemCap = getAccount(itemRef.royaltyVault.address).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)    
        let itemDataID = itemRef.item.itemDataID
        let itemData = ItemNFT.getItemData(id: itemDataID)
        let itemName = itemRef.name
        let mainImage = itemData.mainImage
        var images: [String] = itemData.images
        let garmentCap = getAccount(itemRef.borrowGarment()!.royaltyVault.address).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        let materialCap = getAccount(itemRef.borrowMaterial()!.royaltyVault.address).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)

        // initialize sale cuts for item, garment, material and contract
        let saleCutArray: [TheFabricantMarketplace.SaleCut] =
        [TheFabricantMarketplace.SaleCut(name: "Season 0 Item Creator", receiver: itemCap,  initialAmount: TheFabricantMarketplaceHelper.saleCuts["item"]!.initialAmount, amount: TheFabricantMarketplaceHelper.saleCuts["item"]!.amount),
        TheFabricantMarketplace.SaleCut(name: "Season 0 Garment Creator", receiver: garmentCap, initialAmount: TheFabricantMarketplaceHelper.saleCuts["garment"]!.initialAmount, amount: TheFabricantMarketplaceHelper.saleCuts["garment"]!.amount),
        TheFabricantMarketplace.SaleCut(name: "Season 0 Material Creator", receiver: materialCap, initialAmount: TheFabricantMarketplaceHelper.saleCuts["material"]!.initialAmount, amount: TheFabricantMarketplaceHelper.saleCuts["material"]!.amount),
        TheFabricantMarketplace.SaleCut(name: "Channel Fee Royalty", receiver: TheFabricantMarketplace.getChannelFeeCap()!, initialAmount: TheFabricantMarketplaceHelper.saleCuts["channelFee"]!.initialAmount, amount: TheFabricantMarketplaceHelper.saleCuts["channelFee"]!.amount)]
 
        let listingID = listingRef.createListing(
            nftProviderCapability: nftProviderCapability, 
            nftType: nftType, 
            nftID: nftID, 
            paymentCapability: paymentCapability, 
            salePaymentVaultType: salePaymentVaultType, 
            price: price, 
            saleCuts: saleCutArray)

        emit S0ItemListed(
            name: itemName,
            mainImage: mainImage,
            images: images,
            listingID: listingID, 
            nftType: nftType, 
            nftID: nftID, 
            ftVaultType: salePaymentVaultType, 
            price: price, 
            seller: listingRef.owner?.address, 
            season: "0"
        )
    }

    // make an offer for an s0Item from ItemNFT contract, calling TheFabricantMarketplace's Offers' makeOffer function
    pub fun s0ItemMakeOffer(       
        initialNFTOwner: Address, 
        itemRef: &ItemNFT.NFT,
        offerRef: &TheFabricantMarketplace.Offers,
        ftProviderCapability: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>,
        nftType: Type,
        nftID: UInt64,
        nftReceiver: Capability<&{NonFungibleToken.CollectionPublic}>,
        offerPaymentVaultType: Type,
        price: UFix64) {

        // get the flowToken capabilities for each component of the item (garment, item, material)
        let itemCap = getAccount(itemRef.royaltyVault.address).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)    
        let garmentCap = getAccount(itemRef.borrowGarment()!.royaltyVault.address).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        let materialCap = getAccount(itemRef.borrowMaterial()!.royaltyVault.address).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)

        // initialize sale cuts for item, garment, material and channelFee
        let saleCutArray: [TheFabricantMarketplace.SaleCut] =
        [TheFabricantMarketplace.SaleCut(name: "Season 0 Item Creator", receiver: itemCap,  initialAmount: TheFabricantMarketplaceHelper.saleCuts["item"]!.initialAmount, amount: TheFabricantMarketplaceHelper.saleCuts["item"]!.amount),
        TheFabricantMarketplace.SaleCut(name: "Season 0 Garment Creator", receiver: garmentCap, initialAmount: TheFabricantMarketplaceHelper.saleCuts["garment"]!.initialAmount, amount: TheFabricantMarketplaceHelper.saleCuts["garment"]!.amount),
        TheFabricantMarketplace.SaleCut(name: "Season 0 Material Creator", receiver: materialCap, initialAmount: TheFabricantMarketplaceHelper.saleCuts["material"]!.initialAmount, amount: TheFabricantMarketplaceHelper.saleCuts["material"]!.amount),
        TheFabricantMarketplace.SaleCut(name: "Channel Fee Royalty", receiver: TheFabricantMarketplace.getChannelFeeCap()!, initialAmount: TheFabricantMarketplaceHelper.saleCuts["channelFee"]!.initialAmount, amount: TheFabricantMarketplaceHelper.saleCuts["channelFee"]!.amount)]

        let offerID = offerRef.makeOffer(
            initialNFTOwner: initialNFTOwner,
            ftProviderCapability: ftProviderCapability,
            offerPaymentVaultType: offerPaymentVaultType,
            nftType: nftType, 
            nftID: nftID, 
            nftReceiverCapability: nftReceiver,
            price: price, 
            saleCuts: saleCutArray)

        emit S0ItemOfferMade(offerID: offerID, nftType: nftType, nftID: nftID,  ftVaultType: offerPaymentVaultType, price: price, offerer: offerRef.owner?.address, initialNFTOwner: initialNFTOwner, season: "0")
    }

    // list an s1Item from TheFabricantS1ItemNFT contract, calling TheFabricantMarketplace's Listings' createListing function
    pub fun s1ListItem(        
        itemRef: &TheFabricantS1ItemNFT.NFT,
        listingRef: &TheFabricantMarketplace.Listings,
        nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
        nftType: Type,
        nftID: UInt64,
        paymentCapability: Capability<&{FungibleToken.Receiver}>,
        salePaymentVaultType: Type,
        price: UFix64) {

        // get the flowToken capabilities for each component of the item (garment, item, material)
        let itemCap = getAccount(itemRef.royaltyVault.wallet.address).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        let itemDataID = itemRef.item.itemDataID
        let itemData = TheFabricantS1ItemNFT.getItemData(id: itemDataID)
        let itemMetadata = itemData.getMetadata()
        let itemName = itemRef.name
        let mainImage = itemMetadata["itemImage"]!.metadataValue
        var images: [String] = []
        let itemImage2 =  itemMetadata["itemImage2"]!.metadataValue
        let itemImage3 =  itemMetadata["itemImage3"]!.metadataValue
        let itemImage4 =  itemMetadata["itemImage4"]!.metadataValue
        images = images.concat([itemImage2, itemImage3, itemImage4]) 
        let garmentData = itemRef.borrowGarment()!.garment.garmentDataID
        let garmentRoyalties = TheFabricantS1GarmentNFT.getGarmentData(id: garmentData).getRoyalty()
        let materialData = itemRef.borrowMaterial()!.material.materialDataID
        let materialRoyalties = TheFabricantS1MaterialNFT.getMaterialData(id: materialData).getRoyalty()

        var saleCutArray: [TheFabricantMarketplace.SaleCut] = []
        // initialize sale cuts for item, garment, material and contract
        // add all flowToken capabilities for garment creators
        for key in garmentRoyalties.keys {
            saleCutArray.append(TheFabricantMarketplace.SaleCut(
                name: "Season 1 Garment Creator", 
                receiver: garmentRoyalties[key]!.wallet,
                //receiver: getAccount(garmentRoyalties[key]!.wallet.address).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver),
                initialAmount: garmentRoyalties[key]!.initialCut, 
                amount: garmentRoyalties[key]!.cut))
        }
        // add all flowToken capabilities for material creators
        for key in materialRoyalties.keys {
            saleCutArray.append(TheFabricantMarketplace.SaleCut(
                name: "Season 1 Material Creator",
                receiver: materialRoyalties[key]!.wallet,
                //receiver: getAccount(materialRoyalties[key]!.wallet.address).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver),
                initialAmount: materialRoyalties[key]!.initialCut, 
                amount: materialRoyalties[key]!.cut))
        }

        // add the flowToken capabilities for item creator and channel fee
        saleCutArray.append(TheFabricantMarketplace.SaleCut(name: "Season 1 Item Creator", receiver: itemCap, initialAmount: itemRef.royaltyVault.initialCut, amount: itemRef.royaltyVault.cut))
        saleCutArray.append(TheFabricantMarketplace.SaleCut(name: "Channel Fee Royalty", receiver: TheFabricantMarketplace.getChannelFeeCap()!, initialAmount: TheFabricantMarketplaceHelper.saleCuts["channelFee"]!.initialAmount, amount: TheFabricantMarketplaceHelper.saleCuts["channelFee"]!.amount))
          
        let listingID = listingRef.createListing(
            nftProviderCapability: nftProviderCapability, 
            nftType: nftType, 
            nftID: nftID, 
            paymentCapability: paymentCapability, 
            salePaymentVaultType: salePaymentVaultType, 
            price: price, 
            saleCuts: saleCutArray)

        emit S1ItemListed(
            name: itemName,
            mainImage: mainImage,
            images: images,
            listingID: listingID, 
            nftType: nftType, 
            nftID: nftID, 
            ftVaultType: salePaymentVaultType, 
            price: price, 
            seller: listingRef.owner?.address, 
            season: "1"
        )
    }

    // make an offer for an s1Item from TheFabricantS1ItemNFT contract, calling TheFabricantMarketplace's Offers' makeOffer function
    pub fun s1ItemMakeOffer(       
        initialNFTOwner: Address, 
        itemRef: &TheFabricantS1ItemNFT.NFT,
        offerRef: &TheFabricantMarketplace.Offers,
        ftProviderCapability: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>,
        nftType: Type,
        nftID: UInt64,
        nftReceiver: Capability<&{NonFungibleToken.CollectionPublic}>,
        offerPaymentVaultType: Type,
        price: UFix64) {

        // get all FlowToken royalty capabilities
        let itemCap = getAccount(itemRef.royaltyVault.wallet.address).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        let garmentData = itemRef.borrowGarment()!.garment.garmentDataID
        let garmentRoyalties = TheFabricantS1GarmentNFT.getGarmentData(id: garmentData).getRoyalty()
        let materialData = itemRef.borrowMaterial()!.material.materialDataID
        let materialRoyalties = TheFabricantS1MaterialNFT.getMaterialData(id: materialData).getRoyalty()

        var saleCutArray: [TheFabricantMarketplace.SaleCut] = []

        // initialize sale cuts for item, garment, material and contract

        // add all flowToken capabilities for garment creators
        for key in garmentRoyalties.keys {
            saleCutArray.append(TheFabricantMarketplace.SaleCut(
                name: "Season 1 Garment Creator", 
                receiver: garmentRoyalties[key]!.wallet,
                //receiver: getAccount(garmentRoyalties[key]!.wallet.address).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver),
                initialAmount: garmentRoyalties[key]!.initialCut, 
                amount: garmentRoyalties[key]!.cut))
        }
            
        // add all flowToken capabilities for material creators
        for key in materialRoyalties.keys {
            saleCutArray.append(TheFabricantMarketplace.SaleCut(
                name: "Season 1 Material Creator",
                receiver: materialRoyalties[key]!.wallet,
                //receiver: getAccount(materialRoyalties[key]!.wallet.address).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver),
                initialAmount: materialRoyalties[key]!.initialCut, 
                amount: materialRoyalties[key]!.cut))
        }

        // add the flowToken capabilities for item creator and channel fee
        saleCutArray.append(TheFabricantMarketplace.SaleCut(name: "Season 1 Item Creator", receiver: itemCap, initialAmount: itemRef.royaltyVault.initialCut, amount: itemRef.royaltyVault.cut))
        saleCutArray.append(TheFabricantMarketplace.SaleCut(name: "Channel Fee Royalty", receiver: TheFabricantMarketplace.getChannelFeeCap()!, initialAmount: TheFabricantMarketplaceHelper.saleCuts["channelFee"]!.initialAmount, amount: TheFabricantMarketplaceHelper.saleCuts["channelFee"]!.amount))

        let offerID = offerRef.makeOffer(
            initialNFTOwner: initialNFTOwner,
            ftProviderCapability: ftProviderCapability,
            offerPaymentVaultType: offerPaymentVaultType,
            nftType: nftType, 
            nftID: nftID, 
            nftReceiverCapability: nftReceiver,
            price: price, 
            saleCuts: saleCutArray)

        emit S1ItemOfferMade(offerID: offerID, nftType: nftType, nftID: nftID, ftVaultType: offerPaymentVaultType, price: price, offerer: offerRef.owner?.address, initialNFTOwner: initialNFTOwner, season: "1")

    }

    // list an s2Item from TheFabricantS2ItemNFT contract, calling TheFabricantMarketplace's Listings' createListing function
    pub fun s2ListItem(        
        itemRef: &TheFabricantS2ItemNFT.NFT,
        listingRef: &TheFabricantMarketplace.Listings,
        nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
        nftType: Type,
        nftID: UInt64,
        paymentCapability: Capability<&{FungibleToken.Receiver}>,
        salePaymentVaultType: Type,
        price: UFix64) {

        // get the flowToken capabilities for each component of the item (garment, item, material)
        let itemCap = getAccount(itemRef.royaltyVault.wallet.address).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        let itemDataID = itemRef.item.itemDataID
        let itemData = TheFabricantS2ItemNFT.getItemData(id: itemDataID)
        let itemMetadata = itemData.getMetadata()
        let itemName = itemRef.name
        let mainImage = itemMetadata["itemImage"]!.metadataValue
        var images: [String] = []
        let itemImage2 =  itemMetadata["itemImage2"]!.metadataValue
        let itemImage3 =  itemMetadata["itemImage3"]!.metadataValue
        let itemImage4 =  itemMetadata["itemImage4"]!.metadataValue
        images = images.concat([itemImage2, itemImage3, itemImage4]) 
        let edition = itemMetadata["edition"] != nil ? itemMetadata["edition"]!.metadataValue : nil;
        let garmentData = itemRef.borrowGarment()!.garment.garmentDataID
        let garmentRoyalties = TheFabricantS2GarmentNFT.getGarmentData(id: garmentData).getRoyalty()
        let materialData = itemRef.borrowMaterial()!.material.materialDataID
        let materialRoyalties = TheFabricantS2MaterialNFT.getMaterialData(id: materialData).getRoyalty()

        var saleCutArray: [TheFabricantMarketplace.SaleCut] = []
        // initialize sale cuts for item, garment, material and contract
        // add all flowToken capabilities for garment creators
        for key in garmentRoyalties.keys {
            saleCutArray.append(TheFabricantMarketplace.SaleCut(
                name: "Season 2 Garment Creator", 
                receiver: garmentRoyalties[key]!.wallet,
                //receiver: getAccount(garmentRoyalties[key]!.wallet.address).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver),
                initialAmount: garmentRoyalties[key]!.initialCut, 
                amount: garmentRoyalties[key]!.cut))
        }
        // add all flowToken capabilities for material creators
        for key in materialRoyalties.keys {
            saleCutArray.append(TheFabricantMarketplace.SaleCut(
                name: "Season 2 Material Creator",
                receiver: materialRoyalties[key]!.wallet,
                //receiver: getAccount(materialRoyalties[key]!.wallet.address).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver),
                initialAmount: materialRoyalties[key]!.initialCut, 
                amount: materialRoyalties[key]!.cut))
        }

        // add the flowToken capabilities for item creator and channel fee
        saleCutArray.append(TheFabricantMarketplace.SaleCut(
            name: "Season 2 Item Creator", 
            receiver: itemCap, 
            initialAmount: itemRef.royaltyVault.initialCut, 
            amount: itemRef.royaltyVault.cut
        ))
        saleCutArray.append(TheFabricantMarketplace.SaleCut(
            name: "Channel Fee Royalty", 
            receiver: TheFabricantMarketplace.getChannelFeeCap()!, 
            initialAmount: TheFabricantMarketplaceHelper.saleCuts["channelFee"]!.initialAmount, 
            amount: TheFabricantMarketplaceHelper.saleCuts["channelFee"]!.amount
        ))
          
        let listingID = listingRef.createListing(
            nftProviderCapability: nftProviderCapability, 
            nftType: nftType, 
            nftID: nftID, 
            paymentCapability: paymentCapability, 
            salePaymentVaultType: salePaymentVaultType, 
            price: price, 
            saleCuts: saleCutArray)

        emit S2ItemListed(
            name: itemName,
            mainImage: mainImage,
            images: images,
            listingID: listingID, 
            nftType: nftType, 
            nftID: nftID, 
            ftVaultType: salePaymentVaultType, 
            price: price, 
            seller: listingRef.owner?.address, 
            season: "2", 
            edition: edition
        )
    }

    // make an offer for an s1Item from TheFabricantS1ItemNFT contract, calling TheFabricantMarketplace's Offers' makeOffer function
    pub fun s2ItemMakeOffer(       
        initialNFTOwner: Address, 
        itemRef: &TheFabricantS2ItemNFT.NFT,
        offerRef: &TheFabricantMarketplace.Offers,
        ftProviderCapability: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>,
        nftType: Type,
        nftID: UInt64,
        nftReceiver: Capability<&{NonFungibleToken.CollectionPublic}>,
        offerPaymentVaultType: Type,
        price: UFix64) {

        // get all FlowToken royalty capabilities
        let itemCap = getAccount(itemRef.royaltyVault.wallet.address).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
        let itemDataID = itemRef.item.itemDataID
        let itemData = TheFabricantS2ItemNFT.getItemData(id: itemDataID)
        let itemMetadata = itemData.getMetadata()
        let edition = itemMetadata["edition"] != nil ? itemMetadata["edition"]!.metadataValue : nil;
        let garmentData = itemRef.borrowGarment()!.garment.garmentDataID
        let garmentRoyalties = TheFabricantS2GarmentNFT.getGarmentData(id: garmentData).getRoyalty()
        let materialData = itemRef.borrowMaterial()!.material.materialDataID
        let materialRoyalties = TheFabricantS2MaterialNFT.getMaterialData(id: materialData).getRoyalty()

        var saleCutArray: [TheFabricantMarketplace.SaleCut] = []

        // initialize sale cuts for item, garment, material and contract

        // add all flowToken capabilities for garment creators
        for key in garmentRoyalties.keys {
            saleCutArray.append(TheFabricantMarketplace.SaleCut(
                name: "Season 2 Garment Creator", 
                receiver: garmentRoyalties[key]!.wallet,
                //receiver: getAccount(garmentRoyalties[key]!.wallet.address).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver),
                initialAmount: garmentRoyalties[key]!.initialCut, 
                amount: garmentRoyalties[key]!.cut))
        }
            
        // add all flowToken capabilities for material creators
        for key in materialRoyalties.keys {
            saleCutArray.append(TheFabricantMarketplace.SaleCut(
                name: "Season 2 Material Creator",
                receiver: materialRoyalties[key]!.wallet,
                //receiver: getAccount(materialRoyalties[key]!.wallet.address).getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver),
                initialAmount: materialRoyalties[key]!.initialCut, 
                amount: materialRoyalties[key]!.cut))
        }

        // add the flowToken capabilities for item creator and channel fee
        saleCutArray.append(TheFabricantMarketplace.SaleCut(name: "Season 2 Item Creator", receiver: itemCap, initialAmount: itemRef.royaltyVault.initialCut, amount: itemRef.royaltyVault.cut))
        saleCutArray.append(TheFabricantMarketplace.SaleCut(name: "Channel Fee Royalty", receiver: TheFabricantMarketplace.getChannelFeeCap()!, initialAmount: TheFabricantMarketplaceHelper.saleCuts["channelFee"]!.initialAmount, amount: TheFabricantMarketplaceHelper.saleCuts["channelFee"]!.amount))

        let offerID = offerRef.makeOffer(
            initialNFTOwner: initialNFTOwner,
            ftProviderCapability: ftProviderCapability,
            offerPaymentVaultType: offerPaymentVaultType,
            nftType: nftType, 
            nftID: nftID, 
            nftReceiverCapability: nftReceiver,
            price: price, 
            saleCuts: saleCutArray)

        emit S2ItemOfferMade(offerID: offerID, nftType: nftType, nftID: nftID, ftVaultType: offerPaymentVaultType, price: price, offerer: offerRef.owner?.address, initialNFTOwner: initialNFTOwner, season: "2", edition: edition)

    }

    // list an TheFabricantAccessPass NFT
    pub fun listAccessPass(        
        accessPassRef: &TheFabricantAccessPass.NFT,
        listingRef: &TheFabricantMarketplace.Listings,
        nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
        nftType: Type,
        nftID: UInt64,
        paymentCapability: Capability<&{FungibleToken.Receiver}>,
        salePaymentVaultType: Type,
        price: UFix64) {

        var saleCutArray: [TheFabricantMarketplace.SaleCut] = []
        let royalties = accessPassRef.getTFRoyalties()
        for royalty in royalties {
            saleCutArray.append(TheFabricantMarketplace.SaleCut(name: royalty.description, receiver: royalty.receiver, initialAmount: royalty.initialCut, amount: royalty.cut))
        }
          
        let listingID = listingRef.createListing(
            nftProviderCapability: nftProviderCapability, 
            nftType: nftType, 
            nftID: nftID, 
            paymentCapability: paymentCapability, 
            salePaymentVaultType: salePaymentVaultType, 
            price: price, 
            saleCuts: saleCutArray)

        emit AccessPassListed(
            listingID: listingID, 
            nftType: nftType, 
            nftID: nftID, 
            serial: accessPassRef.serial,
            ftVaultType: salePaymentVaultType, 
            price: price, 
            seller: listingRef.owner?.address,
            variant: accessPassRef.variant,
            promotionId: accessPassRef.promotionId,
            promotionHost: accessPassRef.promotionHost,
            accessUnits: accessPassRef.accessUnits,
            initialAccessUnits: accessPassRef.initialAccessUnits,
            season: "2"
            )
    }
    
    // make an offer for a TheFabricantAccessPass NFT
    pub fun accessPassMakeOffer(       
        initialNFTOwner: Address, 
        accessPassRef: &TheFabricantAccessPass.NFT,
        offerRef: &TheFabricantMarketplace.Offers,
        ftProviderCapability: Capability<&{FungibleToken.Provider, FungibleToken.Balance}>,
        nftType: Type,
        nftID: UInt64,
        nftReceiver: Capability<&{NonFungibleToken.CollectionPublic}>,
        offerPaymentVaultType: Type,
        price: UFix64) {

        var saleCutArray: [TheFabricantMarketplace.SaleCut] = []
        let royalties = accessPassRef.getTFRoyalties()
        for royalty in royalties {
            saleCutArray.append(TheFabricantMarketplace.SaleCut(name: royalty.description, receiver: royalty.receiver, initialAmount: royalty.initialCut, amount: royalty.cut))
        }

        let offerID = offerRef.makeOffer(
            initialNFTOwner: initialNFTOwner,
            ftProviderCapability: ftProviderCapability,
            offerPaymentVaultType: offerPaymentVaultType,
            nftType: nftType, 
            nftID: nftID, 
            nftReceiverCapability: nftReceiver,
            price: price, 
            saleCuts: saleCutArray)

        emit AccessPassOfferMade(offerID: offerID, nftType: nftType, nftID: nftID, ftVaultType: offerPaymentVaultType, price: price, offerer: offerRef.owner?.address, initialNFTOwner: initialNFTOwner, season: "2")

    }

    pub fun xxoryListItem(
        itemRef: &TheFabricantXXories.NFT{TheFabricantNFTStandard.TFNFT},
        listingsRef: &TheFabricantMarketplace.Listings,
        nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
        nftType: Type,
        nftID: UInt64,
        paymentCapability: Capability<&{FungibleToken.Receiver}>,
        salePaymentVaultType: Type,
        price: UFix64
    ) {
        let name = itemRef.getFullName()
        let royalties = itemRef.getTFRoyalties()
        let imagesDict = itemRef.getImages()
        let mainImage = imagesDict["mainImage"] ?? ""
        let images = imagesDict.values
        let editions = itemRef.getEditions()
        let edition = editions.infoList[0].number

        // Create saleCuts
        var saleCutArray: [TheFabricantMarketplace.SaleCut] = []

        // initialAmount: 10%
        // amount: 5%
        let channelFeeSaleCut = TheFabricantMarketplace.SaleCut(
            name: "Channel Fee Royalty",
            receiver: TheFabricantMarketplace.getChannelFeeCap()!,
            initialAmount: TheFabricantMarketplaceHelper.saleCuts["channelFee"]!.initialAmount, 
            amount: TheFabricantMarketplaceHelper.saleCuts["channelFee"]!.amount
        )

        // initialAmount: 10%
        // amount: 5%
        // NOTE: We can re-use the channel fee royalty cap here as they are the same.
        let TFSaleCut = TheFabricantMarketplace.SaleCut(
            name: "The Fabricant XXories",
            receiver: TheFabricantMarketplace.getChannelFeeCap()!,
            initialAmount: TheFabricantMarketplaceHelper.saleCuts["TheFabricantXXories"]!.initialAmount, 
            amount: TheFabricantMarketplaceHelper.saleCuts["TheFabricantXXories"]!.amount
        )

        saleCutArray.append(channelFeeSaleCut)
        saleCutArray.append(TFSaleCut)

        let listingID = listingsRef.createListing(
            nftProviderCapability: nftProviderCapability, 
            nftType: nftType, 
            nftID: nftID, 
            paymentCapability: paymentCapability, 
            salePaymentVaultType: salePaymentVaultType, 
            price: price, 
            saleCuts: saleCutArray
        )

        emit XXoryListed(
            name: name,
            mainImage: mainImage,
            images: images,
            listingID: listingID, 
            nftType: nftType, 
            nftID: nftID, 
            ftVaultType: salePaymentVaultType, 
            price: price, 
            seller: listingsRef.owner?.address, 
            season: "3", 
            edition: edition.toString()
        )
    }

    // Admin
    // Admin can add salecutvalues
    pub resource Admin{
        
        // change contract royalty address
        pub fun addSaleCutValues(royaltyName: String, initialAmount: UFix64, amount: UFix64){
            TheFabricantMarketplaceHelper.saleCuts[royaltyName] = 
                TheFabricantMarketplaceHelper.SaleCutValues(initialAmount: initialAmount, amount: amount)
        }
    }

    pub fun getSaleCuts(): {String: SaleCutValues} {
        return self.saleCuts
    }

    pub init() {
        self.AdminStoragePath = /storage/fabricantTheFabricantMarketplaceHelperAdmin0021
        self.saleCuts = {}
        self.account.save<@Admin>(<- create Admin(), to: self.AdminStoragePath)
    }
}
 