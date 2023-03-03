/**

# The contract implementation of the lending pool.

# Author: Increment Labs

Core functionalities of the lending pool smart contract supporting cross-market supply, redeem, borrow, repay, and liquidation.
Multiple LendingPool contracts will be deployed for each of the different pooled underlying FungibleTokens.

*/
import FungibleToken from 0xf233dcee88fe0abe
import LendingInterfaces from 0x2df970b6cdee5735
import LendingConfig from 0x2df970b6cdee5735
import LendingError from 0x2df970b6cdee5735

pub contract LendingPool {
    /// Account address the pool is deployed to, i.e. the pool 'contract address'
    pub let poolAddress: Address
    /// Initial exchange rate (when LendingPool.totalSupply == 0) between the virtual lpToken and pool underlying token
    pub let scaledInitialExchangeRate: UInt256
    /// Block number that interest was last accrued at
    pub var accrualBlockNumber: UInt256
    /// Accumulator of the total earned interest rate since the opening of the market, scaled up by 1e18
    pub var scaledBorrowIndex: UInt256
    /// Total amount of outstanding borrows of the underlying in this market, scaled up by 1e18
    pub var scaledTotalBorrows: UInt256
    /// Total amount of reserves of the underlying held in this market, scaled up by 1e18
    pub var scaledTotalReserves: UInt256
    /// Total number of virtual lpTokens, scaled up by 1e18
    pub var scaledTotalSupply: UInt256
    /// Fraction of generated interest added to protocol reserves, scaled up by 1e18
    /// Must be in [0.0, 1.0] x scaleFactor
    pub var scaledReserveFactor: UInt256
    /// Share of seized collateral that is added to reserves when liquidation happenes, e.g. 0.028 x 1e18.
    /// Must be in [0.0, 1.0] x scaleFactor
    pub var scaledPoolSeizeShare: UInt256
    /// { supplierAddress => # of virtual lpToken the supplier owns, scaled up by 1e18 }
    access(self) let accountLpTokens: {Address: UInt256}
    /// Reserved parameter fields: {ParamName: Value}
    access(self) let _reservedFields: {String: AnyStruct}

    /// BorrowSnapshot
    ///
    /// Container for borrow balance information
    ///
    pub struct BorrowSnapshot {
        /// Total balance (with accrued interest), after applying the most recent balance-change action
        pub var scaledPrincipal: UInt256
        /// Global borrowIndex as of the most recent balance-change action
        pub var scaledInterestIndex: UInt256
    
        init(principal: UInt256, interestIndex: UInt256) {
            self.scaledPrincipal = principal
            self.scaledInterestIndex = interestIndex
        }
    }

    // { borrowerAddress => BorrowSnapshot }
    access(self) let accountBorrows: {Address: BorrowSnapshot}

    /// Model used to calculate underlying asset's borrow interest rate
    pub var interestRateModelAddress: Address?
    pub var interestRateModelCap: Capability<&{LendingInterfaces.InterestRateModelPublic}>?
    
    /// The address of the comptroller contract
    pub var comptrollerAddress: Address?
    pub var comptrollerCap: Capability<&{LendingInterfaces.ComptrollerPublic}>?

    /// Save underlying asset deposited into this pool
    access(self) let underlyingVault: @FungibleToken.Vault
    /// Underlying type
    access(self) let underlyingAssetType: Type
    
    /// Path
    pub let PoolAdminStoragePath: StoragePath
    pub let UnderlyingAssetVaultStoragePath: StoragePath
    pub let PoolPublicStoragePath: StoragePath
    pub let PoolPublicPublicPath: PublicPath

    /// Event emitted when interest is accrued
    pub event AccrueInterest(_ scaledCashPrior: UInt256, _ scaledInterestAccumulated: UInt256, _ scaledBorrowIndexNew: UInt256, _ scaledTotalBorrowsNew: UInt256)
    /// Event emitted when underlying asset is deposited into pool
    pub event Supply(supplier: Address, scaledSuppliedUnderlyingAmount: UInt256, scaledMintedLpTokenAmount: UInt256)
    /// Event emitted when virtual lpToken is burnt and redeemed for underlying asset
    pub event Redeem(redeemer: Address, scaledLpTokenToRedeem: UInt256, scaledRedeemedUnderlyingAmount: UInt256)
    /// Event emitted when user borrows underlying from the pool
    pub event Borrow(borrower: Address, scaledBorrowAmount: UInt256, scaledBorrowerTotalBorrows: UInt256, scaledPoolTotalBorrows: UInt256)
    /// Event emitted when user repays underlying to pool
    pub event Repay(borrower: Address, scaledActualRepayAmount: UInt256, scaledBorrowerTotalBorrows: UInt256, scaledPoolTotalBorrows: UInt256)
    /// Event emitted when pool reserves get added
    pub event ReservesAdded(donator: Address, scaledAddedUnderlyingAmount: UInt256, scaledNewTotalReserves: UInt256)
    /// Event emitted when pool reserves is reduced
    pub event ReservesReduced(scaledReduceAmount: UInt256, scaledNewTotalReserves: UInt256)
    /// Event emitted when liquidation happenes
    pub event Liquidate(liquidator: Address, borrower: Address, scaledActualRepaidUnderlying: UInt256, collateralPoolToSeize: Address, scaledCollateralPoolLpTokenSeized: UInt256)
    /// Event emitted when interestRateModel is changed
    pub event NewInterestRateModel(_ oldInterestRateModelAddress: Address?, _ newInterestRateModelAddress: Address)
    /// Event emitted when the reserveFactor is changed
    pub event NewReserveFactor(_ oldReserveFactor: UFix64, _ newReserveFactor: UFix64)
    /// Event emitted when the poolSeizeShare is changed
    pub event NewPoolSeizeShare(_ oldPoolSeizeShare: UFix64, _ newPoolSeizeShare: UFix64)
    /// Event emitted when the comptroller is changed
    pub event NewComptroller(_ oldComptrollerAddress: Address?, _ newComptrollerAddress: Address)

    // Return underlying asset's type of current pool
    pub fun getUnderlyingAssetType(): String {
        return self.underlyingAssetType.identifier
    }

    // Gets current underlying balance of this pool, scaled up by 1e18
    pub fun getPoolCash(): UInt256 {
        return LendingConfig.UFix64ToScaledUInt256(self.underlyingVault.balance)
    }

    /// Cal accrue interest
    ///
    /// @Return 0. currentBlockNumber - The block number of current calculation of interest
    ///         1. scaledBorrowIndexNew - The new accumulator of the total earned interest rate since the opening of the market
    ///         2. scaledTotalBorrowsNew - The new total borrows after accrue interest
    ///         3. scaledTotalReservesNew - The new total reserves after accrue interest
    ///
    /// Calculates interest accrued from the last checkpointed block to the current block 
    /// This function is a readonly function and can be called by scripts.
    ///
    pub fun accrueInterestReadonly(): [UInt256; 4] {
        pre {
            self.interestRateModelCap != nil && self.interestRateModelCap!.check() == true:
                LendingError.ErrorEncode(
                    msg: "Cannot borrow reference to InterestRateModel in pool ".concat(LendingPool.poolAddress.toString()),
                    err: LendingError.ErrorCode.CANNOT_ACCESS_INTEREST_RATE_MODEL_CAPABILITY
                )
        }
        let currentBlockNumber = UInt256(getCurrentBlock().height)
        let accrualBlockNumberPrior = self.accrualBlockNumber
        
        let scaledCashPrior = self.getPoolCash()
        let scaledBorrowPrior = self.scaledTotalBorrows
        let scaledReservesPrior = self.scaledTotalReserves
        let scaledBorrowIndexPrior = self.scaledBorrowIndex

        // Get scaled borrow interest rate per block
        let scaledBorrowRatePerBlock =
            self.interestRateModelCap!.borrow()!.getBorrowRate(cash: scaledCashPrior, borrows: scaledBorrowPrior, reserves: scaledReservesPrior)
        let blockDelta = currentBlockNumber - accrualBlockNumberPrior
        let scaledInterestFactor = scaledBorrowRatePerBlock * blockDelta
        let scaleFactor = LendingConfig.scaleFactor
        let scaledInterestAccumulated = scaledInterestFactor * scaledBorrowPrior / scaleFactor
        let scaledTotalBorrowsNew = scaledInterestAccumulated + scaledBorrowPrior
        let scaledTotalReservesNew = self.scaledReserveFactor * scaledInterestAccumulated / scaleFactor + scaledReservesPrior
        let scaledBorrowIndexNew = scaledInterestFactor * scaledBorrowIndexPrior / scaleFactor + scaledBorrowIndexPrior

        return [
            currentBlockNumber,
            scaledBorrowIndexNew,
            scaledTotalBorrowsNew,
            scaledTotalReservesNew
        ]
    }

    /// Accrue Interest
    ///
    /// Applies accrued interest to total borrows and reserves.
    ///
    pub fun accrueInterest() {
        // Return early if accrue 0 interest
        if (UInt256(getCurrentBlock().height) == self.accrualBlockNumber) {
            return
        }
        let scaledCashPrior = self.getPoolCash()
        let scaledBorrowPrior = self.scaledTotalBorrows
        
        let res = self.accrueInterestReadonly()
        
        // Write calculated values into contract storage
        self.accrualBlockNumber = res[0]
        self.scaledBorrowIndex = res[1]
        self.scaledTotalBorrows = res[2]
        self.scaledTotalReserves = res[3]

        emit AccrueInterest(scaledCashPrior, res[2]-scaledBorrowPrior, self.scaledBorrowIndex, self.scaledTotalBorrows)
    }

    /// Calculates the exchange rate from the underlying to virtual lpToken (i.e. how many UnderlyingToken per virtual lpToken)
    /// Note: It doesn't call accrueInterest() first to update with latest states which is used in calculating the exchange rate.
    ///
    pub fun underlyingToLpTokenRateSnapshotScaled(): UInt256 {
        if (self.scaledTotalSupply == 0) {
            return self.scaledInitialExchangeRate
        } else {
            return (self.getPoolCash() + self.scaledTotalBorrows - self.scaledTotalReserves) * LendingConfig.scaleFactor / self.scaledTotalSupply
        }
    }

    /// Calculates the scaled borrow balance of borrower address based on stored states
    /// Note: It doesn't call accrueInterest() first to update with latest states which is used in calculating the borrow balance.
    ///
    pub fun borrowBalanceSnapshotScaled(borrowerAddress: Address): UInt256 {
        if (self.accountBorrows.containsKey(borrowerAddress) == false) {
            return 0
        }
        let borrower = self.accountBorrows[borrowerAddress]!
        return borrower.scaledPrincipal * self.scaledBorrowIndex / borrower.scaledInterestIndex
    }

    /// Supplier deposits underlying asset's Vault into the pool.
    ///
    /// @Param SupplierAddr - The address of the account which is supplying the assets
    /// @Param InUnderlyingVault - The vault for deposit and its type should match the pool's underlying token type 
    ///
    /// Interest will be accrued up to the current block.
    /// The lending pool will mint the corresponding lptoken according to the current
    /// exchange rate of lptoken as the user's deposit certificate and save it in the contract.
    /// 
    pub fun supply(supplierAddr: Address, inUnderlyingVault: @FungibleToken.Vault) {
        pre {
            inUnderlyingVault.balance > 0.0: 
                LendingError.ErrorEncode(msg: "Supplied zero", err: LendingError.ErrorCode.EMPTY_FUNGIBLE_TOKEN_VAULT)
            inUnderlyingVault.isInstance(self.underlyingAssetType):
                LendingError.ErrorEncode(
                    msg: "Supplied vault and pool underlying type mismatch",
                    err: LendingError.ErrorCode.MISMATCHED_INPUT_VAULT_TYPE_WITH_POOL
                )
        }
        // 1. Accrues interests and checkpoints latest states
        self.accrueInterest()

        // 2. Check whether or not supplyAllowed()
        let scaledAmount = LendingConfig.UFix64ToScaledUInt256(inUnderlyingVault.balance)
        let err = self.comptrollerCap!.borrow()!.supplyAllowed(
            poolCertificate: <- create PoolCertificate(),
            poolAddress: self.poolAddress,
            supplierAddress: supplierAddr,
            supplyUnderlyingAmountScaled: scaledAmount
        )
        assert(err == nil, message: err ?? "")
        
        // 3. Deposit into underlying vault and mint corresponding PoolTokens 
        let underlyingToken2LpTokenRateScaled = self.underlyingToLpTokenRateSnapshotScaled()
        let scaledMintVirtualAmount = scaledAmount * LendingConfig.scaleFactor / underlyingToken2LpTokenRateScaled
        // mint pool tokens for supply certificate
        self.accountLpTokens[supplierAddr] = scaledMintVirtualAmount + (self.accountLpTokens[supplierAddr] ?? (0 as UInt256))
        self.scaledTotalSupply = self.scaledTotalSupply + scaledMintVirtualAmount
        self.underlyingVault.deposit(from: <-inUnderlyingVault)

        emit Supply(supplier: supplierAddr, scaledSuppliedUnderlyingAmount: scaledAmount, scaledMintedLpTokenAmount: scaledMintVirtualAmount)
    }

    /// Redeems lpTokens for the underlying asset's vault
    /// or
    /// Redeems lpTokens for a specified amount of underlying asset
    ///
    /// @Param redeemer - The address of the account which is redeeming the tokens
    /// @Param numLpTokenToRedeem - The number of lpTokens to redeem into underlying (only one of numLpTokenToRedeem or numUnderlyingToRedeem may be non-zero)
    /// @Param numUnderlyingToRedeem - The amount of underlying to receive from redeeming lpTokens
    /// @Return The redeemed vault resource of pool's underlying token
    ///
    /// Since redeemer decreases his overall collateral ratio across all markets, safety check happenes inside comptroller.
    ///
    access(self) fun redeemInternal(
        redeemer: Address,
        numLpTokenToRedeem: UFix64,
        numUnderlyingToRedeem: UFix64
    ): @FungibleToken.Vault {
        pre {
            numLpTokenToRedeem == 0.0 || numUnderlyingToRedeem == 0.0:
                LendingError.ErrorEncode(
                    msg: "numLpTokenToRedeem or numUnderlyingToRedeem must be 0.0.",
                    err: LendingError.ErrorCode.INVALID_PARAMETERS
                )
            self.accountLpTokens.containsKey(redeemer):
                LendingError.ErrorEncode(
                    msg: "redeemer has no supply to redeem from",
                    err: LendingError.ErrorCode.REDEEM_FAILED_NO_ENOUGH_LP_TOKEN
                )
        }

        // 1. Accrues interests and checkpoints latest states
        self.accrueInterest()

        // 2. Check whether or not redeemAllowed()
        var scaledLpTokenToRedeem: UInt256 = 0
        var scaledUnderlyingToRedeem: UInt256 = 0
        let scaledUnderlyingToLpRate = self.underlyingToLpTokenRateSnapshotScaled()
        let scaleFactor = LendingConfig.scaleFactor
        if (numLpTokenToRedeem == 0.0) {
            // redeem all
            // the special value of `UFIx64.max` indicating to redeem all virtual LP tokens the redeemer has
            if numUnderlyingToRedeem == UFix64.max {
                scaledLpTokenToRedeem = self.accountLpTokens[redeemer]!
                scaledUnderlyingToRedeem = scaledLpTokenToRedeem * scaledUnderlyingToLpRate / scaleFactor
            } else {
                scaledLpTokenToRedeem = LendingConfig.UFix64ToScaledUInt256(numUnderlyingToRedeem) * scaleFactor / scaledUnderlyingToLpRate
                scaledUnderlyingToRedeem = LendingConfig.UFix64ToScaledUInt256(numUnderlyingToRedeem)
            }
        } else {
            if numLpTokenToRedeem == UFix64.max {
                scaledLpTokenToRedeem = self.accountLpTokens[redeemer]!
            } else {
                scaledLpTokenToRedeem = LendingConfig.UFix64ToScaledUInt256(numLpTokenToRedeem)
            }
            scaledUnderlyingToRedeem = scaledLpTokenToRedeem * scaledUnderlyingToLpRate / scaleFactor
        }

        assert(scaledLpTokenToRedeem <= self.accountLpTokens[redeemer]!, message: 
            LendingError.ErrorEncode(
                msg: "exceeded redeemer lp token balance",
                err: LendingError.ErrorCode.REDEEM_FAILED_NO_ENOUGH_LP_TOKEN
            )
        )

        let err = self.comptrollerCap!.borrow()!.redeemAllowed(
            poolCertificate: <- create PoolCertificate(),
            poolAddress: self.poolAddress,
            redeemerAddress: redeemer,
            redeemLpTokenAmountScaled: scaledLpTokenToRedeem,
        )
        assert(err == nil, message: err ?? "")
        
        // 3. Burn virtual lpTokens, withdraw from underlying vault and return it
        assert(scaledUnderlyingToRedeem <= self.getPoolCash(), message:
            LendingError.ErrorEncode(
                msg: "insufficient pool liquidity to redeem",
                err: LendingError.ErrorCode.INSUFFICIENT_POOL_LIQUIDITY
            )
        )

        self.scaledTotalSupply = self.scaledTotalSupply - scaledLpTokenToRedeem
        if (self.accountLpTokens[redeemer] == scaledLpTokenToRedeem) {
            self.accountLpTokens.remove(key: redeemer)
        } else {
            self.accountLpTokens[redeemer] = self.accountLpTokens[redeemer]! - scaledLpTokenToRedeem
        }
        emit Redeem(
            redeemer: redeemer,
            scaledLpTokenToRedeem: scaledLpTokenToRedeem,
            scaledRedeemedUnderlyingAmount: scaledUnderlyingToRedeem
        )
        let amountUnderlyingToRedeem = LendingConfig.ScaledUInt256ToUFix64(scaledUnderlyingToRedeem)
        return <- self.underlyingVault.withdraw(amount: amountUnderlyingToRedeem)
    }

    /// User redeems lpTokens for the underlying asset's vault
    ///
    /// @Param userCertificateCap - User identity certificate and it can provide a valid user address proof
    /// @Param numLpTokenToRedeem - The number of lpTokens to redeem into underlying
    /// @Return The redeemed vault resource of pool's underlying token
    ///
    /// @Notice It is more convenient to use a resource certificate on flow for authentication than signing a signature.
    ///
    /// RedeemerAddress is inferred from the private capability to the IdentityCertificate resource,
    /// which is stored in user account and can only be given by its owner.
    /// The special value of numLpTokenToRedeem `UFIx64.max` indicating to redeem all virtual LP tokens the redeemer has.
    ///
    pub fun redeem(
        userCertificateCap: Capability<&{LendingInterfaces.IdentityCertificate}>,
        numLpTokenToRedeem: UFix64
    ): @FungibleToken.Vault {
        pre {
            numLpTokenToRedeem > 0.0: LendingError.ErrorEncode(msg: "Redeemed zero", err: LendingError.ErrorCode.INVALID_PARAMETERS)
            userCertificateCap.check() && userCertificateCap.borrow()!.owner != nil:
                LendingError.ErrorEncode(
                    msg: "Cannot borrow reference to IdentityCertificate",
                    err: LendingError.ErrorCode.INVALID_USER_CERTIFICATE
                )
            self.checkUserCertificateType(certCap: userCertificateCap):
                LendingError.ErrorEncode(
                    msg: "Certificate not issued by system",
                    err: LendingError.ErrorCode.INVALID_USER_CERTIFICATE
                )
        }
        let redeemerAddress = userCertificateCap.borrow()!.owner!.address
        return <- self.redeemInternal(
            redeemer: redeemerAddress,
            numLpTokenToRedeem: numLpTokenToRedeem,
            numUnderlyingToRedeem: 0.0
        )
    }

    /// User redeems lpTokens for a specified amount of underlying asset
    ///
    /// @Param userCertificateCap - User identity certificate and it can provide a valid user address proof        
    /// @Param numUnderlyingToRedeem - The amount of underlying to receive from redeeming lpTokens
    /// @Return The redeemed vault resource of pool's underlying token
    ///
    /// @Notice It is more convenient to use a resource certificate on flow for authentication than signing a signature.
    ///
    /// RedeemerAddress is inferred from the private capability to the IdentityCertificate resource,
    /// which is stored in user account and can only be given by its owner.
    /// The special value of numUnderlyingToRedeem `UFIx64.max` indicating to redeem all the underlying liquidity.
    ///
    pub fun redeemUnderlying(
        userCertificateCap: Capability<&{LendingInterfaces.IdentityCertificate}>,
        numUnderlyingToRedeem: UFix64
    ): @FungibleToken.Vault {
        pre {
            numUnderlyingToRedeem > 0.0: LendingError.ErrorEncode(msg: "Redeemed zero", err: LendingError.ErrorCode.INVALID_PARAMETERS)
            userCertificateCap.check() && userCertificateCap.borrow()!.owner != nil:
                LendingError.ErrorEncode(
                    msg: "Cannot borrow reference to IdentityCertificate",
                    err: LendingError.ErrorCode.INVALID_USER_CERTIFICATE
                )
            self.checkUserCertificateType(certCap: userCertificateCap):
                LendingError.ErrorEncode(
                    msg: "Certificate not issued by system",
                    err: LendingError.ErrorCode.INVALID_USER_CERTIFICATE
                )
        }
        let redeemerAddress = userCertificateCap.borrow()!.owner!.address
        return <- self.redeemInternal(
            redeemer: redeemerAddress,
            numLpTokenToRedeem: 0.0,
            numUnderlyingToRedeem: numUnderlyingToRedeem
        )
    }

    /// User borrows underlying asset from the pool.
    ///
    /// @Param userCertificateCap - User identity certificate and it can provide a valid user address proof        
    /// @Param borrowAmount - The amount of the underlying asset to borrow
    /// @Return The vault of borrow asset
    ///
    /// @Notice It is more convenient to use a resource certificate on flow for authentication than signing a signature.
    ///
    /// Since borrower would decrease his overall collateral ratio across all markets, safety check happenes inside comptroller
    ///
    pub fun borrow(
        userCertificateCap: Capability<&{LendingInterfaces.IdentityCertificate}>,
        borrowAmount: UFix64,
    ): @FungibleToken.Vault {
        pre {
            borrowAmount > 0.0: LendingError.ErrorEncode(msg: "borrowAmount zero", err: LendingError.ErrorCode.INVALID_PARAMETERS)
            userCertificateCap.check() && userCertificateCap.borrow()!.owner != nil:
                LendingError.ErrorEncode(
                    msg: "Cannot borrow reference to IdentityCertificate",
                    err: LendingError.ErrorCode.INVALID_USER_CERTIFICATE
                )
            self.checkUserCertificateType(certCap: userCertificateCap):
                LendingError.ErrorEncode(
                    msg: "Certificate not issued by system",
                    err: LendingError.ErrorCode.INVALID_USER_CERTIFICATE
                )
        }
        // 1. Accrues interests and checkpoints latest states
        self.accrueInterest()

        // 2. Pool liquidity check
        let scaledBorrowAmount = LendingConfig.UFix64ToScaledUInt256(borrowAmount)
        assert(scaledBorrowAmount <= self.getPoolCash(), message:
            LendingError.ErrorEncode(
                msg: "insufficient pool liquidity to borrow",
                err: LendingError.ErrorCode.INSUFFICIENT_POOL_LIQUIDITY
            )
        )

        // 3. Check whether or not borrowAllowed()
        let borrower = userCertificateCap.borrow()!.owner!.address
        let err = self.comptrollerCap!.borrow()!.borrowAllowed(
            poolCertificate: <- create PoolCertificate(),
            poolAddress: self.poolAddress,
            borrowerAddress: borrower,
            borrowUnderlyingAmountScaled: scaledBorrowAmount
        )
        assert(err == nil, message: err ?? "")
        
        // 4. Updates borrow states, withdraw from pool underlying vault and deposits into borrower's account
        self.scaledTotalBorrows = self.scaledTotalBorrows + scaledBorrowAmount
        let scaledBorrowBalanceNew = scaledBorrowAmount + self.borrowBalanceSnapshotScaled(borrowerAddress: borrower)
        self.accountBorrows[borrower] = BorrowSnapshot(principal: scaledBorrowBalanceNew, interestIndex: self.scaledBorrowIndex)
        emit Borrow(borrower: borrower, scaledBorrowAmount: scaledBorrowAmount, scaledBorrowerTotalBorrows: scaledBorrowBalanceNew, scaledPoolTotalBorrows: self.scaledTotalBorrows)
        return <- self.underlyingVault.withdraw(amount: borrowAmount)
    }

    /// Repay the borrower's borrow
    ///
    /// @Param borrower - The address of the borrower
    /// @Param borrowAmount - The amount to repay
    /// @Return The overpaid vault will be returned.
    ///
    /// @Note: Caller ensures that LendingPool.accrueInterest() has been called with latest states checkpointed
    ///
    access(self) fun repayBorrowInternal(borrower: Address, repayUnderlyingVault: @FungibleToken.Vault): @FungibleToken.Vault? {
        // Check whether or not repayAllowed()
        let scaledRepayAmount = LendingConfig.UFix64ToScaledUInt256(repayUnderlyingVault.balance)
        let scaledAccountTotalBorrows = self.borrowBalanceSnapshotScaled(borrowerAddress: borrower)
        let scaledActualRepayAmount = scaledAccountTotalBorrows > scaledRepayAmount ? scaledRepayAmount : scaledAccountTotalBorrows
        
        let err = self.comptrollerCap!.borrow()!.repayAllowed(
            poolCertificate: <- create PoolCertificate(),
            poolAddress: self.poolAddress,
            borrowerAddress: borrower,
            repayUnderlyingAmountScaled: scaledActualRepayAmount
        )
        assert(err == nil, message: err ?? "")
        
        // Updates borrow states, deposit repay Vault into pool underlying vault and return any remaining Vault
        let scaledAccountTotalBorrowsNew = scaledAccountTotalBorrows > scaledRepayAmount ? scaledAccountTotalBorrows - scaledRepayAmount : (0 as UInt256)
        self.scaledTotalBorrows = self.scaledTotalBorrows - scaledActualRepayAmount
        emit Repay(borrower: borrower, scaledActualRepayAmount: scaledActualRepayAmount, scaledBorrowerTotalBorrows: scaledAccountTotalBorrowsNew, scaledPoolTotalBorrows: self.scaledTotalBorrows)
        if (scaledAccountTotalBorrows > scaledRepayAmount) {
            self.accountBorrows[borrower] = BorrowSnapshot(principal: scaledAccountTotalBorrowsNew, interestIndex: self.scaledBorrowIndex)
            self.underlyingVault.deposit(from: <-repayUnderlyingVault)
            return nil
        } else {
            self.accountBorrows.remove(key: borrower)
            let surplusAmount = LendingConfig.ScaledUInt256ToUFix64(scaledRepayAmount - scaledAccountTotalBorrows)
            self.underlyingVault.deposit(from: <-repayUnderlyingVault)
            return <- self.underlyingVault.withdraw(amount: surplusAmount)
        }
    }

    /// Anyone can repay borrow with a underlying Vault and receives a new underlying Vault if there's still any remaining left.
    ///
    /// @Param borrower - The address of the borrower
    /// @Param borrowAmount - The amount to repay
    /// @Return The overpaid vault will be returned.
    ///
    /// @Note: Note that the borrower address can potentially not be the same as the repayer address (which means someone can repay on behave of borrower),
    ///        this is allowed as there's no safety issue to do so.
    ///
    pub fun repayBorrow(borrower: Address, repayUnderlyingVault: @FungibleToken.Vault): @FungibleToken.Vault? {
        pre {
            repayUnderlyingVault.balance > 0.0: LendingError.ErrorEncode(msg: "Repaid zero", err: LendingError.ErrorCode.EMPTY_FUNGIBLE_TOKEN_VAULT)
            repayUnderlyingVault.isInstance(self.underlyingAssetType):
                LendingError.ErrorEncode(
                    msg: "Repaid vault and pool underlying type mismatch",
                    err: LendingError.ErrorCode.MISMATCHED_INPUT_VAULT_TYPE_WITH_POOL
                )
        }
        // Accrues interests and checkpoints latest states
        self.accrueInterest()

        return <- self.repayBorrowInternal(borrower: borrower, repayUnderlyingVault: <-repayUnderlyingVault)
    }

    /// Liquidates the borrowers collateral.
    ///
    /// @Param liquidator - The address of the liquidator who will receive the collateral lpToken transfer
    /// @Param borrower - The borrower to be liquidated
    /// @Param poolCollateralizedToSeize - The market address in which to seize collateral from the borrower
    /// @Param repayUnderlyingVault - The amount of the underlying borrowed asset in this pool to repay
    /// @Return The overLiquidate vault will be returned.
    ///
    /// The collateral lpTokens seized is transferred to the liquidator.
    ///
    pub fun liquidate(
        liquidator: Address,
        borrower: Address,
        poolCollateralizedToSeize: Address,
        repayUnderlyingVault: @FungibleToken.Vault
    ): @FungibleToken.Vault? {
        pre {
            repayUnderlyingVault.balance > 0.0: LendingError.ErrorEncode(msg: "Liquidator repaid zero", err: LendingError.ErrorCode.EMPTY_FUNGIBLE_TOKEN_VAULT)
            repayUnderlyingVault.isInstance(self.underlyingAssetType):
                LendingError.ErrorEncode(
                    msg: "Liquidator repaid vault and pool underlying type mismatch",
                    err: LendingError.ErrorCode.MISMATCHED_INPUT_VAULT_TYPE_WITH_POOL
                )
        }
        // 1. Accrues interests and checkpoints latest states
        self.accrueInterest()

        // 2. Check whether or not liquidateAllowed()
        let scaledUnderlyingAmountToRepay = LendingConfig.UFix64ToScaledUInt256(repayUnderlyingVault.balance)
        let err = self.comptrollerCap!.borrow()!.liquidateAllowed(
            poolCertificate: <- create PoolCertificate(),
            poolBorrowed: self.poolAddress,
            poolCollateralized: poolCollateralizedToSeize,
            borrower: borrower,
            repayUnderlyingAmountScaled: scaledUnderlyingAmountToRepay
        )
        assert(err == nil, message: err ?? "")

        // 3. Liquidator repays on behave of borrower
        assert(liquidator != borrower, message:
            LendingError.ErrorEncode(
                msg: "liquidator and borrower cannot be the same",
                err: LendingError.ErrorCode.SAME_LIQUIDATOR_AND_BORROWER
            )
        )
        let remainingVault <- self.repayBorrowInternal(borrower: borrower, repayUnderlyingVault: <-repayUnderlyingVault)

        let scaledRemainingAmount = LendingConfig.UFix64ToScaledUInt256(remainingVault?.balance ?? 0.0)
        let scaledActualRepayAmount = scaledUnderlyingAmountToRepay - scaledRemainingAmount
        // Calculate collateralLpTokenSeizedAmount based on actualRepayAmount
        let scaledCollateralLpTokenSeizedAmount = self.comptrollerCap!.borrow()!.calculateCollateralPoolLpTokenToSeize(
            borrower: borrower,
            borrowPool: self.poolAddress,
            collateralPool: poolCollateralizedToSeize,
            actualRepaidBorrowAmountScaled: scaledActualRepayAmount
        )

        // 4. seizeInternal if current pool is also borrower's collateralPool; otherwise seize external collateralPool
        if (poolCollateralizedToSeize == self.poolAddress) {
            self.seizeInternal(
                liquidator: liquidator,
                borrower: borrower,
                scaledBorrowerLpTokenToSeize: scaledCollateralLpTokenSeizedAmount
            )
        } else {
            // Seize external
            let externalPoolPublicRef = getAccount(poolCollateralizedToSeize)
                .getCapability<&{LendingInterfaces.PoolPublic}>(LendingConfig.PoolPublicPublicPath).borrow() 
                    ?? panic(
                        LendingError.ErrorEncode(
                            msg: "Cannot borrow reference to external PoolPublic resource",
                            err: LendingError.ErrorCode.CANNOT_ACCESS_POOL_PUBLIC_CAPABILITY
                        ) 
                    )
            externalPoolPublicRef.seize(
                seizerPoolCertificate: <- create PoolCertificate(),
                seizerPool: self.poolAddress,
                liquidator: liquidator,
                borrower: borrower,
                scaledBorrowerCollateralLpTokenToSeize: scaledCollateralLpTokenSeizedAmount
            )
        }

        emit Liquidate(
            liquidator: liquidator,
            borrower: borrower,
            scaledActualRepaidUnderlying: scaledActualRepayAmount,
            collateralPoolToSeize: poolCollateralizedToSeize,
            scaledCollateralPoolLpTokenSeized: scaledCollateralLpTokenSeizedAmount
        )
        return <-remainingVault
    }

    /// External seize, transfers collateral tokens (this market) to the liquidator.
    ///
    /// @Param seizerPoolCertificate - Pool's certificate guarantee that this interface can only be called by other valid markets
    /// @Param seizerPool - The external pool seizing the current collateral pool (i.e. borrowPool)
    /// @Param liquidator - The address of the liquidator who will receive the collateral lpToken transfer
    /// @Param borrower - The borrower to be liquidated
    /// @Param scaledBorrowerCollateralLpTokenToSeize - The amount of collateral lpTokens that will be seized from borrower to liquidator
    ///
    /// Only used for "external" seize. Run-time type check of pool certificate ensures it can only be called by other supported markets.
    ///
    pub fun seize(
        seizerPoolCertificate: @{LendingInterfaces.IdentityCertificate},
        seizerPool: Address,
        liquidator: Address,
        borrower: Address,
        scaledBorrowerCollateralLpTokenToSeize: UInt256
    ) {
        pre {
            seizerPool != self.poolAddress:
                LendingError.ErrorEncode(
                    msg: "External seize only, seizerPool cannot be current pool",
                    err: LendingError.ErrorCode.EXTERNAL_SEIZE_FROM_SELF
                )
        }
        // 1. Check and verify caller from another LendingPool contract
        let err = self.comptrollerCap!.borrow()!.callerAllowed(
            callerCertificate: <- seizerPoolCertificate,
            callerAddress: seizerPool
        )
        assert(err == nil, message: err ?? "")

        // 2. Accrues interests and checkpoints latest states
        self.accrueInterest()

        // 3. seizeInternal
        self.seizeInternal(
            liquidator: liquidator,
            borrower: borrower,
            scaledBorrowerLpTokenToSeize: scaledBorrowerCollateralLpTokenToSeize
        )
    }

    /// Internal seize
    ///
    /// @Param liquidator - The address of the liquidator who will receive the collateral lpToken transfer
    /// @Param borrower - The borrower to be liquidated
    /// @Param scaledBorrowerLpTokenToSeize - The amount of collateral lpTokens that will be seized from borrower to liquidator
    ///
    /// Caller ensures accrueInterest() has been called
    ///
    access(self) fun seizeInternal(
        liquidator: Address,
        borrower: Address,
        scaledBorrowerLpTokenToSeize: UInt256
    ) {
        pre {
            liquidator != borrower:
                LendingError.ErrorEncode(
                    msg: "seize: liquidator == borrower",
                    err: LendingError.ErrorCode.SAME_LIQUIDATOR_AND_BORROWER
                )
        }
        
        let err = self.comptrollerCap!.borrow()!.seizeAllowed(
            poolCertificate: <- create PoolCertificate(),
            borrowPool: self.poolAddress,
            collateralPool: self.poolAddress,
            liquidator: liquidator,
            borrower: borrower,
            seizeCollateralPoolLpTokenAmountScaled: scaledBorrowerLpTokenToSeize
        )
        assert(err == nil, message: err ?? "")

        let scaleFactor = LendingConfig.scaleFactor
        let scaledProtocolSeizedLpTokens = scaledBorrowerLpTokenToSeize * self.scaledPoolSeizeShare / scaleFactor
        let scaledLiquidatorSeizedLpTokens = scaledBorrowerLpTokenToSeize - scaledProtocolSeizedLpTokens
        let scaledUnderlyingToLpTokenRate = self.underlyingToLpTokenRateSnapshotScaled()
        let scaledAddedUnderlyingReserves = scaledUnderlyingToLpTokenRate * scaledProtocolSeizedLpTokens / scaleFactor
        self.scaledTotalReserves = self.scaledTotalReserves + scaledAddedUnderlyingReserves
        self.scaledTotalSupply = self.scaledTotalSupply - scaledProtocolSeizedLpTokens
        // in-place liquidation: only virtual lpToken records get updated, no token deposit / withdraw needs to happen
        if (self.accountLpTokens[borrower] == scaledBorrowerLpTokenToSeize) {
            self.accountLpTokens.remove(key: borrower)
        } else {
            self.accountLpTokens[borrower] = self.accountLpTokens[borrower]! - scaledBorrowerLpTokenToSeize
        }
        self.accountLpTokens[liquidator] = scaledLiquidatorSeizedLpTokens + (self.accountLpTokens[liquidator] ?? (0 as UInt256))

        emit ReservesAdded(donator: self.poolAddress, scaledAddedUnderlyingAmount: scaledAddedUnderlyingReserves, scaledNewTotalReserves: self.scaledTotalReserves)
    }

    /// Check whether or not the given certificate is issued by system
    ///
    access(self) fun checkUserCertificateType(certCap: Capability<&{LendingInterfaces.IdentityCertificate}>): Bool {
        return certCap.borrow()!.isInstance(self.comptrollerCap!.borrow()!.getUserCertificateType())
    }

    /// PoolCertificate
    ///
    /// Inherited from IdentityCertificate.
    /// Proof of identity for the pool.
    ///
    pub resource PoolCertificate: LendingInterfaces.IdentityCertificate {}

    /// PoolPublic
    ///
    /// The external interfaces of the pool, and will be exposed as a public capability.
    ///
    pub resource PoolPublic: LendingInterfaces.PoolPublic {

        pub fun getPoolAddress(): Address {
            return LendingPool.poolAddress
        }

        pub fun getUnderlyingTypeString(): String {
            let underlyingType = LendingPool.getUnderlyingAssetType()
            // "A.1654653399040a61.FlowToken.Vault" => "FlowToken"
            return underlyingType.slice(from: 19, upTo: underlyingType.length - 6)
        }

        pub fun getUnderlyingToLpTokenRateScaled(): UInt256 {
            return LendingPool.underlyingToLpTokenRateSnapshotScaled()
        }

        pub fun getAccountLpTokenBalanceScaled(account: Address): UInt256 {
            return LendingPool.accountLpTokens[account] ?? (0 as UInt256)
        }

        pub fun getAccountBorrowBalanceScaled(account: Address): UInt256 {
            return LendingPool.borrowBalanceSnapshotScaled(borrowerAddress: account)
        }

        pub fun getAccountBorrowPrincipalSnapshotScaled(account: Address): UInt256 {
            if (LendingPool.accountBorrows.containsKey(account) == false) {
                return 0
            } else {
                return LendingPool.accountBorrows[account]!.scaledPrincipal
            }
        }

        pub fun getAccountBorrowIndexSnapshotScaled(account: Address): UInt256 {
            if (LendingPool.accountBorrows.containsKey(account) == false) {
                return 0
            } else {
                return LendingPool.accountBorrows[account]!.scaledInterestIndex
            }
        }

        pub fun getAccountSnapshotScaled(account: Address): [UInt256; 5] {
            return [
                self.getUnderlyingToLpTokenRateScaled(),
                self.getAccountLpTokenBalanceScaled(account: account),
                self.getAccountBorrowBalanceScaled(account: account),
                self.getAccountBorrowPrincipalSnapshotScaled(account: account),
                self.getAccountBorrowIndexSnapshotScaled(account: account)
            ]
        }

        pub fun getAccountRealtimeScaled(account: Address): [UInt256; 5] {
            let accrueInterestRealtimeRes = self.accrueInterestReadonly()
            let poolBorrowIndexRealtime = accrueInterestRealtimeRes[1]
            let poolTotalBorrowRealtime = accrueInterestRealtimeRes[2]
            let poolTotalReserveRealtime = accrueInterestRealtimeRes[3]

            let underlyingTolpTokenRateRealtime = (LendingPool.getPoolCash() + poolTotalBorrowRealtime - poolTotalReserveRealtime) * LendingConfig.scaleFactor / LendingPool.scaledTotalSupply
            
            var borrowBalanceRealtimeScaled:UInt256 = 0
            if (LendingPool.accountBorrows.containsKey(account)) {
                borrowBalanceRealtimeScaled = self.getAccountBorrowPrincipalSnapshotScaled(account: account) * poolBorrowIndexRealtime / self.getAccountBorrowIndexSnapshotScaled(account: account)
            }

            return [
                underlyingTolpTokenRateRealtime,
                self.getAccountLpTokenBalanceScaled(account: account),
                borrowBalanceRealtimeScaled,
                self.getAccountBorrowPrincipalSnapshotScaled(account: account),
                self.getAccountBorrowIndexSnapshotScaled(account: account)
            ]
        }

        pub fun getPoolReserveFactorScaled(): UInt256 {
            return LendingPool.scaledReserveFactor
        }

        pub fun getInterestRateModelAddress(): Address {
            return LendingPool.interestRateModelAddress!
        }

        pub fun getPoolTotalBorrowsScaled(): UInt256 {
            return LendingPool.scaledTotalBorrows
        }

        pub fun getPoolAccrualBlockNumber(): UInt256 {
            return LendingPool.accrualBlockNumber
        }

        pub fun getPoolBorrowIndexScaled(): UInt256 {
            return LendingPool.scaledBorrowIndex
        }

        pub fun getPoolTotalLpTokenSupplyScaled(): UInt256 {
            return LendingPool.scaledTotalSupply
        }

        pub fun getPoolTotalSupplyScaled(): UInt256 {
            return LendingPool.getPoolCash() + LendingPool.scaledTotalBorrows
        }

        pub fun getPoolTotalReservesScaled(): UInt256 {
            return LendingPool.scaledTotalReserves
        }

        pub fun getPoolCash(): UInt256 {
            return LendingPool.getPoolCash()
        }

        pub fun getPoolSupplierCount(): UInt256 {
            return UInt256(LendingPool.accountLpTokens.length)
        }

        pub fun getPoolBorrowerCount(): UInt256 {
            return UInt256(LendingPool.accountBorrows.length)
        }

        pub fun getPoolSupplierList(): [Address] {
            return LendingPool.accountLpTokens.keys
        }

        pub fun getPoolSupplierSlicedList(from: UInt64, to: UInt64): [Address] {
            pre {
                from <= to && to < UInt64(LendingPool.accountLpTokens.length):
                    LendingError.ErrorEncode(
                        msg: "Index out of range",
                        err: LendingError.ErrorCode.INVALID_PARAMETERS
                    )
            }
            let borrowers: &[Address] = &LendingPool.accountLpTokens.keys as &[Address]
            let list: [Address] = []
            var i = from
            while i <= to {
                list.append(borrowers[i])
                i = i + 1
            }
            return list
        }

        pub fun getPoolBorrowerList(): [Address] {
            return LendingPool.accountBorrows.keys
        }

        pub fun getPoolBorrowerSlicedList(from: UInt64, to: UInt64): [Address] {
            pre {
                from <= to && to < UInt64(LendingPool.accountBorrows.length):
                    LendingError.ErrorEncode(
                        msg: "Index out of range",
                        err: LendingError.ErrorCode.INVALID_PARAMETERS
                    )
            }
            let borrowers: &[Address] = &LendingPool.accountBorrows.keys as &[Address]
            let list: [Address] = []
            var i = from
            while i <= to {
                list.append(borrowers[i])
                i = i + 1
            }
            return list
        }

        pub fun getPoolBorrowRateScaled(): UInt256 {
            return LendingPool.interestRateModelCap!.borrow()!.getBorrowRate(
                cash: LendingPool.getPoolCash(),
                borrows: LendingPool.scaledTotalBorrows,
                reserves: LendingPool.scaledTotalReserves
            )
        }

        pub fun getPoolBorrowAprScaled(): UInt256 {
            let scaledBorrowRatePerBlock =
                LendingPool.interestRateModelCap!.borrow()!.getBorrowRate(
                    cash: LendingPool.getPoolCash(),
                    borrows: LendingPool.scaledTotalBorrows,
                    reserves: LendingPool.scaledTotalReserves
                )
            let blocksPerYear = LendingPool.interestRateModelCap!.borrow()!.getBlocksPerYear()
            return scaledBorrowRatePerBlock * blocksPerYear
        }

        pub fun getPoolSupplyAprScaled(): UInt256 {
            let scaledSupplyRatePerBlock =
                LendingPool.interestRateModelCap!.borrow()!.getSupplyRate(
                    cash: LendingPool.getPoolCash(),
                    borrows: LendingPool.scaledTotalBorrows,
                    reserves: LendingPool.scaledTotalReserves,
                    reserveFactor: LendingPool.scaledReserveFactor
                )
            let blocksPerYear = LendingPool.interestRateModelCap!.borrow()!.getBlocksPerYear()
            return scaledSupplyRatePerBlock * blocksPerYear
        }

        pub fun accrueInterest() {
            LendingPool.accrueInterest()
        }

        pub fun accrueInterestReadonly(): [UInt256; 4] {
            return LendingPool.accrueInterestReadonly()
        }

        pub fun getPoolCertificateType(): Type {
            return Type<@LendingPool.PoolCertificate>()
        }

        pub fun seize(
            seizerPoolCertificate: @{LendingInterfaces.IdentityCertificate},
            seizerPool: Address,
            liquidator: Address,
            borrower: Address,
            scaledBorrowerCollateralLpTokenToSeize: UInt256
        ) {
            LendingPool.seize(
                seizerPoolCertificate: <- seizerPoolCertificate,
                seizerPool: seizerPool,
                liquidator: liquidator,
                borrower: borrower,
                scaledBorrowerCollateralLpTokenToSeize: scaledBorrowerCollateralLpTokenToSeize
            )
        }
    }

    /// PoolAdmin
    ///
    pub resource PoolAdmin {
        /// Admin function to call accrueInterest() to checkpoint latest states, and then update the interest rate model
        pub fun setInterestRateModel(newInterestRateModelAddress: Address) {
            post {
                LendingPool.interestRateModelCap != nil && LendingPool.interestRateModelCap!.check() == true:
                    LendingError.ErrorEncode(
                        msg: "Invalid contract address of the new interest rate",
                        err: LendingError.ErrorCode.CANNOT_ACCESS_INTEREST_RATE_MODEL_CAPABILITY
                    )
            }
            LendingPool.accrueInterest()
            
            if (newInterestRateModelAddress != LendingPool.interestRateModelAddress) {
                let oldInterestRateModelAddress = LendingPool.interestRateModelAddress
                LendingPool.interestRateModelAddress = newInterestRateModelAddress
                LendingPool.interestRateModelCap = getAccount(newInterestRateModelAddress)
                    .getCapability<&{LendingInterfaces.InterestRateModelPublic}>(LendingConfig.InterestRateModelPublicPath)
                emit NewInterestRateModel(oldInterestRateModelAddress, newInterestRateModelAddress)
            }
            return
        }

        /// Admin function to call accrueInterest() to checkpoint latest states, and then update reserveFactor
        pub fun setReserveFactor(newReserveFactor: UFix64) {
            pre {
                newReserveFactor <= 1.0:
                LendingError.ErrorEncode(
                    msg: "Reserve factor out of range 1.0",
                    err: LendingError.ErrorCode.INVALID_PARAMETERS
                )
            }
            LendingPool.accrueInterest()
            
            let oldReserveFactor = LendingConfig.ScaledUInt256ToUFix64(LendingPool.scaledReserveFactor)
            LendingPool.scaledReserveFactor = LendingConfig.UFix64ToScaledUInt256(newReserveFactor)

            emit NewReserveFactor(oldReserveFactor, newReserveFactor)
            return
        }

        /// Admin function to update poolSeizeShare
        pub fun setPoolSeizeShare(newPoolSeizeShare: UFix64) {
            pre {
                newPoolSeizeShare <= 1.0:
                LendingError.ErrorEncode(
                    msg: "Pool seize share factor out of range 1.0",
                    err: LendingError.ErrorCode.INVALID_PARAMETERS
                )
            }
            let oldPoolSeizeShare = LendingConfig.ScaledUInt256ToUFix64(LendingPool.scaledPoolSeizeShare)
            LendingPool.scaledPoolSeizeShare = LendingConfig.UFix64ToScaledUInt256(newPoolSeizeShare)

            emit NewPoolSeizeShare(oldPoolSeizeShare, newPoolSeizeShare)
            return
        }

        /// Admin function to set comptroller
        pub fun setComptroller(newComptrollerAddress: Address) {
            post {
                LendingPool.comptrollerCap != nil && LendingPool.comptrollerCap!.check() == true:
                    LendingError.ErrorEncode(
                        msg: "Cannot borrow reference to ComptrollerPublic resource",
                        err: LendingError.ErrorCode.CANNOT_ACCESS_COMPTROLLER_PUBLIC_CAPABILITY
                    )
            }
            
            if (newComptrollerAddress != LendingPool.comptrollerAddress) {
                let oldComptrollerAddress = LendingPool.comptrollerAddress
                LendingPool.comptrollerAddress = newComptrollerAddress
                LendingPool.comptrollerCap = getAccount(newComptrollerAddress)
                    .getCapability<&{LendingInterfaces.ComptrollerPublic}>(LendingConfig.ComptrollerPublicPath)
                emit NewComptroller(oldComptrollerAddress, newComptrollerAddress)
            }
        }

        /// Admin function to initialize pool.
        /// Note: can be called only once
        pub fun initializePool(
            reserveFactor: UFix64,
            poolSeizeShare: UFix64,
            interestRateModelAddress: Address
        ) {
            pre {
                LendingPool.accrualBlockNumber == 0 && LendingPool.scaledBorrowIndex == 0:
                    LendingError.ErrorEncode(
                        msg: "Pool can only be initialized once",
                        err: LendingError.ErrorCode.POOL_INITIALIZED
                    )
                reserveFactor <= 1.0 && poolSeizeShare <= 1.0:
                    LendingError.ErrorEncode(
                        msg: "ReserveFactor | poolSeizeShare out of range 1.0",
                        err: LendingError.ErrorCode.INVALID_PARAMETERS
                    )
            }
            post {
                LendingPool.interestRateModelCap != nil && LendingPool.interestRateModelCap!.check() == true:
                    LendingError.ErrorEncode(
                        msg: "InterestRateModel not properly initialized",
                        err: LendingError.ErrorCode.CANNOT_ACCESS_INTEREST_RATE_MODEL_CAPABILITY
                    )
            }
            LendingPool.accrualBlockNumber = UInt256(getCurrentBlock().height)
            LendingPool.scaledBorrowIndex = LendingConfig.scaleFactor
            LendingPool.scaledReserveFactor = LendingConfig.UFix64ToScaledUInt256(reserveFactor)
            LendingPool.scaledPoolSeizeShare = LendingConfig.UFix64ToScaledUInt256(poolSeizeShare)
            LendingPool.interestRateModelAddress = interestRateModelAddress
            LendingPool.interestRateModelCap = getAccount(interestRateModelAddress)
                .getCapability<&{LendingInterfaces.InterestRateModelPublic}>(LendingConfig.InterestRateModelPublicPath)
        }

        /// Admin function to withdraw pool reserve
        pub fun withdrawReserves(reduceAmount: UFix64): @FungibleToken.Vault {
            LendingPool.accrueInterest()
            
            let reduceAmountScaled = reduceAmount == UFix64.max ? LendingPool.scaledTotalReserves : LendingConfig.UFix64ToScaledUInt256(reduceAmount)
            assert(reduceAmountScaled <= LendingPool.scaledTotalReserves, message:
                LendingError.ErrorEncode(
                    msg: "exceeded pool total reserve",
                    err: LendingError.ErrorCode.EXCEED_TOTAL_RESERVES
                )
            )
            assert(reduceAmountScaled <= LendingPool.getPoolCash(), message:
                LendingError.ErrorEncode(
                    msg: "insufficient pool liquidity to withdraw reserve",
                    err: LendingError.ErrorCode.INSUFFICIENT_POOL_LIQUIDITY
                )
            )
            LendingPool.scaledTotalReserves = LendingPool.scaledTotalReserves - reduceAmountScaled
            
            emit ReservesReduced(scaledReduceAmount: reduceAmountScaled, scaledNewTotalReserves: LendingPool.scaledTotalReserves)

            return <- LendingPool.underlyingVault.withdraw(amount: reduceAmount)
        }
    }

    init() {
        self.PoolAdminStoragePath = /storage/incrementLendingPoolAdmin
        self.UnderlyingAssetVaultStoragePath = /storage/poolUnderlyingAssetVault
        self.PoolPublicStoragePath = /storage/incrementLendingPoolPublic
        self.PoolPublicPublicPath = /public/incrementLendingPoolPublic

        self.poolAddress = self.account.address
        self.scaledInitialExchangeRate = LendingConfig.scaleFactor
        self.accrualBlockNumber = 0
        self.scaledBorrowIndex = 0
        self.scaledTotalBorrows = 0
        self.scaledTotalReserves = 0
        self.scaledReserveFactor = 0
        self.scaledPoolSeizeShare = 0
        self.scaledTotalSupply = 0
        self.accountLpTokens = {}
        self.accountBorrows = {}
        self.interestRateModelAddress = nil
        self.interestRateModelCap = nil
        self.comptrollerAddress = nil
        self.comptrollerCap = nil
        self._reservedFields = {}
        self.underlyingVault <- self.account.load<@FungibleToken.Vault>(from: self.UnderlyingAssetVaultStoragePath)
            ?? panic("Deployer should own zero-balanced underlying asset vault first")
        self.underlyingAssetType = self.underlyingVault.getType()
        assert(self.underlyingVault.balance == 0.0, message: "Must initialize pool with zero-balanced underlying asset vault")

        // save pool admin
        destroy <-self.account.load<@AnyResource>(from: self.PoolAdminStoragePath)
        self.account.save(<-create PoolAdmin(), to: self.PoolAdminStoragePath)
        // save pool public interface
        self.account.unlink(self.PoolPublicPublicPath)
        destroy <-self.account.load<@AnyResource>(from: self.PoolPublicStoragePath)
        self.account.save(<-create PoolPublic(), to: self.PoolPublicStoragePath)
        self.account.unlink(self.PoolPublicPublicPath)
        self.account.link<&{LendingInterfaces.PoolPublic}>(LendingConfig.PoolPublicPublicPath, target: self.PoolPublicStoragePath)
    }
}
