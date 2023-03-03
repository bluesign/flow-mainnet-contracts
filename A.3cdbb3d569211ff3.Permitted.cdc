import NonFungibleToken from 0x1d7e57aa55817448

pub contract Permitted {
    pub let StoragePath: StoragePath
    pub let PublicPath: PublicPath

    pub event PermittedType(_ type: String, _ permitted: Bool, _ message: String)
    pub event PermittedUUID(_ uuid: UInt64, _ permitted: Bool, _ message: String)

    pub resource Manager {
        access(account) let permitted: {Type: Bool}
        access(account) let permittedUUID: {UInt64: Bool}

        pub fun isPermitted(_ nft: &NonFungibleToken.NFT): Bool {
            let t = nft.getType()
            return (self.permitted[t] == nil || self.permitted[t]!) && (self.permittedUUID[nft.uuid] == nil || self.permittedUUID[nft.uuid]!)
        }

        pub fun setPermittedType(_ t: Type, _ b: Bool, _ s: String) {
            self.permitted[t] = b

            let manager = Permitted.getReasonManager()
            manager.setReason(t, s)

            emit PermittedType(t.identifier, b, s)
        }

        pub fun setPermittedUUID(_ uuid: UInt64, _ b: Bool, _ s: String) {
            self.permittedUUID[uuid] = b

            emit PermittedUUID(uuid, b, s)
        }

        pub fun getAll(): {Type: Bool} {
            return self.permitted
        }

        init() {
            self.permitted = {}
            self.permittedUUID = {}
        }
    }

    pub fun isPermitted(_ nft: &NonFungibleToken.NFT): Bool {
        return self.account.borrow<&Manager>(from: Permitted.StoragePath)!.isPermitted(nft)
    }

    pub fun getAll(): {Type: Bool} {
        return self.account.borrow<&Manager>(from: Permitted.StoragePath)!.getAll()
    }
    
    pub fun getReasonManagerPublicPath(): PublicPath {
        return /public/permittedReason
    }
    
    pub fun getReasonManagerStoragePath(): StoragePath {
        return /storage/permittedReason
    }

    pub resource PermitReasonManager {
        pub let typeReasons: {Type: String}
        pub let uuidReasons: {Type: String}

        init() {
            self.typeReasons = {}
            self.uuidReasons = {}
        }

        pub fun setReason(_ t: Type, _ s: String) {
            self.typeReasons[t] = s
        }

        pub fun getReason(_ t: Type): String? {
            return self.typeReasons[t]
        }
    }

    pub fun getReason(_ t: Type): String? {
        return self.account.borrow<&PermitReasonManager>(from: Permitted.getReasonManagerStoragePath())!.getReason(t)
    }

    access(account) fun getReasonManager(): &PermitReasonManager {
        return self.account.borrow<&PermitReasonManager>(from: Permitted.getReasonManagerStoragePath())!
    }

    pub fun createReasonManager(): @PermitReasonManager {
        return <- create PermitReasonManager()
    }

    init() {
        self.StoragePath = /storage/permittedManager
        self.PublicPath = /public/permittedManager

        self.account.save(<- create Manager(), to: self.StoragePath)
        self.account.save(<- create PermitReasonManager(), to: self.getReasonManagerStoragePath())
    }
}
 