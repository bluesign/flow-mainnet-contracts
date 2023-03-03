import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import ByteNextMedalNFT from 0x3b16cb9f5c036412

pub contract ByteNextStaking {

  access(contract) let stageStaking: @{UInt64: StageStaking}

  pub var stakingCount: UInt64;

  pub let AdminStoragePath: StoragePath;
  pub let StakingProxyStoragePath: StoragePath;

  pub event Deposit(stageId: UInt64, orderId: UInt64, user: Address?, amount: UFix64, nftBootId: UInt64?, metadata: {String: String}?, time: UFix64);
  pub event Withdraw(stageId: UInt64, orderId: UInt64, user: Address?, amount: UFix64, rewardAmount: UFix64?, fee: UFix64, time: UFix64);
  pub event WithdrawReward(stageId: UInt64, user: Address?, rewardAmount: UFix64, time: UFix64);
  pub event WithdrawRewardByOrder(stageId: UInt64, user: Address?, orderId: Integer, rewardAmount: UFix64, time: UFix64);
  pub event CreateNewStage(stageId: UInt64, startTime: UFix64, endTime: UFix64, minAmount: UFix64, duration: UFix64, annualProfit: UFix64);

  pub struct StakingOrder {
    access(contract) var id: UInt64;
    access(contract) var amount: UFix64;
    access(contract) var nftBoostId: UInt64?;
    access(contract) var stakedAt: UFix64;
    access(contract) var rewardDebt: UFix64;
    access(contract) var isUnstake: Bool;
    access(contract) var rewardClaimed: UFix64;
    access(contract) var lastEarnedTime: UFix64;

    init(id: UInt64, amount: UFix64, tokenId: UInt64?) {
      self.id = id;
      self.amount = amount;
      self.nftBoostId = tokenId;
      self.rewardDebt = 0.0;
      self.isUnstake = false;
      self.stakedAt = getCurrentBlock().timestamp;
      self.rewardClaimed = 0.0;
      self.lastEarnedTime = getCurrentBlock().timestamp;
    }

    access(contract) fun setRewardClaimed(amount: UFix64, newTime: UFix64) {
      self.rewardClaimed = self.rewardClaimed + amount;
      self.lastEarnedTime = newTime;
    }

    access(contract) fun setRewardDebt(reward: UFix64, timeEarned: UFix64) {
      self.rewardDebt = reward;
      self.lastEarnedTime = timeEarned;
    }

    access(contract) fun setUnstake() {
      self.isUnstake = true;
    }
  }

  pub resource interface StageStakingPublic {
    pub fun getRewardsPendding(user: Address): UFix64;
    pub fun getUserOrders(user: Address): [StakingOrder];
    pub fun getUserStakedAmount(user: Address): UFix64;
    pub fun getStakingInfo():  {String: AnyStruct};
  }

  pub resource StageStaking: StageStakingPublic {
    access(contract) var id: UInt64;
    access(contract) var isFrozen: Bool;
    access(contract) var minAmount: UFix64;
    access(contract) var startTime: UFix64;
    access(contract) var endTime: UFix64;
    access(contract) var duration: UFix64;
    access(contract) var annualProfit: UFix64;
    access(contract) var unstakeFee: UFix64;

    access(contract) var totalOrder: UInt64;
    access(contract) let stakers: {Address: [StakingOrder]};
    access(contract) let userStakedAmount: {Address: UFix64}
    access(contract) let nftBoosts: @{UInt64: ByteNextMedalNFT.NFT}
    access(contract) let stakeVault: @FungibleToken.Vault;
    access(contract) let rewardVault: @FungibleToken.Vault;
    access(contract) var receiverFeeUnstake: Capability<&{FungibleToken.Receiver}>?;

    init(
      id: UInt64, startTime: UFix64, endTime: UFix64, minAmount: UFix64, duration: UFix64, annualProfit: UFix64, unstakeFee: UFix64,
      stakeVault: @FungibleToken.Vault, rewardVault: @FungibleToken.Vault
    ) {
      pre {
        startTime >= getCurrentBlock().timestamp: "Start time should be less than current time"
        startTime < endTime: "Start time must be less than end time"
      }
      self.id = id;
      self.isFrozen = false;
      self.startTime = startTime;
      self.endTime = endTime;
      self.minAmount = minAmount;
      self.duration = duration;
      self.annualProfit = annualProfit;
      self.unstakeFee = unstakeFee;

      self.totalOrder = 0;
      self.stakers = {};
      self.userStakedAmount = {}
      self.nftBoosts <- {};
      self.stakeVault <- stakeVault;
      self.rewardVault <- rewardVault;
      self.receiverFeeUnstake = nil;
    }

    destroy() {
      destroy self.nftBoosts;
      destroy self.stakeVault;
      destroy self.rewardVault;
    }

    access(contract) fun setFrozen(isFrozen: Bool) {
      if self.startTime < getCurrentBlock().timestamp && isFrozen {
        self._updateRewardCurrent();
      }
      self.isFrozen = isFrozen
    }

    access(contract) fun setReceiverFeeUnstake(capability: Capability<&{FungibleToken.Receiver}>) {
      pre {
        capability.check(): "Recipient fee unstake invalid"
        self.stakeVault.getType() == capability.borrow()!.getType(): "Should you same type of fund to return"
      }
      self.receiverFeeUnstake = capability;
    }

    access(contract) fun setStageInfo(startTime: UFix64, endTime: UFix64, minAmount: UFix64, duration: UFix64, annualProfit: UFix64, unstakeFee: UFix64) {
      pre {
        startTime < endTime: "Start time must be less than end time"
        endTime > getCurrentBlock().timestamp : "End Time must be greater than current time"
      }
      let currentTime = getCurrentBlock().timestamp;
      // pool launched
      if self.startTime < currentTime {
        assert(startTime == self.startTime, message: "not allow update start time")
        // save data reward current for stakers before update
        if self.duration != duration || self.annualProfit != annualProfit {
          self._updateRewardCurrent()
        }
      }
      self.startTime = startTime;
      self.endTime = endTime;
      self.minAmount = minAmount;
      self.duration = duration;
      self.annualProfit = annualProfit;
      self.unstakeFee = unstakeFee;
    }

    access(self) fun _updateRewardCurrent() {
      for user in self.stakers.keys {
        let orders = self.stakers[user]!
        var index: UInt64 = 0;
        for order in orders {
          if !order.isUnstake {
            let reward = self._calculateInterestOrder(order: order);
            if reward["rewardPending"]! > 0.0 {
              order.setRewardDebt(reward: reward["rewardPending"]!, timeEarned: reward["interestTime"]!)
              self.stakers[user]!.remove(at: index);
              self.stakers[user]!.insert(at: index, order);
            }
          }
          index = index + 1;
        }
      }
    }

    access(contract) fun stakeBoost(user: Address, vault: @FungibleToken.Vault, nftBoost: @ByteNextMedalNFT.NFT) {
      pre {
        !self.isFrozen: "Stage is frozen"
        self.startTime <= getCurrentBlock().timestamp: "Stage staking has not started"
        self.endTime > getCurrentBlock().timestamp: "Stage staking has ended"
        self.minAmount <= vault.balance: "Amount stake is invalid"
        self.stakeVault.getType() == vault.getType(): "Type vault deposit is invalid"
      }

      let vaultBalance = vault.balance;
      self.stakeVault.deposit(from: <- vault);
      self.totalOrder = self.totalOrder + 1;

      let orderId = self.totalOrder;

      let tokenId = nftBoost.id
      let metadata = nftBoost.getMetadata();

      let old <- self.nftBoosts[tokenId] <- nftBoost
      assert(old == nil, message: "Should never panic this")
      destroy old

      let order = StakingOrder(id: orderId, amount: vaultBalance, tokenId: tokenId);

      if self.stakers[user] == nil {
        self.stakers.insert(key: user, [order])
      } else {
        self.stakers[user]!.append(order)
      }

      self.userStakedAmount[user] = (self.userStakedAmount[user] ?? 0.0) + vaultBalance;
      emit Deposit(stageId: self.id, orderId: orderId, user: user, amount: vaultBalance, nftBootId: tokenId, metadata: metadata, time: getCurrentBlock().timestamp)
    }

    access(contract) fun stake(user: Address, vault: @FungibleToken.Vault) {
      pre {
        !self.isFrozen: "Stage is frozen"
        self.startTime <= getCurrentBlock().timestamp: "Stage staking has not started"
        self.endTime > getCurrentBlock().timestamp: "Stage staking has ended"
        self.minAmount <= vault.balance: "Amount stake is invalid"
        self.stakeVault.getType() == vault.getType(): "Type vault deposit is invalid"
      }

      let vaultBalance = vault.balance;
      self.stakeVault.deposit(from: <- vault);
      self.totalOrder = self.totalOrder + 1;

      let orderId = self.totalOrder;
      let order = StakingOrder(id: orderId, amount: vaultBalance, tokenId: nil);

      if self.stakers[user] == nil {
        self.stakers.insert(key: user, [order])
      } else {
        self.stakers[user]!.append(order)
      }

      self.userStakedAmount[user] = (self.userStakedAmount[user] ?? 0.0) + vaultBalance;
      emit Deposit(stageId: self.id, orderId: orderId, user: user, amount: vaultBalance, nftBootId: nil, metadata: nil, time: getCurrentBlock().timestamp)
    }

    access(contract) fun withdrawRewards(receiver: Capability<&{FungibleToken.Receiver}>) {
      pre {
        self.stakers.containsKey(receiver.address): "User not found in list of staking"
        receiver.check(): "Recipient ref invalid"
        self.rewardVault.getType() == receiver.borrow()!.getType(): "Should type receiver same type of reward"
      }
      let user = receiver.address;
      let orders = self.stakers[user]!;
      var totalPending: UFix64 = 0.0;
      var index = 0;
      for order in orders {
        let reward = self._calculateInterestOrder(order: order)
        if reward["rewardPending"]! > 0.0 {
          totalPending = totalPending + reward["rewardPending"]!;
          order.setRewardClaimed(amount: reward["rewardPending"]!, newTime: reward["interestTime"]!);

          self.stakers[user]!.remove(at: index);
          self.stakers[user]!.insert(at: index, order);
        }
        index = index + 1;
      }
      if totalPending > 0.0 {
        receiver.borrow()!.deposit(from: <- self.rewardVault.withdraw(amount: totalPending))
        emit WithdrawReward(stageId: self.id, user: user, rewardAmount: totalPending, time: getCurrentBlock().timestamp)
      }
    }

    access(contract) fun withdrawRewardByOrder(orderId: UInt64, receiverReward: Capability<&{FungibleToken.Receiver}>) {
      pre {
        self.stakers.containsKey(receiverReward.address): "User not found in list of staking"
        receiverReward.check(): "Recipient reward ref invalid"
        self.rewardVault.getType() == receiverReward.borrow()!.getType(): "Should type receiver reward same type of reward"
      }
      let user = receiverReward.address;

      let orders = self.stakers[user]!;
      var orderIndex: Integer = -1;
      var index: UInt64 = 0;
      for order in orders {
        if (order.id == orderId) {
          orderIndex = index;
          break;
        }
        index = index + 1;
      }
      assert(orderIndex != -1, message: "Not found order")
      let order = self.stakers[user]![orderIndex]
      assert(!order.isUnstake, message: "Order has been unstaked");

      let reward = self._calculateInterestOrder(order: order);
      if reward["rewardPending"]! <= 0.0 {
        return;
      }
      receiverReward.borrow()!.deposit(from: <- self.rewardVault.withdraw(amount: reward["rewardPending"]!))
      order.setRewardClaimed(amount: reward["rewardPending"]!, newTime: reward["interestTime"]!);

      self.stakers[user]!.remove(at: orderIndex);
      self.stakers[user]!.insert(at: orderIndex, order);
      
      emit WithdrawRewardByOrder(stageId: self.id, user: user, orderId: orderIndex, rewardAmount: reward["rewardPending"]!, time: getCurrentBlock().timestamp)
    }

    access(contract) fun withdrawByOrder(
      orderId: UInt64,
      receiverReward: Capability<&{FungibleToken.Receiver}>, receiverStaking: Capability<&{FungibleToken.Receiver}>,
      receiverNftBoost: Capability<&{ByteNextMedalNFT.CollectionPublic}>
    ) {
      pre {
        receiverReward.check(): "Recipient reward ref invalid"
        receiverStaking.check(): "Recipient reward ref invalid"
        receiverNftBoost.check(): "Recipient nft boost ref invalid"
        self.rewardVault.getType() == receiverReward.borrow()!.getType(): "Should type receiver reward same type of reward"
        self.stakeVault.getType() == receiverStaking.borrow()!.getType(): "Should type receiver staking same type of staking"
        receiverReward.address == receiverStaking.address: "The addresses must be the same"
        receiverStaking.address == receiverNftBoost.address: "The addresses must be the same"
        self.stakers.containsKey(receiverStaking.address): "User not found in list of staking"
      }
      let user = receiverStaking.address

      let orders = self.stakers[user]!;
      var orderIndex: Integer = -1;
      var index: UInt64 = 0;
      for order in orders {
        if (order.id == orderId) {
          orderIndex = index;
          break;
        }
        index = index + 1;
      }
      assert(orderIndex != -1, message: "Not found order")
      let order = self.stakers[user]![orderIndex]
      assert(!order.isUnstake, message: "Order has been unstaked");

      let expiryTime = order.stakedAt + self.duration > self.endTime ? self.endTime : order.stakedAt + self.duration;
      assert(getCurrentBlock().timestamp >= expiryTime, message: "Withdrawal due date has not been reached")

      let reward = self._calculateInterestOrder(order: order);
      if reward["rewardPending"]! > 0.0 {
        receiverReward.borrow()!.deposit(from: <- self.rewardVault.withdraw(amount: reward["rewardPending"]!))
        order.setRewardClaimed(amount: reward["rewardPending"]!, newTime: reward["interestTime"]!);
      }

      var unstakeFee = 0.0
      if self.unstakeFee > 0.0 {
        unstakeFee = order.amount * self.unstakeFee / 100.0;
        // transfer token fee unstake
        self.receiverFeeUnstake!.borrow()!.deposit(from: <- self.stakeVault.withdraw(amount: unstakeFee))
      }
      // transfer token for owner order
      receiverStaking.borrow()!.deposit(from: <- self.stakeVault.withdraw(amount: order.amount - unstakeFee))

      // transfer nft boost locked
      if (order.nftBoostId != nil) {
        let nft <- self.nftBoosts.remove(key: order.nftBoostId ?? 0)!
        receiverNftBoost.borrow()!.deposit(token: <- nft)
      }

      order.setUnstake();
      self.stakers[user]!.remove(at: orderIndex);
      self.stakers[user]!.insert(at: orderIndex, order);

      self.userStakedAmount[user] = self.userStakedAmount[user]! - order.amount;

      emit Withdraw(stageId: self.id, orderId: orderId, user: user, amount: order.amount, rewardAmount: reward["rewardPending"]!, fee: unstakeFee, time: getCurrentBlock().timestamp)
    }

    access(self) fun _calculateInterestOrder(order: StakingOrder): {String: UFix64} {
      if order.isUnstake {
      return {
          "interestTime": 0.0,
          "rewardPending": 0.0
        }
      }
      var rewardPending = order.rewardDebt;
      let currentTime = getCurrentBlock().timestamp;
      let expiryTime = order.stakedAt + self.duration > self.endTime ? self.endTime : order.stakedAt + self.duration;
      
      let interestTime = currentTime >= expiryTime ? expiryTime : currentTime;
      let durationInterest = interestTime - order.lastEarnedTime;
      if durationInterest <= 0.0 {
        return {
          "interestTime": interestTime,
          "rewardPending": 0.0
        }
      }
      rewardPending = rewardPending + self._calculatePendingEarned(annualProfit: self.annualProfit, userStakedAmount: order.amount, pendingTime: durationInterest)
      return {
          "interestTime": interestTime,
          "rewardPending": rewardPending
        }
    }

    access(self) fun _calculatePendingEarned(annualProfit: UFix64, userStakedAmount: UFix64, pendingTime: UFix64) : UFix64 {
      let secondsOneYear: UInt64 = 31536000 // 365*24*60*60 seconds one year
      return (pendingTime / UFix64(secondsOneYear)) * userStakedAmount * annualProfit  / 100.0;
    }

    pub fun getRewardsPendding(user: Address): UFix64 {
      var totalPendding: UFix64 = 0.0;
      if (self.stakers[user] == nil) {
        return 0.0;
      }
      let orders = self.stakers[user]!;
      for order in orders {
        let reward = self._calculateInterestOrder(order: order)
        if reward["rewardPending"]! > 0.0 {
          totalPendding = totalPendding + reward["rewardPending"]!;
        }
      }
      return totalPendding;
    }

    pub fun getUserOrders(user: Address): [StakingOrder] {
      return self.stakers[user]!;
    }

    pub fun getUserStakedAmount(user: Address): UFix64 {
      return self.userStakedAmount[user] ?? 0.0;
    }

    pub fun getStakingInfo(): {String: AnyStruct} {
      return {
        "id": self.id,
        "isFrozen": self.isFrozen,
        "totalOrder": self.totalOrder,
        "totalStaker": self.stakers.length,
        "startTime": self.startTime,
        "endTime": self.endTime,
        "minAmount": self.minAmount,
        "duration": self.duration,
        "annualProfit": self.annualProfit,
        "unstakeFee": self.unstakeFee,
        "rewardVault": self.rewardVault.balance,
        "stakeVault": self.stakeVault.balance
      }
    }
  }

  pub resource Administrator {

    pub fun freeze(stageId: UInt64) {
      pre {
        ByteNextStaking.stageStaking.containsKey(stageId): "Not found stage staking!"
      }
      let stage = (&ByteNextStaking.stageStaking[stageId] as &StageStaking?)!;
      stage.setFrozen(isFrozen: true);
    }

    pub fun unfreeze(stageId: UInt64) {
      pre {
        ByteNextStaking.stageStaking.containsKey(stageId): "Not found stage staking!"
      }
      let stage = (&ByteNextStaking.stageStaking[stageId] as &StageStaking?)!;
      stage.setFrozen(isFrozen: false);
    }

    pub fun setReceiverFeeUnstake(stageId: UInt64, capability: Capability<&{FungibleToken.Receiver}>) {
      pre {
        ByteNextStaking.stageStaking.containsKey(stageId): "Not found stage staking!"
      }
      let stage = (&ByteNextStaking.stageStaking[stageId] as &StageStaking?)!;
      stage.setReceiverFeeUnstake(capability: capability)
    }

    pub fun createStage(
      startTime: UFix64, endTime: UFix64, minAmount: UFix64, duration: UFix64, annualProfit: UFix64, unstakeFee: UFix64,
      stakeVault: @FungibleToken.Vault, rewardVault: @FungibleToken.Vault
    ) {
      
      let stage <- create StageStaking(
        id: ByteNextStaking.stakingCount, startTime: startTime, endTime: endTime,
        minAmount: minAmount, duration: duration, annualProfit: annualProfit, unstakeFee: unstakeFee,
        stakeVault: <- stakeVault, rewardVault: <- rewardVault
      );

      let oldStage <- ByteNextStaking.stageStaking[ByteNextStaking.stakingCount] <- stage
      destroy oldStage

      emit CreateNewStage(stageId: ByteNextStaking.stakingCount, startTime: startTime, endTime: endTime, minAmount: minAmount, duration: duration, annualProfit: annualProfit)

      ByteNextStaking.stakingCount = ByteNextStaking.stakingCount + 1;
    }

    pub fun updateStageStaking(stageId: UInt64, startTime: UFix64, endTime: UFix64, minAmount: UFix64, duration: UFix64, annualProfit: UFix64, unstakeFee: UFix64) {
      pre {
        ByteNextStaking.stageStaking.containsKey(stageId): "Not found stage staking!"
      }
      let stage = (&ByteNextStaking.stageStaking[stageId] as &StageStaking?)!;
      stage.setStageInfo(startTime: startTime, endTime: endTime, minAmount: minAmount, duration: duration, annualProfit: annualProfit, unstakeFee: unstakeFee)
    }

    pub fun depositToRewardPool(stageId: UInt64, vault: @FungibleToken.Vault) {
      pre {
        ByteNextStaking.stageStaking.containsKey(stageId): "Not found stage staking!"
      }
      let stage = (&ByteNextStaking.stageStaking[stageId] as &StageStaking?)!;

      assert(stage.rewardVault.getType() == vault.getType(), message: "Type vault deposit is invalid!")

      stage.rewardVault.deposit(from: <-vault);
    }

    pub fun withdrawRewardPool(stageId: UInt64, amount: UFix64): @FungibleToken.Vault {
      pre {
        ByteNextStaking.stageStaking.containsKey(stageId): "Not found stage staking!"
      }
      let stage = (&ByteNextStaking.stageStaking[stageId] as &StageStaking?)!;
      return <- stage.rewardVault.withdraw(amount: amount);
    }

  }

  pub resource StakingProxy {

    pub fun stake(stageId: UInt64, vault: @FungibleToken.Vault) {
      pre {
        ByteNextStaking.stageStaking.containsKey(stageId): "Not found stage staking!"
        self.owner != nil: "Owner should not be nil"
      }
      let stage = (&ByteNextStaking.stageStaking[stageId] as &StageStaking?)!;
      stage.stake(user: self.owner!.address, vault: <-vault);
    }

    pub fun stakeBoost(stageId: UInt64, vault: @FungibleToken.Vault, nftBoost: @ByteNextMedalNFT.NFT) {
      pre {
        ByteNextStaking.stageStaking.containsKey(stageId): "Not found stage staking!"
        self.owner != nil: "Owner should not be nil"
      }
      let stage = (&ByteNextStaking.stageStaking[stageId] as &StageStaking?)!;
      stage.stakeBoost(user: self.owner!.address, vault: <-vault, nftBoost: <- nftBoost);
    }

    pub fun withdrawRewards(stageId: UInt64, receiver: Capability<&{FungibleToken.Receiver}>) {
      pre {
        ByteNextStaking.stageStaking.containsKey(stageId): "Not found stage staking!"
        self.owner != nil: "Owner should not be nil"
      }
      let stage = (&ByteNextStaking.stageStaking[stageId] as &StageStaking?)!;
      stage.withdrawRewards(receiver: receiver)
    }

    pub fun withdrawRewardByOrder(stageId: UInt64, orderId: UInt64, receiver: Capability<&{FungibleToken.Receiver}>) {
      pre {
        ByteNextStaking.stageStaking.containsKey(stageId): "Not found stage staking!"
        self.owner != nil: "Owner should not be nil"
      }
      let stage = (&ByteNextStaking.stageStaking[stageId] as &StageStaking?)!;
      stage.withdrawRewardByOrder(orderId: orderId, receiverReward: receiver)
    }

    pub fun withdrawByOrder(
      stageId: UInt64, orderId: UInt64,
      receiverReward: Capability<&{FungibleToken.Receiver}>, receiverStaking: Capability<&{FungibleToken.Receiver}>,
      receiverNftBoost: Capability<&{ByteNextMedalNFT.CollectionPublic}>
    ) {
      pre {
        ByteNextStaking.stageStaking.containsKey(stageId): "Not found stage staking!"
        self.owner != nil: "Owner should not be nil"
      }
      let stage = (&ByteNextStaking.stageStaking[stageId] as &StageStaking?)!
      stage.withdrawByOrder(
        orderId: orderId,
        receiverReward: receiverReward,
        receiverStaking: receiverStaking,
        receiverNftBoost: receiverNftBoost
      )
    }
  }

  pub fun borrowStage(stageId: UInt64): &StageStaking{StageStakingPublic}? {
    return (&self.stageStaking[stageId] as &StageStaking{StageStakingPublic}?)!
  }

  pub fun createStakingProxy(): @StakingProxy {
    return  <- create StakingProxy()
  }

  init() {

    self.stageStaking <- {};
    self.stakingCount = 0;

    self.AdminStoragePath = /storage/ByteNextStakingAdmin
    self.StakingProxyStoragePath = /storage/ByteNextStakingProxy

    let admin <- create Administrator()
    self.account.save(<-admin, to: self.AdminStoragePath)
  }
}
