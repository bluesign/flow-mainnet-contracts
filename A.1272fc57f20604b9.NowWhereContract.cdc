import NFTContract from 0x1e075b24abe6eca6
import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import FlowToken from 0x1654653399040a61

pub contract NowWhereContract {
    // -----------------------------------------------------------------------
    // Nowwhere contract Event definitions
    // -----------------------------------------------------------------------
    pub event ContractInitialized()
    // Emitted when a new Drop is created
    pub event DropCreated(dropId: UInt64, creator: Address, startDate: UFix64, endDate: UFix64)
    // Emitted when a new Drop is updated
    pub event DropUpdated(dropId: UInt64, startDate: UFix64, endDate: UFix64)
    // Emitted when a Drop is purchased
    pub event DropPurchased(dropId: UInt64, templateId: UInt64, mintNumbers: UInt64, receiptAddress: Address)
     // Emitted when a Drop is purchased using flow
    pub event DropPurchasedWithFlow(dropId: UInt64, templateId: UInt64, mintNumbers: UInt64, receiptAddress: Address, price: UFix64)
    // Emitted when a Drop is removed
    pub event DropRemoved(dropId: UInt64)
    // Contract level paths for storing resources
    pub let DropAdminStoragePath: StoragePath
    // The capability that is used for calling the admin functions 
    access(contract) let adminRef: Capability<&{NFTContract.NFTMethodsCapability}>
    // Variable size dictionary of Drop structs
    access(self) var allDrops: {UInt64: Drop}
    // -----------------------------------------------------------------------
    // Nowwhere contract-level Composite Type definitions
    // -----------------------------------------------------------------------
    // These are just *definitions* for Types that this contract
    // and other accounts can use. These definitions do not contain
    // actual stored values, but an instance (or object) of one of these Types
    // can be created by this contract that contains stored values.

    /* Drop
    *   Drop is an event, which has a start-date and end-date. 
    *   In a drop, Admin will add templates that can be purcahsed in that event
    */ 
    pub struct Drop {
        pub let dropId: UInt64
        pub var startDate: UFix64
        pub var endDate: UFix64
        access(contract) var templates: {UInt64: AnyStruct}

        init(dropId: UInt64, startDate: UFix64, endDate: UFix64, templates: {UInt64: AnyStruct}) {
            self.dropId = dropId
            self.startDate = startDate
            self.endDate = endDate
            self.templates = templates
        }

        //Admin can update start-date, end-date and templates of a drop
        // start-date only updated if sale is not started yet
        // end-date can updated any-way, Admin need to check if templates are soldout than no need to active that drop 
        // templates can be updated, if sale is not started yet
        pub fun updateDrop(startDate: UFix64?, endDate: UFix64?, templates: {UInt64: AnyStruct}?) {
            pre{
                (startDate == nil) || (self.startDate > getCurrentBlock().timestamp && startDate! >= getCurrentBlock().timestamp): "can't update start date"
                (endDate == nil) || (endDate! > getCurrentBlock().timestamp): "can't update end date"
                (templates == nil) || (templates!.keys.length != 0 && self.startDate > getCurrentBlock().timestamp) : "can't update templates"
                !(startDate == nil && endDate == nil && templates == nil): "All values are nil"
           }

            if(startDate != nil && startDate! < self.endDate){
                self.startDate = startDate!
            }

            if(endDate != nil && endDate! > self.startDate) {
                self.endDate = endDate!
            }

            if(templates != nil) {
                self.templates = templates!
            }
            
            emit DropUpdated(dropId: self.dropId, startDate: self.startDate, endDate: self.endDate)
        }
        
        
        pub fun getDropTemplates(): {UInt64: AnyStruct} {
            return self.templates
        }
    }

    /* DropAdmin
    *   DropAdmin is a resource, which will be used by the Admin to create, update, remove drop and purchase NFT
    */
    pub resource DropAdmin {
        access(contract) var ownerVault: Capability<&AnyResource{FungibleToken.Receiver}>?

        pub fun addOwnerVault(_ownerVault: Capability<&AnyResource{FungibleToken.Receiver}>){
            self.ownerVault = _ownerVault
        }

        pub fun createDrop(dropId: UInt64, startDate: UFix64, endDate: UFix64, templates: {UInt64: AnyStruct}){
            pre{
                dropId != nil: "invalid drop id"
                NowWhereContract.allDrops[dropId] == nil: "drop id already exists"
                startDate >= getCurrentBlock().timestamp: "Start Date should be greater or Equal than current time"
                endDate > startDate: "End date should be greater than start date"
                templates != nil: "templates must not be null"
            }

            var areValidTemplates: Bool = true
            for templateId in templates.keys {
                var template = NFTContract.getTemplateById(templateId: templateId)
                if(template == nil){
                    areValidTemplates = false
                    break
                }
            }
            assert(areValidTemplates, message:"templateId is not valid")

            var newDrop = Drop(dropId: dropId,startDate: startDate, endDate: endDate, templates: templates)
            NowWhereContract.allDrops[newDrop.dropId] = newDrop

            emit DropCreated(dropId: dropId, creator: self.owner?.address!, startDate: startDate, endDate: endDate)
        }

        pub fun updateDrop(dropId: UInt64, startDate: UFix64?, endDate: UFix64?, templates: {UInt64: AnyStruct}?) {
            pre{
                dropId != nil: "invalid drop id"
                NowWhereContract.allDrops[dropId] != nil: "drop id does not exists"
                startDate != 0.0 || endDate != 0.0: "please provide valid dates"
            }

            if(templates !=nil && templates!.keys.length != 0){
                var areValidTemplates: Bool = true
                for templateId in templates!.keys {
                    var template = NFTContract.getTemplateById(templateId: templateId)
                    var templateSupply = template.issuedSupply
                    if(template == nil || templateSupply != 0){
                        areValidTemplates = false
                        break
                    }
                }
                assert(areValidTemplates, message:"templateId is not valid")
            }
            NowWhereContract.allDrops[dropId]!.updateDrop(startDate: startDate, endDate: endDate, templates: templates)
        }


        pub fun removeDrop(dropId: UInt64){
            pre {
                dropId != nil : "invalid drop id"
                NowWhereContract.allDrops[dropId] != nil: "drop id does not exist"
                getCurrentBlock().timestamp < NowWhereContract.allDrops[dropId]!.startDate: "Drop sale is started"
            }

            NowWhereContract.allDrops.remove(key: dropId)
            emit DropRemoved(dropId: dropId)
        }

        pub fun purchaseNFT(dropId: UInt64,templateId: UInt64, mintNumbers: UInt64, receiptAddress: Address){
            pre {
                mintNumbers > 0: "mint number must be greater than zero"
                mintNumbers <= 10: "mint numbers must be less than ten"
                templateId > 0: "template id must be greater than zero"
                dropId != nil : "invalid drop id"
                receiptAddress !=nil: "invalid receipt Address"
                NowWhereContract.allDrops[dropId] != nil: "drop id does not exist"
                NowWhereContract.allDrops[dropId]!.startDate <= getCurrentBlock().timestamp: "drop not started yet"
                NowWhereContract.allDrops[dropId]!.endDate > getCurrentBlock().timestamp: "drop already ended"
                NowWhereContract.allDrops[dropId]!.templates[templateId] != nil: "template id does not exist"
            }

            var template = NFTContract.getTemplateById(templateId: templateId)
            assert(template.issuedSupply + mintNumbers <= template.maxSupply, message: "template reached to its max supply") 
            var i: UInt64 = 0
            while i < mintNumbers {
                NowWhereContract.adminRef.borrow()!.mintNFT(templateId: templateId, account: receiptAddress)
                i = i + 1
            }
            emit DropPurchased(dropId: dropId,templateId: templateId, mintNumbers: mintNumbers, receiptAddress: receiptAddress)
        }

        pub fun purchaseNFTWithFlow(dropId: UInt64, templateId: UInt64, mintNumbers: UInt64, receiptAddress: Address, price: UFix64, flowPayment: @FungibleToken.Vault) {
            pre{
                price > 0.0: "Price should be greater than zero"
                receiptAddress !=nil: "invalid receipt Address"
                flowPayment.balance == price: "Your vault does not have balance to buy NFT"
                mintNumbers > 0: "mint number must be greater than zero"
                mintNumbers <= 10: "mint numbers must be less than ten"
                templateId > 0: "template id must be greater than zero"
                dropId != nil : "invalid drop id"
                receiptAddress !=nil: "invalid receipt Address"
                NowWhereContract.allDrops[dropId] != nil: "drop id does not exist"
                NowWhereContract.allDrops[dropId]!.startDate <= getCurrentBlock().timestamp: "drop not started yet"
                NowWhereContract.allDrops[dropId]!.endDate > getCurrentBlock().timestamp: "drop already ended"
                NowWhereContract.allDrops[dropId]!.templates[templateId] != nil: "template id does not exist"
            }
                
            let vaultRef = self.ownerVault!.borrow()
                ?? panic("Could not borrow reference to owner token vault")
            vaultRef.deposit(from: <-flowPayment)
            var template = NFTContract.getTemplateById(templateId: templateId)
            assert(template.issuedSupply + mintNumbers <= template.maxSupply, message: "template reached to its max supply")
            
            var i: UInt64 = 0
            while i < mintNumbers {
                NowWhereContract.adminRef.borrow()!.mintNFT(templateId: templateId, account: receiptAddress)
                i = i + 1
            }
            emit DropPurchasedWithFlow(dropId: dropId, templateId: templateId, mintNumbers: mintNumbers, receiptAddress: receiptAddress,price: price)
        }

        init(){
            self.ownerVault = nil
        }
    }

    // getDropById returns the IDs that the specified Drop id
    // is associated with 
    pub fun getDropById(dropId: UInt64): Drop {
        return self.allDrops[dropId]!
    }

    // getAllDrops returns all the Drops in NowWhereContract
    // Returns: A dictionary of all the Drop that have been created
    pub fun getAllDrops(): {UInt64: Drop} {
        return self.allDrops
    }

    init() {
        // Initialize contract fields
        self.allDrops = {}

        self.DropAdminStoragePath = /storage/NowwhereDropAdmin
        // get the private capability to the admin resource interface
        // to call the functions of this interface.
        self.adminRef = self.account.getCapability<&{NFTContract.NFTMethodsCapability}>(NFTContract.NFTMethodsCapabilityPrivatePath)

        // Put the Drop Admin in storage
        self.account.save(<- create DropAdmin(), to: self.DropAdminStoragePath)
        emit ContractInitialized()
    }
}
