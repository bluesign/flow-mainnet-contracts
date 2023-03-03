import ContractVersion from 0xa49cc0ee46c54bfb
import MotoGPAdmin from 0xa49cc0ee46c54bfb

pub contract MotoGPCardSerialPoolV2: ContractVersion {

    pub fun getVersion(): String {
        return "1.0.2"
    }

    // Should be used only to set a serial base not equal to 0
    //
    pub fun setSerialBase(adminRef: &MotoGPAdmin.Admin, cardID: UInt64, base: UInt64) {
        if self.serialBaseByCardID[cardID] != nil {
            assert(base > self.serialBaseByCardID[cardID]!, message: "new base is less than current base")
        }
        self.serialBaseByCardID[cardID] = base
    }

    // Method to add sequential serials for a card id
    // Can be called multiple times
    // Will generate serial starting from the base for that cardID
    //
    pub fun addSerials(adminRef: &MotoGPAdmin.Admin, cardID: UInt64, count: UInt64) {
        if self.serialBaseByCardID[cardID] == nil {
            self.serialBaseByCardID[cardID] = 0
        }

        var index: UInt64 = 0
        if self.serialsByCardID[cardID] == nil {
            self.serialsByCardID[cardID] = [];
        }

        while (index < count) {
            index = index + UInt64(1)
            self.serialsByCardID[cardID]!.append(index + self.serialBaseByCardID[cardID]!)
        }
        
        self.serialBaseByCardID[cardID] =  index + self.serialBaseByCardID[cardID]!
    }

    // Method to pick a serial for a cardID
    // Randomness for n should be generated before calling this method
    //
    access(account) fun pickSerial(n: UInt64, cardID: UInt64): UInt64 {
       
        pre {
            self.serialsByCardID[cardID]!.length != 0 : "No serials for cardID ".concat(cardID.toString())
        }
        
        let r = n % UInt64(self.serialsByCardID[cardID]!.length)
        return self.serialsByCardID[cardID]!.remove(at: r)
    }

    pub fun getSerialBaseByCardID(cardID: UInt64): UInt64 {
        return self.serialBaseByCardID[cardID] ?? 0    
    }

    pub fun getAllSerialsByCardID(cardID: UInt64): [UInt64] {
        return self.serialsByCardID[cardID] ?? []
    }

    access(contract) let serialsByCardID : {UInt64 : [UInt64]}
    access(contract) let serialBaseByCardID : {UInt64 : UInt64}

    init() {
        self.serialsByCardID = {}
        self.serialBaseByCardID = {}
    }
}