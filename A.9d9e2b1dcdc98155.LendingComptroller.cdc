/**

# The Comptroller contract of LendingPools.

# Author: Increment Labs

The Comptroller contract manages market parameters and provides safety auditing before actions being applied to LendingPools.

*/
import LendingInterfaces from 0x2df970b6cdee5735
import LendingConfig from 0x2df970b6cdee5735
import LendingError from 0x2df970b6cdee5735

pub contract LendingComptroller {
    /// Account address LendingComptroller contract is deployed to, i.e. 'the contract address'
    pub let comptrollerAddress: Address

    /// The storage path for the Admin resource
    pub let AdminStoragePath: StoragePath
    /// The storage path for the Comptroller resource
    pub let ComptrollerStoragePath: StoragePath
    pub let ComptrollerPublicPath: PublicPath
    /// The private path for the capability to Comptroller resource for admin functions
    pub let ComptrollerPrivatePath: PrivatePath
    /// Reserved parameter fields: {ParamName: Value}
    access(self) let _reservedFields: {String: AnyStruct}
    
    /// events
    pub event MarketAdded(market: Address, marketType: String, liquidationPenalty: UFix64, collateralFactor: UFix64)
    pub event NewOracle(_ oldOracleAddress: Address?, _ newOracleAddress: Address)
    pub event NewCloseFactor(_ oldCloseFactor: UFix64, _ newCloseFactor: UFix64)
    pub event ConfigMarketParameters(
        market: Address,
        oldIsOpen: Bool?, newIsOpen: Bool?,
        oldIsMining: Bool?, newIsMining: Bool?,
        oldLiquidationPenalty: UFix64?, newLiquidationPenalty: UFix64?,
        oldCollateralFactor: UFix64?, newCollateralFactor: UFix64?,
        oldBorrowCap: UFix64?, newBorrowCap: UFix64?,
        oldSupplyCap: UFix64?, newSupplyCap: UFix64?
    )

    /// Market
    ///
    pub struct Market {
        /// Contains functions to query public market data
        pub let poolPublicCap: Capability<&{LendingInterfaces.PoolPublic}>
        /// Whether market open
        pub var isOpen: Bool
        /// Whether or not liquidity mining is enabled for this market
        pub var isMining: Bool
        /// When liquidation happenes, liquidators repay part of the borrowed amount on behalf of the borrower,
        /// and in return they receive corresponding amount of collateral with an additional incentive.
        /// It's an incentive for the liquidator but a penalty for the liquidated borrower.
        /// Must be in [0.0, 1.0] x scaleFactor
        pub var scaledLiquidationPenalty: UInt256
        /// The most one can borrow against his collateral in this market
        /// Must be in [0.0, 1.0] x scaleFactor
        pub var scaledCollateralFactor: UInt256
        /// maximum totalBorrows this market can reach.
        /// Any borrow request that makes totalBorrows greater than borrowCap would be rejected
        /// Note: value of 0 represents unlimited cap when market.isOpen is set
        pub var scaledBorrowCap: UInt256
        /// maximum Supply amount this market can reach.
        /// Note: value of 0 represents unlimited cap when market.isOpen is set
        pub var scaledSupplyCap: UInt256
        /// Reserved parameter fields: {ParamName: Value}
        access(self) let _reservedFields: {String: AnyStruct}

        
        pub fun setMarketStatus(isOpen: Bool) {
            if (self.isOpen != isOpen) {
                self.isOpen = isOpen
            }
        }

        pub fun setMiningStatus(isMining: Bool) {
            if (self.isMining != isMining) { 
                self.isMining = isMining
            }
        }

        pub fun setLiquidationPenalty(newLiquidationPenalty: UFix64) {
            pre {
                newLiquidationPenalty <= 1.0: LendingError.ErrorEncode(msg: "newLiquidationPenalty out of range 1.0", err: LendingError.ErrorCode.INVALID_PARAMETERS)
            }
            let scaledNewLiquidationPenalty = LendingConfig.UFix64ToScaledUInt256(newLiquidationPenalty)
            if (self.scaledLiquidationPenalty != scaledNewLiquidationPenalty) {
                self.scaledLiquidationPenalty = scaledNewLiquidationPenalty
            }
        }

        pub fun setCollateralFactor(newCollateralFactor: UFix64) {
            pre {
                newCollateralFactor <= 1.0: LendingError.ErrorEncode(msg: "newCollateralFactor out of range 1.0", err: LendingError.ErrorCode.INVALID_PARAMETERS)
            }
            let scaledNewCollateralFactor = LendingConfig.UFix64ToScaledUInt256(newCollateralFactor)
            if (self.scaledCollateralFactor != scaledNewCollateralFactor) {
                self.scaledCollateralFactor = scaledNewCollateralFactor
            }
        }

        pub fun setBorrowCap(newBorrowCap: UFix64) {
            let scaledNewBorrowCap = LendingConfig.UFix64ToScaledUInt256(newBorrowCap)
            if (self.scaledBorrowCap != scaledNewBorrowCap) {
                self.scaledBorrowCap = scaledNewBorrowCap
            }
        }

        pub fun setSupplyCap(newSupplyCap: UFix64) {
            let scaledNewSupplyCap = LendingConfig.UFix64ToScaledUInt256(newSupplyCap)
            if (self.scaledSupplyCap != scaledNewSupplyCap) {
                self.scaledSupplyCap = scaledNewSupplyCap
            }
        }

        init(
            poolPublicCap: Capability<&{LendingInterfaces.PoolPublic}>,
            isOpen: Bool,
            isMining: Bool,
            liquidationPenalty: UFix64,
            collateralFactor: UFix64,
            borrowCap: UFix64,
            supplyCap: UFix64
        ) {
            pre {
                collateralFactor <= 1.0: LendingError.ErrorEncode(msg: "collateralFactor out of range 1.0", err: LendingError.ErrorCode.INVALID_PARAMETERS)
                liquidationPenalty <= 1.0: LendingError.ErrorEncode(msg: "liquidationPenalty out of range 1.0", err: LendingError.ErrorCode.INVALID_PARAMETERS)
            }
            self.poolPublicCap = poolPublicCap
            self.isOpen = isOpen
            self.isMining = isMining
            self.scaledLiquidationPenalty = LendingConfig.UFix64ToScaledUInt256(liquidationPenalty)
            self.scaledCollateralFactor = LendingConfig.UFix64ToScaledUInt256(collateralFactor)
            self.scaledBorrowCap = LendingConfig.UFix64ToScaledUInt256(borrowCap)
            self.scaledSupplyCap = LendingConfig.UFix64ToScaledUInt256(supplyCap)
            self._reservedFields = {}
        }
    }

    /// UserCertificate
    ///
    /// This certificate identifies account address and needs to be stored in storage path locally.
    /// User should keep it safe and never give this resource's capability to others
    /// It is more convenient to use a resource certificate on flow for authentication than signing a signature.
    ///
    pub resource UserCertificate: LendingInterfaces.IdentityCertificate {}

    /// Anyone can apply for a user certificate
    /// 
    pub fun IssueUserCertificate(): @UserCertificate {
        return <- create UserCertificate()
    }

    /// Comptroller
    ///
    pub resource Comptroller: LendingInterfaces.ComptrollerPublic {
        /// Oracle cap
        access(self) var oracleCap: Capability<&{LendingInterfaces.OraclePublic}>?
        /// Multiplier used to calculate the maximum repayAmount when liquidating a borrow. [0.0, 1.0] x scaleFactor
        access(self) var scaledCloseFactor: UInt256
        /// { poolAddress => Market States }
        access(self) let markets: {Address: Market}
        /// { accountAddress => markets the account has either provided liquidity to or borrowed from }
        access(self) let accountMarketsIn: {Address: [Address]}
        /// Reserved parameter fields: {ParamName: Value}
        access(self) let _reservedFields: {String: AnyStruct}

        /// Supply audit
        ///
        /// @Param poolCertificate - Can only be called by one of the valid LendPools
        /// @Param poolAddress - Caller address
        /// @Param supplierAddress - The address of supply
        /// @Param supplyUnderlyingAmountScaled - Supply amount scaled by 1e18
        /// @Return error code
        ///
        pub fun supplyAllowed(
            poolCertificate: @{LendingInterfaces.IdentityCertificate},
            poolAddress: Address,
            supplierAddress: Address,
            supplyUnderlyingAmountScaled: UInt256
        ): String? {
            let err = self.callerAllowed(callerCertificate: <- poolCertificate, callerAddress: poolAddress)
            if (err != nil) {
                return err
            }

            // Supply limit check if not unlimited supplyCap
            let market = self.markets[poolAddress]!
            let scaledSupplyCap = market.scaledSupplyCap
            let poolRef = market.poolPublicCap.borrow()!

            if (scaledSupplyCap != 0) {
                let scaledTotalSupplyNew = supplyUnderlyingAmountScaled + poolRef.getPoolCash() + poolRef.getPoolTotalBorrowsScaled()
                
                if (scaledTotalSupplyNew > scaledSupplyCap) {
                    return LendingError.ErrorEncode(msg: "supply too much, exceed market supplyCap", err: LendingError.ErrorCode.SUPPLY_NOT_ALLOWED_EXCEED_SUPPLY_CAP)
                }
            }

            // Add to user markets list
            if (self.accountMarketsIn.containsKey(supplierAddress) == false) {
                self.accountMarketsIn[supplierAddress] = [poolAddress]
            } else if (self.accountMarketsIn[supplierAddress]!.contains(poolAddress) == false) {
                self.accountMarketsIn[supplierAddress]!.append(poolAddress)
            }

            return nil
        }

        /// Redeem audit
        ///
        /// @Param poolCertificate - Can only be called by one of the valid LendPools
        /// @Param poolAddress - Caller address
        /// @Param redeemerAddress - The address of redeemer
        /// @Param redeemLpTokenAmountScaled - Redeem amount scaled by 1e18
        /// @Return error code
        ///
        /// Since borrower would decrease his overall collateral ratio across all markets, safety check is important.
        ///
        pub fun redeemAllowed(
            poolCertificate: @{LendingInterfaces.IdentityCertificate},
            poolAddress: Address,
            redeemerAddress: Address,
            redeemLpTokenAmountScaled: UInt256
        ): String? {
            let err = self.callerAllowed(callerCertificate: <- poolCertificate, callerAddress: poolAddress)
            if (err != nil) {
                return err
            }

            // Hypothetical account liquidity check if virtual lpToken was redeemed
            // liquidity[0] - cross-market collateral value
            // liquidity[1] - cross-market borrow value
            // liquidity[2] - cross-market supply value
            let scaledLiquidity: [UInt256;3] = self.getHypotheticalAccountLiquidity(
                account: redeemerAddress,
                poolToModify: poolAddress,
                scaledAmountLPTokenToRedeem: redeemLpTokenAmountScaled,
                scaledAmountUnderlyingToBorrow: 0
            )
            if (scaledLiquidity[1] > scaledLiquidity[0]) {
                return LendingError.ErrorEncode(msg: "redeem too much", err: LendingError.ErrorCode.REDEEM_NOT_ALLOWED_POSITION_UNDER_WATER)
            }

            // Remove pool out of user markets list if necessary
            self.removePoolFromAccountMarketsOnCondition(
                poolAddress: poolAddress,
                account: redeemerAddress,
                scaledRedeemOrRepayAmount: redeemLpTokenAmountScaled
            )

            return nil
        }

        /// Borrow audit
        ///
        /// @Param poolCertificate - Can only be called by one of the valid LendPools
        /// @Param poolAddress - Caller address
        /// @Param borrowerAddress - The address of borrower
        /// @Param borrowUnderlyingAmountScaled - Borrow amount scaled by 1e18
        /// @Return error code
        ///
        pub fun borrowAllowed(
            poolCertificate: @{LendingInterfaces.IdentityCertificate},
            poolAddress: Address,
            borrowerAddress: Address,
            borrowUnderlyingAmountScaled: UInt256
        ): String? {
            let err = self.callerAllowed(callerCertificate: <- poolCertificate, callerAddress: poolAddress)
            if (err != nil) {
                return err
            }

            // 1. totalBorrows limit check if not unlimited borrowCap
            let scaledBorrowCap = self.markets[poolAddress]!.scaledBorrowCap
            if (scaledBorrowCap != 0) {
                let scaledTotalBorrowsNew = self.markets[poolAddress]!.poolPublicCap.borrow()!.getPoolTotalBorrowsScaled() + borrowUnderlyingAmountScaled
                if (scaledTotalBorrowsNew > scaledBorrowCap) {
                    return LendingError.ErrorEncode(msg: "borrow too much, exceed market borrowCap", err: LendingError.ErrorCode.BORROW_NOT_ALLOWED_EXCEED_BORROW_CAP)
                }
            }

            // 2. Add to user markets list
            if (self.accountMarketsIn.containsKey(borrowerAddress) == false) {
                self.accountMarketsIn[borrowerAddress] = [poolAddress]
            } else if (self.accountMarketsIn[borrowerAddress]!.contains(poolAddress) == false) {
                self.accountMarketsIn[borrowerAddress]!.append(poolAddress)
            }

            // 3. Hypothetical account liquidity check after underlying was borrowed
            // liquidity[0] - cross-market collateral value
            // liquidity[1] - cross-market borrow value
            // liquidity[2] - cross-market supply value
            let scaledLiquidity: [UInt256; 3] = self.getHypotheticalAccountLiquidity(
                account: borrowerAddress,
                poolToModify: poolAddress,
                scaledAmountLPTokenToRedeem: 0,
                scaledAmountUnderlyingToBorrow: borrowUnderlyingAmountScaled
            )
            if (scaledLiquidity[1] > scaledLiquidity[0]) {
                return LendingError.ErrorEncode(msg: "borrow too much, more than collaterized position value", err: LendingError.ErrorCode.BORROW_NOT_ALLOWED_POSITION_UNDER_WATER)
            }
            
            return nil
        }

        /// Repay audit
        ///
        /// @Param poolCertificate - Can only be called by one of the valid LendPools
        /// @Param poolAddress - Caller address
        /// @Param borrowerAddress - The address of borrower
        /// @Param repayUnderlyingAmountScaled - Repay amount scaled by 1e18
        /// @Return error code
        ///
        pub fun repayAllowed(
            poolCertificate: @{LendingInterfaces.IdentityCertificate},
            poolAddress: Address,
            borrowerAddress: Address,
            repayUnderlyingAmountScaled: UInt256
        ): String? {
            let err = self.callerAllowed(callerCertificate: <- poolCertificate, callerAddress: poolAddress)
            if (err != nil) {
                return err
            }

            // Remove pool out of user markets list if necessary
            self.removePoolFromAccountMarketsOnCondition(
                poolAddress: poolAddress,
                account: borrowerAddress,
                scaledRedeemOrRepayAmount: repayUnderlyingAmountScaled
            )

            return nil
        }

        /// Liquidation audit
        ///
        /// @Param poolCertificate - Can only be called by one of the valid LendPools
        /// @Param poolAddress - Caller address
        /// @Param poolCollateralized - The address of collateral pool holded by borrower to be repaid.
        /// @Param borrower - The address of borrower
        /// @Param repayUnderlyingAmountScaled - The amount repaid on behalf of the liquidator.
        /// @Return error code
        ///
        pub fun liquidateAllowed(
            poolCertificate: @{LendingInterfaces.IdentityCertificate},
            poolBorrowed: Address,
            poolCollateralized: Address,
            borrower: Address,
            repayUnderlyingAmountScaled: UInt256
        ): String? {
            pre {
                self.markets[poolCollateralized]?.isOpen == true: LendingError.ErrorEncode(msg: "collateral market not open", err: LendingError.ErrorCode.MARKET_NOT_OPEN)
            }

            let err = self.callerAllowed(callerCertificate: <- poolCertificate, callerAddress: poolBorrowed)
            if (err != nil) {
                return err
            }

            // Current account liquidity check
            // liquidity[0] - cross-market collateral value
            // liquidity[1] - cross-market borrow value
            // liquidity[2] - cross-market supply value
            let scaledLiquidity: [UInt256;3] = self.getHypotheticalAccountLiquidity(
                account: borrower,
                poolToModify: 0x0,
                scaledAmountLPTokenToRedeem: 0,
                scaledAmountUnderlyingToBorrow: 0
            )
            if (scaledLiquidity[0] >= scaledLiquidity[1]) {
                return LendingError.ErrorEncode(msg: "borrower account fully collaterized", err: LendingError.ErrorCode.LIQUIDATION_NOT_ALLOWED_POSITION_ABOVE_WATER)
            }
            
            let scaledBorrowBalance = self.markets[poolBorrowed]!.poolPublicCap.borrow()!.getAccountBorrowBalanceScaled(account: borrower)
            // liquidator cannot repay more than closeFactor * borrow
            if (repayUnderlyingAmountScaled > scaledBorrowBalance * self.scaledCloseFactor / LendingConfig.scaleFactor) {
                return LendingError.ErrorEncode(msg: "liquidator repaid more than closeFactor x accountBorrow", err: LendingError.ErrorCode.LIQUIDATION_NOT_ALLOWED_TOO_MUCH_REPAY)
            }

            return nil
        }

        /// Seize audit
        ///
        /// @Param poolCertificate - Can only be called by one of the valid LendPools
        /// @Param poolAddress - Caller address
        /// @Param collateralPool - The address of collateral pool holded by borrower to be repaid
        /// @Param liquidator - The address of liquidator
        /// @Param borrower - The address of borrower
        /// @Param seizeCollateralPoolLpTokenAmountScaled - The amount of Lptoken that the borrower will be liquidated.
        /// @Return error code
        ///
        pub fun seizeAllowed(
            poolCertificate: @{LendingInterfaces.IdentityCertificate},
            borrowPool: Address,
            collateralPool: Address,
            liquidator: Address,
            borrower: Address,
            seizeCollateralPoolLpTokenAmountScaled: UInt256
        ): String? {
            pre {
                self.markets[collateralPool]?.isOpen == true: LendingError.ErrorEncode(msg: "Collateral market not open", err: LendingError.ErrorCode.MARKET_NOT_OPEN)
            }

            let err = self.callerAllowed(callerCertificate: <- poolCertificate, callerAddress: borrowPool)
            if (err != nil) {
                return err
            }

            // Add to liquidator markets list
            if (self.accountMarketsIn.containsKey(liquidator) == false) {
                self.accountMarketsIn[liquidator] = [collateralPool]
            } else if (self.accountMarketsIn[liquidator]!.contains(collateralPool) == false) {
                self.accountMarketsIn[liquidator]!.append(collateralPool)
            }

            // Remove pool out of user markets list if necessary
            self.removePoolFromAccountMarketsOnCondition(
                poolAddress: collateralPool,
                account: borrower,
                scaledRedeemOrRepayAmount: seizeCollateralPoolLpTokenAmountScaled
            )

            return nil
        }

        /// Given actualRepaidBorrowAmount underlying of borrowPool, calculate seized number of lpTokens of collateralPool
        /// Called in LendingPool.liquidate()
        ///
        pub fun calculateCollateralPoolLpTokenToSeize(
            borrower: Address,
            borrowPool: Address,
            collateralPool: Address,
            actualRepaidBorrowAmountScaled: UInt256
        ): UInt256 {
            let borrowPoolUnderlyingPriceUSD = self.oracleCap!.borrow()!.getUnderlyingPrice(pool: borrowPool)
            assert(
                borrowPoolUnderlyingPriceUSD != 0.0,
                message: LendingError.ErrorEncode(msg: "Price feed not available for market ".concat(borrowPool.toString()), err: LendingError.ErrorCode.UNKNOWN_MARKET)
            )
            let collateralPoolUnderlyingPriceUSD = self.oracleCap!.borrow()!.getUnderlyingPrice(pool: collateralPool)
            assert(
                collateralPoolUnderlyingPriceUSD != 0.0,
                message: LendingError.ErrorEncode(msg: "Price feed not available for market ".concat(collateralPool.toString()), err: LendingError.ErrorCode.UNKNOWN_MARKET)
            )
            // 1. Accrue interests first to use latest collateralPool states to do calculation
            self.markets[collateralPool]!.poolPublicCap.borrow()!.accrueInterest()

            // 2. Calculate collateralPool lpTokenSeizedAmount
            let scaledCollateralUnderlyingToLpTokenRate = self.markets[collateralPool]!.poolPublicCap.borrow()!.getUnderlyingToLpTokenRateScaled()
            let scaledCollateralPoolLiquidationIncentive = self.markets[collateralPool]!.scaledLiquidationPenalty
            let scaledBorrowPoolUnderlyingPriceUSD = LendingConfig.UFix64ToScaledUInt256(borrowPoolUnderlyingPriceUSD)
            let scaledCollateralPoolUnderlyingPriceUSD = LendingConfig.UFix64ToScaledUInt256(collateralPoolUnderlyingPriceUSD)
            let scaleFactor = LendingConfig.scaleFactor
            
            
            let scaledActualRepaidBorrowWithIncentiveInUSD =
                scaledBorrowPoolUnderlyingPriceUSD * (scaleFactor + scaledCollateralPoolLiquidationIncentive) / scaleFactor *
                    actualRepaidBorrowAmountScaled / scaleFactor
            let scaledCollateralPoolLpTokenPriceUSD = scaledCollateralPoolUnderlyingPriceUSD * scaledCollateralUnderlyingToLpTokenRate / scaleFactor
            let scaledCollateralLpTokenSeizedAmount = scaledActualRepaidBorrowWithIncentiveInUSD * scaleFactor / scaledCollateralPoolLpTokenPriceUSD

            // 3. borrower collateralPool lpToken balance check
            let scaledLpTokenAmount = self.markets[collateralPool]!.poolPublicCap.borrow()!.getAccountLpTokenBalanceScaled(account: borrower)
            assert(
                scaledCollateralLpTokenSeizedAmount <= scaledLpTokenAmount,
                message: LendingError.ErrorEncode(
                    msg: "Liquidation seized too much, more than borrower collateralPool supply balance".concat((scaledCollateralLpTokenSeizedAmount).toString().concat(" <= ").concat(scaledLpTokenAmount.toString())),
                    err: LendingError.ErrorCode.LIQUIDATION_NOT_ALLOWED_SEIZE_MORE_THAN_BALANCE
                )
            )
            return scaledCollateralLpTokenSeizedAmount
        }

        pub fun getUserCertificateType(): Type {
            return Type<@LendingComptroller.UserCertificate>()
        }

        pub fun callerAllowed(
            callerCertificate: @{LendingInterfaces.IdentityCertificate},
            callerAddress: Address
        ): String? {
            if (self.markets[callerAddress]?.isOpen != true) {
                destroy callerCertificate
                return LendingError.ErrorEncode(msg: "Market not open", err: LendingError.ErrorCode.MARKET_NOT_OPEN)
            }
            let callerPoolCertificateType = self.markets[callerAddress]!.poolPublicCap.borrow()!.getPoolCertificateType()
            if (callerCertificate.isInstance(callerPoolCertificateType)) {
                destroy callerCertificate
                return nil
            } else {
                let errMsg = callerCertificate.getType().identifier.concat("!=").concat(callerPoolCertificateType.identifier)
                destroy callerCertificate
                return LendingError.ErrorEncode(msg: "not called from valid market contract".concat(errMsg), err: LendingError.ErrorCode.INVALID_POOL_CERTIFICATE)
            }
        }

        /// Remove pool out of user markets list if necessary
        access(self) fun removePoolFromAccountMarketsOnCondition(
            poolAddress: Address,
            account: Address,
            scaledRedeemOrRepayAmount: UInt256
        ): Bool {
            // snapshot[1] - lpTokenBalance; snapshot[2] - borrowBalance
            let snapshot = self.markets[poolAddress]!.poolPublicCap.borrow()!.getAccountSnapshotScaled(account: account)
            if (snapshot[1] == 0 && snapshot[2] == scaledRedeemOrRepayAmount || (snapshot[1] == scaledRedeemOrRepayAmount && snapshot[2] == 0)) {
                var id = 0
                let marketsIn: &[Address] = &(self.accountMarketsIn[account]!) as &[Address]
                while (id < marketsIn.length) {
                    if (marketsIn[id] == poolAddress) {
                        marketsIn.remove(at: id)
                        return true
                    }
                    id = id + 1
                }
            }
            return false
        }

        /// Calculate what the account liquidity would be if the given amounts were redeemed / borrowed
        ///
        /// @Param account - Target account
        /// @Param poolToModify - The market to hypothetically redeem/borrow from
        /// @Param scaledAmountLPTokenToRedeem - The number of LPTokens to hypothetically redeem
        /// @Param scaledAmountUnderlyingToBorrow - The amount of underlying to hypothetically borrow
        /// @Return: 0. hypothetical cross-market total collateral value normalized in usd
        ///          1. hypothetical cross-market tatal borrow value normalized in usd
        ///          2. hypothetical cross-market total supply value normalized in usd
        ///
        access(self) fun getHypotheticalAccountLiquidity(
            account: Address,
            poolToModify: Address,
            scaledAmountLPTokenToRedeem: UInt256,
            scaledAmountUnderlyingToBorrow: UInt256
        ): [UInt256; 3] {
            if (self.accountMarketsIn.containsKey(account) == false) {
                return [0, 0, 0]
            }
            // Cross-market total supply value applies with hypothetical side effects, normalized in usd
            var sumScaledSupplyWithEffectsNormalized: UInt256 = 0
            // Cross-market total collateral value applies with hypothetical side effects, normalized in usd
            var sumScaledCollateralWithEffectsNormalized: UInt256 = 0
            // Cross-market total borrow value applies with hypothetical side-effects, normalized in usd
            var sumScaledBorrowWithEffectsNormalized: UInt256 = 0
            for poolAddress in self.accountMarketsIn[account]! {
                let scaledCollateralFactor = self.markets[poolAddress]!.scaledCollateralFactor
                let scaledAccountSnapshot = self.markets[poolAddress]!.poolPublicCap.borrow()!.getAccountSnapshotScaled(account: account)
                let scaledUnderlyingToLpTokenRate = scaledAccountSnapshot[0]
                let scaledLpTokenAmount = scaledAccountSnapshot[1]
                let scaledBorrowBalance = scaledAccountSnapshot[2]
                let underlyingPriceInUSD = self.oracleCap!.borrow()!.getUnderlyingPrice(pool: poolAddress)
                assert(
                    underlyingPriceInUSD != 0.0,
                    message: LendingError.ErrorEncode(msg: "Price feed not available for market ".concat(poolAddress.toString()), err: LendingError.ErrorCode.UNKNOWN_MARKET)
                )
                let scaledUnderlyingPriceInUSD = LendingConfig.UFix64ToScaledUInt256(underlyingPriceInUSD)
                let scaleFactor = LendingConfig.scaleFactor
                if (scaledLpTokenAmount > 0) {
                    sumScaledCollateralWithEffectsNormalized = sumScaledCollateralWithEffectsNormalized +
                        scaledCollateralFactor * scaledUnderlyingPriceInUSD / scaleFactor *
                            scaledUnderlyingToLpTokenRate / scaleFactor * scaledLpTokenAmount / scaleFactor
                    sumScaledSupplyWithEffectsNormalized = sumScaledSupplyWithEffectsNormalized +
                        scaledUnderlyingPriceInUSD * scaledUnderlyingToLpTokenRate / scaleFactor * scaledLpTokenAmount / scaleFactor
                }
                if (scaledBorrowBalance > 0) {
                    sumScaledBorrowWithEffectsNormalized = sumScaledBorrowWithEffectsNormalized +
                        scaledBorrowBalance * scaledUnderlyingPriceInUSD / scaleFactor
                }
                if (poolAddress == poolToModify) {
                    // Apply hypothetical redeem side-effect
                    if (scaledAmountLPTokenToRedeem > 0) {
                        sumScaledCollateralWithEffectsNormalized = sumScaledCollateralWithEffectsNormalized -
                            scaledCollateralFactor * scaledUnderlyingPriceInUSD / scaleFactor *
                                scaledUnderlyingToLpTokenRate / scaleFactor * scaledAmountLPTokenToRedeem / scaleFactor
                        sumScaledSupplyWithEffectsNormalized = sumScaledSupplyWithEffectsNormalized -
                            scaledUnderlyingPriceInUSD * scaledUnderlyingToLpTokenRate / scaleFactor * scaledAmountLPTokenToRedeem / scaleFactor
                    }
                    // Apply hypothetical borrow side-effect
                    if (scaledAmountUnderlyingToBorrow > 0) {
                        sumScaledBorrowWithEffectsNormalized = sumScaledBorrowWithEffectsNormalized +
                            scaledAmountUnderlyingToBorrow * scaledUnderlyingPriceInUSD / scaleFactor
                    }
                }
            }
            return [sumScaledCollateralWithEffectsNormalized, sumScaledBorrowWithEffectsNormalized, sumScaledSupplyWithEffectsNormalized]
        }

        access(contract) fun addMarket(poolAddress: Address, liquidationPenalty: UFix64, collateralFactor: UFix64) {
            pre {
                self.markets.containsKey(poolAddress) == false:
                    LendingError.ErrorEncode(
                        msg: "Market has already been added",
                        err: LendingError.ErrorCode.ADD_MARKET_DUPLICATED
                    )
                    
                self.oracleCap!.borrow()!.getUnderlyingPrice(pool: poolAddress) != 0.0:
                    LendingError.ErrorEncode(
                        msg: "Price feed for market is not available yet",
                        err: LendingError.ErrorCode.ADD_MARKET_NO_ORACLE_PRICE
                    )
                    
            }
            // Add a new market with collateralFactor of 0.0 and borrowCap of 0.0
            let poolPublicCap = getAccount(poolAddress).getCapability<&{LendingInterfaces.PoolPublic}>(LendingConfig.PoolPublicPublicPath)
            assert(poolPublicCap.check() == true, message:
                LendingError.ErrorEncode(
                    msg: "Cannot borrow reference to PoolPublic resource",
                    err: LendingError.ErrorCode.CANNOT_ACCESS_POOL_PUBLIC_CAPABILITY
                )
            )

            self.markets[poolAddress] =
                Market(poolPublicCap: poolPublicCap, isOpen: false, isMining: false, liquidationPenalty: liquidationPenalty, collateralFactor: collateralFactor, borrowCap: 0.0, supplyCap: 0.0)
            emit MarketAdded(
                market: poolAddress,
                marketType: poolPublicCap.borrow()!.getUnderlyingTypeString(),
                liquidationPenalty: liquidationPenalty,
                collateralFactor: collateralFactor
            )
        }

        /// Tune parameters of an already-listed market
        access(contract) fun configMarket(pool: Address, isOpen: Bool?, isMining: Bool?, liquidationPenalty: UFix64?, collateralFactor: UFix64?, borrowCap: UFix64?, supplyCap: UFix64?) {
            pre {
                self.markets.containsKey(pool):
                    LendingError.ErrorEncode(
                        msg: "Market has not been added yet",
                        err: LendingError.ErrorCode.UNKNOWN_MARKET
                    )
            }
            let oldOpen = self.markets[pool]?.isOpen
            if (isOpen != nil) {
                self.markets[pool]!.setMarketStatus(isOpen: isOpen!)
            }
            let oldMining = self.markets[pool]?.isMining
            if (isMining != nil) {
                self.markets[pool]!.setMiningStatus(isMining: isMining!)
            }
            let oldLiquidationPenalty = LendingConfig.ScaledUInt256ToUFix64(self.markets[pool]?.scaledLiquidationPenalty ?? (0 as UInt256))
            if (collateralFactor != nil) {
                self.markets[pool]!.setCollateralFactor(newCollateralFactor: collateralFactor!)
            }
            let oldCollateralFactor = LendingConfig.ScaledUInt256ToUFix64(self.markets[pool]?.scaledCollateralFactor ?? (0 as UInt256))
            if (liquidationPenalty != nil) {
                self.markets[pool]!.setLiquidationPenalty(newLiquidationPenalty: liquidationPenalty!)
            }
            let oldBorrowCap = LendingConfig.ScaledUInt256ToUFix64(self.markets[pool]?.scaledBorrowCap ?? (0 as UInt256))
            if (borrowCap != nil) {
                self.markets[pool]!.setBorrowCap(newBorrowCap: borrowCap!)
            }
            let oldSupplyCap = LendingConfig.ScaledUInt256ToUFix64(self.markets[pool]?.scaledSupplyCap ?? (0 as UInt256))
            if (supplyCap != nil) {
                self.markets[pool]!.setSupplyCap(newSupplyCap: supplyCap!)
            }
            emit ConfigMarketParameters(
                market: pool,
                oldIsOpen: oldOpen, newIsOpen: self.markets[pool]?.isOpen,
                oldIsMining: oldMining, newIsMining: self.markets[pool]?.isMining,
                oldLiquidationPenalty: oldLiquidationPenalty, newLiquidationPenalty: liquidationPenalty,
                oldCollateralFactor: oldCollateralFactor, newCollateralFactor: collateralFactor,
                oldBorrowCap: oldBorrowCap, newBorrowCap: borrowCap,
                oldSupplyCap: oldSupplyCap, newSupplyCap: supplyCap
            )
        }

        access(contract) fun configOracle(oracleAddress: Address) {
            let oldOracleAddress = (self.oracleCap != nil)? self.oracleCap!.borrow()!.owner?.address : nil
            self.oracleCap = getAccount(oracleAddress).getCapability<&{LendingInterfaces.OraclePublic}>(LendingConfig.OraclePublicPath)
            emit NewOracle(oldOracleAddress, self.oracleCap!.borrow()!.owner!.address)
        }

        access(contract) fun setCloseFactor(newCloseFactor: UFix64) {
            pre {
                newCloseFactor <= 1.0:
                    LendingError.ErrorEncode(
                        msg: "newCloseFactor out of range 1.0",
                        err: LendingError.ErrorCode.INVALID_PARAMETERS
                    )
            }
            let oldCloseFactor = LendingConfig.ScaledUInt256ToUFix64(self.scaledCloseFactor)
            self.scaledCloseFactor = LendingConfig.UFix64ToScaledUInt256(newCloseFactor)
            emit NewCloseFactor(oldCloseFactor, newCloseFactor)
        }

        pub fun getPoolPublicRef(poolAddr: Address): &{LendingInterfaces.PoolPublic} {
            pre {
                self.markets.containsKey(poolAddr):
                    LendingError.ErrorEncode(
                        msg: "Invalid market address",
                        err: LendingError.ErrorCode.UNKNOWN_MARKET
                    )
            }
            return self.markets[poolAddr]!.poolPublicCap.borrow() ?? panic(
                LendingError.ErrorEncode(
                    msg: "Cannot borrow reference to PoolPublic",
                    err: LendingError.ErrorCode.CANNOT_ACCESS_POOL_PUBLIC_CAPABILITY
                )
            )
        }

        pub fun getAllMarkets(): [Address] {
            return self.markets.keys
        }

        pub fun getMarketInfo(poolAddr: Address): {String: AnyStruct} {
            pre {
                self.markets.containsKey(poolAddr):
                    LendingError.ErrorEncode(
                        msg: "Invalid market address",
                        err: LendingError.ErrorCode.UNKNOWN_MARKET
                    )
            }
            let market = self.markets[poolAddr]!
            let poolRef = market.poolPublicCap.borrow()!
            var oraclePrice = 0.0
            if(self.oracleCap != nil && self.oracleCap!.check()) {
                oraclePrice = self.oracleCap!.borrow()!.getUnderlyingPrice(pool: poolAddr)
            }

            let accrueInterestRealtimeRes = poolRef.accrueInterestReadonly()

            return {
                "isOpen": market.isOpen,
                "isMining": market.isMining,
                "marketAddress": poolAddr,
                "marketType": poolRef.getUnderlyingTypeString(),
                "marketSupplyScaled": (poolRef.getPoolCash()+accrueInterestRealtimeRes[2]).toString(),
                "marketBorrowScaled": accrueInterestRealtimeRes[2].toString(),
                "marketReserveScaled": poolRef.getPoolTotalReservesScaled().toString(),
                "marketSupplyApr": poolRef.getPoolSupplyAprScaled().toString(),
                "marketBorrowApr": poolRef.getPoolBorrowAprScaled().toString(),
                "marketLiquidationPenalty": market.scaledLiquidationPenalty.toString(),
                "marketCollateralFactor": market.scaledCollateralFactor.toString(),
                "marketBorrowCap": market.scaledBorrowCap.toString(),
                "marketSupplyCap": market.scaledSupplyCap.toString(),
                "marketOraclePriceUsd": LendingConfig.UFix64ToScaledUInt256(oraclePrice).toString(),
                "marketSupplierCount": poolRef.getPoolSupplierCount().toString(),
                "marketBorrowerCount": poolRef.getPoolBorrowerCount().toString(),
                "marketReserveFactor": poolRef.getPoolReserveFactorScaled().toString()
            }
        }

        pub fun getUserMarkets(userAddr: Address): [Address] {
            if (self.accountMarketsIn.containsKey(userAddr) == false) {
                return []
            }
            return self.accountMarketsIn[userAddr]!
        }

        /// Return the current account cross-market liquidity snapshot:
        /// [cross-market account collateral value in usd, cross-market account borrows in usd, cross-market account supplies in usd]
        /// Used in liquidation allowance check, or LTV (loan-to-value) ratio calculation
        pub fun getUserCrossMarketLiquidity(userAddr: Address): [String; 3] {
            let scaledLiquidity = self.getHypotheticalAccountLiquidity(
                account: userAddr,
                poolToModify: 0x0,
                scaledAmountLPTokenToRedeem: 0,
                scaledAmountUnderlyingToBorrow: 0
            )
            return [scaledLiquidity[0].toString(), scaledLiquidity[1].toString(), scaledLiquidity[2].toString()]
        }

        pub fun getUserMarketInfo(userAddr: Address, poolAddr: Address): {String: AnyStruct} {
            pre {
                self.markets.containsKey(poolAddr):
                    LendingError.ErrorEncode(
                        msg: "Invalid market address",
                        err: LendingError.ErrorCode.UNKNOWN_MARKET
                    )
            }
            if (self.accountMarketsIn.containsKey(userAddr) == false || self.accountMarketsIn[userAddr]!.contains(poolAddr) == false) {
                return {}
            }
            let market = self.markets[poolAddr]!
            let poolRef = market.poolPublicCap.borrow()!

            let scaledAccountSnapshot = poolRef.getAccountSnapshotScaled(account: userAddr)
            let scaledAccountRealtime = poolRef.getAccountRealtimeScaled(account: userAddr)

            return {
                "userSupplyScaled": (scaledAccountRealtime[1] * scaledAccountRealtime[0] / LendingConfig.scaleFactor).toString(),
                "userBorrowScaled": scaledAccountRealtime[2].toString(),
                "userBorrowPrincipalSnapshotScaled": scaledAccountSnapshot[3].toString(),
                "userBorrowIndexSnapshotScaled": scaledAccountSnapshot[4].toString(),
                "userLpTokenBalanceScaled": scaledAccountSnapshot[1].toString()
            }
        }

        init() {
            self.oracleCap = nil
            self.scaledCloseFactor = 0
            self.markets = {}
            self.accountMarketsIn = {}
            self._reservedFields = {}
        }
    }

    /// Admin
    ///
    pub resource Admin {
        /// Admin function to list a new asset pool to the lending market
        /// Note: Do not list a new asset pool before the oracle feed is ready
        pub fun addMarket(poolAddress: Address, liquidationPenalty: UFix64, collateralFactor: UFix64) {
            let comptrollerRef = LendingComptroller.account.borrow<&Comptroller>(from: LendingComptroller.ComptrollerStoragePath) ?? panic("lost local comptroller")
            comptrollerRef.addMarket(poolAddress: poolAddress, liquidationPenalty: liquidationPenalty, collateralFactor: collateralFactor)
        }
        /// Admin function to config parameters of a listed-market
        pub fun configMarket(pool: Address, isOpen: Bool?, isMining: Bool?, liquidationPenalty: UFix64?, collateralFactor: UFix64?, borrowCap: UFix64?, supplyCap: UFix64?) {
            let comptrollerRef = LendingComptroller.account.borrow<&Comptroller>(from: LendingComptroller.ComptrollerStoragePath) ?? panic("lost local comptroller")
            comptrollerRef.configMarket(
                pool: pool,
                isOpen: isOpen,
                isMining: isMining,
                liquidationPenalty: liquidationPenalty,
                collateralFactor: collateralFactor,
                borrowCap: borrowCap,
                supplyCap: supplyCap
            )
        }
        /// Admin function to set a new oracle
        pub fun configOracle(oracleAddress: Address) {
            let comptrollerRef = LendingComptroller.account.borrow<&Comptroller>(from: LendingComptroller.ComptrollerStoragePath) ?? panic("lost local comptroller")
            comptrollerRef.configOracle(oracleAddress: oracleAddress)
        }
        /// Admin function to set closeFactor
        pub fun setCloseFactor(closeFactor: UFix64) {
            let comptrollerRef = LendingComptroller.account.borrow<&Comptroller>(from: LendingComptroller.ComptrollerStoragePath) ?? panic("lost local comptroller")
            comptrollerRef.setCloseFactor(newCloseFactor: closeFactor)
        }
    }

    init() {
        self.AdminStoragePath = /storage/comptrollerAdmin
        self.ComptrollerStoragePath = /storage/comptrollerModule
        self.ComptrollerPublicPath = /public/comptrollerModule
        self.ComptrollerPrivatePath = /private/comptrollerModule
        self.comptrollerAddress = self.account.address
        self._reservedFields = {}

        destroy <-self.account.load<@AnyResource>(from: self.AdminStoragePath)
        self.account.save(<-create Admin(), to: self.AdminStoragePath)
        
        destroy <-self.account.load<@AnyResource>(from: self.ComptrollerStoragePath)
        self.account.save(<-create Comptroller(), to: self.ComptrollerStoragePath)
        self.account.unlink(self.ComptrollerPublicPath)
        self.account.link<&{LendingInterfaces.ComptrollerPublic}>(self.ComptrollerPublicPath, target: self.ComptrollerStoragePath)
    }
}
