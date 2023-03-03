import NonFungibleToken from 0x1d7e57aa55817448
import FungibleToken from 0xf233dcee88fe0abe
import FlowNia from 0xafb8473247d9354c

pub contract FlowNiaRareMintContract {
    pub let AdminStoragePath: StoragePath

    pub var sale: Sale?

    pub struct Sale {
        pub var startTime: UFix64?
        pub var endTime: UFix64?
        pub var max: UInt64
        pub var current: UInt64
        pub var whitelist: {Address:Bool}
        init(startTime: UFix64?,
             endTime: UFix64?,
             max: UInt64,
             current: UInt64,
             whitelist: {Address:Bool}){
            self.startTime=startTime
            self.endTime=endTime
            self.max=max
            self.current=current
            self.whitelist = whitelist
        }
        access(contract) fun useWhitelist(_ address: Address){
            self.whitelist[address] = true
        }
        access(contract) fun incCurrent(){
            self.current = self.current + UInt64(1)
        }
    }
    
    pub fun paymentMint(
        recipient: &{NonFungibleToken.CollectionPublic}
    ){
    }

    pub resource Administrator {
        pub fun setSale(sale:Sale?){
            FlowNiaRareMintContract.sale = sale
        }
    }
    
    init() {
        self.sale = nil
        self.AdminStoragePath = /storage/FlowNiaRareMintContractAdmin

        self.account.save(<- create Administrator(), to: self.AdminStoragePath)
    }
}