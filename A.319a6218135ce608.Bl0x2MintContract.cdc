import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import Bl0x2 from 0x319a6218135ce608

pub contract Bl0x2MintContract {
    pub let AdminStoragePath: StoragePath

    pub var whitelist: {Address: UInt64}
    pub var extraFields: {String: AnyStruct}
    init() {
        self.whitelist = {}
        
        self.extraFields = {}
        
        self.AdminStoragePath = /storage/Bl0x2MintContractAdmin

        self.account.save(<- create Administrator(), to: self.AdminStoragePath)
    }
    
    pub resource Administrator {
        pub fun setFields(fields:{String:AnyStruct}){
            for key in fields.keys {
                if(key == "whitelist"){
                    Bl0x2MintContract.whitelist = fields[key] as! {Address: UInt64}? ?? {}
                } else if(key == "whitelistToAdd"){
                    let whitelistToAdd = fields[key] as! {Address: UInt64}? ?? {}
                    for k in whitelistToAdd.keys {
                      Bl0x2MintContract.whitelist[k] = (Bl0x2MintContract.whitelist[k] ?? UInt64(0)) + whitelistToAdd[k]!
                    }
                }
                else {
                    Bl0x2MintContract.extraFields[key] = fields[key]
                }
            }
        }
    }
    pub fun getFreeMintNum(_ signer: AuthAccount): UInt64{
        return self.whitelist[signer.address] ?? 0
    }
    pub fun getTier(_ signer: AuthAccount): UInt64{
        var hasCommonBl = false
        let Bl0xRare = self.extraFields["Bl0xRare"] as! {UInt64: Bool}? ?? {}
        let bl = signer.borrow<&{NonFungibleToken.CollectionPublic}>(from: /storage/bl0xNFTs)
        if(bl!=nil){
            let ids = bl!.getIDs()
            for id in ids{
                if(Bl0xRare.containsKey(id)){
                    return 3
                }
                hasCommonBl = true
            }
        }
        var hasRare = false
        let fl = signer.borrow<&{NonFungibleToken.CollectionPublic}>(from: /storage/MatrixMarketFlowNiaCollection)
        if(fl!=nil){
            let ids = fl!.getIDs()
            for id in ids{
                if(id<=2999){
                    hasRare = true
                }
            }
        }
        if(hasCommonBl&&hasRare){
            return 3
        }
        if(hasCommonBl||hasRare){
            return 2
        }
        return 1
    }

    pub fun paymentMint(
        _ signer: AuthAccount,
        count: UInt64
    ){
        var opened = self.extraFields["opened"] as! Bool? ?? false
        if !opened {
            panic("sale closed")
        }
        var startTime = self.extraFields["freeMintStartTime"] as! UFix64?
        var endTime = self.extraFields["freeMintEndTime"] as! UFix64?
        var paymentMintStartTime = self.extraFields["paymentMintStartTime"] as! UFix64?
        var paymentMintEndTime = self.extraFields["paymentMintEndTime"] as! UFix64?
        var currentTokenId = UInt64(self.extraFields["currentTokenId"] as! Number? ?? 0)
        var maxTokenId = UInt64(self.extraFields["maxTokenId"] as! Number? ?? 2221)
        var receiverAddr1 = (self.extraFields["receiverAddr1"] as! Address?)!
        var receiverAddr2 = (self.extraFields["receiverAddr2"] as! Address?)!

        
        if !(startTime == nil || startTime! <= getCurrentBlock().timestamp){
            panic("sale not started yet")
        }
        if !(endTime == nil || endTime! > getCurrentBlock().timestamp){
            panic("sale already ended")
        }
        if !(currentTokenId <= maxTokenId){
            panic("all minted")
        }
        var realCount = count
        if(maxTokenId - currentTokenId + 1 < realCount){
            realCount = maxTokenId - currentTokenId + 1
        }
        
        let tier = self.getTier(signer)
        if(tier == 1){
            if !(paymentMintStartTime == nil || paymentMintStartTime! <= getCurrentBlock().timestamp){
            panic("sale not started yet")
            }
            if !(paymentMintEndTime == nil || paymentMintEndTime! > getCurrentBlock().timestamp){
            panic("sale already ended")
            }
        }
        var price: UFix64 = 33.0
        if(tier == 1){
        }else if(tier == 2){
            price = 22.0
        }else if(tier == 3){
            price = 17.0
        }
        
        var tokenStoragePath = /storage/flowTokenVault

        let vault = signer.borrow<&FungibleToken.Vault>(from: tokenStoragePath)
            ?? panic("Cannot borrow vault from signer storage")
            
        var tokenReceiverPath = /public/flowTokenReceiver
        let receiver1 = getAccount(receiverAddr1).getCapability<&{FungibleToken.Receiver}>(tokenReceiverPath).borrow() ?? panic("Cannot borrow FungibleToken receiver")
        let receiver2 = getAccount(receiverAddr2).getCapability<&{FungibleToken.Receiver}>(tokenReceiverPath).borrow() ?? panic("Cannot borrow FungibleToken receiver")

        let payment1 <- vault.withdraw(amount: price*UFix64(realCount)*0.95)
        let payment2 <- vault.withdraw(amount: price*UFix64(realCount)*0.05)
        receiver1.deposit(from: <- payment1)
        receiver2.deposit(from: <- payment2)
        
        let recipient = signer.getCapability(Bl0x2.CollectionPublicPath).borrow<&{NonFungibleToken.CollectionPublic}>() ?? panic("Cannot borrow NFT collection receiver from account")

        // start minting
        let minter = self.account.borrow<&Bl0x2.NFTMinter>(from: Bl0x2.MinterStoragePath)!
        let metadata: {String:String} = {}
        
        var i = UInt64(0)
        while(i < realCount){
            minter.mintNFTWithID(id: currentTokenId + i, recipient: recipient, metadata: metadata)

            i = i + UInt64(1)
        }
        
        self.extraFields["currentTokenId"] = currentTokenId + i
    }
    pub fun freeMint(
        _ signer: AuthAccount
    ){
        var opened = self.extraFields["opened"] as! Bool? ?? false
        if !opened {
            panic("sale closed")
        }
        var startTime = self.extraFields["freeMintStartTime"] as! UFix64?
        var endTime = self.extraFields["freeMintEndTime"] as! UFix64?
        var currentTokenId = UInt64(self.extraFields["currentTokenId"] as! Number? ?? 0)
        var maxTokenId = UInt64(self.extraFields["maxTokenId"] as! Number? ?? 2221)
        var receiverAddr1 = (self.extraFields["receiverAddr1"] as! Address?)!
        var receiverAddr2 = (self.extraFields["receiverAddr2"] as! Address?)!

        
        if !(startTime == nil || startTime! <= getCurrentBlock().timestamp){
            panic("sale not started yet")
        }
        if !(endTime == nil || endTime! > getCurrentBlock().timestamp){
            panic("sale already ended")
        }
        if !(currentTokenId <= maxTokenId){
            panic("all minted")
        }
        let count = self.getFreeMintNum(signer)
        var realCount = count
        if(maxTokenId - currentTokenId + 1 < realCount){
            realCount = maxTokenId - currentTokenId + 1
        }
        
        let recipient = signer.getCapability(Bl0x2.CollectionPublicPath).borrow<&{NonFungibleToken.CollectionPublic}>() ?? panic("Cannot borrow NFT collection receiver from account")

        // start minting
        let minter = self.account.borrow<&Bl0x2.NFTMinter>(from: Bl0x2.MinterStoragePath)!
        let metadata: {String:String} = {}
        
        var i = UInt64(0)
        while(i < realCount){
            minter.mintNFTWithID(id: currentTokenId + i, recipient: recipient, metadata: metadata)

            i = i + UInt64(1)
        }
        
        self.whitelist[signer.address] = 0
        self.extraFields["currentTokenId"] = currentTokenId + i
    }
}
