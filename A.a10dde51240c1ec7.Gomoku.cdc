import MatchContract from 0xa10dde51240c1ec7
import FungibleToken from 0xf233dcee88fe0abe
import FlowToken from 0x1654653399040a61

import GomokuIdentity from 0xa10dde51240c1ec7
import GomokuResult from 0xa10dde51240c1ec7
import GomokuType from 0xa10dde51240c1ec7

pub contract Gomoku {

    // Paths
    pub let AdminStoragePath: StoragePath

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath

    // Bets
    access(account) let hostOpeningBetMap: @{ UInt32: FlowToken.Vault }
    access(account) let challengerOpeningBetMap: @{ UInt32: FlowToken.Vault }

    access(account) let hostRaisedBetMap: @{ UInt32: FlowToken.Vault }
    access(account) let challengerRaisedBetMap: @{ UInt32: FlowToken.Vault }

    // Bets value when finalize
    access(account) let hostFinalizedOpeningBetMap: { UInt32: UFix64 }
    access(account) let challengerFinalizedOpeningBetMap: { UInt32: UFix64 }

    access(account) let hostFinalizedRaisedBetMap: { UInt32: UFix64 }
    access(account) let challengerFinalizedRaisedBetMap: { UInt32: UFix64 }

    // Events
    // Event be emitted when the composition is created
    pub event HostOpeningBet(balance: UFix64)

    // Event be emitted when the contract is created
    pub event CompositionMatched(
        host: Address,
        challenger: Address,
        currency: String,
        openingBet: UFix64)

    pub event CompositionCreated(
        host: Address,
        currency: String)
    pub event CollectionCreated()
    pub event Withdraw(id: UInt32, from: Address?)
    pub event Deposit(id: UInt32, to: Address?)
    pub event Surrender(id: UInt32, from: Address)

    pub event CollectionNotFound(type: Type, path: Path, address: Address)
    pub event ResourceNotFound(id: UInt32, type: Type, address: Address)

    pub event MakeMove(
        compositionId: UInt32,
        locationX: Int8,
        locationY: Int8,
        stoneColor: UInt8)

    pub event RoundSwitch(
        compositionId: UInt32,
        previous: UInt8,
        next: UInt8
    )

    pub resource Admin {

        pub fun manualFinalizeByTimeout(index: UInt32) {
            if let compositionRef = Gomoku.getCompositionRef(by: index) as &Gomoku.Composition? {
                let participants = Gomoku.getParticipants(by: index)
                assert(participants.length == 2, message: "Composition not matched.")
                for participant in participants {
                    if let identityCollectionRef = getAccount(participant)
                        .getCapability<&GomokuIdentity.IdentityCollection>(GomokuIdentity.CollectionPublicPath)
                        .borrow() {
                        let identityToken <- identityCollectionRef.withdraw(by: index) ?? panic("identity not found in address "
                            .concat(participant.toString())
                            .concat(" at index ")
                            .concat(index.toString()))
                        if let identityTokenBack <- compositionRef.finalizeByTimeout(identityToken: <- identityToken) {
                            identityCollectionRef.deposit(token: <- identityTokenBack)
                        } else {
                            identityCollectionRef.deposit(token: <- identityToken)
                        }
                        return
                    }
                }
            } else {
                panic("Can't find reference to composition by ".concat(index.toString()))
            }
        }

        pub fun recycleBets() {

            let capability = Gomoku.account.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
            let flowReceiverReference = capability.borrow() ?? panic("Could not borrow a reference to the Flow token receiver capability")

            for key in Gomoku.hostOpeningBetMap.keys {
                var hostOpeningBet: @FlowToken.Vault? <- FlowToken.createEmptyVault() as! @FlowToken.Vault
                Gomoku.hostOpeningBetMap[key] <-> hostOpeningBet
                flowReceiverReference.deposit(from: <- (hostOpeningBet as! @FungibleToken.Vault))
                let emptyVault <- Gomoku.hostOpeningBetMap.remove(key: key)
                destroy emptyVault
            }

            for key in Gomoku.challengerOpeningBetMap.keys {
                var challengerOpeningBet: @FlowToken.Vault? <- FlowToken.createEmptyVault() as! @FlowToken.Vault
                Gomoku.challengerOpeningBetMap[key] <-> challengerOpeningBet
                flowReceiverReference.deposit(from: <- (challengerOpeningBet as! @FungibleToken.Vault))
                let emptyVault <- Gomoku.challengerOpeningBetMap.remove(key: key)
                destroy emptyVault
            }

            for key in Gomoku.hostRaisedBetMap.keys {
                var hostRaisedBet: @FlowToken.Vault? <- FlowToken.createEmptyVault() as! @FlowToken.Vault
                Gomoku.hostRaisedBetMap[key] <-> hostRaisedBet
                flowReceiverReference.deposit(from: <- (hostRaisedBet as! @FungibleToken.Vault))
                let emptyVault <- Gomoku.hostRaisedBetMap.remove(key: key)
                destroy emptyVault
            }

            for key in Gomoku.challengerRaisedBetMap.keys {
                var challengerRaisedBet: @FlowToken.Vault? <- FlowToken.createEmptyVault() as! @FlowToken.Vault
                Gomoku.challengerRaisedBetMap[key] <-> challengerRaisedBet
                flowReceiverReference.deposit(from: <- (challengerRaisedBet as! @FungibleToken.Vault))
                let emptyVault <- Gomoku.challengerRaisedBetMap.remove(key: key)
                destroy emptyVault
            }
        }
    }

    init() {
        self.CollectionStoragePath = /storage/gomokuCompositionCollection
        self.CollectionPublicPath = /public/gomokuCompositionCollection

        self.hostOpeningBetMap <- {}
        self.challengerOpeningBetMap <- {}
        self.hostRaisedBetMap <- {}
        self.challengerRaisedBetMap <- {}

        self.hostFinalizedOpeningBetMap = {}
        self.challengerFinalizedOpeningBetMap = {}
        self.hostFinalizedRaisedBetMap = {}
        self.challengerFinalizedRaisedBetMap = {}

        self.AdminStoragePath = /storage/gomokuAdmin
        let admin <- create Admin()
        self.account.save(<- admin, to: self.AdminStoragePath)

        if self.account.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault) == nil {
            let flowVault <- FlowToken.createEmptyVault()
            self.account.save(<- flowVault, to: /storage/flowTokenVault)
        }

        if self.account.getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver) == nil {
            // Create a public capability to the stored Vault that only exposes
            // the `deposit` method through the `Receiver` interface
            self.account.link<&FlowToken.Vault{FungibleToken.Receiver}>(
                /public/flowTokenReceiver,
                target: /storage/flowTokenVault
            )
        }

        if self.account.getCapability<&FlowToken.Vault{FungibleToken.Balance}>(/public/flowTokenBalance) == nil {
            // Create a public capability to the stored Vault that only exposes
            // the `balance` field through the `Balance` interface
            self.account.link<&FlowToken.Vault{FungibleToken.Balance}>(
                /public/flowTokenBalance,
                target: /storage/flowTokenVault
            )
        }
    }

    // Scripts
    pub fun getCompositionRef(by index: UInt32): &Gomoku.Composition? {
        if let host = MatchContract.getHostAddress(by: index) {
            if let collectionRef = getAccount(host)
                .getCapability<&Gomoku.CompositionCollection>(self.CollectionPublicPath)
                .borrow() {
                return collectionRef.borrow(id: index)
            } else {
                return nil
            }
        } else {
            return nil
        }
    }

    pub fun getParticipants(by index: UInt32): [Address] {
        return self.getCompositionRef(by: index)?.getParticipants() ?? []
    }

    pub fun getCompositeResult(by index: UInt32): GomokuType.Result? {
        if let compositionRef = self.getCompositionRef(by: index) {
            let roundWinners = compositionRef.getRoundWinners()
            if roundWinners.length != 2 {
                return nil
            }

            if let winner = compositionRef.getWinner() {
                switch winner {
                    case GomokuType.Role.host:
                        return GomokuType.Result.hostWins
                    case GomokuType.Role.challenger:
                        return GomokuType.Result.challengerWins
                    default:
                        return GomokuType.Result.draw
                }
            } else {
                return GomokuType.Result.draw
            }
        } else {
            return nil
        }
    }

    // Opening bets
    pub fun getOpeningBet(by index: UInt32): UFix64? {
        let hostBet = self.getHostOpeningBet(by: index)
        if hostBet == nil {
            return nil
        }
        let challengerBet = self.getChallengerOpeningBet(by: index)
        if challengerBet == nil {
            return hostBet!
        }
        return hostBet! + challengerBet!
    }

    pub fun getHostOpeningBet(by index: UInt32): UFix64? {
        return self.hostOpeningBetMap[index]?.balance
    }

    pub fun getChallengerOpeningBet(by index: UInt32): UFix64? {
        return self.challengerOpeningBetMap[index]?.balance
    }

    pub fun getHostRaisedBet(by index: UInt32): UFix64? {
        return self.hostRaisedBetMap[index]?.balance
    }

    pub fun getChallengerRaisedBet(by index: UInt32): UFix64? {
        return self.challengerRaisedBetMap[index]?.balance
    }

    pub fun getFinalizedBets(by index: UInt32): [UFix64]? {
        if let roundWinners = self.getCompositionRef(by: index)?.getRoundWinners() {
            if roundWinners.length != 2 {
                return nil
            }
            return [
                self.hostFinalizedOpeningBetMap[index] ?? UFix64(0),
                self.challengerFinalizedOpeningBetMap[index] ?? UFix64(0),
                self.hostFinalizedRaisedBetMap[index] ?? UFix64(0),
                self.challengerFinalizedRaisedBetMap[index] ?? UFix64(0)
            ]
        } else {
            return nil
        }
    }

    // Opening bets + raised bets
    pub fun getValidBets(by index: UInt32): UFix64? {
        let openingBet = self.getOpeningBet(by: index)
        if let bet = openingBet {
            let hostRaisedBet = self.getHostRaisedBet(by: index) ?? UFix64(0)
            let challengerRaisedBet = self.getChallengerRaisedBet(by: index) ?? UFix64(0)
            if hostRaisedBet >= challengerRaisedBet {
                return bet + (challengerRaisedBet * UFix64(2))
            } else {
                return bet + (hostRaisedBet * UFix64(2))
            }
        }
        return nil
    }

    // Transaction
    pub fun register(
        host: Address,
        openingBet: @FlowToken.Vault,
        identityCollectionRef: auth &GomokuIdentity.IdentityCollection,
        resultCollectionRef: auth &GomokuResult.ResultCollection,
        compositionCollectionRef: auth &Gomoku.CompositionCollection
    ) { 
        pre {
            identityCollectionRef.owner?.address == host: "You are not authorized to move other's Gomoku identity collection."
            resultCollectionRef.owner?.address == host: "You are not authorized to move other's Gomoku result collection."
            compositionCollectionRef.owner?.address == host: "You are not authorized to move other's Gomoku composition collection."
        }
        let index = MatchContract.register(host: host)

        let betBalance: UFix64 = openingBet.balance
        if self.hostOpeningBetMap.keys.contains(index) {
            let balance = self.hostOpeningBetMap[index]?.balance ?? UFix64(0)
            assert(balance == UFix64(0), message: "Already registered.")

            var tempVault: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault

            tempVault.deposit(from: <- openingBet)

            let empty <- self.hostOpeningBetMap[index] <- tempVault
            destroy empty
        } else {
            self.hostOpeningBetMap[index] <-! openingBet
        }

        let identity <- GomokuIdentity.createIdentity(
            id: index,
            address: host,
            role: GomokuType.Role.host,
            stoneColor: GomokuType.StoneColor.white
        )
        identityCollectionRef.deposit(token: <- identity)

        let composition <- Gomoku.createComposition(
            id: index,
            host: host,
            boardSize: 15,
            totalRound: 2)

        emit HostOpeningBet(balance: betBalance)

        compositionCollectionRef.deposit(token: <- composition)
    }

    pub fun matchOpponent(
        index: UInt32,
        challenger: Address,
        bet: @FlowToken.Vault,
        recycleBetVaultRef: &FlowToken.Vault{FungibleToken.Receiver},
        identityCollectionRef: auth &GomokuIdentity.IdentityCollection,
        resultCollectionRef: auth &GomokuResult.ResultCollection
    ): Bool {
        if let matchedHost = MatchContract.match(index: index, challengerAddress: challenger) {
            assert(matchedHost != challenger, message: "You can't play with yourself.")

            if let compositionCollectionRef = getAccount(matchedHost)
                .getCapability<&Gomoku.CompositionCollection>(self.CollectionPublicPath)
                .borrow() {

                let hostBet = self.hostOpeningBetMap[index]?.balance ?? UFix64(0)
                assert(hostBet == bet.balance, message: "Opening bets not equal.")
                self.hostRaisedBetMap[index] <-! FlowToken.createEmptyVault() as! @FlowToken.Vault
                self.challengerRaisedBetMap[index] <-! FlowToken.createEmptyVault() as! @FlowToken.Vault

                if let compositionRef = compositionCollectionRef.borrow(id: index) {
                    self.challengerOpeningBetMap[index] <-! bet

                    compositionRef.match(
                        identityCollectionRef: identityCollectionRef,
                        challenger: challenger)

                    let hostOpeningBet = self.getHostOpeningBet(by: index)
                    let challengerOpeningBet = self.getChallengerOpeningBet(by: index)
                    assert(hostOpeningBet != nil, message: "Host opening bet should not be 0.")
                    assert(challengerOpeningBet != nil, message: "Challenger opening bet should not be 0.")
                    assert(hostOpeningBet! == challengerOpeningBet!, message: "Opening bet not match.")
                    emit CompositionMatched(
                        host: matchedHost,
                        challenger: challenger,
                        currency: Type<FlowToken>().identifier,
                        openingBet: hostOpeningBet! + challengerOpeningBet!)
                    return true
                } else {
                    recycleBetVaultRef.deposit(from: <- bet)
                    return false
                }
            } else {
                recycleBetVaultRef.deposit(from: <- bet)
                return false
            }
        } else {
            recycleBetVaultRef.deposit(from: <- bet)
            return false
        }
    }

    pub resource Composition {

        pub let id: UInt32

        pub let boardSize: UInt8
        pub let totalRound: UInt8
        pub var currentRound: UInt8

        // timeout of block height
        pub var latestBlockHeight: UInt64
        pub var blockHeightTimeout: UInt64

        priv var winner: GomokuType.Role?

        priv var host: Address
        priv var challenger: Address?
        priv var roundWinners: [GomokuType.Result]
        priv var steps: @[[Stone]]
        priv var locationStoneMaps: [{String: GomokuType.StoneColor}]
        priv var destroyable: Bool

        init(
            id: UInt32,
            host: Address,
            boardSize: UInt8,
            totalRound: UInt8
        ) {
            pre {
                totalRound >= 2: "Total round should be 2 to take turns to make first move (black stone) for fairness."
                totalRound % 2 == 0: "Total round should be event number to take turns to make first move (black stone) for fairness."
            }

            self.id = id
            self.host = host
            self.boardSize = boardSize
            self.challenger = nil
            self.totalRound = totalRound
            self.currentRound = 0
            self.winner = nil
            self.roundWinners = []

            self.steps <- []
            self.locationStoneMaps = []
            var stepIndex = UInt8(0)
            while totalRound > stepIndex {
                self.steps.append(<- [])
                self.locationStoneMaps.append({})
                stepIndex = stepIndex + UInt8(1)
            }

            self.latestBlockHeight = getCurrentBlock().height
            self.blockHeightTimeout = UInt64(60 * 60 * 24 * 7)
            self.destroyable = false

            emit CompositionCreated(
                host: host,
                currency: Type<FlowToken>().identifier)
        }

        // Script
        pub fun getTimeout(): UInt64 {
            return self.latestBlockHeight + self.blockHeightTimeout
        }

        pub fun getStoneData(for round: UInt8): [StoneData] {
            pre {
                self.steps.length > Int(round): "Round ".concat(round.toString()).concat(" not exist.")
            }
            var placeholderArray: @[Stone] <- []
            self.steps[round] <-> placeholderArray
            var placeholderStone <- create Stone(
                color: GomokuType.StoneColor.black,
                location: GomokuType.StoneLocation(x: 0, y: 0)
            )
            var stoneData: [StoneData] = []
            var index = 0
            while index < placeholderArray.length {
                placeholderArray[index] <-> placeholderStone
                stoneData.append(placeholderStone.convertToData() as! StoneData)
                placeholderArray[index] <-> placeholderStone
                // destroy step
                index = index + 1
            }

            self.steps[round] <-> placeholderArray

            destroy placeholderArray
            destroy placeholderStone
            return stoneData
        }

        pub fun getParticipants(): [Address] {
            if let challenger = self.challenger {
                return [self.host, challenger]
            } else {
                return [self.host]
            }
        }

        pub fun getRoundWinner(by index: UInt8): GomokuType.Result? {
            if self.roundWinners.length > Int(index) {
                return self.roundWinners[index]
            } else {
                return nil
            }
        }

        pub fun getRoundWinners(): [GomokuType.Result] {
            return self.roundWinners
        }

        pub fun getWinner(): GomokuType.Role? {
            return self.winner
        }

        // Transaction
        pub fun makeMove(
            identityCollectionRef: auth &GomokuIdentity.IdentityCollection,
            resultCollectionRef: auth &GomokuResult.ResultCollection,
            location: GomokuType.StoneLocation,
            raisedBet: @FlowToken.Vault
        ) {

            // check identity
            let identityTokenRef = identityCollectionRef.borrow(id: self.id) as &GomokuIdentity.IdentityToken?
            assert(identityTokenRef != nil, message: "Identity token ref not found.")
            assert(identityTokenRef?.owner?.address == identityTokenRef?.address, message: "Identity token should not be transfer to other.")

            let identityToken <- identityCollectionRef.withdraw(by: self.id) ?? panic("You are not suppose to make this move.")
            assert(Int(self.currentRound) + 1 > self.roundWinners.length, message: "Game Over.")

            // check result
            assert(resultCollectionRef.owner?.address == identityTokenRef?.address, message: "Gomoku result collection not found.")

            let stone <- create Stone(
                color: identityToken.stoneColor,
                location: location
            )

            // check raise bet type
            assert(
                raisedBet.getType() == Type<@FlowToken.Vault>(),
                message: "You can onlty raise bet with the same token of opening bet: "
                    .concat(raisedBet.getType().identifier)
            )

            let currentRole = self.getRole()

            switch currentRole {
            case GomokuType.Role.host:
                assert(identityToken.address == self.host, message: "It's not you turn yet!")
                var emptyBet: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
                var hostRaisedBet <- Gomoku.hostRaisedBetMap[self.id] <- emptyBet
                if let oldBet <- hostRaisedBet {
                    oldBet.deposit(from: <- raisedBet)
                    let empty <- Gomoku.hostRaisedBetMap[self.id] <- oldBet
                    destroy empty
                } else {
                    let empty <- Gomoku.hostRaisedBetMap[self.id] <- raisedBet
                    destroy empty
                    destroy hostRaisedBet
                }
            case GomokuType.Role.challenger:
                assert(self.challenger != nil, message: "Challenger not found.")
                assert(identityToken.address == self.challenger!, message: "It's not you turn yet!")
                var emptyBet: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
                var hostRaisedBet <- Gomoku.challengerRaisedBetMap[self.id] <- emptyBet
                if let oldBet <- hostRaisedBet {
                    oldBet.deposit(from: <- raisedBet)
                    let empty <- Gomoku.challengerRaisedBetMap[self.id] <- oldBet
                    destroy empty
                } else {
                    let empty <- Gomoku.challengerRaisedBetMap[self.id] <- raisedBet
                    destroy empty
                    destroy hostRaisedBet
                }
            default:
                panic("Should not be the case.")
            }

            let stoneRef = &stone as &Stone

            // validate move
            self.verifyAndStoreStone(stone: <- stone)

            // reset timeout
            self.latestBlockHeight = getCurrentBlock().height

            emit MakeMove(
                compositionId: self.id,
                locationX: stoneRef.location.x,
                locationY: stoneRef.location.y,
                stoneColor: stoneRef.color.rawValue)

            let hasRoundWinner = self.checkWinnerInAllDirection(
                targetColor: stoneRef.color,
                center: stoneRef.location)

            if hasRoundWinner {
                var rountResult: GomokuType.Result = GomokuType.Result.draw
                switch identityToken.role {
                case GomokuType.Role.host:
                    rountResult = GomokuType.Result.hostWins
                case GomokuType.Role.challenger:
                    rountResult = GomokuType.Result.challengerWins
                default:
                    panic("Should not be the case.")
                }
                self.roundWinners.append(rountResult)
                // event
                // end of current round
                if self.currentRound + UInt8(1) < self.totalRound {
                    identityCollectionRef.deposit(token: <- identityToken)
                    self.switchRound()
                } else {
                    // end of game
                    self.finalize(identityToken: <- identityToken)
                }
            } else {
                if UInt8(self.steps[self.currentRound].length) == self.boardSize * self.boardSize {
                    // no step to take next.
                    self.roundWinners.append(GomokuType.Result.draw)
                    // end of current round
                    if self.currentRound + UInt8(1) < self.totalRound {
                        identityCollectionRef.deposit(token: <- identityToken)
                        self.switchRound()
                    } else {
                        // end of game
                        self.finalize(identityToken: <- identityToken)
                    }
                } else {
                    identityCollectionRef.deposit(token: <- identityToken)
                }
            }
        }

        pub fun surrender(
            identityCollectionRef: auth &GomokuIdentity.IdentityCollection,
            resultCollectionRef: auth &GomokuResult.ResultCollection
        ) {
            pre {
                self.roundWinners.length == Int(self.currentRound): "Current round index should be equal to number of round winners."
            }

            // check identity
            let identityTokenRef = identityCollectionRef.borrow(id: self.id) as &GomokuIdentity.IdentityToken?
            assert(identityTokenRef != nil, message: "Identity token ref not found.")
            assert(identityTokenRef?.owner?.address == identityTokenRef?.address, message: "Identity token should not be transfer to other.")

            // check result
            assert(resultCollectionRef.owner?.address == identityTokenRef?.address, message: "Gomoku result collection not found.")

            let identityToken <- identityCollectionRef.withdraw(by: self.id) ?? panic("Identity token ref not found.")

            switch identityToken.role {
            case GomokuType.Role.host:
                self.roundWinners.append(GomokuType.Result.challengerWins)
            case GomokuType.Role.challenger:
                self.roundWinners.append(GomokuType.Result.hostWins)
            default:
                panic("Should not be the case.")
            }
            emit Surrender(id: self.id, from: identityTokenRef!.address)
            if self.currentRound + 1 < self.totalRound {
                // switch to next round
                identityCollectionRef.deposit(token: <- identityToken)
                self.switchRound()
            } else {
                // final round
                self.finalize(identityToken: <- identityToken)
            }
        }

        // Can only match by Gomoku.cdc to prevent from potential attack.
        access(account) fun match(
            identityCollectionRef: &GomokuIdentity.IdentityCollection,
            challenger: Address
        ) {
            pre {
                self.challenger == nil: "Already matched."
            }
            self.challenger = challenger

            // generate identity token to identify who take what stone in case someone takes other's move.
            let identity <- GomokuIdentity.createIdentity(
                id: self.id,
                address: challenger,
                role: GomokuType.Role.challenger,
                stoneColor: GomokuType.StoneColor.black
            )
            identityCollectionRef.deposit(token: <- identity)
        }

        // Restricted to prevent from potential attack.
        access(account) fun finalizeByTimeout(
            identityToken: @GomokuIdentity.IdentityToken
        ): @GomokuIdentity.IdentityToken? {
            pre {
                getCurrentBlock().height > self.getTimeout(): "Let's give opponent more time to think......"
            }

            let nextRole = self.getRole()
            switch nextRole {
            case GomokuType.Role.host:
                self.roundWinners.append(GomokuType.Result.challengerWins)
            case GomokuType.Role.challenger:
                self.roundWinners.append(GomokuType.Result.hostWins)
            default:
                panic("Should not be the case.")
            }

            // self.roundWiners.append(lastRole)
            if self.currentRound + UInt8(1) < self.totalRound {
                self.switchRound()
                return <- identityToken
            } else {
                // end of game
                // distribute reward
                self.finalize(identityToken: <- identityToken)
                return nil
            }
        }

        // Private Method
        priv fun finalize(
            identityToken: @GomokuIdentity.IdentityToken
        ) {
            pre {
                self.roundWinners.length == Int(self.totalRound): "Game not over yet!"
                self.challenger != nil: "Challenger not found."
                Gomoku.hostOpeningBetMap.keys.contains(identityToken.id): "Host's OpeningBet not found."
                Gomoku.challengerOpeningBetMap.keys.contains(identityToken.id): "Challenger's OpeningBet not found."
                Gomoku.hostRaisedBetMap.keys.contains(identityToken.id): "Host's RaisedBet not found."
                Gomoku.challengerRaisedBetMap.keys.contains(identityToken.id): "Challenger's RaisedBet not found."
            }

            // Flow Receiver
            let devFlowTokenReceiver = Gomoku.account
                .getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                .borrow() ?? panic("Could not borrow a reference to the dev flowTokenReceiver capability.")

            let hostFlowTokenReceiver = getAccount(self.host)
                .getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                .borrow() ?? panic("Could not borrow a reference to the dev flowTokenReceiver capability.")

            let challengerFlowTokenReceiver = getAccount(self.challenger!)
                .getCapability<&FlowToken.Vault{FungibleToken.Receiver}>(/public/flowTokenReceiver)
                .borrow() ?? panic("Could not borrow a reference to the dev flowTokenReceiver capability.")

            // withdraw reward
            let tatalVault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            let hostOpeningBet: @FlowToken.Vault? <- Gomoku.hostOpeningBetMap[identityToken.id] <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            Gomoku.hostFinalizedOpeningBetMap[identityToken.id] = hostOpeningBet?.balance ?? UFix64(0)
            if let hostBet <- hostOpeningBet {
                tatalVault.deposit(from: <- hostBet)
            } else {
                destroy hostOpeningBet
            }
            let challengerOpeningBet: @FlowToken.Vault? <- Gomoku.challengerOpeningBetMap[identityToken.id] <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            Gomoku.challengerFinalizedOpeningBetMap[identityToken.id] = challengerOpeningBet?.balance ?? UFix64(0)
            if let challengerBet <- challengerOpeningBet {
                tatalVault.deposit(from: <- challengerBet)
            } else {
                destroy challengerOpeningBet
            }
            destroy Gomoku.hostOpeningBetMap.remove(key: identityToken.id)
            destroy Gomoku.challengerOpeningBetMap.remove(key: identityToken.id)

            let hostRaisedBet: @FlowToken.Vault? <- Gomoku.hostRaisedBetMap[identityToken.id] <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            Gomoku.hostFinalizedRaisedBetMap[identityToken.id] = hostRaisedBet?.balance ?? UFix64(0)
            let challengerRaisedBet: @FlowToken.Vault? <- Gomoku.challengerRaisedBetMap[identityToken.id] <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            Gomoku.challengerFinalizedRaisedBetMap[identityToken.id] = challengerRaisedBet?.balance ?? UFix64(0)
            if let hostBet <- hostRaisedBet {
                if let challengerBet <- challengerRaisedBet {
                    if hostBet.balance == challengerBet.balance {
                        tatalVault.deposit(from: <- hostBet)
                        tatalVault.deposit(from: <- challengerBet)
                    } else if hostBet.balance > challengerBet.balance {
                        let backToHost <- hostBet.withdraw(amount: hostBet.balance - challengerBet.balance)
                        hostFlowTokenReceiver.deposit(from: <- backToHost)
                        tatalVault.deposit(from: <- hostBet)
                        tatalVault.deposit(from: <- challengerBet)
                    } else {
                        let backToChallenger <- challengerBet.withdraw(amount: challengerBet.balance - hostBet.balance)
                        challengerFlowTokenReceiver.deposit(from: <- backToChallenger)
                        tatalVault.deposit(from: <- hostBet)
                        tatalVault.deposit(from: <- challengerBet)
                    }
                } else {
                    hostFlowTokenReceiver.deposit(from: <- hostBet)
                    destroy challengerRaisedBet
                }
            } else {
                if let challengerBet <- challengerRaisedBet {
                    challengerFlowTokenReceiver.deposit(from: <- challengerBet)
                } else {
                    destroy challengerRaisedBet
                }
                destroy hostRaisedBet
            }

            let totalReward = tatalVault.balance
            destroy Gomoku.hostRaisedBetMap.remove(key: identityToken.id)
            destroy Gomoku.challengerRaisedBetMap.remove(key: identityToken.id)

            let devReward: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            let hostReward: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            let challengerReward: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            let winnerReward: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            let losserReward: @FlowToken.Vault <- FlowToken.createEmptyVault() as! @FlowToken.Vault
            let result = self.getWinnerResult()
            switch result {
            case GomokuType.Result.hostWins:
                // developer get 5% for developing this game
                // host get extra 1% for being host.
                // winner get 94%
                let devRewardBalance = tatalVault.balance * UFix64(5) / UFix64(100)
                let hostRewardBalance = tatalVault.balance * UFix64(1) / UFix64(100)
                let winnerRewardBalance = tatalVault.balance - devRewardBalance - hostRewardBalance
                devReward.deposit(from: <- tatalVault.withdraw(amount: devRewardBalance))
                hostReward.deposit(from: <- tatalVault.withdraw(amount: hostRewardBalance))
                winnerReward.deposit(from: <- tatalVault.withdraw(amount: winnerRewardBalance))
                destroy tatalVault
                self.winner = GomokuType.Role.host
            case GomokuType.Result.challengerWins:
                // developer get 5% for developing this game
                // host get extra 1% for being host.
                // winner get 94%.
                let devRewardBalance = tatalVault.balance * UFix64(5) / UFix64(100)
                let hostRewardBalance = tatalVault.balance * UFix64(1) / UFix64(100)
                let winnerRewardBalance = tatalVault.balance - devRewardBalance - hostRewardBalance
                devReward.deposit(from: <- tatalVault.withdraw(amount: devRewardBalance))
                hostReward.deposit(from: <- tatalVault.withdraw(amount: hostRewardBalance))
                winnerReward.deposit(from: <- tatalVault.withdraw(amount: winnerRewardBalance))
                destroy tatalVault
                self.winner = GomokuType.Role.challenger
            case GomokuType.Result.draw:
                // draw
                // developer get 2% for developing this game
                // each player get 49%.
                let hostRewardBalance = tatalVault.balance * UFix64(49) / UFix64(100)
                let challengerRewardBalance = tatalVault.balance * UFix64(49) / UFix64(100)
                let devRewardBalance = tatalVault.balance - hostRewardBalance - challengerRewardBalance
                devReward.deposit(from: <- tatalVault.withdraw(amount: devRewardBalance))
                hostReward.deposit(from: <- tatalVault.withdraw(amount: hostRewardBalance))
                challengerReward.deposit(from: <- tatalVault.withdraw(amount: challengerRewardBalance))
                destroy tatalVault
            default:
                panic("Should not be the case.")
            }

            devFlowTokenReceiver.deposit(from: <- devReward)

            // Identity collection check
            let identityTokenId = identityToken.id

            if identityToken.address == self.host {
                if let identityCollectionRef = getAccount(self.challenger!)
                    .getCapability<&GomokuIdentity.IdentityCollection>(GomokuIdentity.CollectionPublicPath)
                    .borrow() {
                    if let challengerIdentityToken <- identityCollectionRef.withdraw(by: identityTokenId) {
                        challengerIdentityToken.setDestroyable(true)
                        destroy challengerIdentityToken
                    } else {
                        emit ResourceNotFound(
                            id: identityTokenId,
                            type: Type<@GomokuIdentity.IdentityToken>(),
                            address: self.challenger!)
                    }
                } else {
                    emit CollectionNotFound(
                        type: Type<@GomokuIdentity.IdentityCollection>(),
                        path: GomokuIdentity.CollectionPublicPath,
                        address: self.challenger!)
                }
            } else if identityToken.address == self.challenger {
                if let identityCollectionRef = getAccount(self.host)
                    .getCapability<&GomokuIdentity.IdentityCollection>(GomokuIdentity.CollectionPublicPath)
                    .borrow() {
                    if let hostIdentityToken <- identityCollectionRef.withdraw(by: identityTokenId) {
                        hostIdentityToken.setDestroyable(true)
                        destroy hostIdentityToken
                    } else {
                        emit ResourceNotFound(
                            id: identityTokenId,
                            type: Type<@GomokuIdentity.IdentityToken>(),
                            address: self.host)
                    }
                } else {
                    emit CollectionNotFound(
                        type: Type<@GomokuIdentity.IdentityCollection>(),
                        path: GomokuIdentity.CollectionPublicPath,
                        address: self.host)
                }
            }
            identityToken.setDestroyable(true)
            destroy identityToken

            self.mintCompositionResults(
                id: identityTokenId,
                totalReward: totalReward,
                winnerReward: winnerReward.balance,
                hostReward: hostReward.balance,
                challengerReward: challengerReward.balance
            )

            switch result {
            case GomokuType.Result.hostWins:
                hostFlowTokenReceiver.deposit(from: <- winnerReward)
                challengerFlowTokenReceiver.deposit(from: <- losserReward)
            case GomokuType.Result.challengerWins:
                hostFlowTokenReceiver.deposit(from: <- losserReward)
                challengerFlowTokenReceiver.deposit(from: <- winnerReward)
            case GomokuType.Result.draw:
                destroy winnerReward
                destroy losserReward
            default:
                panic("Should not be the case.")
            }

            hostFlowTokenReceiver.deposit(from: <- hostReward)
            challengerFlowTokenReceiver.deposit(from: <- challengerReward)
            MatchContract.finish(index: identityTokenId)
        }

        priv fun mintCompositionResults(
            id: UInt32,
            totalReward: UFix64,
            winnerReward: UFix64,
            hostReward: UFix64,
            challengerReward: UFix64
        ) {
            pre {
                self.challenger != nil: "Challenger not found."
            }

            // get steps data
            var steps: [[StoneData]] = []
            var index: UInt8 = 0
            while index < self.totalRound {
                steps.append(self.getStoneData(for: index))
                index = index + UInt8(1)
            }

            let winnerResultCollection <- GomokuResult.createEmptyVault()
            let losserResultCollection <- GomokuResult.createEmptyVault()
            var winnerAddress: Address = self.host
            var losserAddress: Address = self.host
            let result = self.getWinnerResult()
            switch result {
            case GomokuType.Result.hostWins:
                winnerAddress = self.host
                losserAddress = self.challenger!

                let winnerResultToken <- GomokuResult.createResult(
                    id: id,
                    winner: winnerAddress,
                    losser: losserAddress,
                    gain: Fix64(winnerReward + hostReward),
                    roundWinners: self.roundWinners,
                    steps: steps
                )
                winnerResultCollection.deposit(token: <- winnerResultToken)

                let losserResultToken <- GomokuResult.createResult(
                    id: id,
                    winner: winnerAddress,
                    losser: losserAddress,
                    gain: Fix64(0),
                    roundWinners: self.roundWinners,
                    steps: steps
                )
                losserResultCollection.deposit(token: <- losserResultToken)
            case GomokuType.Result.challengerWins:
                winnerAddress = self.challenger!
                losserAddress = self.host

                let winnerResultToken <- GomokuResult.createResult(
                    id: id,
                    winner: winnerAddress,
                    losser: losserAddress,
                    gain: Fix64(winnerReward + challengerReward),
                    roundWinners: self.roundWinners,
                    steps: steps
                )
                winnerResultCollection.deposit(token: <- winnerResultToken)

                let losserResultToken <- GomokuResult.createResult(
                    id: id,
                    winner: winnerAddress,
                    losser: losserAddress,
                    gain: Fix64(hostReward),
                    roundWinners: self.roundWinners,
                    steps: steps
                )
                losserResultCollection.deposit(token: <- losserResultToken)
            case GomokuType.Result.draw:
                winnerAddress = self.host
                losserAddress = self.challenger!

                let drawResultToken1 <- GomokuResult.createResult(
                    id: id,
                    winner: nil,
                    losser: nil,
                    gain: Fix64(0),
                    roundWinners: self.roundWinners,
                    steps: steps
                )
                winnerResultCollection.deposit(token: <- drawResultToken1)

                let drawResultToken2 <- GomokuResult.createResult(
                    id: id,
                    winner: nil,
                    losser: nil,
                    gain: Fix64(0),
                    roundWinners: self.roundWinners,
                    steps: steps
                )
                losserResultCollection.deposit(token: <- drawResultToken2)
            default:
                panic("Should not be the case.")
            }

            let winnerResultToken <- winnerResultCollection.withdraw(by: id)!
            let losserResultToken <- losserResultCollection.withdraw(by: id)!

            if let winnerResultCollectionCapability = getAccount(winnerAddress)
                .getCapability<&GomokuResult.ResultCollection>(GomokuResult.CollectionPublicPath)
                .borrow() {
                winnerResultCollectionCapability.deposit(token: <- winnerResultToken)
            } else {
                winnerResultToken.setDestroyable(true)
                destroy winnerResultToken
            }
            
            if let losserResultCollectionCapability = getAccount(losserAddress)
                .getCapability<&GomokuResult.ResultCollection>(GomokuResult.CollectionPublicPath)
                .borrow() {
                losserResultCollectionCapability.deposit(token: <- losserResultToken)
            } else {
                losserResultToken.setDestroyable(true)
                destroy losserResultToken
            }

            destroy winnerResultCollection
            destroy losserResultCollection
            self.destroyable = true
        }

        // Challenger go first in first round
        priv fun getRole(): GomokuType.Role {
            let roundSteps = &self.steps[self.currentRound] as &[Stone]
            if self.currentRound % 2 == 0 {
                // first move is challenger if index is even
                if roundSteps.length % 2 == 0 {
                    // step for challenger
                    return GomokuType.Role.challenger
                } else {
                    // step for host
                    return GomokuType.Role.host
                }
            } else {
                // first move is host if index is odd
                if roundSteps.length % 2 == 0 {
                    // step for host
                    return GomokuType.Role.host
                } else {
                    // step for challenger
                    return GomokuType.Role.challenger
                }
            }
        }

        priv fun switchRound() {
            pre {
                self.roundWinners[self.currentRound] != nil: "Current round winner not decided."
                self.totalRound > self.currentRound + 1: "Next round should not over totalRound."
            }
            post {
                self.currentRound == before(self.currentRound) + 1: "fatal error."
                self.roundWinners.length == Int(self.currentRound): "Should not have winner right after switching rounds."
            }
            let previous = self.currentRound
            self.currentRound = self.currentRound + 1

            let hostIdentityCollectionCapability = getAccount(self.host)
                .getCapability<&GomokuIdentity.IdentityCollection>(GomokuIdentity.CollectionPublicPath)
                .borrow() ?? panic("Could not borrow a reference to the host capability.")
            if let identityToken = hostIdentityCollectionCapability.borrow(id: self.id) {
                identityToken.switchIdentity()
            } else {
                panic("Could not borrow a reference to identityToken.")
            }

            assert(self.challenger != nil, message: "Challenger not found.")

            let challengerIdentityCollectionCapability = getAccount(self.challenger!)
                .getCapability<&GomokuIdentity.IdentityCollection>(GomokuIdentity.CollectionPublicPath)
                .borrow() ?? panic("Could not borrow a reference to the challenger capability.")
            if let identityToken = challengerIdentityCollectionCapability.borrow(id: self.id) {
                identityToken.switchIdentity()
            } else {
                panic("Could not borrow a reference to identityToken.")
            }

            emit RoundSwitch(
                compositionId: self.id,
                previous: previous,
                next: self.currentRound
            )
        }

        priv fun verifyAndStoreStone(stone: @Stone) {
            pre {
                self.steps.length == 2: "Steps length should be 2."
                Int(self.currentRound) <= 1: "Composition only has 2 round each."
            }
            let roundSteps = &self.steps[self.currentRound] as &[AnyResource{GomokuType.Stoning}]

            // check stone location is within board.
            let isOnBoard = self.verifyOnBoard(location: stone.location)
            assert(
                isOnBoard,
                message: "Stone location"
                    .concat(stone.location.description())
                    .concat(" is invalid."))

            // check location not yet taken.
            assert(self.locationStoneMaps[self.currentRound][stone.key()] == nil, message: "This place had been taken.")

            if roundSteps.length % 2 == 0 {
                // black stone move
                assert(stone.color == GomokuType.StoneColor.black, message: "It should be black side's turn.")
            } else {
                // white stone move
                assert(stone.color == GomokuType.StoneColor.white, message: "It should be white side's turn.")
            }

            let stoneColor = stone.color
            let stoneLocation = stone.location
            self.locationStoneMaps[self.currentRound][stone.key()] = stoneColor
            self.steps[self.currentRound].append(<- stone)
        }

        priv fun verifyOnBoard(location: GomokuType.StoneLocation): Bool {
            if location.x > Int8(self.boardSize) - Int8(1) {
                return false
            }
            if location.x < Int8(0) {
                return false
            }
            if location.y > Int8(self.boardSize) - Int8(1) {
                return false
            }
            if location.y < Int8(0) {
                return false
            }
            return true
        }

        priv fun checkWinnerInAllDirection(
            targetColor: GomokuType.StoneColor,
            center: GomokuType.StoneLocation
        ): Bool {
            return self.checkWinner(
                    targetColor: targetColor,
                    center: center,
                    direction: GomokuType.VerifyDirection.vertical)
                || self.checkWinner(
                    targetColor: targetColor,
                    center: center, 
                    direction: GomokuType.VerifyDirection.horizontal)
                || self.checkWinner(
                    targetColor: targetColor,
                    center: center, 
                    direction: GomokuType.VerifyDirection.diagonal)
                || self.checkWinner(
                    targetColor: targetColor,
                    center: center, 
                    direction: GomokuType.VerifyDirection.reversedDiagonal)
        }

        priv fun checkWinner(
            targetColor: GomokuType.StoneColor,
            center: GomokuType.StoneLocation,
            direction: GomokuType.VerifyDirection
        ): Bool {
            var countInRow: UInt8 = 1
            var shift: Int8 = 1
            var isFinished: Bool = false
            switch direction {
            case GomokuType.VerifyDirection.vertical:
                while !isFinished
                        && shift <= Int8(4)
                        && center.x - shift >= Int8(0) {
                    let currentCheckedLocation = GomokuType.StoneLocation(x: center.x - shift, y: center.y)
                    if let color = self.locationStoneMaps[self.currentRound][currentCheckedLocation.key()] {
                        if color == targetColor {
                            countInRow = countInRow + UInt8(1)
                        } else {
                            isFinished = true
                        }
                    } else {
                        isFinished = true
                    }
                    shift = shift + Int8(1)
                }
                shift = 1
                isFinished = false
                while !isFinished
                        && shift <= Int8(4)
                        && center.x + shift >= Int8(0) {
                    let currentCheckedLocation = GomokuType.StoneLocation(x: center.x + shift, y: center.y)
                    if let color = self.locationStoneMaps[self.currentRound][currentCheckedLocation.key()] {
                        if color == targetColor {
                            countInRow = countInRow + UInt8(1)
                        } else {
                            isFinished = true
                        }
                    } else {
                        isFinished = true
                    }
                    shift = shift + Int8(1)
                }
            case GomokuType.VerifyDirection.horizontal:
                while !isFinished
                        && shift <= Int8(4)
                        && center.y - shift >= Int8(0) {
                    let currentCheckedLocation = GomokuType.StoneLocation(x: center.x, y: center.y - shift)
                    if let color = self.locationStoneMaps[self.currentRound][currentCheckedLocation.key()] {
                        if color == targetColor {
                            countInRow = countInRow + UInt8(1)
                        } else {
                            isFinished = true
                        }
                    } else {
                        isFinished = true
                    }
                    shift = shift + Int8(1)
                }
                shift = 1
                isFinished = false
                while !isFinished
                        && shift <= Int8(4)
                        && center.y + shift >= Int8(0) {
                    let currentCheckedLocation = GomokuType.StoneLocation(x: center.x, y: center.y + shift)
                    if let color = self.locationStoneMaps[self.currentRound][currentCheckedLocation.key()] {
                        if color == targetColor {
                            countInRow = countInRow + UInt8(1)
                        } else {
                            isFinished = true
                        }
                    } else {
                        isFinished = true
                    }
                    shift = shift + Int8(1)
                }
            case GomokuType.VerifyDirection.diagonal:
                while !isFinished
                        && shift <= Int8(4)
                        && center.x - shift >= Int8(0)
                        && center.y - shift >= Int8(0) {
                    let currentCheckedLocation = GomokuType.StoneLocation(x: center.x - shift, y: center.y - shift)
                    if let color = self.locationStoneMaps[self.currentRound][currentCheckedLocation.key()] {
                        if color == targetColor {
                            countInRow = countInRow + UInt8(1)
                        } else {
                            isFinished = true
                        }
                    } else {
                        isFinished = true
                    }
                    shift = shift + Int8(1)
                }
                shift = 1
                isFinished = false
                while !isFinished
                        && shift <= Int8(4)
                        && center.x + shift >= Int8(0)
                        && center.y + shift >= Int8(0) {
                    let currentCheckedLocation = GomokuType.StoneLocation(x: center.x + shift, y: center.y + shift)
                    if let color = self.locationStoneMaps[self.currentRound][currentCheckedLocation.key()] {
                        if color == targetColor {
                            countInRow = countInRow + UInt8(1)
                        } else {
                            isFinished = true
                        }
                    } else {
                        isFinished = true
                    }
                    shift = shift + Int8(1)
                }
            case GomokuType.VerifyDirection.reversedDiagonal:
                while !isFinished
                        && shift <= Int8(4)
                        && center.x - shift >= Int8(0)
                        && center.y + shift >= Int8(0) {
                    let currentCheckedLocation = GomokuType.StoneLocation(x: center.x - shift, y: center.y + shift)
                    if let color = self.locationStoneMaps[self.currentRound][currentCheckedLocation.key()] {
                        if color == targetColor {
                            countInRow = countInRow + UInt8(1)
                        } else {
                            isFinished = true
                        }
                    } else {
                        isFinished = true
                    }
                    shift = shift + Int8(1)
                }
                shift = 1
                isFinished = false
                while !isFinished
                        && shift <= Int8(4)
                        && center.x + shift >= Int8(0)
                        && center.y - shift >= Int8(0) {
                    let currentCheckedLocation = GomokuType.StoneLocation(x: center.x + shift, y: center.y - shift)
                    if let color = self.locationStoneMaps[self.currentRound][currentCheckedLocation.key()] {
                        if color == targetColor {
                            countInRow = countInRow + UInt8(1)
                        } else {
                            isFinished = true
                        }
                    } else {
                        isFinished = true
                    }
                    shift = shift + Int8(1)
                }
            }
            return countInRow >= UInt8(5)
        }

        priv fun getWinnerResult(): GomokuType.Result {
            pre {
                self.roundWinners.length == Int(self.totalRound): "Game not over yet!"
            }

            let firstRoundWinner = self.roundWinners[0]
            let secondRoundWinner = self.roundWinners[1]
            if firstRoundWinner == secondRoundWinner {
                // has winner
                return firstRoundWinner
            } else if self.roundWinners.contains(GomokuType.Result.draw) {
                if self.roundWinners.contains(GomokuType.Result.hostWins) {
                    return GomokuType.Result.hostWins
                } else if self.roundWinners.contains(GomokuType.Result.challengerWins) {
                    return GomokuType.Result.challengerWins
                } else {
                    return GomokuType.Result.draw
                }
            } else {
                return GomokuType.Result.draw
            }
        }

        destroy() {
            if self.destroyable == false {
                panic("You can't destory this composition by yourself!")
            }
            destroy self.steps
        }

    }

    access(account) fun createComposition(
        id: UInt32,
        host: Address,
        boardSize: UInt8,
        totalRound: UInt8
    ): @Gomoku.Composition {

        let Composition <- create Composition(
            id: id,
            host: host,
            boardSize: boardSize,
            totalRound: totalRound
        )

        return <- Composition
    }

    pub resource CompositionCollection {

        pub let StoragePath: StoragePath
        pub let PublicPath: PublicPath

        priv var ownedCompositionMap: @{UInt32: Gomoku.Composition}
        priv var destroyable: Bool

        init () {
            self.ownedCompositionMap <- {}
            self.destroyable = false
            self.StoragePath = /storage/gomokuCollection
            self.PublicPath = /public/gomokuCollection
        }

        access(account) fun withdraw(by id: UInt32): @Gomoku.Composition {
            let token <- self.ownedCompositionMap.remove(key: id) ?? panic("missing Composition")
            emit Withdraw(id: token.id, from: self.owner?.address)
            if self.ownedCompositionMap.keys.length == 0 {
                self.destroyable = true
            }
            return <- token
        }

        access(account) fun deposit(token: @Gomoku.Composition) {
            let token <- token
            let id: UInt32 = token.id
            let oldToken <- self.ownedCompositionMap[id] <- token
            emit Deposit(id: id, to: self.owner?.address)
            self.destroyable = false
            destroy oldToken
        }

        pub fun getIds(): [UInt32] {
            return self.ownedCompositionMap.keys
        }

        pub fun getBalance(): Int {
            return self.ownedCompositionMap.keys.length
        }

        pub fun borrow(id: UInt32): &Gomoku.Composition? {
            return &self.ownedCompositionMap[id] as &Gomoku.Composition?
        }

        destroy() {
            destroy self.ownedCompositionMap
            if self.destroyable == false {
                panic("Ha Ha! Got you! You can't destory this collection if there are Gomoku Composition!")
            }
        }
    }

    pub fun createEmptyVault(): @Gomoku.CompositionCollection {
        emit CollectionCreated()
        return <- create CompositionCollection()
    }

    pub struct StoneData: GomokuType.StoneDataing {
        pub let color: GomokuType.StoneColor
        pub let location: GomokuType.StoneLocation

        init(
            color: GomokuType.StoneColor,
            location: GomokuType.StoneLocation
        ) {
            self.color = color
            self.location = location
        }
    }

    pub resource Stone: GomokuType.Stoning {
        pub let color: GomokuType.StoneColor
        pub let location: GomokuType.StoneLocation

        pub init(
            color: GomokuType.StoneColor,
            location: GomokuType.StoneLocation
        ) {
            self.color = color
            self.location = location
        }

        pub fun key(): String {
            return self.location.key()
        }

        pub fun convertToData(): AnyStruct{GomokuType.StoneDataing} {
            return StoneData(
                color: self.color,
                location: self.location
            )
        }
    }
}