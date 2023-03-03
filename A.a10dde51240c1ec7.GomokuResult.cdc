import GomokuType from 0xa10dde51240c1ec7

pub contract GomokuResult {

    // Paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    // Events
    pub event TokenCreated(winner: Address?, losser: Address?, gain: Fix64)
    pub event CollectionCreated()
    pub event Withdraw(id: UInt32, from: Address?)
    pub event Deposit(id: UInt32, to: Address?)

    init() {
        self.CollectionStoragePath = /storage/gomokuResultCollection
        self.CollectionPublicPath = /public/gomokuResultCollection
    }

    pub resource ResultToken {
        pub let id: UInt32
        pub let winner: Address?
        pub let losser: Address?
        pub let isDraw: Bool
        pub let roundWinners: [GomokuType.Result]
        pub let gain: Fix64
        access(account) let steps: [[AnyStruct{GomokuType.StoneDataing}]]

        priv var destroyable: Bool

        init(
            id: UInt32,
            winner: Address?,
            losser: Address?,
            gain: Fix64,
            roundWinners: [GomokuType.Result],
            steps: [[AnyStruct{GomokuType.StoneDataing}]]
        ) {
            self.id = id
            self.winner = winner
            self.losser = losser
            if winner == nil && losser == nil {
                self.isDraw = true
            } else {
                self.isDraw = false
            }
            self.gain = gain
            self.roundWinners = roundWinners
            self.destroyable = false
            self.steps = steps
            emit TokenCreated(
                winner: winner,
                losser: losser,
                gain: gain
            )
        }

        access(account) fun setDestroyable(_ value: Bool) {
            self.destroyable = value
        }

        pub fun getSteps(round: UInt32): [AnyStruct{GomokuType.StoneDataing}] {
            pre {
                round < UInt32(self.steps.length): "Invalid round index."
            }

            return self.steps[round]
        }

        destroy() {
            if self.destroyable == false {
                panic("You can't destroy this token before setting destroyable to true.")
            }
        }

    }

    access(account) fun createResult(
        id: UInt32,
        winner: Address?,
        losser: Address?,
        gain: Fix64,
        roundWinners: [GomokuType.Result],
        steps: [[AnyStruct{GomokuType.StoneDataing}]]
    ): @GomokuResult.ResultToken {
        return <- create ResultToken(
            id: id,
            winner: winner,
            losser: losser,
            gain: gain,
            roundWinners: roundWinners,
            steps: steps
        )
    }

    pub resource ResultCollection {

        pub let StoragePath: StoragePath
        pub let PublicPath: PublicPath

        priv var ownedResultTokenMap: @{UInt32: GomokuResult.ResultToken}
        priv var destroyable: Bool

        init () {
            self.ownedResultTokenMap <- {}
            self.destroyable = false
            self.StoragePath = /storage/gomokuResultCollection
            self.PublicPath = /public/gomokuResultCollection
        }

        access(account) fun withdraw(by id: UInt32): @GomokuResult.ResultToken? {
            if let token <- self.ownedResultTokenMap.remove(key: id) {
                emit Withdraw(id: token.id, from: self.owner?.address)
                if self.ownedResultTokenMap.keys.length == 0 {
                    self.destroyable = true
                }
                return <- token
            } else {
                return nil
            }
        }

        access(account) fun deposit(token: @GomokuResult.ResultToken) {
            let token <- token
            let id: UInt32 = token.id
            let oldToken <- self.ownedResultTokenMap[id] <- token
            emit Deposit(id: id, to: self.owner?.address)
            self.destroyable = false
            destroy oldToken
        }

        pub fun getIds(): [UInt32] {
            return self.ownedResultTokenMap.keys
        }

        pub fun borrow(id: UInt32): &GomokuResult.ResultToken? {
            return &self.ownedResultTokenMap[id] as &GomokuResult.ResultToken?
        }

        pub fun getBalance(): Int {
            return self.ownedResultTokenMap.keys.length
        }

        destroy() {
            destroy self.ownedResultTokenMap
            if self.destroyable == false {
                panic("Ha Ha! Got you! You can't destory this collection if there are Gomoku ResultToken!")
            }
        }
    }

    pub fun createEmptyVault(): @GomokuResult.ResultCollection {
        emit CollectionCreated()
        return <- create ResultCollection()
    }

}
 