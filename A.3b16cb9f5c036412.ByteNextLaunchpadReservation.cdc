import FungibleToken from 0xf233dcee88fe0abe;
import NonFungibleToken from 0x1d7e57aa55817448;

pub contract ByteNextLaunchpadReservation {

  access(contract) let launchpads: @{UInt64: Launchpad};
  pub var launchpadCount: UInt64;

  pub let AdminStoragePath: StoragePath;
  pub let LaunchpadProxyStoragePath: StoragePath;

  pub resource interface LaunchpadPublic {
    pub fun getLaunchpadInfo(): {String: AnyStruct};
    pub fun getUserInfo(account: Address): {String: AnyStruct};
  }

  pub resource Launchpad: LaunchpadPublic {
    pub(set) var isFrozen: Bool;

    pub(set) var startTime: UFix64;
    pub(set) var endTime: UFix64;

    pub(set) var claimTime: UFix64;

    pub(set) var nftType: Type;

    pub(set) var price: UFix64;

    pub(set) var tokenPerUser: UInt64;

    pub(set) var totalSell: UInt64;

    pub(set) var comboPrice: {UInt64: UFix64};

    pub(set) var comboSell: {UInt64: UInt64};

    pub(set) var comboSold: {UInt64: UInt64};

    pub(set) var comboEndTime: {UInt64: UFix64};

    pub(set) var totalSold: UInt64;

    pub(set) var totalClaim: UInt64;

    pub(set) var totalRefund: UInt64;

    pub(set) var userBoughts: {Address: UInt64};

    pub(set) var userBoughtNormal: {Address: UInt64};

    pub(set) var userPayments: {Address: UFix64};
  
    pub(set) var userCapReceivers: {Address: Capability<&{NonFungibleToken.CollectionPublic}>};

    pub(set) var userClaims: {Address: UInt64};

    pub(set) var userRefunds: {Address: UInt64};

    pub (set) var nftVaults: @[NonFungibleToken.NFT];

    pub (set) var fundVault: @FungibleToken.Vault;

    init(
      totalSell: UInt64, nftType: Type, startTime: UFix64, endTime: UFix64, claimTime: UFix64,
      price: UFix64, tokenPerUser: UInt64, fundVault: @FungibleToken.Vault
    ) {
      pre {
        totalSell > 0: "total sell token is invalid";
      }

      self.isFrozen = false;

      self.totalSell = totalSell;

      self.comboPrice = {};
      self.comboSell = {};
      self.comboSold = {};
      self.comboEndTime = {}

      self.nftType = nftType;

      self.startTime = startTime;
      self.endTime = endTime;
      self.claimTime = claimTime;

      self.price = price;

      self.tokenPerUser = tokenPerUser;

      self.userBoughts = {};
      self.userBoughtNormal = {};
      self.userPayments = {};
      self.userCapReceivers = {};
      self.userClaims = {};
      self.userRefunds = {};

      self.nftVaults <- [];
      self.fundVault <- fundVault;

      self.totalSold = 0;
      self.totalRefund = 0;
      self.totalClaim = 0;
    }

    destroy () {
      destroy self.nftVaults;
      destroy self.fundVault;
    }

    pub fun setFrozen(isFrozen: Bool) {
      self.isFrozen = isFrozen;
    }

    pub fun setNftType(nftType: Type) {
      self.nftType = nftType;
    }

    pub fun setTotalSell(amount: UInt64) {
      self.totalSell = amount;
    }

    pub fun setTokenPerUser(amount: UInt64) {
      self.tokenPerUser = amount;
    }

    pub fun setTime(startTime: UFix64, endTime: UFix64, claimTime: UFix64) {
      pre {
        startTime < endTime: "startTime should be less than endTime";
        endTime < claimTime: "startTime should be less than endTime";
      }
      self.startTime = startTime;
      self.endTime = endTime;
      self.claimTime = claimTime;
    }

    pub fun setComboInfo(quantity: UInt64, totalSell: UInt64, price: UFix64, endTime: UFix64) {
      self.comboSell.remove(key: quantity);
      self.comboSell.insert(key: quantity, totalSell);
      self.comboPrice.remove(key: quantity);
      self.comboPrice.insert(key: quantity, price);
      self.comboEndTime.remove(key: quantity);
      self.comboEndTime.insert(key: quantity, endTime);
    }

    pub fun setPriceToken(price: UFix64, fundVault: @FungibleToken.Vault) {
      pre {
        self.fundVault.balance == 0.0 : "Fund vault must be empty"
      }
      self.price = price;
      let oldVault <-self.fundVault <- fundVault;
      destroy oldVault;
    }

    pub fun depositNftVault(nfts: @[NonFungibleToken.NFT]) {
      let depositAmount = nfts.length;
      var index = 0;
      while index < depositAmount {
        let nft <- nfts.removeLast();
        
        if nft.getType() != self.nftType {
          panic("NFT type is invalid")
        }
        self.nftVaults.append(<- nft)

        index = index + 1;
      }
      destroy nfts;
    }

    pub fun withdrawNftVault(amount: UInt64, capReceiver: Capability<&{NonFungibleToken.CollectionPublic}>) {
      var index: UInt64 = 0;
      while index < amount {
        let nft <- self.nftVaults.removeLast();

        capReceiver.borrow()!.deposit(token: <- nft);

        index = index + 1;
      }
    }

    pub fun depositFund(depVault: @FungibleToken.Vault) {
      pre {
        depVault.getType() == self.fundVault.getType(): "Token deposit must be same type token IDO"
      }
      self.fundVault.deposit(from: <- depVault.withdraw(amount: depVault.balance))
      destroy depVault;
    }

    pub fun withdrawFund(amount: UFix64): @FungibleToken.Vault {
      pre {
        amount <= self.fundVault.balance: "Amount withdraw is invalid"
      }
      return <- self.fundVault.withdraw(amount: amount);
    }

    //PUBLIC FUNCTIONS
    pub fun getLaunchpadInfo(): {String: AnyStruct} {
      return {
        "isFrozen": self.isFrozen,
        "totalSell": self.totalSell,
        "comboPrice": self.comboPrice,
        "comboSell": self.comboSell,
        "comboSold": self.comboSold,
        "comboEndTime": self.comboEndTime,
        "nftType": self.nftType,
        "startTime": self.startTime,
        "endTime": self.endTime,
        "claimTime": self.claimTime,
        "price": self.price,
        "tokenPerUser": self.tokenPerUser,
        "totalSold": self.totalSold,
        "totalClaim": self.totalClaim,
        "totalRefund": self.totalRefund,
        "amountNft": self.nftVaults.length,
        "fundBalance": self.fundVault.balance
      }
    }

    pub fun getUserInfo(account: Address): {String: AnyStruct} {
      let userInfo: {String: AnyStruct} = {};

      userInfo.insert(key: "bought", (self.userBoughts[account] ?? 0));
      userInfo.insert(key: "payment", (self.userPayments[account] ?? 0.0));
      userInfo.insert(key: "claim", (self.userClaims[account] ?? 0));
      userInfo.insert(key: "refund", (self.userRefunds[account] ?? 0));
      userInfo.insert(key: "boughtNormal", (self.userBoughtNormal[account] ?? 0));

      return userInfo;
    }

    pub fun buy(
      launchpadId: UInt64,
      account: Address,
      quantity: UInt64,
      paymentVault: @FungibleToken.Vault,
      recipientCapability: Capability<&{NonFungibleToken.CollectionPublic}>
    ) {
      pre {
        paymentVault.getType() == self.fundVault.getType(): "Payment token is not allowed"
      }

      assert(!self.isFrozen, message: "Launchpad is frozen");

      if (self.startTime > getCurrentBlock().timestamp || self.endTime < getCurrentBlock().timestamp) {
        panic("Can not join this launchpad at this time");
      }

      if (self.userBoughtNormal.containsKey(account)) {
        panic("Only one purchase per account");
      }

      if (quantity > (self.totalSell - self.totalSold)) {
        panic("The number of tokens has already been sold out.");
      }
    
      let maxTokenToBuy: UInt64 = self.tokenPerUser - (self.userBoughts[account] ?? 0);
      if (quantity > maxTokenToBuy) {
        panic("You can not join this launchpad anymore");
      }

      // validate vaul balance
      let paymentVaultBalance = paymentVault.balance;
      let paymentToBuy = UFix64(quantity) * self.price;
      if (paymentVaultBalance != paymentToBuy) {
        panic("Payment Vault is invalid");
      }

      let userBought = (self.userBoughts[account] ?? 0);
      self.userBoughts.remove(key: account);
      self.userBoughts.insert(key: account, userBought + quantity);

      self.userBoughtNormal.insert(key: account, userBought + quantity);

      let userPayment = (self.userPayments[account] ?? 0.0);
      self.userPayments.remove(key: account);
      self.userPayments.insert(key: account, userPayment + paymentVaultBalance);

      self.userCapReceivers.remove(key: account);
      self.userCapReceivers.insert(key: account, recipientCapability);

      self.totalSold = self.totalSold + quantity;

      self.fundVault.deposit(from: <- paymentVault)

      emit Joined(launchpadId: launchpadId, account: account, tokenQuantity: quantity, paymentAmount: paymentVaultBalance, typeCombo: false);
    }

    pub fun buyCombo(
      launchpadId: UInt64,
      account: Address,
      comboType: UInt64,
      quantity: UInt64,
      paymentVault: @FungibleToken.Vault,
      recipientCapability: Capability<&{NonFungibleToken.CollectionPublic}>
    ) {
      pre {
        paymentVault.getType() == self.fundVault.getType(): "Payment token is not allowed"
      }

      assert(!self.isFrozen, message: "Launchpad is frozen");

      let now = getCurrentBlock().timestamp;
      if (self.startTime > now || self.endTime < now) {
        panic("Can not join this launchpad at this time");
      }

      if (!self.comboPrice.containsKey(comboType) || !self.comboSell.containsKey(comboType) || !self.comboEndTime.containsKey(comboType)) {
        panic("Combo type is not found");
      }

      if (self.comboEndTime[comboType]! < now) {
        panic("Combo sale time has ended");
      }

      let comboSold = (self.comboSold[comboType] ?? 0);
      let comboRemaining = self.comboSell[comboType]! - comboSold;
      if (quantity > comboRemaining) {
        panic("The number of combo has already been sold out");
      }

      let totalBuy = comboType * quantity;
      if (totalBuy > (self.totalSell - self.totalSold)) {
        panic("The number of tokens has already been sold out");
      }

      let maxTokenToBuy: UInt64 = self.tokenPerUser - (self.userBoughts[account] ?? 0);
      if (totalBuy > maxTokenToBuy) {
        panic("You can not join this launchpad anymore");
      }

      // validate vaul balance
      let paymentVaultBalance = paymentVault.balance;
      let paymentToBuy = UFix64(totalBuy) * self.comboPrice[comboType]!
      if (paymentVaultBalance != paymentToBuy) {
        panic("Payment Vault is invalid");
      }

      let userBought = (self.userBoughts[account] ?? 0);
      self.userBoughts.remove(key: account);
      self.userBoughts.insert(key: account, userBought + totalBuy);

      let userPayment = (self.userPayments[account] ?? 0.0);
      self.userPayments.remove(key: account);
      self.userPayments.insert(key: account, userPayment + paymentVaultBalance);

      self.userCapReceivers.remove(key: account);
      self.userCapReceivers.insert(key: account, recipientCapability);

      self.comboSold.remove(key: comboType);
      self.comboSold.insert(key: comboType, comboSold + quantity);

      self.totalSold = self.totalSold + totalBuy;

      self.fundVault.deposit(from: <- paymentVault)

      emit Joined(launchpadId: launchpadId, account: account, tokenQuantity: totalBuy, paymentAmount: paymentVaultBalance, typeCombo: true);
    }

    pub fun claim(launchpadId: UInt64, account: Address) {
      pre {
        self.userCapReceivers[account] != nil: "The account were not join this launchpad";
      }

      assert(!self.isFrozen, message: "Launchpad is frozen");

      let now =  getCurrentBlock().timestamp;
      if (now < self.claimTime) {
        panic("Can not claim token at this time");
      }

      if (!self.userBoughts.containsKey(account)) {
        panic("The account can not claim for this launchpad");
      }

      if (self.userRefunds.containsKey(account)) {
        panic("The account has been selected refund");
      }

      if (self.userClaims.containsKey(account)) {
        panic("The account has been claimed");
      }

      let nftClaimAvailable = UInt64(self.nftVaults.length);
      if (nftClaimAvailable == 0) {
        panic("There is no NFT left to claim");
      }

      var quantity: UInt64 = self.userBoughts[account]!;
      if (quantity > nftClaimAvailable) {
        quantity = nftClaimAvailable
      }

      var index: UInt64 = 0;
      while index < quantity {
        let nft <- self.nftVaults.removeLast();
        self.userCapReceivers[account]!.borrow()!.deposit(token: <- nft);

        index = index + 1;
      }

      self.userClaims.insert(key: account, quantity);
      self.totalClaim = self.totalClaim + quantity;

      emit Claimed(launchpadId: launchpadId, account: account, tokenQuantity: quantity);
    }

    pub fun refund(launchpadId: UInt64, account: Address): @FungibleToken.Vault {
      pre {
        self.userBoughts.containsKey(account): "The account were not join this launchpad";
      }

      assert(!self.isFrozen, message: "Launchpad is frozen");

      let now =  getCurrentBlock().timestamp;
      if (now < self.claimTime) {
        panic("Can not refund at this time");
      }
      if (self.nftVaults.length != 0) {
        panic("Can not refund this launchpad");
      }

      if (self.userRefunds.containsKey(account)) {
        panic("The account has been refund before");
      }

      let amountNftRefund: UInt64 = self.userBoughts[account]! - (self.userClaims[account] ?? 0);

      let paymentRefund: UFix64 = UFix64(amountNftRefund) * self.price;

      self.userRefunds.insert(key: account, amountNftRefund);

      self.totalRefund = self.totalRefund + amountNftRefund;

      emit Refund(launchpadId: launchpadId, account: account, tokenQuantity: amountNftRefund, paymentAmount: paymentRefund);

      return <- self.fundVault.withdraw(amount: paymentRefund);
    }
  }

  pub resource Administrator {
    pub fun borrowLaunchpad(launchpadId: UInt64) : &Launchpad {
      pre {
        ByteNextLaunchpadReservation.launchpads.containsKey(launchpadId): "Launchpad is invalid"
        self.owner != nil: "Owner should not be nil"
      }
      return (&ByteNextLaunchpadReservation.launchpads[launchpadId] as &Launchpad?)!;
    }

    pub fun createLaunchpad(
      totalSell: UInt64, nftType: Type, startTime: UFix64, endTime: UFix64, claimTime: UFix64,
      price: UFix64, tokenPerUser: UInt64, fundVault: @FungibleToken.Vault
    ) {
      let launchpad <- create Launchpad(
        totalSell: totalSell, nftType: nftType, startTime: startTime, endTime: endTime, claimTime: claimTime,
        price: price, tokenPerUser: tokenPerUser, fundVault: <- fundVault
      );

      let oldLaunchpad <- ByteNextLaunchpadReservation.launchpads[ByteNextLaunchpadReservation.launchpadCount] <- launchpad
      destroy oldLaunchpad

      emit NewLaunchpadCreated(
        id: ByteNextLaunchpadReservation.launchpadCount, totalSell: totalSell, nftType: nftType, startTime: startTime,
        endTime: endTime, claimTime: claimTime, price: price, tokenPerUser: tokenPerUser
      );

      ByteNextLaunchpadReservation.launchpadCount = ByteNextLaunchpadReservation.launchpadCount + 1;
    }
  }

  pub resource LaunchpadProxy {
    pub fun buy(
      launchpadId: UInt64,
      quantity: UInt64,
      paymentVault: @FungibleToken.Vault,
      recipientCapability: Capability<&{NonFungibleToken.CollectionPublic}>
    ) {
      pre {
        ByteNextLaunchpadReservation.launchpads.containsKey(launchpadId): "Launchpad is invalid"
        self.owner != nil: "Owner should not be nil"
      }
      let launchpad = (&ByteNextLaunchpadReservation.launchpads[launchpadId] as &Launchpad?)!;
      launchpad.buy(launchpadId: launchpadId, account: self.owner!.address, quantity: quantity,paymentVault: <- paymentVault, recipientCapability: recipientCapability)
    }

    pub fun buyCombo(
      launchpadId: UInt64,
      comboType: UInt64,
      quantity: UInt64,
      paymentVault: @FungibleToken.Vault,
      recipientCapability: Capability<&{NonFungibleToken.CollectionPublic}>
    ) {
      pre {
        ByteNextLaunchpadReservation.launchpads.containsKey(launchpadId): "Launchpad is invalid"
        self.owner != nil: "Owner should not be nil"
      }
      let launchpad = (&ByteNextLaunchpadReservation.launchpads[launchpadId] as &Launchpad?)!;
      launchpad.buyCombo(launchpadId: launchpadId, account: self.owner!.address, comboType: comboType, quantity: quantity, paymentVault: <- paymentVault, recipientCapability: recipientCapability)
    }

    pub fun claim(launchpadId: UInt64) {
      pre {
          ByteNextLaunchpadReservation.launchpads.containsKey(launchpadId): "Launchpad is invalid"
          self.owner != nil: "Owner should not be nil"
      }
      let launchpad = (&ByteNextLaunchpadReservation.launchpads[launchpadId] as &Launchpad?)!;
      launchpad.claim(launchpadId: launchpadId, account: self.owner!.address)
    }

    pub fun refund(launchpadId: UInt64): @FungibleToken.Vault {
      pre {
          ByteNextLaunchpadReservation.launchpads.containsKey(launchpadId): "Launchpad is invalid"
          self.owner != nil: "Owner should not be nil"
      }
      let launchpad = (&ByteNextLaunchpadReservation.launchpads[launchpadId] as &Launchpad?)!;
      return <- launchpad.refund(launchpadId: launchpadId, account: self.owner!.address)
    }
  }

  pub fun createLaunchpadProxy(): @LaunchpadProxy {
    return  <- create LaunchpadProxy()
  }

  pub fun borrowLaunchpadPublic(launchpadId: UInt64): &{LaunchpadPublic}? {
    if (self.launchpads.containsKey(launchpadId)) {
      return (&self.launchpads[launchpadId] as &{LaunchpadPublic}?)!
    }
    return nil;
  }

  init() {
    self.launchpads <- {};
    self.launchpadCount = 0;

    self.AdminStoragePath = /storage/ByteNextLaunchpadReservationAdmin
    self.LaunchpadProxyStoragePath = /storage/ByteNextLaunchpadReservationProxy

    let admin <- create Administrator()
    self.account.save(<-admin, to: self.AdminStoragePath)
  }

  pub event NewLaunchpadCreated(
    id: UInt64, totalSell: UInt64, nftType: Type, startTime: UFix64, endTime: UFix64,
    claimTime: UFix64, price: UFix64, tokenPerUser: UInt64
  );
  pub event Claimed(launchpadId: UInt64, account: Address, tokenQuantity: UInt64);
  pub event Joined(launchpadId: UInt64, account: Address, tokenQuantity: UInt64, paymentAmount: UFix64, typeCombo: Bool);
  pub event Refund(launchpadId: UInt64, account: Address, tokenQuantity: UInt64, paymentAmount: UFix64);
}
 