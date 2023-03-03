import JoyridePayments from 0xecfad18ba9582d4f

pub contract JoyrideGameShim {
    pub event PlayerTransaction(gameID: String)
    pub event FinalizeTransaction(gameID: String)
    pub event RefundTransaction(gameID: String)

    //Fake Token Events for User Mapping
    pub event TokensWithdrawn(amount: UFix64, from: Address?)
    pub event TokensDeposited(amount: UFix64, to: Address?)

    pub fun GameIDtoStoragePath(_ gameID:String) : StoragePath {
      return StoragePath(identifier: "JoyrideGame_".concat(gameID))!
    }

    pub fun GameIDtoCapabilityPath(_ gameID:String) : PrivatePath {
      return PrivatePath(identifier: "JoyrideGame_".concat(gameID))!
    }

    pub fun CreateJoyrideGame(paymentsAdmin: Capability<&{JoyridePayments.WalletAdmin}>,gameID:String) : @JoyrideGameShim.JoyrideGame {
      return <- create JoyrideGameShim.JoyrideGame(paymentsAdmin:paymentsAdmin, gameID:gameID)
    }

    pub resource interface JoyrideGameData {
      pub fun readGameInfo(_ key:String) : AnyStruct
      pub fun setGameInfo(_ key:String, value:AnyStruct)
    }

    pub resource JoyrideGame: JoyrideGameData, JoyridePayments.WalletAdmin
    {
      access(self) let gameInfo:{String:AnyStruct}
      access(self) var paymentsAdmin: Capability<&{JoyridePayments.WalletAdmin}>

      init(paymentsAdmin: Capability<&{JoyridePayments.WalletAdmin}>, gameID:String) {
        self.gameInfo = {"gameID":gameID}
        self.paymentsAdmin = paymentsAdmin
      }

      pub fun readGameInfo(_ key:String) : AnyStruct {
        return self.gameInfo[key]
      }

      pub fun setGameInfo(_ key:String, value:AnyStruct) {
        self.gameInfo[key] = value
      }

      pub fun PlayerTransaction(playerID: String, tokenContext: String, amount:Fix64, gameID: String, txID: String, reward: Bool, notes: String) : Bool {
        if(!self.gameInfo.containsKey("gameID")) {
            panic("gameID not set")
        }
        let _gameID = self.readGameInfo("gameID")! as! String
        if(gameID != _gameID) { panic("Incorrect GameID for Shim") }

        emit JoyrideGameShim.PlayerTransaction(gameID: gameID)
        return self.paymentsAdmin.borrow()!.PlayerTransaction(playerID: playerID, tokenContext: tokenContext, amount: amount, gameID: gameID, txID: txID, reward: reward, notes: notes)
      }

      pub fun FinalizeTransactionWithDevPercentage(txID: String, profit: UFix64, devPercentage: UFix64) : Bool {
        emit JoyrideGameShim.FinalizeTransaction(gameID: self.readGameInfo("gameID")! as! String)
        return self.paymentsAdmin.borrow()!.FinalizeTransactionWithDevPercentage(txID: txID, profit: profit, devPercentage: devPercentage)
      }

      pub fun RefundTransaction(txID: String) : Bool {
        emit JoyrideGameShim.RefundTransaction(gameID: self.readGameInfo("gameID")! as! String)
        return self.paymentsAdmin.borrow()!.RefundTransaction(txID: txID)
      }
    }
}
