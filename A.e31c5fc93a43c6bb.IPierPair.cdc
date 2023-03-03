import FungibleToken from 0xf233dcee88fe0abe
import PierLPToken from 0xe31c5fc93a43c6bb 
import PierMath from 0x3620aa78dc6c5b54 

/**

IPierPair is the interface that defines the parts of a pair
that should be exposed to public access.

@author Metapier Foundation Ltd.

 */
pub contract interface IPierPair {

    // Event that is emitted when the contract is created
    pub event ContractInitialized()

    // Event that is emitted when swap is executed
    pub event Swap(poolId: UInt64, amountIn: UFix64, amountOut: UFix64, swapAForB: Bool)

    // Event that is emitted when mint is executed
    pub event Mint(poolId: UInt64, amountAIn: UFix64, amountBIn: UFix64)

    // Event that is emitted when burn is executed
    pub event Burn(poolId: UInt64, amountLP: UFix64, amountAOut: UFix64, amountBOut: UFix64)

    // IPool defines the exposed components of a liquidity pool
    pub resource interface IPool {
        
        // *** Basic Information ***

        // The identifier (owner's address) of the pool
        pub let poolId: UInt64
        // The K value computed by the last mint or burn
        pub var kLast: UInt256

        // Type of token A's vault (e.g., A.0x1654653399040a61.FlowToken.Vault)
        pub let tokenAType: Type
        // Type of token B's vault (e.g., A.0x3c5959b568896393.FUSD.Vault)
        pub let tokenBType: Type

        // returns [token A reserve, token B reserve]
        pub fun getReserves(): [UFix64; 2]

        // *** TWAP Information for Oracles ***

        // The timestamp of the most recent burn, mint, or swap
        pub var lastBlockTimestamp: UFix64

        // use Word64 instead of UFix64 because overflow is acceptable
        // as long as the delta can be computed correctly
        pub var lastPriceACumulative: Word64
        pub var lastPriceBCumulative: Word64

        // *** Trading & Liquidity ***

        // Takes in a vault of token A or token B, then returns a vault of the other token
        // with its balance equals to `forAmount`. It throws an error if the `xy = k` curve
        // cannot be maintained.
        //
        // @param fromVault The input vault of the swap (either token A or token B)
        // @param forAmount The expected output balance of the swap
        // @return A vault of the other token in the pool with its balance equals to `forAmount`
        pub fun swap(fromVault: @FungibleToken.Vault, forAmount: UFix64): @FungibleToken.Vault {
            pre {
                forAmount > 0.0: "Metapier IPierPair: Zero swap output amount"
                fromVault.balance > 0.0: "Metapier IPierPair: Zero swap input amount"
                fromVault.isInstance(self.tokenAType) || fromVault.isInstance(self.tokenBType): "Metapier IPierPair: Invalid swap input type"
            }
            post {
                !result.isInstance(before(fromVault.getType())): "Metapier IPierPair: Unexpected swap output"
                result.isInstance(self.tokenAType) || result.isInstance(self.tokenBType): "Metapier IPierPair: Unexpected swap output"
                result.balance == forAmount: "Metapier IPierPair: Inaccurate swap output amount"
            }
        }

        // Mints new LP tokens by providing liquidity to the pool.
        //
        // @param vaultA Liquidity to provide for token A
        // @param vaultB Liquidity to provide for token B
        // @return New LP tokens as a share of the pool
        pub fun mint(vaultA: @FungibleToken.Vault, vaultB: @FungibleToken.Vault): @PierLPToken.Vault {
            pre {
                vaultA.balance > 0.0 && vaultB.balance > 0.0: "Metapier IPierPair: Zero mint input amount"
                vaultA.isInstance(self.tokenAType): "Metapier IPierPair: Invalid token A for mint"
                vaultB.isInstance(self.tokenBType): "Metapier IPierPair: Invalid token B for mint"
            }
            post {
                result.tokenId == self.poolId: "Metapier IPierPair: Unexpected LP token minted"
            }
        }

        // Burns the given LP tokens to withdraw its share of the pool.
        //
        // @param lpTokenVault The LP tokens to burn
        // @return The withdrawn share of the pool as [token A vault, token B vault]
        pub fun burn(lpTokenVault: @PierLPToken.Vault): @[FungibleToken.Vault; 2] {
            pre {
                lpTokenVault.tokenId == self.poolId: "Metapier IPierPair: Invalid LP token to burn"
                lpTokenVault.balance > 0.0: "Metapier IPierPair: Zero balance to burn"
            }
            post {
                result[0].isInstance(self.tokenAType): "Metapier IPierPair: Unexpected burn output"
                result[1].isInstance(self.tokenBType): "Metapier IPierPair: Unexpected burn output"
            }
        }
    }
}
