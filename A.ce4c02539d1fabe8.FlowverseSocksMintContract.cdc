import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import FlowverseSocks from 0xce4c02539d1fabe8
import RaribleNFT from 0x01ab36aaf654a13e

pub contract FlowverseSocksMintContract {
    pub let AdminStoragePath: StoragePath

    pub var sale: Sale?

    pub struct Sale {
        pub var startTime: UFix64?
        pub var endTime: UFix64?
        pub var max: UInt64
        pub var current: UInt64
        pub var idMapping: {UInt64:UInt64}
        init(startTime: UFix64?,
             endTime: UFix64?,
             max: UInt64,
             current: UInt64,
             idMapping: {UInt64:UInt64}){
            self.startTime=startTime
            self.endTime=endTime
            self.max=max
            self.current=current
            self.idMapping = idMapping
        }
        access(contract) fun incCurrent(){
            self.current = self.current + UInt64(1)
        }
    }
    
    pub fun paymentMint(
        toBurn: @NonFungibleToken.NFT,
        recipient: &{NonFungibleToken.CollectionPublic}
    ){
        pre {
            self.sale != nil: "sale closed"
            self.sale!.startTime == nil || self.sale!.startTime! <= getCurrentBlock().timestamp: "sale not started yet"
            self.sale!.endTime == nil || self.sale!.endTime! > getCurrentBlock().timestamp: "sale already ended"
            self.sale!.max > self.sale!.current: "sale items sold out"
            toBurn.isInstance(Type<@RaribleNFT.NFT>()): "toBurn is not requested NFT type"

        }
        let id = self.sale!.idMapping[toBurn.id]
        if(id == nil){
            panic("NFT id not in list")
        }
        destroy toBurn

        let minter = self.account.borrow<&FlowverseSocks.NFTMinter>(from: FlowverseSocks.MinterStoragePath)!
        let metadata: {String:String} = {}
        let tokenId = id
        // metadata code here
        
        
        minter.mintNFTWithID(id: id!, recipient: recipient, metadata: metadata)
        
        self.sale!.incCurrent()
    }

    pub resource Administrator {
        pub fun setSale(sale:Sale?){
            FlowverseSocksMintContract.sale = sale
        }
    }
    
    init() {
        self.sale = nil
        self.AdminStoragePath = /storage/FlowverseSocksMintContractAdmin

        self.account.save(<- create Administrator(), to: self.AdminStoragePath)
    }
}
