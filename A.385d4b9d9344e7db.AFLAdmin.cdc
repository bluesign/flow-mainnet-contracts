import AFLNFT from 0x385d4b9d9344e7db
import AFLPack from 0x385d4b9d9344e7db
import FungibleToken from 0xf233dcee88fe0abe
pub contract AFLAdmin {

    // Admin
    // the admin resource is defined so that only the admin account
    // can have this resource. It possesses the ability to open packs
    // given a user's Pack Collection and Card Collection reference.
    // It can also create a new pack type and mint Packs.
    //
    pub resource Admin {

        pub fun createTemplate(maxSupply:UInt64, immutableData:{String: AnyStruct}){
            AFLNFT.createTemplate(maxSupply:maxSupply, immutableData:immutableData)
        }

        pub fun openPack(templateId: UInt64, account: Address){
            AFLNFT.mintNFT(templateId:templateId, account:account)
        }
        // createAdmin
        // only an admin can ever create
        // a new Admin resource
        //
        pub fun createAdmin(): @Admin {
            return <- create Admin()
        }

        init() {
            
        }
    }

    init() {
        self.account.save(<- create Admin(), to: /storage/AFLAdmin)
    }
}