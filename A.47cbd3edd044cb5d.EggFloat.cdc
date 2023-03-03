// mainnet
import NonFungibleToken from 0x1d7e57aa55817448
import ArleeScene from 0x47cbd3edd044cb5d
import FLOAT from 0x2d4c3caffbeab845

// testnet
// import NonFungibleToken from 0x631e88ae7f1d7c20
// import ArleeScene from 0xe7fd8b1148e021b2
// import FLOAT from 0x0afe396ebc8eee65

// local
// import FLOAT from "./lib/FLOAT.cdc"
// import NonFungibleToken from "./lib/NonFungibleToken.cdc"
// import ArleeScene from "./ArleeScene.cdc"

pub contract EggFloat {

    // For each Float ID you can register a list of possible Eggs to be hatched according to their weight
    access(contract) let eggsByID: {UInt64: [Egg]}

    // paths
    pub let EggAdminStoragePath: StoragePath

    // public functions

    // hatch requires ref to admin resource from admin account (multisig tx)
    pub fun hatchEgg(floatRef: &FLOAT.NFT, floatProviderCap: Capability<&{NonFungibleToken.Provider}>, admin: &Admin) {
        pre {
            self.eggsByID.containsKey(floatRef.eventId): "This Float is not an Arlee Egg Float!"
        }
        let eggs = self.eggsByID[floatRef.eventId]!
        let float <- floatProviderCap.borrow()!.withdraw(withdrawID: floatRef.uuid)
        assert(float.uuid == floatRef.uuid, message: "Mismatching IDs")

        let egg = self.pickEgg(eggs) ?? panic("something went wrong")

        let receipient = getAccount(floatProviderCap.address).getCapability<&ArleeScene.Collection{ArleeScene.CollectionPublic}>(ArleeScene.CollectionPublicPath).borrow() ?? panic("Cannot borrow recipient's ArleeScene CollectionPublic")
        ArleeScene.mintSceneNFT(recipient: receipient, cid: egg.cid, metadata: egg.metadata)
    
        destroy float
    }

    pub fun getRegisteredEventIDs(): [UInt64] {
        return self.eggsByID.keys
    }

    pub fun getEggsForEvent(id: UInt64): [Egg] {
        pre { self.eggsByID[id] != nil }
        return self.eggsByID[id]!
    }

    // takes an array of eggs and returns one picked at random
    // note unsafeRandom() is same for every claim in the same block! 
    // so backend should add a random delay before sending the co-signed tx   
    pub fun pickEgg(_ eggs: [Egg]): Egg? {
        var weights: [UInt64] = []
        var totalWeight: UInt64 = 0     
        for egg in eggs {
            totalWeight = totalWeight + egg.weight
            weights.append(totalWeight)
        } 
        let p = unsafeRandom() % totalWeight // number between 0-19
        var lastWeight: UInt64 = 0
        for i, egg in eggs {
            if p >= lastWeight && p < weights[i] {    
                log("Picked Number: ".concat(p.toString()).concat("/".concat(totalWeight.toString())).concat(" corresponding to ".concat(i.toString())))
                egg.addLuckyNumber(p)
                return egg 
            }
            lastWeight = egg.weight
        }
        return nil
    }

    // structs
    pub struct Egg {
        pub let cid: String
        pub let metadata: {String: String}
        pub let weight: UInt64

        init(cid: String, metadata: {String: String}, weight: UInt64) {
            self.cid = cid
            self.metadata = metadata
            self.weight = weight
        }

        pub fun addLuckyNumber(_ number: UInt64) {
            self.metadata.insert(key: "luckyNumber", number.toString())
        }
    }

    // resources
    pub resource Admin {

        pub fun registerEvent(eventID: UInt64, eggs: [Egg]) {
            EggFloat.eggsByID[eventID] = eggs
        }

        pub fun removeEvent(eventID: UInt64) {
            EggFloat.eggsByID.remove(key: eventID)
        }

    }

    init() {

        self.eggsByID = {}
        self.EggAdminStoragePath = /storage/ArleeEggFloatAdminStoragePath
    
        destroy self.account.load<@AnyResource>(from: self.EggAdminStoragePath)
        self.account.save(<- create Admin(), to: self.EggAdminStoragePath)
    }

}