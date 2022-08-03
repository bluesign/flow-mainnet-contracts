import FungibleToken from 0xf233dcee88fe0abe
import MultiFungibleToken from 0xa378eeb799df8387
import PierLPToken from 0x609e10301860b683
import IPierPair from 0x609e10301860b683
import PierMath from 0xa378eeb799df8387
import PierSwapSettings from 0x066a74dfb4da0306

/**

PierPair is the implementation of IPierPair.

@author Metapier Foundation Ltd.

 */
pub contract PierPair: IPierPair {

    // The initial liquidity that will be minted and locked
    // by the pool. It's fixed to 1e-5.
    pub let MINIMUM_LIQUIDITY: UFix64

    pub event ContractInitialized()
    pub event Swap(poolId: UInt64, amountIn: UFix64, amountOut: UFix64, swapAForB: Bool)
    pub event Mint(poolId: UInt64, amountAIn: UFix64, amountBIn: UFix64)
    pub event Burn(poolId: UInt64, amountLP: UFix64, amountAOut: UFix64, amountBOut: UFix64)

    access(self) let lpTokenAdmin: @PierLPToken.Admin
    
    pub resource Pool: IPierPair.IPool {
        pub let poolId: UInt64
        pub var kLast: UInt256

        pub let tokenAType: Type
        pub let tokenBType: Type

        pub var lastBlockTimestamp: UFix64
        pub var lastPriceACumulative: Word64
        pub var lastPriceBCumulative: Word64

        // Lock to prevent reentrancy attacks
        access(self) var lock: Bool

        access(self) let tokenAVault: @FungibleToken.Vault
        access(self) let tokenBVault: @FungibleToken.Vault
        access(self) let lpTokenMaster: @PierLPToken.TokenMaster

        pub fun getReserves(): [UFix64; 2] {
            return [self.tokenAVault.balance, self.tokenBVault.balance]
        }

        pub fun swap(fromVault: @FungibleToken.Vault, forAmount: UFix64): @FungibleToken.Vault {
            pre {
                !self.lock: "Metapier PierPair: Reentrant call"
            }
            post {
                !self.lock: "Metapier PierPair: Lock not released"
            }
            self.lock = true

            let reserveALast = self.tokenAVault.balance
            let reserveBLast = self.tokenBVault.balance

            let swapAForB = fromVault.isInstance(self.tokenAType)
            var amountAIn = 0.0
            var amountBIn = 0.0
            var outputVault: @FungibleToken.Vault? <- nil

            if swapAForB {
                assert(reserveBLast > forAmount, message: "Metapier PierPair: Insufficient liquidity")
                amountAIn = fromVault.balance
                self.tokenAVault.deposit(from: <-fromVault)
                outputVault <-!self.tokenBVault.withdraw(amount: forAmount)
            } else {
                assert(reserveALast > forAmount, message: "Metapier PierPair: Insufficient liquidity")
                amountBIn = fromVault.balance
                self.tokenBVault.deposit(from: <-fromVault)
                outputVault <-!self.tokenAVault.withdraw(amount: forAmount)
            }

            let totalFeeCoefficient = UInt256(PierSwapSettings.getPoolTotalFeeCoefficient())

            // adjustedBalanceA = balanceA * 1000 - amountAIn * TotalFeeCoefficient
            let adjustedBalanceA = PierMath.UFix64ToRawUInt256(self.tokenAVault.balance) * 1000
                - PierMath.UFix64ToRawUInt256(amountAIn) * totalFeeCoefficient

            // adjustedBalanceB = balanceB * 1000 - amountBIn * TotalFeeCoefficient
            let adjustedBalanceB = PierMath.UFix64ToRawUInt256(self.tokenBVault.balance) * 1000
                - PierMath.UFix64ToRawUInt256(amountBIn) * totalFeeCoefficient

            // prevK = reserveALast * reserveBLast * 1000^2
            let prevK = PierMath.UFix64ToRawUInt256(reserveALast) 
                * PierMath.UFix64ToRawUInt256(reserveBLast)
                * 1_000_000

            assert(
                adjustedBalanceA * adjustedBalanceB >= prevK,
                message: "Metapier PierPair: K not maintained"
            )

            self.makeObservation(reserveA: reserveALast, reserveB: reserveBLast)

            emit Swap(
                poolId: self.poolId,
                amountIn: swapAForB ? amountAIn : amountBIn,
                amountOut: forAmount,
                swapAForB: swapAForB
            )

            self.lock = false
            return <-outputVault!
        }

        pub fun mint(vaultA: @FungibleToken.Vault, vaultB: @FungibleToken.Vault): @PierLPToken.Vault {
            pre {
                !self.lock: "Metapier PierPair: Reentrant call"
            }
            post {
                !self.lock: "Metapier PierPair: Lock not released"
            }
            self.lock = true

            let reserveALast = self.tokenAVault.balance
            let reserveBLast = self.tokenBVault.balance

            let amountA = vaultA.balance
            let amountB = vaultB.balance

            self.tokenAVault.deposit(from: <-vaultA)
            self.tokenBVault.deposit(from: <-vaultB)

            let isFeeOn = self.mintFee(reserveALast: reserveALast, reserveBLast: reserveBLast)

            // note that totalSupply can update in mintFee
            let totalSupply = PierMath.UFix64ToRawUInt256(PierLPToken.getTotalSupply(tokenId: self.poolId)!)
            var liquidity = 0 as UInt256
            if totalSupply == 0 {
                // first liquidity for this pool
                // liquidity = sqrt(amountA * amountB) - MINIMUM_LIQUIDITY
                liquidity = PierMath.sqrt(PierMath.UFix64ToRawUInt256(amountA) * PierMath.UFix64ToRawUInt256(amountB))
                    - PierMath.UFix64ToRawUInt256(PierPair.MINIMUM_LIQUIDITY)

                // permanently lock the first MINIMUM_LIQUIDITY tokens
                let minimumLP <- self.lpTokenMaster.mintTokens(amount: PierPair.MINIMUM_LIQUIDITY)
                destroy minimumLP
            } else {
                // liquidityA = amountA * totalSupply / reserveALast
                let liquidityA = PierMath.UFix64ToRawUInt256(amountA) * totalSupply 
                    / PierMath.UFix64ToRawUInt256(reserveALast)

                // liquidityB = amountB * totalSupply / reserveBLast
                let liquidityB = PierMath.UFix64ToRawUInt256(amountB) * totalSupply 
                    / PierMath.UFix64ToRawUInt256(reserveBLast)
                
                // liquidity = min(liquidityA, liquidityB)
                liquidity = liquidityA > liquidityB ? liquidityB : liquidityA
            }

            assert(liquidity > 0, message: "Metapier PierPair: Cannot mint zero liquidity")
            let lpTokenVault <-self.lpTokenMaster.mintTokens(amount: PierMath.rawUInt256ToUFix64(liquidity))

            if isFeeOn {
                // kLast = balanceA * balanceB
                self.kLast = PierMath.UFix64ToRawUInt256(self.tokenAVault.balance) 
                    * PierMath.UFix64ToRawUInt256(self.tokenBVault.balance)
            }

            self.makeObservation(reserveA: reserveALast, reserveB: reserveBLast)

            emit Mint(poolId: self.poolId, amountAIn: amountA, amountBIn: amountB)

            self.lock = false
            return <-lpTokenVault
        }

        pub fun burn(lpTokenVault: @PierLPToken.Vault): @[FungibleToken.Vault; 2]  {
            pre {
                !self.lock: "Metapier PierPair: Reentrant call"
            }
            post {
                !self.lock: "Metapier PierPair: Lock not released"
            }
            self.lock = true

            let reserveALast = self.tokenAVault.balance
            let reserveBLast = self.tokenBVault.balance
            let liquidity = lpTokenVault.balance
            let balanceA = self.tokenAVault.balance
            let balanceB = self.tokenBVault.balance

            let isFeeOn = self.mintFee(reserveALast: reserveALast, reserveBLast: reserveBLast)

            // note that totalSupply can update in mintFee
            let totalSupply = PierMath.UFix64ToRawUInt256(PierLPToken.getTotalSupply(tokenId: self.poolId)!)
            let liquidityUInt256 = PierMath.UFix64ToRawUInt256(liquidity)

            // amountA = liquidity * balanceA / totalSupply
            let amountA = liquidityUInt256 * PierMath.UFix64ToRawUInt256(balanceA) / totalSupply
            // amountB = liquidity * balanceB / totalSupply
            let amountB = liquidityUInt256 * PierMath.UFix64ToRawUInt256(balanceB) / totalSupply

            assert(
                amountA > 0 && amountB > 0,
                message: "Metapier PierPair: Insufficient liquidity to burn"
            )
    
            // burn LP tokens
            self.lpTokenMaster.burnTokens(vault: <-lpTokenVault)

            let outputTokens: @[FungibleToken.Vault; 2]  <-[
                <-self.tokenAVault.withdraw(amount: PierMath.rawUInt256ToUFix64(amountA)),
                <-self.tokenBVault.withdraw(amount: PierMath.rawUInt256ToUFix64(amountB))
            ]

            if isFeeOn {
                // kLast = balanceA * balanceB
                self.kLast = PierMath.UFix64ToRawUInt256(self.tokenAVault.balance) 
                    * PierMath.UFix64ToRawUInt256(self.tokenBVault.balance)
            }

            self.makeObservation(reserveA: reserveALast, reserveB: reserveBLast)

            emit Burn(
                poolId: self.poolId, 
                amountLP: liquidity, 
                amountAOut: outputTokens[0].balance, 
                amountBOut: outputTokens[1].balance
            )

            self.lock = false
            return <-outputTokens
        }

        // Updates the cumulative price information if this function
        // is called for the first time in the current block. 
        access(self) fun makeObservation(reserveA: UFix64, reserveB: UFix64) {
            let curTimestamp = getCurrentBlock().timestamp
            let timeElapsed = curTimestamp - self.lastBlockTimestamp

            if timeElapsed > 0.0 && reserveA != 0.0 && reserveB != 0.0 {
                self.lastBlockTimestamp = curTimestamp
                self.lastPriceACumulative = PierMath.computePriceCumulative(
                    lastPrice1Cumulative: self.lastPriceACumulative,
                    reserve1: reserveA,
                    reserve2: reserveB,
                    timeElapsed: timeElapsed
                )
                self.lastPriceBCumulative = PierMath.computePriceCumulative(
                    lastPrice1Cumulative: self.lastPriceBCumulative,
                    reserve1: reserveB,
                    reserve2: reserveA,
                    timeElapsed: timeElapsed
                )
            }
        }

        // Mints new LP tokens as protocol fees.
        access(self) fun mintFee(reserveALast: UFix64, reserveBLast: UFix64): Bool {
            let isFeeOn = PierSwapSettings.poolProtocolFee > 0.0
            if isFeeOn {
                if (self.kLast > 0) {
                    // rootK = sqrt(reserveALast * reserveBLast)
                    let rootK = PierMath.sqrt(PierMath.UFix64ToRawUInt256(reserveALast) 
                        * PierMath.UFix64ToRawUInt256(reserveBLast))

                    // rootKLast = sqrt(kLast)
                    let rootKLast = PierMath.sqrt(self.kLast)

                    let totalSupply = PierMath.UFix64ToRawUInt256(PierLPToken.getTotalSupply(tokenId: self.poolId)!)
                    if (rootK > rootKLast) {
                        // numerator = totalSupply * (rootK - rootKLast)
                        let numerator = totalSupply * (rootK - rootKLast)

                        // denominator = rootK * ProtocolFeeCoefficient + rootKLast
                        let denominator = rootK * UInt256(PierSwapSettings.getPoolProtocolFeeCoefficient()) + rootKLast

                        // liquidity = numerator / denominator
                        let liquidity = PierMath.rawUInt256ToUFix64(numerator / denominator)
                        if (liquidity > 0.0) {
                            let protocolFee <-self.lpTokenMaster.mintTokens(amount: liquidity)
                            PierSwapSettings.depositProtocolFee(vault: <-protocolFee)
                        }
                    }
                }
            } else if (self.kLast > 0) {
                self.kLast = 0
            }
            
            return isFeeOn
        }

        init(
            vaultA: @FungibleToken.Vault,
            vaultB: @FungibleToken.Vault,
            lpTokenMaster: @PierLPToken.TokenMaster,
            poolId: UInt64
        ) {
            pre {
                vaultA.balance == 0.0: "MetaPier PierPair: Pool creation requires empty vaults"
                vaultB.balance == 0.0: "MetaPier PierPair: Pool creation requires empty vaults"
                !vaultA.isInstance(vaultB.getType()) && !vaultB.isInstance(vaultA.getType()):
                    "MetaPier PierPair: Pool creation requires vaults of different types"
            }
            self.poolId = poolId
            self.kLast = 0

            self.tokenAVault <- vaultA
            self.tokenBVault <- vaultB
            self.tokenAType = self.tokenAVault.getType()
            self.tokenBType = self.tokenBVault.getType()

            self.lastBlockTimestamp = getCurrentBlock().timestamp
            self.lastPriceACumulative = 0
            self.lastPriceBCumulative = 0
            
            self.lpTokenMaster <- lpTokenMaster

            self.lock = false
        }

        destroy() {
            destroy self.tokenAVault
            destroy self.tokenBVault
            destroy self.lpTokenMaster
        }
    }
    
    // Creates a new pool resource.
    // This function is only accessible to code in the same account.
    access(account) fun createPool(        
        vaultA: @FungibleToken.Vault,
        vaultB: @FungibleToken.Vault,
        poolId: UInt64
    ): @Pool {
        return <-create PierPair.Pool(
            vaultA: <-vaultA,
            vaultB: <-vaultB,
            lpTokenMaster: <-self.lpTokenAdmin.initNewLPToken(tokenId: poolId),
            poolId: poolId
        )
    }
    
    init() {
        self.MINIMUM_LIQUIDITY = 0.00001

        // requires PierLPToken to be deployed to the same account
        self.lpTokenAdmin <-self.account.load<@PierLPToken.Admin>(from: /storage/metapierLPTokenAdmin)
            ?? panic("Metapier PierPair: Cannot load LP token admin")

        emit ContractInitialized()
    }
}
