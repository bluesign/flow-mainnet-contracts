import MetadataViews from 0x1d7e57aa55817448

pub contract RoyaltiesOverride {
    pub let StoragePath: StoragePath

    pub resource Ledger {
        access(account) let overrides: {Type: Bool}

        pub fun set(_ type: Type, _ b: Bool) {
            self.overrides[type] = b
        }

        pub fun get(_ type: Type): Bool {
            return self.overrides[type] ?? false
        }

        pub fun remove(_ type: Type) {
            self.overrides.remove(key: type)
        }

        init() {
            self.overrides = {}
        }
    }

    pub fun get(_ type: Type): Bool {
        return self.account.borrow<&Ledger>(from: RoyaltiesOverride.StoragePath)!.get(type)
    }

    init() {
        self.StoragePath = /storage/RoyaltiesOverride
        self.account.save(<- create Ledger(), to: self.StoragePath)   
    }
}