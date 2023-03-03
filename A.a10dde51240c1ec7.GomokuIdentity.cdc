import GomokuType from 0xa10dde51240c1ec7

pub contract GomokuIdentity {

    // Paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    // Events
    pub event Create(id: UInt32, address: Address, role: UInt8)
    pub event CollectionCreated()
    pub event Withdraw(id: UInt32, from: Address?)
    pub event Deposit(id: UInt32, to: Address?)

    init() {
        self.CollectionStoragePath = /storage/gomokuIdentityCollection
        self.CollectionPublicPath = /public/gomokuIdentityCollection
    }

    pub resource IdentityToken {
        pub let id: UInt32
        pub let address: Address
        pub let role: GomokuType.Role
        pub var stoneColor: GomokuType.StoneColor

        priv var destroyable: Bool

        init(
            id: UInt32,
            address: Address,
            role: GomokuType.Role,
            stoneColor: GomokuType.StoneColor
        ) {
            self.id = id
            self.address = address
            self.role = role
            self.stoneColor = stoneColor
            self.destroyable = false
        }

        access(account) fun switchIdentity() {
            switch self.stoneColor {
            case GomokuType.StoneColor.black:
                self.stoneColor = GomokuType.StoneColor.white
            case GomokuType.StoneColor.white:
                self.stoneColor = GomokuType.StoneColor.black
            }
        }

        access(account) fun setDestroyable(_ value: Bool) {
            self.destroyable = value
        }

        destroy() {
            if self.destroyable == false {
                panic("You can't destroy this token before setting destroyable to true.")
            }
        }
    }

    access(account) fun createIdentity(
        id: UInt32,
        address: Address,
        role: GomokuType.Role,
        stoneColor: GomokuType.StoneColor
    ): @IdentityToken {
        emit Create(
            id: id, 
            address: address, 
            role: role.rawValue)

        return <- create IdentityToken(
            id: id,
            address: address,
            role: role,
            stoneColor: stoneColor
        )
    }

    pub resource IdentityCollection {

        pub let StoragePath: StoragePath
        pub let PublicPath: PublicPath

        priv var ownedIdentityTokenMap: @{UInt32: IdentityToken}
        priv var destroyable: Bool

        init () {
            self.ownedIdentityTokenMap <- {}
            self.destroyable = false
            self.StoragePath = /storage/compositionIdentity
            self.PublicPath = /public/compositionIdentity
        }

        access(account) fun withdraw(by id: UInt32): @IdentityToken? {
            if let token <- self.ownedIdentityTokenMap.remove(key: id) {
                emit Withdraw(id: token.id, from: self.owner?.address)
                if self.ownedIdentityTokenMap.keys.length == 0 {
                    self.destroyable = true
                }
                return <- token
            } else {
                return nil
            }
        }

        access(account) fun deposit(token: @IdentityToken) {
            let token <- token
            let id: UInt32 = token.id
            let oldToken <- self.ownedIdentityTokenMap[id] <- token
            emit Deposit(id: id, to: self.owner?.address)
            self.destroyable = false
            destroy oldToken
        }

        pub fun getIds(): [UInt32] {
            return self.ownedIdentityTokenMap.keys
        }

        pub fun getBalance(): Int {
            return self.ownedIdentityTokenMap.keys.length
        }

        pub fun borrow(id: UInt32): &IdentityToken? {
            return &self.ownedIdentityTokenMap[id] as? &IdentityToken?
        }

        destroy() {
            destroy self.ownedIdentityTokenMap
            if self.destroyable == false {
                panic("Ha Ha! Got you! You can't destory this collection if there are Gomoku Composition!")
            }
        }
    }

    pub fun createEmptyVault(): @IdentityCollection {
        emit CollectionCreated()
        return <- create IdentityCollection()
    }
}
 