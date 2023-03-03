import sFlowToken from 0xe3e282271a7c714e
import FungibleToken from 0xf233dcee88fe0abe
import FlowToken from 0x1654653399040a61
import FlowStakingCollection from 0x8d0e87b65159ae63
import FlowIDTableStaking from 0x8624b52f9ddcd04a

pub contract sFlowStakingManager {

    /// Unstaking Request List
    access(contract) var unstakeList: [{String: AnyStruct}]
    access(contract) var minimumPoolTaking: UFix64
    access(contract) var nodeID: String
    access(contract) var delegatorID: UInt32
    access(contract) var prevNodeID: String
    access(contract) var prevDelegatorID: UInt32

  

    pub fun getCurrentUnstakeAmount(userAddress: Address) : UFix64 {
        var requestedUnstakeAmount:UFix64 = 0.0
        for unstakeTicket in sFlowStakingManager.unstakeList {
            let tempAddress : AnyStruct = unstakeTicket["address"]!
            let accountAddress : Address = tempAddress as! Address
            let accountStaker = getAccount(accountAddress)
            let tempAmount : AnyStruct = unstakeTicket["amount"]!
            let amount : UFix64 = tempAmount as! UFix64

            if(userAddress == accountAddress){
                requestedUnstakeAmount = requestedUnstakeAmount + amount
            }
        }
        return requestedUnstakeAmount
    }

    pub fun getCurrentPoolAmount() : UFix64{
        let vaultRef = self.account
            .getCapability(/public/flowTokenBalance)
            .borrow<&FlowToken.Vault{FungibleToken.Balance}>()
            ?? panic("Could not borrow Balance reference to the Vault")
    
        return vaultRef.balance
    }

    pub fun getDelegatorInfo() : FlowIDTableStaking.DelegatorInfo{
        let delegatingInfo = FlowStakingCollection.getAllDelegatorInfo(address: self.account.address);
        if delegatingInfo.length == 0 {
            panic("No Delegating Information")
        }
        for info in delegatingInfo {
            if (info.nodeID == self.nodeID && info.id == self.delegatorID){
                return info
            }
        }
        panic("No Delegating Information")
    }

    pub fun getPrevDelegatorInfo() : FlowIDTableStaking.DelegatorInfo{
        if(self.prevNodeID == "") {
            panic("No Prev Delegating Information")
        }

        let delegatingInfo = FlowStakingCollection.getAllDelegatorInfo(address: self.account.address);
        if delegatingInfo.length == 0 {
            panic("No Prev Delegating Information")
        }
        for info in delegatingInfo {
            if (info.nodeID == self.prevNodeID && info.id == self.prevDelegatorID)
            {
                return info
            }
        }
        panic("No Prev Delegating Information")
    }

    pub fun getCurrentPrice() : UFix64{
        let amountInPool = self.getCurrentPoolAmount()

        var amountInStaking = 0.0

        let delegatingInfo = FlowStakingCollection.getAllDelegatorInfo(address: self.account.address);

        for info in delegatingInfo {
            amountInStaking = amountInStaking + 
                info.tokensCommitted +
                info.tokensStaked +
                info.tokensUnstaking +
                info.tokensRewarded +
                info.tokensUnstaked
        }

        if((amountInPool + amountInStaking) == 0.0 || sFlowToken.totalSupply == 0.0){
            return 1.0
        }
        return (amountInPool + amountInStaking)/sFlowToken.totalSupply
    }

    pub fun stake(from: @FungibleToken.Vault) : @sFlowToken.Vault {
        let vault <- from as! @FlowToken.Vault
        let currentPrice: UFix64 = self.getCurrentPrice()
        let amount: UFix64 = vault.balance / currentPrice

        let managerFlowVault =  self.account.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow Manager's Flow Vault")
        managerFlowVault.deposit(from: <-vault)

        let managerMinterVault =  self.account.borrow<&sFlowToken.Minter>(from: /storage/sFlowTokenMinter)
            ?? panic("Could not borrow Manager's Minter Vault")
        return <- managerMinterVault.mintTokens(amount: amount);
    }

    pub fun unstake(accountAddress: Address, from: @FungibleToken.Vault) {
        self.unstakeList.append({"address": accountAddress, "amount": from.balance});
        let managersFlowTokenVault =  self.account
            .borrow<&sFlowToken.Vault>(from: /storage/sFlowTokenVault)
            ?? panic("Could not borrow Manager's Minter Vault")
        managersFlowTokenVault.deposit(from: <-from)
    }

    pub fun createInstance() : @Instance {
        return <- create Instance()
    }

    pub resource interface InstanceInterface {
        pub fun setCapability(cap: Capability<&Manager>)
        pub fun setNewDelegator(nodeID: String, delegatorID: UInt32)
        pub fun setMinimumPoolTaking(amount: UFix64)
        pub fun registerNewDelegator(id: String, amount: UFix64)
        pub fun unstakeAll(nodeId: String, delegatorId: UInt32)
    }

    pub resource Instance : InstanceInterface {
        access(self) var managerCapability: Capability<&Manager>?
        
        init() {
            self.managerCapability = nil
        }

        pub fun setCapability(cap: Capability<&Manager>) {
            pre {
                cap.borrow() != nil: "Invalid manager capability"
            }
            self.managerCapability = cap
        }

        pub fun setNewDelegator(nodeID: String, delegatorID: UInt32){
            pre {
                self.managerCapability != nil: 
                    "Cannot manage staking until the manger capability not set"
            }
            
            let managerRef = self.managerCapability!.borrow()!

            managerRef.setNewDelegator(nodeID: nodeID, delegatorID: delegatorID)
        }

        pub fun setMinimumPoolTaking(amount: UFix64){
            pre {
                self.managerCapability != nil: 
                    "Cannot manage staking until the manger capability not set"
            }
            
            let managerRef = self.managerCapability!.borrow()!

            managerRef.setMinimumPoolTaking(amount: amount)
        }

        pub fun registerNewDelegator(id: String, amount: UFix64){
            pre {
                self.managerCapability != nil: 
                    "Cannot manage staking until the manger capability not set"
            }
            
            let managerRef = self.managerCapability!.borrow()!
            managerRef.registerNewDelegator(id: id, amount: amount)
        }

        pub fun unstakeAll(nodeId: String, delegatorId: UInt32){
            pre {
                self.managerCapability != nil: 
                    "Cannot manage staking until the manger capability not set"
            }
            
            let managerRef = self.managerCapability!.borrow()!
            managerRef.unstakeAll(nodeId: nodeId, delegatorId: delegatorId)
        }
    }

    pub resource Manager {
        init() {
            
        }

        pub fun setNewDelegator(nodeID: String, delegatorID: UInt32){
            if(nodeID == sFlowStakingManager.nodeID){
                panic("Node id is same")
            }

            sFlowStakingManager.prevNodeID = sFlowStakingManager.nodeID
            sFlowStakingManager.prevDelegatorID = sFlowStakingManager.delegatorID
            sFlowStakingManager.nodeID = nodeID
            sFlowStakingManager.delegatorID = delegatorID
        }

        pub fun setMinimumPoolTaking(amount: UFix64){
            sFlowStakingManager.minimumPoolTaking = amount
        }

        pub fun registerNewDelegator(id: String, amount: UFix64){
            let stakingCollectionRef: &FlowStakingCollection.StakingCollection = sFlowStakingManager.account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
                ?? panic("Could not borrow ref to StakingCollection")
            stakingCollectionRef.registerDelegator(nodeID: id, amount: amount)
        }

        pub fun unstakeAll(nodeId: String, delegatorId: UInt32){
            let delegatingInfo = FlowStakingCollection.getAllDelegatorInfo(address: sFlowStakingManager.account.address);
            if delegatingInfo.length == 0 {
                panic("No Delegating Information")
            }
            for info in delegatingInfo {
                if (info.nodeID == nodeId && info.id == delegatorId){
                    let stakingCollectionRef: &FlowStakingCollection.StakingCollection = sFlowStakingManager.account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
                        ?? panic("Could not borrow ref to StakingCollection")
                    if(info.tokensCommitted > 0.0 || info.tokensStaked > 0.0){
                        stakingCollectionRef.requestUnstaking(nodeID: nodeId, delegatorID: delegatorId, amount: info.tokensCommitted + info.tokensStaked)
                    }
                    if(info.tokensRewarded > 0.0){
                        stakingCollectionRef.withdrawRewardedTokens(nodeID: nodeId, delegatorID: delegatorId, amount: info.tokensRewarded)
                    }
                    if(info.tokensUnstaked > 0.0){
                        stakingCollectionRef.withdrawUnstakedTokens(nodeID: nodeId, delegatorID: delegatorId, amount: info.tokensUnstaked)
                    }
                }
            }
        }
    }


    pub fun manageCollection(){
        log("starting manageCollection()")

        let accountStorageAmount = 0.001

        var requiredStakedAmount:UFix64 = 0.0
        var index = 0
        for unstakeTicket in sFlowStakingManager.unstakeList {
            let tempAddress : AnyStruct = unstakeTicket["address"]!
            let accountAddress : Address = tempAddress as! Address
            let accountStaker = getAccount(accountAddress)
            let tempAmount : AnyStruct = unstakeTicket["amount"]!
            let amount : UFix64 = tempAmount as! UFix64

            let requiredFlow = amount * sFlowStakingManager.getCurrentPrice();
            if (sFlowStakingManager.getCurrentPoolAmount() > requiredFlow + sFlowStakingManager.minimumPoolTaking)
            {
                let providerRef =  sFlowStakingManager.account
                    .borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
                    ?? panic("Could not borrow provider reference to the provider's Vault")

                // Deposit the withdrawn tokens in the provider's receiver
                let sentVault: @FungibleToken.Vault <- providerRef.withdraw(amount: requiredFlow)

                let receiverRef =  accountStaker
                    .getCapability(/public/flowTokenReceiver)
                    .borrow<&{FungibleToken.Receiver}>()
                    ?? panic("Could not borrow receiver reference to the recipient's Vault")
                receiverRef.deposit(from: <-sentVault)

                let managersFlowTokenVault =  sFlowStakingManager.account
                    .borrow<&sFlowToken.Vault>(from: /storage/sFlowTokenVault)
                    ?? panic("Could not borrow provider reference to the provider's Vault")

                // Deposit the withdrawn tokens in the provider's receiver
                let burningVault: @FungibleToken.Vault <- managersFlowTokenVault.withdraw(amount: amount)

                let managersFlowTokenBurnerVault =  sFlowStakingManager.account
                    .borrow<&sFlowToken.Burner>(from: /storage/sFlowTokenBurner)
                    ?? panic("Could not borrow provider reference to the provider's Vault")

                managersFlowTokenBurnerVault.burnTokens(from: <- burningVault)

                sFlowStakingManager.unstakeList.remove(at: index)
                continue
            }
            requiredStakedAmount = requiredStakedAmount + requiredFlow
            index = index + 1
        }


        var bStakeNew : Bool = true

        log("required stake amount: ")
        log(requiredStakedAmount)

        if( requiredStakedAmount > 0.0 ){
            requiredStakedAmount = requiredStakedAmount + sFlowStakingManager.minimumPoolTaking + accountStorageAmount - sFlowStakingManager.getCurrentPoolAmount()
            let delegatingInfo = sFlowStakingManager.getDelegatorInfo()
            if( delegatingInfo.tokensUnstaked > 0.0 ) {
                let stakingCollectionRef: &FlowStakingCollection.StakingCollection = sFlowStakingManager.account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
                    ?? panic("Could not borrow ref to StakingCollection")
                var amount: UFix64 = 0.0
                if(delegatingInfo.tokensUnstaked >= requiredStakedAmount)
                {
                    amount = requiredStakedAmount                    
                } else {
                    amount = delegatingInfo.tokensUnstaked
                }
                stakingCollectionRef.withdrawUnstakedTokens(nodeID: sFlowStakingManager.nodeID, delegatorID: sFlowStakingManager.delegatorID, amount: amount)
                requiredStakedAmount = requiredStakedAmount - amount
                bStakeNew = false
            }
        }


        log("required stake amount: ")
        log(requiredStakedAmount)

        if( requiredStakedAmount > 0.0 ){
            let delegatingInfo = sFlowStakingManager.getDelegatorInfo()
            if( delegatingInfo.tokensRewarded > 0.0 ) {
                let stakingCollectionRef: &FlowStakingCollection.StakingCollection = sFlowStakingManager.account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
                    ?? panic("Could not borrow ref to StakingCollection")
                var amount: UFix64 = 0.0
                if(delegatingInfo.tokensRewarded >= requiredStakedAmount)
                {
                    amount = requiredStakedAmount                    
                } else {
                    amount = delegatingInfo.tokensRewarded
                }
                stakingCollectionRef.withdrawRewardedTokens(nodeID: sFlowStakingManager.nodeID, delegatorID: sFlowStakingManager.delegatorID, amount: amount)
                requiredStakedAmount = requiredStakedAmount - amount
                bStakeNew = false
            }
        }

        log("required stake amount: ")
        log(requiredStakedAmount)

        if( requiredStakedAmount > 0.0 ){
            let delegatingInfo = sFlowStakingManager.getDelegatorInfo()
            if( delegatingInfo.tokensCommitted > 0.0 ) {
                let stakingCollectionRef: &FlowStakingCollection.StakingCollection = sFlowStakingManager.account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
                    ?? panic("Could not borrow ref to StakingCollection")
                var amount: UFix64 = 0.0
                if(delegatingInfo.tokensCommitted >= requiredStakedAmount)
                {
                    amount = requiredStakedAmount                    
                } else {
                    amount = delegatingInfo.tokensCommitted
                }
                stakingCollectionRef.requestUnstaking(nodeID: sFlowStakingManager.nodeID, delegatorID: sFlowStakingManager.delegatorID, amount: amount)
                requiredStakedAmount = requiredStakedAmount - amount
                bStakeNew = false
            }
        }


        log("required stake amount: ")
        log(requiredStakedAmount)

        if( requiredStakedAmount > 0.0 ){
            let delegatingInfo = sFlowStakingManager.getDelegatorInfo()
            if(delegatingInfo.tokensUnstaking + delegatingInfo.tokensRequestedToUnstake < requiredStakedAmount){
                let amount: UFix64 = requiredStakedAmount - delegatingInfo.tokensUnstaking - delegatingInfo.tokensRequestedToUnstake

                let stakingCollectionRef: &FlowStakingCollection.StakingCollection = sFlowStakingManager.account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
                    ?? panic("Could not borrow ref to StakingCollection")
                stakingCollectionRef.requestUnstaking(nodeID: sFlowStakingManager.nodeID, delegatorID: sFlowStakingManager.delegatorID, amount: amount)
                bStakeNew = false
            }
        }


        log("required stake amount: ")
        log(requiredStakedAmount)

        if( requiredStakedAmount == 0.0 && bStakeNew && FlowIDTableStaking.stakingEnabled() ){
            let delegatingInfo = sFlowStakingManager.getDelegatorInfo()
            let stakingCollectionRef: &FlowStakingCollection.StakingCollection = sFlowStakingManager.account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
                ?? panic("Could not borrow ref to StakingCollection")
            stakingCollectionRef.stakeUnstakedTokens(nodeID: sFlowStakingManager.nodeID, delegatorID: sFlowStakingManager.delegatorID, amount: delegatingInfo.tokensUnstaked)
            stakingCollectionRef.stakeRewardedTokens(nodeID: sFlowStakingManager.nodeID, delegatorID: sFlowStakingManager.delegatorID, amount: delegatingInfo.tokensRewarded)

            if(sFlowStakingManager.getCurrentPoolAmount() > sFlowStakingManager.minimumPoolTaking){
                stakingCollectionRef.stakeNewTokens(nodeID: sFlowStakingManager.nodeID, delegatorID: sFlowStakingManager.delegatorID, amount: (sFlowStakingManager.getCurrentPoolAmount() - sFlowStakingManager.minimumPoolTaking - accountStorageAmount))
            }
        }

        if(sFlowStakingManager.prevNodeID != ""  && FlowIDTableStaking.stakingEnabled()) {
            let delegatingInfo = sFlowStakingManager.getPrevDelegatorInfo()
            let stakingCollectionRef: &FlowStakingCollection.StakingCollection = sFlowStakingManager.account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
                ?? panic("Could not borrow ref to StakingCollection")
            if(delegatingInfo.tokensCommitted > 0.0 || delegatingInfo.tokensStaked > 0.0){
                stakingCollectionRef.requestUnstaking(nodeID: sFlowStakingManager.prevNodeID, delegatorID: sFlowStakingManager.prevDelegatorID, amount: delegatingInfo.tokensCommitted + delegatingInfo.tokensStaked)
            }
            if(delegatingInfo.tokensRewarded > 0.0){
                stakingCollectionRef.withdrawRewardedTokens(nodeID: sFlowStakingManager.prevNodeID, delegatorID: sFlowStakingManager.prevDelegatorID, amount: delegatingInfo.tokensRewarded)
            }
            if(delegatingInfo.tokensUnstaked > 0.0){
                stakingCollectionRef.withdrawUnstakedTokens(nodeID: sFlowStakingManager.prevNodeID, delegatorID: sFlowStakingManager.prevDelegatorID, amount: delegatingInfo.tokensUnstaked)
            }
            if(delegatingInfo.tokensCommitted == 0.0 &&
            delegatingInfo.tokensStaked == 0.0 &&
            delegatingInfo.tokensUnstaking == 0.0 &&
            delegatingInfo.tokensRewarded == 0.0 &&
            delegatingInfo.tokensUnstaked == 0.0) {
                sFlowStakingManager.prevNodeID = ""
                sFlowStakingManager.prevDelegatorID = 0
            }
        }
    }

    init(nodeID: String, delegatorID: UInt32) {
        self.unstakeList = []

                /// create a single admin collection and store it
        self.account.save(<-create Manager(), to: /storage/sFlowStakingManager)
        
        self.account.link<&sFlowStakingManager.Manager>(
            /private/sFlowStakingManager,
            target: /storage/sFlowStakingManager
        ) ?? panic("Could not get a capability to the manager")

        self.minimumPoolTaking = 0.0
        self.nodeID = nodeID
        self.delegatorID = delegatorID
        self.prevNodeID = ""
        self.prevDelegatorID = 0
    }
}