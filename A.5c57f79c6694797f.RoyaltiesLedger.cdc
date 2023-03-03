import MetadataViews from 0x1d7e57aa55817448

pub contract RoyaltiesLedger {
    pub let StoragePath: StoragePath

    pub resource Ledger {
        access(account) let royalties: {UInt64: MetadataViews.Royalties}

        access(contract) fun set(_ id: UInt64, _ r: MetadataViews.Royalties?) {
            if r == nil {
                return
            }

            self.royalties[id] = r
        }

        access(contract) fun get(_ id: UInt64): MetadataViews.Royalties? {
            return self.royalties[id]
        }

        pub fun remove(_ id: UInt64) {
            self.royalties.remove(key: id)
        }

        init() {
            self.royalties = {}
        }
    }

    access(account) fun set(_ id: UInt64, _ r: MetadataViews.Royalties) {
        self.account.borrow<&Ledger>(from: RoyaltiesLedger.StoragePath)!.set(id, r)
    }

    access(account) fun remove(_ id: UInt64) {
        self.account.borrow<&Ledger>(from: RoyaltiesLedger.StoragePath)!.remove(id)
    }

    pub fun get(_ id: UInt64): MetadataViews.Royalties? {
        return self.account.borrow<&Ledger>(from: RoyaltiesLedger.StoragePath)!.get(id)
    }

    init() {
        self.StoragePath = /storage/RoyaltiesLedger
        self.account.save(<- create Ledger(), to: self.StoragePath)   
    }
}