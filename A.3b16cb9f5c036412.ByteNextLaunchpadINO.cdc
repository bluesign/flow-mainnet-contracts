import FungibleToken from 0xf233dcee88fe0abe;
import NonFungibleToken from 0x1d7e57aa55817448;
import ByteNextMedalNFT from 0x3b16cb9f5c036412;
import NonFungibleTokenMinter from 0x3b16cb9f5c036412;

pub contract ByteNextLaunchpadINO {

  access(contract) let launchpads: @{UInt64: Launchpad};

  // user swap ticket for point, using point to join launchpad
  access(contract) let userPoints: {Address: UInt64};
  // mapping type medal ticket to point when swap
  access(contract) let configTicketPoints: {String: UInt64};
  
  pub let swapHistory: {UInt64: Address};

  pub var launchpadCount: UInt64;

  pub let AdminStoragePath: StoragePath;
  pub let LaunchpadProxyStoragePath: StoragePath;

  pub struct Whitelist {
    pub var user: Address;
    pub var allocation: UInt64;

    init(user: Address, allocation: UInt64) {
      self.user = user;
      self.allocation = allocation;
    }
  }

  pub struct NFTFormatTemplate {
    access(contract) let metadataTemp: {String: String};
    access(contract) let mintFromId: UInt64;
    access(contract) let indexReplace: {String : [Int]};

    init(template: {String: String}, mintFromId: UInt64) {
      self.metadataTemp = template;
      self.mintFromId = mintFromId;
      let result : {String : [Int]} = {}
      for field in template.keys {
        let strData = template[field]!
        var openTag = 0;
        var endTag = 0;
        var index = 0;
        while index < strData.length {
          if strData[index] == "{" {
              openTag = index;
          }
          if strData[index] == "}" {
              endTag = index;
          }
          index = index + 1;
        }
        result.insert(key: field, [openTag, endTag])
      }
      self.indexReplace = result;
    }
  }

  pub struct LaunchpadStage {
    pub(set) var isFrozen: Bool;
    pub(set) var isPublic: Bool;
    pub(set) var acceptingPoint: Bool;

    pub(set) var startTime: UFix64;
    pub(set) var endTime: UFix64;

    // Price of token to INO
    pub(set) var price: UFix64;
    // Type of payment vault which user will paid
    pub(set) var paymentType: Type;

    pub(set) var totalAllocation: UInt64;

    pub(set) var userAllocations: {Address: UInt64};

    // use when stage is public
    pub(set) var tokenPerUser: UInt64;

    pub(set) var totalAllocated: UInt64;

    pub(set) var userBoughts: {Address: UInt64};

    // The receiver to receiver user fund when join pool
    pub (set) var tokenReceiver: Capability<&{FungibleToken.Receiver}>;

    pub(set) var tokenSold: UInt64;

    init(
      isPublic: Bool, tokenPerUser: UInt64, acceptingPoint: Bool,
      totalAllocation: UInt64, startTime: UFix64, endTime: UFix64, price: UFix64, paymentType: Type,
      tokenReceiver: Capability<&{FungibleToken.Receiver}>
    ) {
      pre {
        startTime >= getCurrentBlock().timestamp: "Start time should be less than current time"
        startTime < endTime: "Start time must be less than end time"
        tokenReceiver.check(): "Recipient ref invalid"
        paymentType == tokenReceiver.borrow()!.getType(): "Should type receiver same type of payment"
      }
      self.isFrozen = false;
      self.isPublic = isPublic;
      self.acceptingPoint = acceptingPoint;

      self.startTime = startTime;
      self.endTime = endTime;
      self.price = price;
      self.paymentType = paymentType;
      self.tokenReceiver = tokenReceiver;
      self.totalAllocation = totalAllocation;

      if (isPublic) {
        self.tokenPerUser = tokenPerUser;
      } else {
        self.tokenPerUser = 0;
      }

      self.userAllocations = {};
      self.totalAllocated = 0;
      self.userBoughts = {};

      self.tokenSold = 0;
    }
  }

  pub resource interface LaunchpadPublic {
    pub fun getLaunchpadInfo(): {String: AnyStruct};
    pub fun getNFTForMint(): {UInt64: {String: String}};
    pub fun getStageInfo(stageId: UInt8): LaunchpadStage;
    pub fun getTokenRemaining(stageId: UInt8): Int;
    pub fun getUserAllocation(stageId: UInt8, account: Address): UInt64?;
    pub fun getUserBought(stageId: UInt8, account: Address): UInt64;
    pub fun setMinterCapability(capability: Capability<&{NonFungibleTokenMinter.MinterProvider}>);
  }

  pub resource Launchpad: LaunchpadPublic {
    access(self) var totalStage: UInt8;
    access(self) let stages: {UInt8: LaunchpadStage};

    access(self) var totalSell: UInt64;

    access(self) var mintByTemp: Bool;
    // format template to build metadata for nft
    access(self) var nftFormatTemp: NFTFormatTemplate?;
    // list type nft special for mint
    access(self) var nftForMints: {UInt64: {String: String}};

    // Type of token NFT to INO
    access(self) var tokenType: Type;
    access(self) var tokenAddress: Address;

    access(self) var totalSold: UInt64;
    access(self) var totalRevice: UFix64;

    access(self) var minterCapability: Capability<&{NonFungibleTokenMinter.MinterProvider}>?

    init(totalSell: UInt64, tokenType: Type, tokenAddress: Address, mintByTemp: Bool) {
      pre {
        totalSell > 0: "total sell token is invalid";
      }

      self.totalSell = totalSell;
      self.mintByTemp = mintByTemp;
      self.nftFormatTemp = nil;
      self.nftForMints = {};
      self.tokenAddress = tokenAddress;
      self.tokenType = tokenType;
      self.stages = {};
      self.totalSold = 0;
      self.totalRevice = 0.0;
      self.totalStage = 0;
      self.minterCapability = nil;
    }

    access(contract) fun setTotalSell(amount: UInt64) {
      self.totalSell = amount;
    }

    access(contract) fun setMintByTemp(mintByTemp: Bool) {
      self.mintByTemp = mintByTemp;
    }

    access(contract) fun setTokenAddress(tokenAddress: Address) {
      self.tokenAddress = tokenAddress;
    }

    access(contract) fun setTypeContract(type: Type) {
      self.tokenType = type;
    }

    // for owner of ino set capability for mint
    pub fun setMinterCapability(capability: Capability<&{NonFungibleTokenMinter.MinterProvider}>) {
      pre {
        capability.address == self.tokenAddress: "You not owner of contract nft"
      }
      self.minterCapability = capability;
    }

    access(contract) fun setNFTFormatTemplate(nftFormatTemp: NFTFormatTemplate) {
      self.nftFormatTemp = nftFormatTemp;
    }

    access(contract) fun setListNFTForMint(tokenIds: [UInt64], metadatas: [{String: String}]) {
      pre {
        tokenIds.length == metadatas.length: "Params data not same length"
      }

      var index: UInt64 = 0;
      for tokenId in tokenIds {
        self.nftForMints.insert(key: tokenId, metadatas[index])
        index = index + 1;
      }
    }

    access(contract) fun removeNFTForMint(tokenIds: [UInt64]) {
      for tokenId in tokenIds {
        if (self.nftForMints.containsKey(tokenId)) {
          self.nftForMints.remove(key: tokenId)
        }
      }
    }

    access(contract) fun createNewStage(
      launchpadId: UInt64, isPublic: Bool, tokenPerUser: UInt64, acceptingPoint: Bool,
      totalAllocation: UInt64, startTime: UFix64, endTime: UFix64, price: UFix64, paymentType: Type,
      tokenReceiver: Capability<&{FungibleToken.Receiver}>
    ) {
      pre {
        totalAllocation <= self.totalSell - self.totalSold: "Allocation has exceeded the total raise"
      }

      var countAllocation: UInt64 = 0
      for key in self.stages.keys {
        let stage = self.stages[key]!
        countAllocation = countAllocation + stage.totalAllocation
      }
      let allocationRemain = self.totalSell - countAllocation
      assert(totalAllocation <= allocationRemain, message: "Allocation has exceeded the total raise")

      self.stages[self.totalStage] = LaunchpadStage(
        isPublic: isPublic,
        tokenPerUser: tokenPerUser,
        acceptingPoint: acceptingPoint,
        totalAllocation: totalAllocation,
        startTime: startTime,
        endTime: endTime,
        price: price,
        paymentType: paymentType,
        tokenReceiver: tokenReceiver
      );

      emit NewStageCreated(
        launchpadId: launchpadId,
        id: self.totalStage,
        isPublic: isPublic,
        tokenPerUser: tokenPerUser,
        totalAllocation: totalAllocation,
        startTime: startTime,
        endTime: endTime,
        price: price,
        paymentType: paymentType
      );

      self.totalStage = self.totalStage + 1;
    }

    access(contract) fun setFrozen(stageId: UInt8, isFrozen: Bool) {
      pre {
        self.stages.containsKey(stageId): "Stage is invalid";
      }
      let stageInfo = self.stages[stageId]!;
      stageInfo.isFrozen = isFrozen;
      self.stages[stageId] = stageInfo;
    }

    access(contract) fun acceptingPoint(stageId: UInt8, isAccepting: Bool) {
      pre {
        self.stages.containsKey(stageId): "Stage is invalid";
      }
      let stageInfo = self.stages[stageId]!;
      stageInfo.acceptingPoint = isAccepting;
      self.stages[stageId] = stageInfo;
    }

    access(contract) fun setTotalAllocationStage(stageId: UInt8, amount: UInt64) {
      pre {
        self.stages.containsKey(stageId): "Stage is invalid";
      }

      var countAllocation: UInt64 = 0
      for key in self.stages.keys {
        let stage = self.stages[key]!
        if (key != stageId) {
          countAllocation = countAllocation + stage.totalAllocation
        }
      }
      let allocationRemain = self.totalSell - countAllocation
      assert(amount <= allocationRemain, message: "Allocation has exceeded the total raise")

      let stageInfo = self.stages[stageId]!
      assert(amount >= stageInfo.totalAllocated, message: "Allocation must be greater allocated")

      stageInfo.totalAllocation = amount;
      self.stages[stageId] = stageInfo;
    }

    access(contract) fun setTypeStage(stageId: UInt8, isPublic: Bool, tokenPerUser: UInt64) {
      pre {
        self.stages.containsKey(stageId): "Stage is invalid";
      }
      let stageInfo = self.stages[stageId]!;
      stageInfo.isPublic = isPublic;
      if (isPublic) {
        stageInfo.tokenPerUser = tokenPerUser;
      } else {
        stageInfo.tokenPerUser = 0;
      }
      self.stages[stageId] = stageInfo;
    }

    access(contract) fun setTime(stageId: UInt8, startTime: UFix64, endTime: UFix64) {
      pre {
        self.stages.containsKey(stageId): "Stage is invalid";
        startTime < endTime: "startTime should be less than endTime";
      }
      let stageInfo = self.stages[stageId]!;
      stageInfo.startTime = startTime;
      stageInfo.endTime = endTime;
      self.stages[stageId] = stageInfo;
    }

    access(contract) fun setPriceToken(stageId: UInt8, price: UFix64, paymentType: Type) {
      pre {
        self.stages.containsKey(stageId): "Stage is invalid";
      }
      let stageInfo = self.stages[stageId]!;
      stageInfo.price = price;
      stageInfo.paymentType = paymentType;

      self.stages[stageId] = stageInfo;
    }

    access(contract) fun registJoin(stageId: UInt8, user: Address) {
      pre {
        self.stages.containsKey(stageId): "Stage is invalid"
        !self.stages[stageId]!.isPublic: "Stage must be private sale"
      }

      let stageInfo = self.stages[stageId]!;
      assert(stageInfo.acceptingPoint, message: "This stage not accepting point")
      assert(stageInfo.startTime > getCurrentBlock().timestamp, message: "Can not regist join stage at this time")
      // assert(UInt64(whitelist.length) + stageInfo.totalAllocated <= stageInfo.totalAllocation, message: "Allocation has exceeded in stage")

      if (stageInfo.userAllocations.containsKey(user) && stageInfo.userAllocations[user]! > 0) {
        panic("The account already exists on the whitelist");
      }

      // update allocation stage infos
      stageInfo.userAllocations.insert(key: user, 1);
      stageInfo.totalAllocated = stageInfo.totalAllocated + 1;
      self.stages[stageId] = stageInfo;

      // update point of user
      let currentPoint = ByteNextLaunchpadINO.userPoints.remove(key: user);
      let amountPoint = (currentPoint ?? 0) - 1;
      ByteNextLaunchpadINO.userPoints.insert(key: user, amountPoint);
    }

    access(contract) fun setUserAllocation(stageId: UInt8, whitelist: [Whitelist]) {
      pre {
        self.stages.containsKey(stageId): "Stage is invalid"
        !self.stages[stageId]!.isPublic: "Stage must be private sale"
      }

      let stageInfo = self.stages[stageId]!;
      // assert(UInt64(whitelist.length) + stageInfo.totalAllocated <= stageInfo.totalAllocation, message: "Allocation has exceeded in stage")

      for data in whitelist {
        let userAddress = data.user;
        let userAllocation = data.allocation;

        if userAllocation == 0 {
          continue;
        }
        if (stageInfo.userAllocations.containsKey(userAddress)) {
          stageInfo.totalAllocated = stageInfo.totalAllocated - stageInfo.userAllocations[userAddress]!
          stageInfo.userAllocations.remove(key: userAddress);
        }

        stageInfo.totalAllocated = stageInfo.totalAllocated + userAllocation;

        // assert(countAllocation <= stageInfo.totalAllocation, message: "Whitelist has exceeded allocation in stage")

        stageInfo.userAllocations.insert(key: userAddress, userAllocation);
      }

      self.stages[stageId] = stageInfo;
    }

    access(contract) fun removeUserAllocation(stageId: UInt8, accounts: [Address]) {
      pre {
        self.stages.containsKey(stageId): "Stage is invalid"
        !self.stages[stageId]!.isPublic: "Stage must be private sale"
      }
      let stageInfo = self.stages[stageId]!;

      var countAllocationRemove: UInt64 = 0;
      for account in accounts {
        if (stageInfo.userAllocations.containsKey(account)) {
          countAllocationRemove = countAllocationRemove + stageInfo.userAllocations[account]!
          stageInfo.userAllocations.remove(key: account);
        }
      }

      stageInfo.totalAllocated = stageInfo.totalAllocated - countAllocationRemove;
      self.stages[stageId] = stageInfo;
    }

    //PUBLIC FUNCTIONS
    pub fun getLaunchpadInfo(): {String: AnyStruct} {
      return {
        "totalSale": self.totalSell,
        "totalSold": self.totalSold,
        "tokenType": self.tokenType,
        "tokenAddress": self.tokenAddress,
        "mintByTemp": self.mintByTemp,
        "minterCapability": self.minterCapability,
        "nftFormatTemp": self.nftFormatTemp,
        "totalRevice": self.totalRevice,
        "totalStage": self.totalStage
      }
    }

    pub fun getNFTForMint(): {UInt64: {String: String}} {
      return self.nftForMints;
    }

    pub fun getStageInfo(stageId: UInt8): LaunchpadStage {
      pre {
        self.stages.containsKey(stageId): "Stage is invalid";
      }
      return self.stages[stageId]!
    }

    pub fun getUserAllocation(stageId: UInt8, account: Address): UInt64? {
      pre {
        self.stages.containsKey(stageId): "Stage is invalid";
      }
      if self.stages[stageId]!.isFrozen {
        return nil;
      }
      if self.stages[stageId]!.isPublic {
        return self.stages[stageId]!.tokenPerUser;
      }
      let allocation = self.stages[stageId]!.userAllocations;
      if !allocation.containsKey(account) {
        return nil;
      }
      return allocation[account]!
    }

    pub fun getTokenRemaining(stageId: UInt8): Int {
      pre {
        self.stages.containsKey(stageId): "Stage is invalid";
        !self.stages[stageId]!.isFrozen: "Stage is frozen"
      }
      var tokenUnsold: Int = 0;
      var index: UInt8 = 0;
      while index < stageId {
        let currentStage = self.stages[index]!
        if (currentStage.totalAllocation >= currentStage.tokenSold) {
          tokenUnsold = tokenUnsold + Int(currentStage.totalAllocation - currentStage.tokenSold)
        } else {
          tokenUnsold = tokenUnsold - Int(currentStage.tokenSold - currentStage.totalAllocation)
        }
        index = index + 1;
      }
      let stage = self.stages[stageId]!;
      return tokenUnsold + Int(stage.totalAllocation) - Int(stage.tokenSold);
    }

    pub fun getUserBought(stageId: UInt8, account: Address): UInt64 {
      pre {
        self.stages.containsKey(stageId): "Stage is invalid";
      }
      let bought = self.stages[stageId]!.userBoughts;
      if !bought.containsKey(account) {
        return 0;
      }
      return bought[account]!
    }

    access(contract) fun join(
      launchpadId: UInt64,
      stageId: UInt8,
      account: Address,
      paymentVault: @FungibleToken.Vault,
      recipient: &{NonFungibleToken.CollectionPublic}
    ) {
      pre {
        self.stages.containsKey(stageId): "Stage is invalid"
        paymentVault.isInstance(self.getStageInfo(stageId: stageId).paymentType): "Payment token is not allowed"
      }

      let stage = self.stages[stageId]!;
      assert(!stage.isFrozen, message: "Stage is frozen");

      if (stage.startTime > getCurrentBlock().timestamp || stage.endTime < getCurrentBlock().timestamp) {
        panic("Can not join this launchpad at this time");
      }

      var maxTokenToBuy: UInt64 = 0;
      if (stage.isPublic) {
        maxTokenToBuy = stage.tokenPerUser - (stage.userBoughts[account] ?? 0);
      } else {
        assert((self.getUserAllocation(stageId: stageId, account: account) ?? 0) > 0, message: "You can not join this stage")
        maxTokenToBuy = stage.userAllocations[account]! - (stage.userBoughts[account] ?? 0);
      }
      if (maxTokenToBuy == 0) {
        panic("You can not join this stage anymore");
      }

      let paymentVaultBalance = paymentVault.balance;

      var tokenToBuy = maxTokenToBuy;
      if (stage.price != 0.0) {
        let maxPaymentToBuy = UFix64(maxTokenToBuy) * stage.price;
        if (paymentVaultBalance > maxPaymentToBuy) {
          panic("Excess payment vault to buy");
        }

        tokenToBuy = UInt64(paymentVaultBalance / stage.price);
        if (tokenToBuy <= 0) {
          panic("Payment vault is not enough to buy");
        }
      }
      
      let tokenRemaining: Int = self.getTokenRemaining(stageId: stageId)
      if (tokenRemaining <= 0 || tokenToBuy > UInt64(tokenRemaining)) {
        panic("The number of tokens in this round has already been sold out.");
      }

      let userBought = (stage.userBoughts[account] ?? 0);
      stage.userBoughts.remove(key: account);
      stage.userBoughts.insert(key: account, userBought + tokenToBuy);
      stage.tokenSold = stage.tokenSold + tokenToBuy;
      stage.tokenReceiver.borrow()!.deposit(from: <- paymentVault);
      self.stages[stageId] = stage;

      self._mintNFT(account: account, recipient: recipient, amount: tokenToBuy)

      self.totalSold = self.totalSold + tokenToBuy;
      self.totalRevice = self.totalRevice + paymentVaultBalance;
      emit Joined(launchpadId: launchpadId, stageId: stageId, account: account, tokenQuantity: tokenToBuy, paymentAmount: paymentVaultBalance);
    }

    access(self) fun _mintNFT(account: Address, recipient: &{NonFungibleToken.CollectionPublic}, amount: UInt64) {
      let minterRef = self.minterCapability!.borrow() ?? panic("Can not borrow minter");

      if (self.mintByTemp) {
        assert(self.nftFormatTemp != nil, message: "Template nft unset");
        var minted : UInt64 = 0;
        while minted < amount {
          let tokenId = self.nftFormatTemp!.mintFromId + self.totalSold + minted;
          let metadata = self._buildMetadataMint(tokenId: tokenId, formatTemplate: self.nftFormatTemp!);
          minterRef.mintNFT(
            id: tokenId,
            recipient: recipient,
            metadata: metadata
          );
          minted = minted + 1;
        }
      } else {
        let tokenIds = self.nftForMints.keys
        assert(UInt64(tokenIds.length) >= amount, message: "NFT is not enough to mint");
        var minted : UInt64 = 0;
        while minted < amount {
          let tokenId = tokenIds[minted]
          let metadata = self.nftForMints[tokenId]!;
          minterRef.mintNFT(
            id: tokenId,
            recipient: recipient,
            metadata: metadata
          );
          minted = minted + 1;
          self.nftForMints.remove(key: tokenId)
        }
      }
    }

    access(self) fun _buildMetadataMint(tokenId: UInt64, formatTemplate: NFTFormatTemplate): {String: String} {
      let metadata : {String: String} = {};
      for field in formatTemplate.metadataTemp.keys {
        let strTemp = formatTemplate.metadataTemp[field]!
        let replaceFrom = formatTemplate.indexReplace[field]![0]
        let replaceTo = formatTemplate.indexReplace[field]![1]

        if (replaceFrom == 0 || replaceTo == 0) {
          metadata.insert(key: field, strTemp)
          continue;
        }
        let firstPart = strTemp.slice(from: 0, upTo: replaceFrom)
        let secondPart = strTemp.slice(from: replaceTo+1, upTo: strTemp.length)
        let result = firstPart.concat(tokenId.toString()).concat(secondPart)
        metadata.insert(key: field, result)
      }
      return metadata;
    }
  }

  pub resource Administrator {

    access(self) fun getLaunchpad(launchpadId: UInt64) : &Launchpad {
      pre {
        ByteNextLaunchpadINO.launchpads.containsKey(launchpadId): "Launchpad is invalid"
        self.owner != nil: "Owner should not be nil"
      }
      return (&ByteNextLaunchpadINO.launchpads[launchpadId] as &Launchpad?)!;
    }

    pub fun createLaunchpad(totalSell: UInt64, tokenType: Type, tokenAddress: Address, mintByTemp: Bool) {
      let launchpad <- create Launchpad(totalSell: totalSell, tokenType: tokenType, tokenAddress: tokenAddress, mintByTemp: mintByTemp);

      let oldLaunchpad <- ByteNextLaunchpadINO.launchpads[ByteNextLaunchpadINO.launchpadCount] <- launchpad
      destroy oldLaunchpad

      emit NewLaunchpadCreated(id: ByteNextLaunchpadINO.launchpadCount, totalSell: totalSell, tokenType: tokenType)

      ByteNextLaunchpadINO.launchpadCount = ByteNextLaunchpadINO.launchpadCount + 1;
    }

    pub fun createStageOfLaunchpad(
      launchpadId: UInt64, isPublic: Bool, tokenPerUser: UInt64, acceptingPoint: Bool,
      totalAllocation: UInt64, startTime: UFix64, endTime: UFix64, price: UFix64, paymentType: Type,
      tokenReceiver: Capability<&{FungibleToken.Receiver}>
    ) {
      let launchpad = self.getLaunchpad(launchpadId: launchpadId)
      launchpad.createNewStage(
        launchpadId: launchpadId,
        isPublic: isPublic,
        tokenPerUser: tokenPerUser,
        acceptingPoint: acceptingPoint,
        totalAllocation: totalAllocation,
        startTime: startTime,
        endTime: endTime,
        price: price,
        paymentType: paymentType,
        tokenReceiver: tokenReceiver
      )
    }

    pub fun setTotalSellLaunchpad(launchpadId: UInt64, amount: UInt64) {
      let launchpad = self.getLaunchpad(launchpadId: launchpadId)
      launchpad.setTotalSell(amount: amount)
    }

    pub fun setTypeContract(launchpadId: UInt64, type: Type) {
      let launchpad = self.getLaunchpad(launchpadId: launchpadId)
      launchpad.setTypeContract(type: type)
    }

    pub fun setMintByTemp(launchpadId: UInt64, mintByTemp: Bool) {
      let launchpad = self.getLaunchpad(launchpadId: launchpadId)
      launchpad.setMintByTemp(mintByTemp: mintByTemp)
    }

    pub fun setNFTFormatTemplate(launchpadId: UInt64, nftFormatTemp: NFTFormatTemplate) {
      let launchpad = self.getLaunchpad(launchpadId: launchpadId)
      launchpad.setNFTFormatTemplate(nftFormatTemp: nftFormatTemp)
    }

    pub fun setListNFTForMint(launchpadId: UInt64, tokenIds: [UInt64], metadatas: [{String: String}]) {
      let launchpad = self.getLaunchpad(launchpadId: launchpadId)
      launchpad.setListNFTForMint(tokenIds: tokenIds, metadatas: metadatas)
    }

    pub fun removeNFTForMint(launchpadId: UInt64, tokenIds: [UInt64]) {
      let launchpad = self.getLaunchpad(launchpadId: launchpadId)
      launchpad.removeNFTForMint(tokenIds: tokenIds)
    }

    pub fun setFrozenStage(launchpadId: UInt64, stageId: UInt8) {
      let launchpad = self.getLaunchpad(launchpadId: launchpadId)
      launchpad.setFrozen(stageId: stageId, isFrozen: true);
    }

    pub fun setAcceptingPoint(launchpadId: UInt64, stageId: UInt8, isAccepting: Bool) {
      let launchpad = self.getLaunchpad(launchpadId: launchpadId)
      launchpad.acceptingPoint(stageId: stageId, isAccepting: isAccepting);
    }

    pub fun setTypeStage(launchpadId: UInt64, stageId: UInt8, isPublic: Bool, tokenPerUser: UInt64) {
      let launchpad = self.getLaunchpad(launchpadId: launchpadId)
      launchpad.setTypeStage(stageId: stageId, isPublic: isPublic, tokenPerUser: tokenPerUser)
    }

    pub fun setTotalAllocationStage(launchpadId: UInt64, stageId: UInt8, amount: UInt64) {
      let launchpad = self.getLaunchpad(launchpadId: launchpadId)
      launchpad.setTotalAllocationStage(stageId: stageId, amount: amount)
    }

    pub fun setTimeStage(launchpadId: UInt64, stageId: UInt8, startTime: UFix64, endTime: UFix64) {
      let launchpad = self.getLaunchpad(launchpadId: launchpadId)
      launchpad.setTime(stageId: stageId, startTime: startTime, endTime: endTime)
    }

    pub fun setPriceTokenStage(launchpadId: UInt64, stageId: UInt8, price: UFix64, paymentType: Type) {
      let launchpad = self.getLaunchpad(launchpadId: launchpadId)
      launchpad.setPriceToken(stageId: stageId, price: price, paymentType: paymentType)
    }

    pub fun setUserAllocationStage(launchpadId: UInt64, stageId: UInt8, whitelist : [Whitelist]) {
      let launchpad = self.getLaunchpad(launchpadId: launchpadId)
      launchpad.setUserAllocation(stageId: stageId, whitelist: whitelist)
    }

    pub fun removeUserAllocationStage(launchpadId: UInt64, stageId: UInt8, accounts: [Address]) {
      let launchpad = self.getLaunchpad(launchpadId: launchpadId)
      launchpad.removeUserAllocation(stageId: stageId, accounts: accounts)
    }
  }

  pub resource LaunchpadProxy {

    pub fun swapTicketForPoint(tickets: @[ByteNextMedalNFT.NFT]) {
      var i = 0;
      var totalPointReceive: UInt64 = 0;
      let ticketIds: [UInt64] = [];

      while i < tickets.length {
        let ref = &tickets[i] as &ByteNextMedalNFT.NFT
        let tokenId = ref.id
        let metadata = ref.getMetadata();

        assert(metadata.containsKey("level") , message: "Ticket NFT not found level property");
        assert(ByteNextLaunchpadINO.configTicketPoints.containsKey(metadata["level"]!), message: "Data Ticket not match")

        let pointReceive = ByteNextLaunchpadINO.configTicketPoints[metadata["level"]!];
        totalPointReceive = totalPointReceive + (pointReceive ?? 0);

        ByteNextLaunchpadINO.swapHistory.insert(key: tokenId, self.owner!.address);
        ticketIds.append(tokenId);

        i = i + 1
      }

      let currentPoint = ByteNextLaunchpadINO.userPoints.remove(key: self.owner!.address);
      let amountPoint = (currentPoint ?? 0) + totalPointReceive;
      ByteNextLaunchpadINO.userPoints.insert(key: self.owner!.address, amountPoint);

      emit SwapTicket(tickets: ticketIds, account: self.owner!.address, point: totalPointReceive);
      destroy tickets;
    }

    pub fun registJoin(launchpadId: UInt64, stageId: UInt8) {
      pre {
        ByteNextLaunchpadINO.launchpads.containsKey(launchpadId): "Launchpad is invalid"
        self.owner != nil: "Owner should not be nil"
        ByteNextLaunchpadINO.userPoints[self.owner!.address]! > 0: "Not enough points to participate"
      }
      let launchpad = (&ByteNextLaunchpadINO.launchpads[launchpadId] as &Launchpad?)!;
      launchpad.registJoin(stageId: stageId, user: self.owner!.address)

      emit RegistJoin(launchpadId: launchpadId, stageId: stageId, account: self.owner!.address)
    }

    pub fun join(launchpadId: UInt64, stageId: UInt8, vault: @FungibleToken.Vault, recipient: &{NonFungibleToken.CollectionPublic}) {
      pre {
        ByteNextLaunchpadINO.launchpads.containsKey(launchpadId): "Launchpad is invalid"
        self.owner != nil: "Owner should not be nil"
      }
      let launchpad = (&ByteNextLaunchpadINO.launchpads[launchpadId] as &Launchpad?)!;
      launchpad.join(launchpadId: launchpadId, stageId: stageId, account: self.owner!.address, paymentVault: <- vault, recipient: recipient)
    }
  }

  pub fun getConfigTicketPoint(): {String: UInt64} {
    return self.configTicketPoints;
  }

  pub fun getUserPoint(user: Address): UInt64 {
    if (!self.userPoints.containsKey(user)) {
      return 0;
    }
    return self.userPoints[user]!;
  }

  pub fun borrowLaunchpad(launchpadId: UInt64): &Launchpad{LaunchpadPublic}? {
    if (self.launchpads.containsKey(launchpadId)) {
      return (&self.launchpads[launchpadId] as &Launchpad{LaunchpadPublic}?)!
    }
    return nil;
  }

  pub fun createLaunchpadProxy(): @LaunchpadProxy {
    return  <- create LaunchpadProxy()
  }

  init() {
    self.launchpads <- {};
    self.userPoints = {};
    // default config ticket level 0 = 1 point, level 1 = 2 point, level 2 = 3 point
    self.configTicketPoints = {
      "0": 1,
      "1": 2,
      "2": 3
    };
    self.swapHistory = {};
    self.launchpadCount = 0;

    self.AdminStoragePath = /storage/ByteNextLaunchpadINOAdmin
    self.LaunchpadProxyStoragePath = /storage/ByteNextLaunchpadINOProxy

    let admin <- create Administrator()
    self.account.save(<-admin, to: self.AdminStoragePath)
  }

  pub event SwapTicket(tickets: [UInt64], account: Address, point: UInt64);
  pub event RegistJoin(launchpadId: UInt64, stageId: UInt8, account: Address);

  pub event NewLaunchpadCreated(id: UInt64, totalSell: UInt64, tokenType: Type);
  pub event NewStageCreated(launchpadId: UInt64, id: UInt8, isPublic: Bool, tokenPerUser: UInt64, totalAllocation: UInt64, startTime: UFix64, endTime: UFix64, price: UFix64, paymentType: Type);
  pub event Joined(launchpadId: UInt64, stageId: UInt8, account: Address, tokenQuantity: UInt64, paymentAmount: UFix64);
}
