import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import AFLNFT from 0x8f9231920da9af6d
import FiatToken from 0xb19436aae4d94622

pub contract AFLPack {
    // event when a pack is bought
    pub event PackBought(templateId: UInt64, receiptAddress: Address?)
    pub event PurchaseDetails(buyer: Address, momentsInPack: [{String: UInt64}], pricePaid: UFix64, packID: UInt64, settledOnChain: Bool)
    // event when a pack is opened
    pub event PackOpened(nftId: UInt64, receiptAddress: Address?)

    // path for pack storage
    pub let PackStoragePath : StoragePath
    // path for pack public
    pub let PackPublicPath : PublicPath

    access(self) var ownerAddress: Address

    access(contract) let adminRef : Capability<&FiatToken.Vault{FungibleToken.Receiver}>
    
    pub resource interface PackPublic {
        // making this function public to call by authorized users
        pub fun openPack(packNFT: @AFLNFT.NFT, receiptAddress: Address)
    }
    pub resource Pack : PackPublic {

        pub fun updateOwnerAddress(owner:Address){
            pre{
                owner != nil: "owner must not be null"
            }
            AFLPack.ownerAddress = owner
        }

        pub fun buyPackFromAdmin(templateIds: [{String: UInt64}], packTemplateId: UInt64, receiptAddress: Address, price: UFix64) {
            pre {
                price > 0.0: "Price should be greater than zero"
                templateIds.length > 0 : "template id  must not be zero"
                receiptAddress != nil : "receipt address must not be null"
            }
            var allNftTemplateExists = true;
            assert(templateIds.length <= 10, message: "templates limit exceeded")
            let nftTemplateIds : [{String: UInt64}] = []
            for tempID in templateIds {
                let nftTemplateData = AFLNFT.getTemplateById(templateId: tempID["id"]!)
                if(nftTemplateData == nil) {
                    allNftTemplateExists = false
                    break
                }
                nftTemplateIds.append(tempID)
            }

            let originalPackTemplateData = AFLNFT.getTemplateById(templateId: packTemplateId)
            let originalPackTemplateImmutableData = originalPackTemplateData.getImmutableData()
            originalPackTemplateImmutableData["nftTemplates"] = nftTemplateIds
            

            assert(allNftTemplateExists, message: "Invalid NFTs")
            AFLNFT.createTemplate(maxSupply: 1, immutableData: originalPackTemplateImmutableData)

            let lastIssuedTemplateId = AFLNFT.getLatestTemplateId()
            AFLNFT.mintNFT(templateInfo: {"id":lastIssuedTemplateId}, account: receiptAddress)
            AFLNFT.allTemplates[packTemplateId]!.incrementIssuedSupply()
            emit PackBought(templateId: lastIssuedTemplateId, receiptAddress: receiptAddress)
            emit PurchaseDetails(buyer: receiptAddress, momentsInPack: templateIds, pricePaid: price, packID: packTemplateId, settledOnChain: false) 
        } 
        
        pub fun buyPack(templateIds: [{String: UInt64}], packTemplateId: UInt64, receiptAddress: Address, price: UFix64, flowPayment: @FungibleToken.Vault) {
            pre {
                price > 0.0: "Price should be greater than zero"
                templateIds.length > 0 : "template id  must not be zero"
                flowPayment.balance == price: "Your vault does not have balance to buy NFT"
                receiptAddress != nil : "receipt address must not be null"
            }
            var allNftTemplateExists = true;
            assert(templateIds.length <= 10, message: "templates limit exceeded")
            let nftTemplateIds : [{String: UInt64}] = []
            for tempID in templateIds {
                let nftTemplateData = AFLNFT.getTemplateById(templateId: tempID["id"]!)
                if(nftTemplateData == nil) {
                    allNftTemplateExists = false
                    break
                }
                nftTemplateIds.append(tempID)
            }

            let originalPackTemplateData = AFLNFT.getTemplateById(templateId: packTemplateId)
            let originalPackTemplateImmutableData = originalPackTemplateData.getImmutableData()
            originalPackTemplateImmutableData["nftTemplates"] = nftTemplateIds
            

            assert(allNftTemplateExists, message: "Invalid NFTs")
            AFLNFT.createTemplate(maxSupply: 1, immutableData: originalPackTemplateImmutableData)

            let lastIssuedTemplateId = AFLNFT.getLatestTemplateId()
            let receiptAccount = getAccount(AFLPack.ownerAddress)
            let recipientCollection = receiptAccount
                 .getCapability(FiatToken.VaultReceiverPubPath)
                .borrow<&FiatToken.Vault{FungibleToken.Receiver}>()
                ?? panic("Could not get receiver reference to the flow receiver")
            recipientCollection.deposit(from: <-flowPayment)

            AFLNFT.mintNFT(templateInfo: {"id":lastIssuedTemplateId}, account: receiptAddress)
            AFLNFT.allTemplates[packTemplateId]!.incrementIssuedSupply()
            emit PackBought(templateId: lastIssuedTemplateId, receiptAddress: receiptAddress)
            emit PurchaseDetails(buyer: receiptAddress, momentsInPack: templateIds, pricePaid: price, packID: packTemplateId, settledOnChain: true) 
        }

        pub fun openPack(packNFT: @AFLNFT.NFT, receiptAddress: Address) {
            pre {
                packNFT != nil : "pack nft must not be null"
                receiptAddress != nil : "receipt address must not be null"
            }
            var packNFTData = AFLNFT.getNFTData(nftId: packNFT.id)
            var packTemplateData = AFLNFT.getTemplateById(templateId: packNFTData.templateId)
            let templateImmutableData = packTemplateData.getImmutableData()

            let allIds = templateImmutableData["nftTemplates"]! as! [AnyStruct]

            let packSlug = templateImmutableData["slug"]! as! String

            assert(allIds.length <= 10, message: "templates limit exceeded")
            for tempID in allIds {
                if(packSlug == "ripper-skippers") {
                    let templateInfo = {"id":tempID as! UInt64}
                    AFLNFT.mintNFT(templateInfo: templateInfo!,  account: receiptAddress)
                } else {
                    let templateInfo = tempID as? {String: UInt64}
                    AFLNFT.mintNFT(templateInfo: templateInfo!,  account: receiptAddress)
                }
            }
            emit PackOpened(nftId: packNFT.id, receiptAddress: self.owner?.address)
            destroy packNFT
        }
        init(){
        }
    }
    init() {
        self.ownerAddress = self.account!.address
        self.adminRef = self.account.getCapability<&FiatToken.Vault{FungibleToken.Receiver}>(FiatToken.VaultReceiverPubPath)
        self.PackStoragePath = /storage/AFLPack
        self.PackPublicPath = /public/AFLPack
        self.account.save(<- create Pack(), to: self.PackStoragePath)
        self.account.link<&{PackPublic}>(self.PackPublicPath, target: self.PackStoragePath)
    }
}
 