import FungibleToken from 0xf233dcee88fe0abe
import LeofyNFT from 0x14af75b8c487333c
import LeofyCoin from 0x14af75b8c487333c

pub contract LeofyMarketPlace{

    // The total amount of MarketplaceItems that have been created
    pub var totalMarketPlaceItems: UInt64
    pub var cutPercentage: UFix64
    pub var marketplaceVault: Capability<&{FungibleToken.Receiver}>
    pub var minimumBidIncrement: UFix64
    pub var extendsTime: UFix64
    pub var extendsWhenTimeLowerThan: Fix64

    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let AdminStoragePath: StoragePath

    pub event Created(tokenID: UInt64, nftID: UInt64?, owner: Address, startPrice: UFix64, startTime: UFix64, auctionLength: UFix64, purchasePrice: UFix64)
    pub event Bid(tokenID: UInt64, bidderAddress: Address, bidPrice: UFix64)
    pub event Cancelled(tokenID: UInt64, owner: Address)
    pub event Settled(tokenID: UInt64, price: UFix64)
    pub event Purchased(tokenID: UInt64, price: UFix64)
    pub event MarketplaceEarned(amount:UFix64, owner: Address)
    pub event DropExtended(tokenID: UInt64, owner: Address, extendWith: UFix64, extendTo: UFix64)

    pub struct MarketplaceStatus{
        pub let id: UInt64
        pub let price : UFix64
        pub let bids : UInt64
        //Active is probably not needed when we have completed and expired above, consider removing it
        pub let active: Bool
        pub let timeRemaining : Fix64
        pub let endTime : Fix64
        pub let startTime : Fix64
        pub let metadata: AnyStruct?
        pub let nftId: UInt64?
        pub let owner: Address
        pub let leader: Address?
        pub let completed: Bool
        pub let expired: Bool
        pub let minNextBid: UFix64
        pub let purchasePrice: UFix64
        pub let cutPercentage: UFix64
    
        init(id:UInt64, 
            currentPrice: UFix64, 
            bids:UInt64, 
            active: Bool, 
            timeRemaining:Fix64, 
            metadata: AnyStruct?,
            nftId: UInt64?,
            leader:Address?, 
            owner: Address, 
            startTime: Fix64,
            endTime: Fix64,
            completed: Bool,
            expired:Bool,
            minNextBid:UFix64,
            purchasePrice: UFix64,
            cutPercentage:UFix64
        ) {
            self.id=id
            self.price=currentPrice
            self.bids=bids
            self.active=active
            self.timeRemaining=timeRemaining
            self.metadata=metadata
            self.nftId=nftId
            self.leader= leader
            self.owner=owner
            self.startTime=startTime
            self.endTime=endTime
            self.completed=completed
            self.expired=expired
            self.minNextBid=minNextBid
            self.purchasePrice=purchasePrice
            self.cutPercentage=cutPercentage
        }
    }
    
    pub resource MarketplaceItem{
        priv var numberOfBids: UInt64
        //This is the escrow vault that holds the tokens for the current largest bid
        priv var NFT: @LeofyNFT.NFT?
        priv let bidVault: @FungibleToken.Vault

        //The id of this individual auction
        pub let marketplaceID: UInt64

        //the time the acution should start at
        priv var auctionStartTime: UFix64

        //The length in seconds for this auction
        priv var auctionLength: UFix64

        //Auction Ended
        priv var auctionCompleted: Bool

        // Auction State
        access(account) var startPrice: UFix64
        priv var currentPrice: UFix64

        //the capability that points to the resource where you want the NFT transfered to if you win this bid. 
        priv var recipientCollectionCap: Capability<&{LeofyNFT.LeofyCollectionPublic}>?

        //the capablity to send the escrow bidVault to if you are outbid
        priv var recipientVaultCap: Capability<&{FungibleToken.Receiver}>?

        //the capability for the owner of the NFT to return the item to if the auction is cancelled
        priv let ownerCollectionCap: Capability<&{LeofyNFT.LeofyCollectionPublic}>

        //the capability to pay the owner of the item when the auction is done
        priv let ownerVaultCap: Capability<&{FungibleToken.Receiver}>

        priv var purchasePrice: UFix64

        priv var cutPercentage: UFix64

        init(
            NFT: @LeofyNFT.NFT,
            auctionStartTime: UFix64,
            auctionLength: UFix64,
            startPrice: UFix64,
            ownerCollectionCap: Capability<&{LeofyNFT.LeofyCollectionPublic}>,
            ownerVaultCap: Capability<&{FungibleToken.Receiver}>,
            purchasePrice: UFix64
        ) {
            pre {
                ownerCollectionCap.check() == true: "Can't validate that the ownerCollectionCapability Exists"
                ownerVaultCap.check() == true: "Can't validate that the ownerVaultCap Exists"
            }
            LeofyMarketPlace.totalMarketPlaceItems = LeofyMarketPlace.totalMarketPlaceItems + (1 as UInt64)
            
            self.NFT <- NFT;
            self.numberOfBids = 0
            self.bidVault <- LeofyCoin.createEmptyVault();
            self.marketplaceID = LeofyMarketPlace.totalMarketPlaceItems
            self.auctionStartTime = auctionStartTime;
            self.auctionLength = auctionLength
            self.auctionCompleted = false;
            self.startPrice = startPrice;
            self.currentPrice = 0.00;
            self.recipientCollectionCap = nil;
            self.recipientVaultCap = nil;
            self.ownerCollectionCap = ownerCollectionCap;
            self.ownerVaultCap = ownerVaultCap;
            self.purchasePrice = purchasePrice;
            self.cutPercentage = LeofyMarketPlace.cutPercentage;
        }

        // sendNFT sends the NFT to the Collection belonging to the provided Capability
        access(contract) fun sendNFT(_ capability: Capability<&{LeofyNFT.LeofyCollectionPublic}>) {
            if let collectionRef = capability.borrow() {
                let NFT <- self.NFT <- nil
                collectionRef.deposit(token: <-NFT!)
                return
            } 
            if let ownerCollection=self.ownerCollectionCap.borrow() {
                let NFT <- self.NFT <- nil
                ownerCollection.deposit(token: <-NFT!)
                return 
            } 
        }


        // sendBidTokens sends the bid tokens to the Vault Receiver belonging to the provided Capability
        access(contract) fun sendBidTokens(_ capability: Capability<&{FungibleToken.Receiver}>) {
            // borrow a reference to the owner's NFT receiver
            if let vaultRef = capability.borrow() {
                let bidVaultRef = &self.bidVault as &FungibleToken.Vault
                if(bidVaultRef.balance > 0.0) {
                    vaultRef.deposit(from: <-bidVaultRef.withdraw(amount: bidVaultRef.balance))
                }
                return
            }

            if let ownerRef= self.ownerVaultCap.borrow() {
                let bidVaultRef = &self.bidVault as &FungibleToken.Vault
                if(bidVaultRef.balance > 0.0) {
                    ownerRef.deposit(from: <-bidVaultRef.withdraw(amount: bidVaultRef.balance))
                }
                return
            }
        }

        access(contract) fun releasePreviousBid() {
            if let vaultCap = self.recipientVaultCap {
                self.sendBidTokens(self.recipientVaultCap!)
                return
            } 
        }

        //This method should probably use preconditions more 
        pub fun settleAuction(cutPercentage: UFix64, cutVault:Capability<&{FungibleToken.Receiver}> )  {

            pre {
                !self.auctionCompleted : "The auction is already settled"
                self.NFT != nil: "NFT in auction does not exist"
                self.isAuctionExpired() : "Auction has not completed yet"
            }

            // return if there are no bids to settle
            if self.currentPrice == 0.0{
                self.returnAuctionItemToOwner()
                return
            }            

            //Withdraw cutPercentage to marketplace and put it in their vault
            let amount=self.currentPrice*(cutPercentage/100.00)
            let beneficiaryCut <- self.bidVault.withdraw(amount:amount )

            let cutVault=cutVault.borrow()!
            emit MarketplaceEarned(amount: amount, owner: cutVault.owner!.address)
            cutVault.deposit(from: <- beneficiaryCut)

            self.sendNFT(self.recipientCollectionCap!)
            self.sendBidTokens(self.ownerVaultCap)

            self.auctionCompleted = true
            
            emit Settled(tokenID: self.marketplaceID, price: self.currentPrice)
            
        }

        access(contract) fun returnAuctionItemToOwner() {
            // release the bidder's tokens
            self.releasePreviousBid()

            // deposit the NFT into the owner's collection
            self.sendNFT(self.ownerCollectionCap)
        }

        //this can be negative if is expired
        pub fun timeRemaining() : Fix64 {
            let auctionLength = self.auctionLength

            let startTime = self.auctionStartTime
            let currentTime = getCurrentBlock().timestamp

            let remaining= Fix64(startTime+auctionLength) - Fix64(currentTime)
            return remaining
        }

      
        pub fun isAuctionExpired(): Bool {
            let timeRemaining= self.timeRemaining()
            if(self.auctionStartTime == UFix64(0.0) || self.auctionLength == UFix64(0.0)){
                return false
            }
            return timeRemaining < Fix64(0.0)
        }

        pub fun minNextBid() :UFix64{
            //If there are bids then the next min bid is the current price plus the increment
            if self.currentPrice != 0.0 {
                return self.currentPrice+LeofyMarketPlace.minimumBidIncrement
            }
            //else start price
            return self.startPrice
        }

        //Extend an auction with a given set of blocks
        access(contract) fun extendWith(_ amount: UFix64) {
            self.auctionLength= self.auctionLength + amount
            emit DropExtended(tokenID: self.marketplaceID, owner: self.ownerCollectionCap.address, extendWith: amount, extendTo: self.auctionStartTime+self.auctionLength)
        }

        pub fun bidder() : Address? {
            if let vaultCap = self.recipientVaultCap {
                return vaultCap.borrow()!.owner!.address
            }
            return nil
        }

        pub fun currentBidForUser(address:Address): UFix64 {
             if(self.bidder() == address) {
                return self.bidVault.balance
            }
            return 0.0
        }

        pub fun placeBid(
            bidTokens: @FungibleToken.Vault, 
            vaultCap: Capability<&{FungibleToken.Receiver}>, 
            collectionCap: Capability<&{LeofyNFT.LeofyCollectionPublic}>
        ){
            pre {
                !self.auctionCompleted : "The auction is already settled"
                self.NFT != nil: "NFT in auction does not exist"
                !self.isAuctionExpired(): "Auction already expired"
                self.auctionStartTime > UFix64(0.0): "Not an auction"
                self.auctionLength > UFix64(0.0): "Not an auction"
            }

            let bidderAddress=vaultCap.borrow()!.owner!.address

            let amountYouAreBidding= bidTokens.balance + self.currentBidForUser(address: bidderAddress)
            let minNextBid=self.minNextBid()
            if amountYouAreBidding < minNextBid {
                panic("bid amount + (your current bid) must be larger or equal to the current price + minimum bid increment ".concat(amountYouAreBidding.toString()).concat(" < ").concat(minNextBid.toString()))
            }

            
            // Return balance from the current BID to the previus bidder
            if self.bidder() != bidderAddress {
              if self.bidVault.balance != 0.0 {
                self.sendBidTokens(self.recipientVaultCap!)
              }
            }

            // Deposit and save the new bidder vaults and collections
            
            self.bidVault.deposit(from: <- bidTokens)
            self.recipientVaultCap = vaultCap
            self.recipientCollectionCap = collectionCap
            self.currentPrice = self.bidVault.balance
            self.numberOfBids = self.numberOfBids + 1;

            if(self.timeRemaining() < LeofyMarketPlace.extendsWhenTimeLowerThan ){
                self.extendWith(LeofyMarketPlace.extendsTime)
            }

            emit Bid(tokenID: self.marketplaceID, bidderAddress: vaultCap.borrow()!.owner!.address, bidPrice: self.currentPrice)
        }

        pub fun placePurchase(
            payment: @FungibleToken.Vault, 
            collectionCap: Capability<&{LeofyNFT.LeofyCollectionPublic}>
        ){
            pre {
                !self.auctionCompleted : "The auction is already settled"
                self.NFT != nil: "NFT in auction does not exist"
                !self.isAuctionExpired(): "Auction already expired"
                payment.isInstance(Type<@LeofyCoin.Vault>()): "payment vault is not requested fungible token"
                self.purchasePrice == payment.balance: "Purchase must be equal to the purchasePrice"
                self.purchasePrice > 0.00: "Item is not available for sell"
                self.purchasePrice > self.currentPrice: "Item is now only available for auction"
            }

            self.releasePreviousBid()

            let cutPercentage = self.getMarketplaceStatus().cutPercentage
            let cutVault = LeofyMarketPlace.marketplaceVault.borrow()!

            let amount=self.purchasePrice*(cutPercentage/100.00)
            let beneficiaryCut <- payment.withdraw(amount:amount )

            emit MarketplaceEarned(amount: amount, owner: cutVault.owner!.address)
            cutVault.deposit(from: <- beneficiaryCut)

            self.sendNFT(collectionCap)

            if let ownerRef= self.ownerVaultCap.borrow() {
                if(payment.balance > 0.0) {
                  // ownerRef.deposit(from: <- payment)
                }
            }
            let ownerRef = self.ownerVaultCap.borrow()
			?? panic("Could not borrow reference to the owner's Vault!")

            ownerRef.deposit(from: <- payment)

            //self.ownerVaultCap.borrow().deposit(from: <- payment)

            self.auctionCompleted = true
            
            emit Purchased(tokenID: self.marketplaceID, price: self.purchasePrice)

            

        }

        pub fun getMarketplaceStatus() : MarketplaceStatus {

            var leader:Address?= nil
            if let recipient = self.recipientVaultCap {
                leader=recipient.address
            }

            let view = self.NFT?.resolveView(Type<LeofyNFT.LeofyNFTMetadataView>())

            return MarketplaceStatus(
                id:self.marketplaceID,
                currentPrice: self.currentPrice, 
                bids: self.numberOfBids,
                active: !self.auctionCompleted  && !self.isAuctionExpired(),
                timeRemaining: self.timeRemaining(),
                metadata: view,
                nftId: self.NFT?.id,
                leader: leader,
                owner: self.ownerVaultCap.address,
                startTime: Fix64(self.auctionStartTime),
                endTime: Fix64(self.auctionStartTime+self.auctionLength),
                completed: self.auctionCompleted,
                expired: self.isAuctionExpired(),
                minNextBid: self.minNextBid(),
                purchasePrice: self.purchasePrice,
                cutPercentage: self.cutPercentage
            )
        }

        destroy() {
            if self.NFT != nil {
                self.sendNFT(self.ownerCollectionCap)
            }

            // if there's a bidder...
            if let vaultCap = self.recipientVaultCap {
                // ...send the bid tokens back to the bidder
                self.sendBidTokens(vaultCap)
            }
            
            destroy self.bidVault;
            destroy self.NFT;
        }  
    }

     pub resource interface MarketplaceCollectionPublic {
        pub fun placeBid(id: UInt64, bidTokens: @FungibleToken.Vault, vaultCap: Capability<&{FungibleToken.Receiver}>, collectionCap: Capability<&{LeofyNFT.LeofyCollectionPublic}>)
        pub fun placePurchase(id: UInt64, payment: @FungibleToken.Vault, collectionCap: Capability<&{LeofyNFT.LeofyCollectionPublic}>)
        pub fun getMarketplaceStatuses(): {UInt64: MarketplaceStatus}
        pub fun getMarketplaceStatus(_ id:UInt64): MarketplaceStatus
        pub fun settleAuction(_ id: UInt64)
    }

    pub resource MarketplaceCollection: MarketplaceCollectionPublic{
        access(account) var marketplaceItems: @{UInt64: MarketplaceItem}
        init(){
            self.marketplaceItems <- {}
        }

        pub fun sellItem(
            token: @LeofyNFT.NFT,
            auctionStartTime: UFix64,
            auctionLength: UFix64,
            startPrice: UFix64,
            ownerCollectionCap: Capability<&{LeofyNFT.LeofyCollectionPublic}>,
            ownerVaultCap: Capability<&{FungibleToken.Receiver}>,
            purchasePrice: UFix64
        ){
            pre {
                 ( purchasePrice == 0.00 && auctionStartTime > 0.00 && auctionLength > 0.00 || purchasePrice > (startPrice + LeofyMarketPlace.minimumBidIncrement )):
                    "Purchase Price ("
                    .concat(purchasePrice.toString())
                    .concat(") must be higher than startPrice (")
                    .concat(startPrice.toString()).concat(") + the minimumBidIncrement (")
                    .concat(LeofyMarketPlace.minimumBidIncrement.toString())
                    .concat(") or be zero")
            }

            let marketPlaceItem <- create MarketplaceItem(
                NFT: <-token,
                auctionStartTime: auctionStartTime,
                auctionLength: auctionLength,
                startPrice: startPrice,
                ownerCollectionCap: ownerCollectionCap,
                ownerVaultCap: ownerVaultCap,
                purchasePrice: purchasePrice
            )

            let id = marketPlaceItem.marketplaceID
            let nftID = marketPlaceItem.getMarketplaceStatus().nftId;

            let oldItem <- self.marketplaceItems[marketPlaceItem.marketplaceID] <- marketPlaceItem
            destroy oldItem

            emit Created(tokenID: id, nftID: nftID, owner: ownerVaultCap.address, startPrice: startPrice, startTime: auctionStartTime, auctionLength: auctionLength, purchasePrice: purchasePrice)
        }

        // getAuctionPrices returns a dictionary of available NFT IDs with their current price
        pub fun getMarketplaceStatuses(): {UInt64: MarketplaceStatus} {
            let priceList: {UInt64: MarketplaceStatus} = {}

            for id in self.marketplaceItems.keys {
                let itemRef = (&self.marketplaceItems[id] as? &MarketplaceItem?)!
                priceList[id] = itemRef.getMarketplaceStatus()
            }
            
            return priceList
        }

        pub fun getMarketplaceStatus(_ id:UInt64): MarketplaceStatus {
            pre {
                self.marketplaceItems[id] != nil:
                    "NFT doesn't exist"
            }

            // Get the auction item resources
            let itemRef = (&self.marketplaceItems[id] as &MarketplaceItem?)!
            return itemRef.getMarketplaceStatus()

        }

        pub fun cancelAuction(_ id: UInt64) {
            pre {
                self.marketplaceItems[id] != nil:
                    "Auction does not exist"
            }
            let itemRef = (&self.marketplaceItems[id] as &MarketplaceItem?)!

            let tokenID = itemRef.marketplaceID;
            let owner = itemRef.getMarketplaceStatus().owner
            //itemRef.destroy()
            //itemRef.returnAuctionItemToOwner()

            let oldItem <- self.marketplaceItems[id] <- nil
            destroy oldItem

            emit Cancelled(tokenID: tokenID, owner: owner)
            
        }

         pub fun placeBid(id: UInt64, bidTokens: @FungibleToken.Vault, vaultCap: Capability<&{FungibleToken.Receiver}>, collectionCap: Capability<&{LeofyNFT.LeofyCollectionPublic}>) {
            pre {
                self.marketplaceItems[id] != nil: "Auction does not exist in this drop"
            }

            // Get the auction item resources
            let itemRef = (&self.marketplaceItems[id] as &MarketplaceItem?)!
            itemRef.placeBid(bidTokens: <- bidTokens, 
              vaultCap:vaultCap, 
              collectionCap:collectionCap)

        }

         pub fun placePurchase(id: UInt64, payment: @FungibleToken.Vault, collectionCap: Capability<&{LeofyNFT.LeofyCollectionPublic}>) {
            pre {
                self.marketplaceItems[id] != nil: "Auction does not exist in this drop"
            }

            // Get the auction item resources
            let itemRef = (&self.marketplaceItems[id] as &MarketplaceItem?)!
            itemRef.placePurchase(payment: <- payment,
              collectionCap:collectionCap)

            let oldItem <- self.marketplaceItems[id] <- nil
            destroy oldItem

        }

        // settleAuction sends the auction item to the highest bidder
        // and deposits the FungibleTokens into the auction owner's account
        pub fun settleAuction(_ id: UInt64) {
            pre {
                self.marketplaceItems[id] != nil: "Auction does not exist in this drop"
            }

            let itemRef = (&self.marketplaceItems[id] as &MarketplaceItem?)!
            itemRef.settleAuction(cutPercentage: itemRef.getMarketplaceStatus().cutPercentage, cutVault: LeofyMarketPlace.marketplaceVault)

            let oldItem <- self.marketplaceItems[id] <- nil
            destroy oldItem
        }

        destroy() {
            log("destroy auction collection")
            // destroy the empty resources
            destroy self.marketplaceItems
        }
    }

    // public function that anyone can call to create a new empty collection
    pub fun createEmptyCollection(): @LeofyMarketPlace.MarketplaceCollection {
        return <- create MarketplaceCollection()
    }

    // Only owner of this resource object can call this function
    pub resource LeofyMarketPlaceAdmin {
        pub fun changePercentage(_ cutPercentage: UFix64){
            pre {
                 cutPercentage >= 0.00 && cutPercentage <= 100.00: "Cut percentage must be between 0 and 100"
            }
            LeofyMarketPlace.cutPercentage = cutPercentage
        }

        pub fun changeBidIncrement(_ minimumBidIncrement: UFix64){
            LeofyMarketPlace.minimumBidIncrement = minimumBidIncrement
        }

        pub fun changeExtendsTime(_ extendsTime: UFix64){
            LeofyMarketPlace.extendsTime = extendsTime
        }

        pub fun changeExtendsWhenTimeLowerThan(_ extendsWhenTimeLowerThan: Fix64){
            LeofyMarketPlace.extendsWhenTimeLowerThan = extendsWhenTimeLowerThan
        }

        pub fun changeMarketplaceVault(_ marketplaceVault: Capability<&{FungibleToken.Receiver}>){
           pre {
                marketplaceVault.check() == true: "Can't validate that the marketplaceVault Exists"
           }
           LeofyMarketPlace.marketplaceVault = marketplaceVault
        }
    }

    init() {
        self.totalMarketPlaceItems = 0
        self.cutPercentage = 15.00
        self.marketplaceVault = self.account.getCapability<&AnyResource{FungibleToken.Receiver}>(LeofyCoin.ReceiverPublicPath)
        self.minimumBidIncrement = 1.00
        self.extendsTime = 300.00
        self.extendsWhenTimeLowerThan = 60.00

        self.CollectionStoragePath = /storage/LeofyMarketPlaceCollection
        self.CollectionPublicPath = /public/LeofyMarketPlaceCollection
        self.AdminStoragePath = /storage/LeofyMarketPlaceAdmin

        destroy self.account.load<@MarketplaceCollection>(from: self.CollectionStoragePath)
        let marketplaceCollection <- create MarketplaceCollection()
        self.account.save(<-marketplaceCollection, to: self.CollectionStoragePath)

        destroy self.account.load<@LeofyMarketPlaceAdmin>(from: self.AdminStoragePath)
        // Put the Admin in storage
        self.account.save<@LeofyMarketPlaceAdmin>(<- create LeofyMarketPlaceAdmin(), to: self.AdminStoragePath)

        // create a public capability for the collection
        self.account.link<&LeofyMarketPlace.MarketplaceCollection{LeofyMarketPlace.MarketplaceCollectionPublic}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )
    }   
}
 