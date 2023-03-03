import FungibleToken from 0xf233dcee88fe0abe  //mainnet
import FlowToken from 0x1654653399040a61 //mainnet

pub contract CoinFlip{

    // BetCreated triggers when a bet is created
    pub event BetCreated(bettor: Address, amount: UFix64, guess: String)

    // OutcomeCreated triggers when the outcome is derived from the blockID
    pub event OutcomeCreated(blockID: String)

    // PayoutSent triggers when the payout has been sent to the winner
    pub event PayoutSent(amount: UFix64, winner: Address)

    // declare public fields
    pub let bettor: Address
    pub let banker: Address
    pub let amount: UFix64
    pub let guess: String
    pub var blockID: String
    pub var winner: Address
    
    // makeBet creates a new bet
    pub fun makeBet(bettor: Address, banker: Address, amount: UFix64, guess: String) {      
        
        emit BetCreated(bettor: bettor, amount: amount, guess: guess)
        }

     // Randomization event that occurs after a bet is placed
    pub fun DecidingOutcome(blockID: String){


        emit OutcomeCreated(blockID: blockID) 
        }
    
    // PayoutBet sends the winnings to the winner if they were correct in their guess, 
    // or to the FlowBook wallet if they were wrong
    pub fun PayoutBet(amount:UFix64, winner: Address){
    
        emit PayoutSent(amount: amount, winner: winner)
        }

    init() {
        self.bettor = 0x1654653399040a61
        self.banker = 0x1654653399040a61
        self.winner = 0x1654653399040a61
        self.amount = 184467440737.09551615
        self.guess = "Heads"
        self.blockID = "0x1654653399040a61"
    }
}
