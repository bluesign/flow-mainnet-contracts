/**
*  SPDX-License-Identifier: GPL-3.0-only
*/
                                                                                            
// PartyMansionGiveawayContract
//                                                      
pub contract PartyMansionGiveawayContract {
    
    // Giveaways
    access(self) var giveaways: {String: String}

    // Admin storage path
    pub let AdminStoragePath: StoragePath

    pub resource Admin {
        // offerFreeDrinks
        pub fun addGiveawayCode(giveawayKey: String) {
            if (PartyMansionGiveawayContract.giveaways.containsKey(giveawayKey)){
                panic("Giveaway code already known.")
            }
            PartyMansionGiveawayContract.giveaways.insert(key: giveawayKey, giveawayKey)
        }
    }

    // checkGiveawayCode
    pub fun checkGiveawayCode(giveawayCode: String) : Bool {
        // Hash giveawayCode
        let digest = HashAlgorithm.SHA3_256.hash(giveawayCode.decodeHex())
        let giveawayKey = String.encodeHex(digest)
        if (!PartyMansionGiveawayContract.giveaways.containsKey(giveawayKey)) {
            return false
        }
        return true
    }

    // removeGiveawayCode
    pub fun removeGiveawayCode(giveawayCode: String) {
        // Hash giveawayCode
        let digest = HashAlgorithm.SHA3_256.hash(giveawayCode.decodeHex())
        let giveawayKey = String.encodeHex(digest)
        if (!PartyMansionGiveawayContract.giveaways.containsKey(giveawayKey)) {
            let msg = "Unknown Giveaway Code:"
            panic(msg.concat(giveawayKey))
        }
        PartyMansionGiveawayContract.giveaways.remove(key: giveawayKey)
    }

    // Init function of the smart contract
    init() {
        // init & save Admin
        self.AdminStoragePath = /storage/PartyMansionGiveawayAdmin
        self.account.save<@Admin>(<- create Admin(), to: self.AdminStoragePath)

        // Initialize Giveawaxys
        self.giveaways = {}
    }
}
