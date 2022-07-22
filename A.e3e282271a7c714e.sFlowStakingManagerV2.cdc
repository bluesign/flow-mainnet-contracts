// import sFlowToken from "./sFlowToken.cdc"

// Testnet
// import FungibleToken from 0x9a0766d93b6608b7
// import FlowToken from 0x7e60df042a9c0868
// import FlowStakingCollection from 0x95e019a17d0e23d7
// import FlowIDTableStaking from 0x9eca2b38b18b5dfe

// Mainnet
import sFlowToken from 0xe3e282271a7c714e
import FungibleToken from 0xf233dcee88fe0abe
import FlowToken from 0x1654653399040a61
import FlowStakingCollection from 0x8d0e87b65159ae63
import FlowIDTableStaking from 0x8624b52f9ddcd04a

pub contract sFlowStakingManagerV2 {
	access(contract) var unstakeRequests: [{String: AnyStruct}]
	access(contract) var poolFee: UFix64
	access(contract) var nodeID: String
	access(contract) var delegatorID: UInt32
	access(contract) var prevNodeID: String
	access(contract) var prevDelegatorID: UInt32

	// getters
	pub fun getPoolFee(): UFix64 {
		return sFlowStakingManagerV2.poolFee
	}

	pub fun getNodeId(): String {
		return sFlowStakingManagerV2.nodeID
	}

	pub fun getDelegatorId(): UInt32 {
		return self.delegatorID
	}

	pub fun getPrevNodeId(): String {
		return self.prevNodeID
	}

	pub fun getPrevDelegatorId(): UInt32 {
		return self.prevDelegatorID
	}

	pub fun getUnstakeRequests(): [{String: AnyStruct}] {
		return self.unstakeRequests
	}

	pub fun isStakingEnabled(): Bool {
		return FlowIDTableStaking.stakingEnabled()
	}

	// This returns flow that is not yet delegated (aka the balance of the account)
	pub fun getAccountFlowBalance(): UFix64 {
		let vaultRef = self.account
            .getCapability(/public/flowTokenBalance)
            .borrow<&FlowToken.Vault{FungibleToken.Balance}>()
            ?? panic("Could not borrow Balance reference to the Vault")
    
        return vaultRef.balance
	}

	pub fun getDelegatorInfo(): FlowIDTableStaking.DelegatorInfo {
		let delegatingInfo = FlowStakingCollection.getAllDelegatorInfo(address: self.account.address);

		for info in delegatingInfo {
			 if (info.nodeID == self.nodeID && info.id == self.delegatorID){
                return info
            }
		}

		panic("No Delegating Information")
	}

	pub fun getsFlowPrice(): UFix64 {
		let undelegatedFlowBalance = self.getAccountFlowBalance()
		let delegatingInfo = FlowStakingCollection.getAllDelegatorInfo(address: self.account.address);

		var delegatedFlowBalance = 0.0

		for info in delegatingInfo {
			delegatedFlowBalance = delegatedFlowBalance +
				info.tokensCommitted +
				info.tokensStaked + 
				info.tokensUnstaking +
				info.tokensUnstaked +
				info.tokensRewarded
		}

		if (undelegatedFlowBalance + delegatedFlowBalance == 0.0) {
			return 1.0
		}

		if (sFlowToken.totalSupply == 0.0) {
			return 1.0
		}

		return (undelegatedFlowBalance + delegatedFlowBalance)/sFlowToken.totalSupply
	}

	pub fun stake(from: @FungibleToken.Vault): @sFlowToken.Vault {
		let vault <- from as! @FlowToken.Vault
        let sFlowPrice: UFix64 = self.getsFlowPrice()
        let amount: UFix64 = vault.balance / sFlowPrice

        let managerFlowVault =  self.account.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)  ?? panic("Could not borrow Manager's Flow Vault")
        managerFlowVault.deposit(from: <-vault)

		let stakingCollectionRef: &FlowStakingCollection.StakingCollection = self.account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath) ?? panic("Could not borrow ref to StakingCollection")
		stakingCollectionRef.stakeNewTokens(nodeID: self.nodeID, delegatorID: self.delegatorID, amount: (amount * sFlowPrice))

        let managerMinterVault =  self.account.borrow<&sFlowToken.Minter>(from: /storage/sFlowTokenMinter) ?? panic("Could not borrow Manager's Minter Vault")
        return <- managerMinterVault.mintTokens(amount: amount);
	}

	pub fun unstake(accountAddress: Address, from: @FungibleToken.Vault) {
		var withdrawableFlowAmount = 0.0
		let sFlowPrice = self.getsFlowPrice()
		let flowUnstakeAmount = from.balance * sFlowPrice
		let delegationInfo = self.getDelegatorInfo()
		let notAvailableForFastUnstake: Fix64 = Fix64(flowUnstakeAmount) - Fix64(delegationInfo.tokensCommitted)

		// Burn sFlow tokens
		// NOTE: I dont think we have to do this step?
		// let burningVault: @FungibleToken.Vault <- managersFlowTokenVault.withdraw(amount: from.balance)
		let managersFlowTokenBurnerVault =  self.account.borrow<&sFlowToken.Burner>(from: /storage/sFlowTokenBurner) ?? panic("Could not borrow provider reference to the provider's Vault")
		managersFlowTokenBurnerVault.burnTokens(from: <- from)

		
		if (delegationInfo.tokensCommitted >= 0.0) {
			var fastUnstakeAmount = 0.0

			if (delegationInfo.tokensCommitted > flowUnstakeAmount) {
				fastUnstakeAmount = flowUnstakeAmount
			} 

			if (delegationInfo.tokensCommitted < flowUnstakeAmount) {
				fastUnstakeAmount = delegationInfo.tokensCommitted
			}
		
			// First we unstake committed tokens
			let stakingCollectionRef: &FlowStakingCollection.StakingCollection = self.account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)  ?? panic("Could not borrow ref to StakingCollection")
			stakingCollectionRef.requestUnstaking(nodeID: self.nodeID, delegatorID: self.delegatorID, amount: fastUnstakeAmount)
			stakingCollectionRef.withdrawUnstakedTokens(nodeID: self.nodeID, delegatorID: self.delegatorID, amount: fastUnstakeAmount)

			let unstakerAccount = getAccount(accountAddress)
			let unstakerReceiverRef = unstakerAccount.getCapability(/public/flowTokenReceiver).borrow<&{FungibleToken.Receiver}>() ?? panic("Could not borrow receiver reference to recipient's Flow Vault")
			let managerProviderRef =  self.account.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault) ?? panic("Could not borrow provider reference to the provider's Vault")
			let	managerFlowVault: @FungibleToken.Vault <- managerProviderRef.withdraw(amount: fastUnstakeAmount)

			unstakerReceiverRef.deposit(from: <- managerFlowVault)
		}
		
		if (notAvailableForFastUnstake > 0.0) {
			self.unstakeRequests.append({"address": accountAddress, "amount": notAvailableForFastUnstake })
		
			let stakingCollectionRef: &FlowStakingCollection.StakingCollection = self.account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)  ?? panic("Could not borrow ref to StakingCollection")
			stakingCollectionRef.requestUnstaking(nodeID: self.nodeID, delegatorID: self.delegatorID, amount: UFix64(notAvailableForFastUnstake))
		}
	}

	pub fun updateStakingCollection() {
		let delegatorInfo = self.getDelegatorInfo()
		let stakingCollectionRef: &FlowStakingCollection.StakingCollection = self.account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath) ?? panic("Could not borrow ref to StakingCollection")



		stakingCollectionRef.stakeUnstakedTokens(nodeID: self.nodeID, delegatorID: self.delegatorID, amount: delegatorInfo.tokensUnstaked)
		stakingCollectionRef.stakeRewardedTokens(nodeID: self.nodeID, delegatorID: self.delegatorID, amount: delegatorInfo.tokensRewarded)
	}

	pub fun processUnstakeRequests() {
		let delegatorInfo = self.getDelegatorInfo()
		let stakingCollectionRef: &FlowStakingCollection.StakingCollection = self.account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath) ?? panic("Could not borrow ref to StakingCollection")

		if (delegatorInfo.tokensUnstaked > 0.0) {
			stakingCollectionRef.withdrawUnstakedTokens(nodeID: self.nodeID, delegatorID: self.delegatorID, amount: delegatorInfo.tokensUnstaked)
		}


		var index = 0
		for request in self.unstakeRequests {
			let tempAddress: AnyStruct = request["address"]!
			let accountAddress: Address = tempAddress as! Address
			let stakingAccount = getAccount(accountAddress)
			let tempAmount: AnyStruct = request["amount"]!
			let requestAmount: UFix64 = tempAmount as! UFix64

			let withdrawAmount = requestAmount * self.getsFlowPrice()

			let unstakerReceiverRef = stakingAccount.getCapability(/public/flowTokenReceiver).borrow<&{FungibleToken.Receiver}>() ?? panic("Could not borrow receiver reference to recipient's Flow Vault")
			let providerRef =  self.account.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault) ?? panic("Could not borrow provider reference to the provider's Vault")
			let managersFlowTokenVault =  self.account.borrow<&sFlowToken.Vault>(from: /storage/sFlowTokenVault) ?? panic("Could not borrow provider reference to the provider's Vault")
			let managersFlowTokenBurnerVault =  self.account.borrow<&sFlowToken.Burner>(from: /storage/sFlowTokenBurner) ?? panic("Could not borrow provider reference to the provider's Vault")

			let flowVault: @FungibleToken.Vault <- providerRef.withdraw(amount: withdrawAmount)
			let burnVault: @FungibleToken.Vault <- managersFlowTokenVault.withdraw(amount: withdrawAmount)

			unstakerReceiverRef.deposit(from: <- flowVault)
			managersFlowTokenBurnerVault.burnTokens(from: <- burnVault)

			self.unstakeRequests.remove(at: index)

			index = index + 1
		}

	}



	pub resource Manager {
        init() {
            
        }

        pub fun setNewDelegator(nodeID: String, delegatorID: UInt32){
            if(nodeID == sFlowStakingManagerV2.nodeID){
                panic("Node id is same")
            }

            sFlowStakingManagerV2.prevNodeID = sFlowStakingManagerV2.nodeID
            sFlowStakingManagerV2.prevDelegatorID = sFlowStakingManagerV2.delegatorID
            sFlowStakingManagerV2.nodeID = nodeID
            sFlowStakingManagerV2.delegatorID = delegatorID
        }

        pub fun setPoolFee(amount: UFix64){
            sFlowStakingManagerV2.poolFee = amount
        }

        pub fun registerNewDelegator(id: String, amount: UFix64){
            let stakingCollectionRef: &FlowStakingCollection.StakingCollection = sFlowStakingManagerV2.account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
                ?? panic("Could not borrow ref to StakingCollection")
            stakingCollectionRef.registerDelegator(nodeID: id, amount: amount)
        }

        pub fun unstakeAll(nodeId: String, delegatorId: UInt32){
            let delegatingInfo = FlowStakingCollection.getAllDelegatorInfo(address: sFlowStakingManagerV2.account.address);
            if delegatingInfo.length == 0 {
                panic("No Delegating Information")
            }
            for info in delegatingInfo {
                if (info.nodeID == nodeId && info.id == delegatorId){
                    let stakingCollectionRef: &FlowStakingCollection.StakingCollection = sFlowStakingManagerV2.account.borrow<&FlowStakingCollection.StakingCollection>(from: FlowStakingCollection.StakingCollectionStoragePath)
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




	init(nodeID: String, delegatorID: UInt32) {
        self.unstakeRequests = []
        self.poolFee = 0.0
        self.nodeID = nodeID
        self.delegatorID = delegatorID
        self.prevNodeID = ""
        self.prevDelegatorID = 0

        /// create a single admin collection and store it
        self.account.save(<-create Manager(), to: /storage/sFlowStakingManagerV2)
        
        self.account.link<&sFlowStakingManagerV2.Manager>(
            /private/sFlowStakingManagerV2,
            target: /storage/sFlowStakingManagerV2
        ) ?? panic("Could not get a capability to the manager")

    }



}