import FungibleToken from 0xf233dcee88fe0abe
import PierLPToken from 0x609e10301860b683
import IPierPair from 0x609e10301860b683
import PierPair from 0x609e10301860b683
import PierMath from 0xa378eeb799df8387
import PierSwapSettings from 0x066a74dfb4da0306
import FlowToken from 0x1654653399040a61
import FlowStorageFees from 0xe467b9dd11fa00df

/**

PierSwapFactory is responsible for creating new pools
and querying existing pools.

@author Metapier Foundation Ltd.

 */
pub contract PierSwapFactory {

    // Event that is emitted when the contract is created
    pub event ContractInitialized()

    // Event that is emitted when a new pool is created
    pub event NewPoolCreated(poolId: UInt64)

    // Defines liquidity pool storage path
    pub let SwapPoolStoragePath: StoragePath

    // Defines liquidity pool public access path
    pub let SwapPoolPublicPath: PublicPath

    // A mapping from pair hash to pool id (pool owner's address in UInt64)
    access(self) let pairHashToPoolId: {String: UInt64}

    // An array of pool ids (pool owner's addresses in UInt64) in their
    // creation order
    access(self) let pools: [UInt64]

    // Computes the unique hash for a pair (token A, token B) indicated by
    // the given type identifiers.
    // 
    // @param tokenATypeIdentifier The type identifier of token A's vault (e.g., A.0x1654653399040a61.FlowToken.Vault)
    // @param tokenBTypeIdentifier The type identifier of token B's vault (e.g., A.0x3c5959b568896393.FUSD.Vault)
    // @return A unique hash string for the pair
    access(self) fun getPairHash(tokenATypeIdentifier: String, tokenBTypeIdentifier: String): String {
        // "\n" should be an invalid syntax for type identifier, thus making sure the raw id
        // is unique for each pair of type identifiers.
        let rawId = tokenATypeIdentifier.concat("\n").concat(tokenBTypeIdentifier)
        return String.encodeHex(HashAlgorithm.SHA3_256.hash(rawId.utf8))
    }

    // Returns the number of liquidity pools created so far
    pub fun getPoolsSize(): Int {
        return self.pools.length
    }

    // Queries the pool id (owner's address) of the liquidity pool
    // at the requested index.
    //
    // @param index The index of the stored liquidity pool
    // @return The pool id representing the pool owner's address
    //  (in UInt64)
    pub fun getPoolIdByIndex(index: UInt64): UInt64 {
        return self.pools[index]
    }

    // Queries a liquidity pool resource reference by borrowing it from
    // the address represented by the pool id.
    //
    // @param poolId The pool id representing the pool owner's address
    // @return The resource reference of the requested liquidity pool
    pub fun getPoolById(poolId: UInt64): &PierPair.Pool{IPierPair.IPool} {
        let address = Address(poolId)
        return getAccount(address).getCapability<&PierPair.Pool{IPierPair.IPool}>(self.SwapPoolPublicPath).borrow()
            ?? panic("Metapier PierSwapFactory: Couldn't borrow swap pool from the account")
    }

    // Queries a liquidity pool resource reference using the
    // requested index.
    //
    // @param index The index of the stored liquidity pool
    // @return The resource reference of the requested liquidity pool
    pub fun getPoolByIndex(index: UInt64): &PierPair.Pool{IPierPair.IPool} {
        return self.getPoolById(poolId: self.pools[index])
    }

    // Queries a liquidity pool resource reference using the types
    // of a token pair.
    //
    // @param tokenAType The type of token A's vault
    // @param tokenBType The type of token B's vault
    // @return The resource reference of the requested liquidity pool, or nil
    //  if there's no liquidity pool for the token pair
    pub fun getPoolByTypes(tokenAType: Type, tokenBType: Type): &PierPair.Pool{IPierPair.IPool}? {
        let pairHash = self.getPairHash(
            tokenATypeIdentifier: tokenAType.identifier, 
            tokenBTypeIdentifier: tokenBType.identifier
        )

        if let poolId = self.pairHashToPoolId[pairHash] {
            return self.getPoolById(poolId: poolId)
        }
        return nil
    }

    // Queries a liquidity pool resource reference using the type
    // identifiers of a token pair.
    //
    // @param tokenATypeIdentifier The type identifier of token A's vault
    // @param tokenBTypeIdentifier The type identifier of token B's vault
    // @return The resource reference of the requested liquidity pool, or nil
    //  if there's no liquidity pool for the token pair
    pub fun getPoolByTypeIdentifiers(tokenATypeIdentifier: String, tokenBTypeIdentifier: String): &PierPair.Pool{IPierPair.IPool}? {
        let pairHash = self.getPairHash(
            tokenATypeIdentifier: tokenATypeIdentifier, 
            tokenBTypeIdentifier: tokenBTypeIdentifier
        )
        
        if let poolId = self.pairHashToPoolId[pairHash] {
            return self.getPoolById(poolId: poolId)
        }
        return nil
    }

    // Queries the pool id of a liquidity pool using the type 
    // identifiers of a token pair.
    //
    // @param tokenATypeIdentifier The type identifier of token A's vault
    // @param tokenBTypeIdentifier The type identifier of token B's vault
    // @return The pool id of the requested liquidity pool, or nil if
    //  there's no liquidity pool for the token pair
    pub fun getPoolIdByTypeIdentifiers(tokenATypeIdentifier: String, tokenBTypeIdentifier: String): UInt64? {
        let pairHash = self.getPairHash(
            tokenATypeIdentifier: tokenATypeIdentifier, 
            tokenBTypeIdentifier: tokenBTypeIdentifier
        )

        if let poolId = self.pairHashToPoolId[pairHash] {
            return poolId
        }
        return nil
    }

    // Creates a new liquidity pool resource for the given token pair,
    // and stores the new resource in a new account.
    //
    // @param vaultA An empty vault of token A in the pair
    // @param vaultB An empty vault of token B in the pair
    // @param fees A vault that contains the minimum amount of Flow token for account creation
    // @return The pool id of the new liquidity pool
    pub fun createPoolForPair(
        vaultA: @FungibleToken.Vault,
        vaultB: @FungibleToken.Vault,
        fees: @FungibleToken.Vault
    ): UInt64 {
        pre {
            vaultA.balance == 0.0: "MetaPier PierSwapFactory: Pool creation requires empty vaults"
            vaultB.balance == 0.0: "MetaPier PierSwapFactory: Pool creation requires empty vaults"
            fees.balance >= FlowStorageFees.minimumStorageReservation: 
                "Metapier PierSwapFactory: Expecting minimum storage fees for account creation"
        }

        // deposits fees for account creation
        let receiverRef = self.account
            .getCapability(/public/flowTokenReceiver)
            .borrow<&FlowToken.Vault{FungibleToken.Receiver}>()
			?? panic("Metapier PierSwapFactory: Could not borrow receiver reference to the Flow Token Vault")
        receiverRef.deposit(from: <- fees)

        // computes the hash strings for both (A, B) and (B, A)
        let tokenATypeIdentifier = vaultA.getType().identifier
        let tokenBTypeIdentifier = vaultB.getType().identifier
        let pairABHash = self.getPairHash(
            tokenATypeIdentifier: tokenATypeIdentifier, 
            tokenBTypeIdentifier: tokenBTypeIdentifier
        )
        let pairBAHash = self.getPairHash(
            tokenATypeIdentifier: tokenBTypeIdentifier,
            tokenBTypeIdentifier: tokenATypeIdentifier
        )

        assert(
            !self.pairHashToPoolId.containsKey(pairABHash) && !self.pairHashToPoolId.containsKey(pairBAHash), 
            message: "MetaPier PierSwapFactory: Pool already exists for this pair"
        )

        // creates a new account without an owner (public key)
        let newAccount = AuthAccount(payer: self.account)

        // converts the new account's address to pool id
        let newPoolId = PierMath.AddressToUInt64(address: newAccount.address)

        // creates the new liquidity pool resource
        let newPool <- PierPair.createPool(vaultA: <-vaultA, vaultB: <-vaultB, poolId: newPoolId)

        // stores the new pool into the new account
        newAccount.save(<-newPool, to: self.SwapPoolStoragePath)
        newAccount.link<&PierPair.Pool{IPierPair.IPool}>(self.SwapPoolPublicPath, target: self.SwapPoolStoragePath)

        // registers the pairs (A, B) and (B, A), assigns them to the same pool
        self.pairHashToPoolId[pairABHash] = newPoolId
        self.pairHashToPoolId[pairBAHash] = newPoolId
        // also appends the new pool id to `self.pools`
        self.pools.append(newPoolId)

        emit NewPoolCreated(poolId: newPoolId)
        return newPoolId
    }

    init() {
        self.SwapPoolStoragePath = /storage/metapierSwapPool
        self.SwapPoolPublicPath = /public/metapierSwapPoolPublic
        self.pairHashToPoolId = {}
        self.pools = []

        emit ContractInitialized()
    }
}