import AFLPack from 0x8f9231920da9af6d

pub contract MyAdmin {

    pub resource interface MinterProxyPublic {
        pub fun setMinterCapability(cap: Capability<&AFLPack.Pack>)
    } 

    pub resource MinterProxy: MinterProxyPublic {

        access(self) var minterCapability: Capability<&AFLPack.Pack>?

        pub fun setMinterCapability(cap: Capability<&AFLPack.Pack>) {
            self.minterCapability = cap
        }

        pub fun updateOwner(owner:Address) {
            self.minterCapability!
            .borrow()!
            .updateOwnerAddress(owner:owner)
        }

        init() {
            self.minterCapability = nil
        }

    }   

    init() {
	self.account.save(<- create MinterProxy(), to: /storage/admin)
    }
}
