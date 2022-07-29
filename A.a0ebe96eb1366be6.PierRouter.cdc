import FungibleToken from 0xf233dcee88fe0abe
import PierPair from 0x609e10301860b683
import IPierPair from 0x609e10301860b683
import PierSwapFactory from 0x609e10301860b683
import PierLPToken from 0x609e10301860b683
import PierRouterLib from 0xa0ebe96eb1366be6

/**

PierRouter helps with liquidity position management and multi-hop token swap.
Slippage and deadline are provided as safety guards.

@author Metapier Foundation Ltd.

 */
pub contract PierRouter {

    // AddLPResult is a resource that stores the result of `addLiquidity`
    pub resource AddLPResult {
        // the amounts of tokens actually provided, in the order of [token A, token B]
        pub let amountsProvided: [UFix64; 2]
        // the LP tokens representing the share of pool of the provided liquidity 
        pub(set) var vaultLP: @PierLPToken.Vault

        init(amountsProvided: [UFix64; 2], vaultLP: @PierLPToken.Vault) {
            self.amountsProvided = amountsProvided
            self.vaultLP <- vaultLP
        }

        destroy() {
            destroy self.vaultLP
        }
    }

    // Adds liquidity to the pool of token A and token B.
    // Note: The order of `vaultA` and `vaultB` don't have to follow the same order of the token
    //  types in the `pool`. Ordering will be handled by this function automatically.
    //
    // @param pool Reference to the target liquidity pool
    // @param vaultA Reference to the vault from which to withdraw the liquidity for token A
    // @param vaultB Reference to the vault from which to withdraw the liquidity for token B
    // @param amountADesired The desired amount of token A to provide (upper bound)
    // @param amountBDesired The desired amount of token B to provide (upper bound)
    // @param amountAMin The minimum amount of token A to provide (lower bound)
    // @param amountBMin The minimum amount of token B to provide (lower bound)
    // @param deadline The deadline for this function to be executed
    // @return An AddLPResult resource containing amounts provided info and the minted LP tokens
    pub fun addLiquidity(
        pool: &PierPair.Pool{IPierPair.IPool},
        vaultA: &FungibleToken.Vault, 
        vaultB: &FungibleToken.Vault, 
        amountADesired: UFix64, 
        amountBDesired: UFix64, 
        amountAMin: UFix64, 
        amountBMin: UFix64, 
        deadline: UFix64
    ): @AddLPResult {
        pre {
            getCurrentBlock().timestamp < deadline: "Metapier PierRouter: Transaction expired"
            vaultA.balance >= amountAMin: "Metapier PierRouter: Insufficient token A to provide"
            vaultB.balance >= amountBMin: "Metapier PierRouter: Insufficient token B to provide"
        }

        // whether the order of the types of (vaultA, vaultB) match the order of the types
        // in the actual pool
        let tokenSorted = vaultA.isInstance(pool.tokenAType)
        let amountsProvided: [UFix64; 2] = [0.0, 0.0]
        let reserves = pool.getReserves()

        if !tokenSorted {
            // sort reserves to match with the given order of vaults
            reserves[0] <-> reserves[1]
        }

        if reserves[0] == 0.0 && reserves[1] == 0.0 {
            // initial liquidity
            amountsProvided[0] = amountADesired
            amountsProvided[1] = amountBDesired
        } else {
            // get quote, check amount of A optimal, B optimal.
            let amountBOptimal = PierRouterLib.quote(
                amountA: amountADesired, 
                reserveA: reserves[0], 
                reserveB: reserves[1]
            )

            if amountBOptimal <= amountBDesired {
                assert(amountBOptimal >= amountBMin, message: "Metapier PierRouter: Invalid amountBOptimal")
                amountsProvided[0] = amountADesired
                amountsProvided[1] = amountBOptimal
            } else {
                let amountAOptimal = PierRouterLib.quote(
                    amountA: amountBDesired, 
                    reserveA: reserves[1], 
                    reserveB: reserves[0]
                )
                assert(
                    amountAOptimal <= amountADesired && amountAOptimal >= amountAMin, 
                    message: "Metapier PierRouter: Invalid amountAOptimal"
                )
                amountsProvided[0] = amountAOptimal
                amountsProvided[1] = amountBDesired
            }
        }

        var tokensAToProvide <- vaultA.withdraw(amount: amountsProvided[0])
        var tokensBToProvide <- vaultB.withdraw(amount: amountsProvided[1])
        if !tokenSorted {
            // sort tokens to provide to match with the order of tokens in the pool
            tokensAToProvide <-> tokensBToProvide
        }
        let vaultLPMinted <- pool.mint(vaultA: <-tokensAToProvide, vaultB: <-tokensBToProvide)
        
        return <- create AddLPResult(amountsProvided: amountsProvided, vaultLP: <-vaultLPMinted)
    }

    // Burns the given LP tokens and stores the redeemed tokens to `vaultA` and `vaultB`.
    //
    // @param vaultA The reference to the vault receiver for token A
    // @param vaultB The reference to the vault receiver for token B
    // @param vaultLP The vault that contains the LP token to burn
    // @param amountAMin The minimum amount of token A to receive
    // @param amountBMin The minimum amount of token B to receive
    // @param deadline The deadline for this function to be executed
    // @return [amount of token A redeemed, amount of token B redeemed]
    pub fun removeLiquidity(
        vaultA: &{FungibleToken.Receiver}, 
        vaultB: &{FungibleToken.Receiver}, 
        vaultLP: @PierLPToken.Vault, 
        amountAMin: UFix64, 
        amountBMin: UFix64, 
        deadline: UFix64
    ): [UFix64; 2] {
        pre {
            getCurrentBlock().timestamp < deadline: "Metapier PierRouter: Transaction expired"
        }
        post {
            result[0] >= amountAMin: "Metapier PierRouter: Cannot redeem less than amountAMin of token A"
            result[1] >= amountBMin: "Metapier PierRouter: Cannot redeem less than amountBMin of token B"
        }

        let pool = PierSwapFactory.getPoolByTypes(tokenAType: vaultA.getType(), tokenBType: vaultB.getType())!
        let vaultsRedeemed <- pool.burn(lpTokenVault: <-vaultLP)
        var tokensARedeemed <- vaultsRedeemed[0].withdraw(amount: vaultsRedeemed[0].balance)
        var tokensBRedeemed <- vaultsRedeemed[1].withdraw(amount: vaultsRedeemed[1].balance)
        destroy vaultsRedeemed

        if !tokensARedeemed.isInstance(vaultA.getType()) {
            // sort vaults redeemed according to the order of (vaultA, vaultB)
            tokensARedeemed <-> tokensBRedeemed
        }

        let amountsRedeemed: [UFix64; 2] = [tokensARedeemed.balance, tokensBRedeemed.balance]
        vaultA.deposit(from: <-tokensARedeemed)
        vaultB.deposit(from: <-tokensBRedeemed)
        return amountsRedeemed
    }

    // Swap exact amount of token A for some token B by following the given path.
    //
    // @param fromVault The vault from which to withdraw `amountIn` amount of token A
    // @param toVault The vault receiver to receive token B
    // @param amountIn The exact amount of token A as the input for this swap
    // @param amountOutMin The minimum amount of token B to receive
    // @param path The path to follow for this swap. E.g., [A.0x01.TokenA, A.0x02.TokenB, A.0x03.TokenC]
    // @param deadline The deadline for this swap to execute
    // @return The actual amount of token B out
    pub fun swapExactTokensAForTokensB(
        fromVault: &FungibleToken.Vault, 
        toVault: &{FungibleToken.Receiver}, 
        amountIn: UFix64, 
        amountOutMin: UFix64, 
        path: [String], 
        deadline: UFix64
    ): UFix64 {
        pre {
            getCurrentBlock().timestamp < deadline: "Metapier PierRouter: Transaction expired"
            fromVault.balance >= amountIn: "Metapier PierRouter: Insufficient input balance"
        }

        let pathRef = &path as &[String]
        let pools = PierRouterLib.getPoolsByPath(path: pathRef)
        let poolsRef = &pools as &[&{IPierPair.IPool}]

        let amounts = PierRouterLib.getAmountsByAmountIn(amountIn: amountIn, path: pathRef, pools: poolsRef)
        let amountOut = amounts[amounts.length - 1]
        
        assert(amountOut >= amountOutMin, message: "Metapier PierRouter: Insufficient output amount")

        let amountsRef = &amounts as &[UFix64]
        let swapOutput <-PierRouterLib.makeSwaps(
            inputVault: <-fromVault.withdraw(amount: amountIn), 
            pools: poolsRef, 
            amounts: amountsRef
        )
        toVault.deposit(from: <-swapOutput)

        return amountOut
    }

    // Swap some token A for the exact amount of token B by following the given path.
    //
    // @param fromVault The vault from which to withdraw token A
    // @param toVault The vault receiver to receive `amountOut` amount of token B
    // @param amountInMax The maximum amount of token A as the input for this swap
    // @param amountOut The exact amount of token B to receive
    // @param path The path to follow for this swap. E.g., [A.0x01.TokenA, A.0x02.TokenB, A.0x03.TokenC]
    // @param deadline The deadline for this swap to execute
    // @return The actual amount of token A in
    pub fun swapTokensAForExactTokensB(
        fromVault: &FungibleToken.Vault, 
        toVault: &{FungibleToken.Receiver}, 
        amountInMax: UFix64, 
        amountOut: UFix64, 
        path: [String], 
        deadline: UFix64
    ): UFix64 {
        pre {
            getCurrentBlock().timestamp < deadline: "Metapier PierRouter: Transaction expired"
        }

        let pathRef = &path as &[String]
        let pools = PierRouterLib.getPoolsByPath(path: pathRef)
        let poolsRef = &pools as &[&{IPierPair.IPool}]

        let amounts = PierRouterLib.getAmountsByAmountOut(amountOut: amountOut, path: pathRef, pools: poolsRef)
        let amountIn = amounts[0]

        assert(amountIn <= amountInMax, message: "Metapier PierRouter: Excessive input amount")

        let amountsRef = &amounts as &[UFix64]
        let swapOutput <-PierRouterLib.makeSwaps(
            inputVault: <-fromVault.withdraw(amount: amountIn), 
            pools: poolsRef, 
            amounts: amountsRef
        )
        toVault.deposit(from: <-swapOutput)

        return amountIn   
    }
} 
