/**

PierMath provides the math utility functions for other contracts
under Pier Wharf v1.

@author Metapier Foundation Ltd.

 */
pub contract PierMath {

    // Event that is emitted when the contract is created
    pub event ContractInitialized()

    // fixed scaling factor 10^8 in UInt256
    access(self) let scaleUI256: UInt256
    // fixed scaling factor 10^8 in UFix64
    access(self) let scaleUF64: UFix64

    // Converts a UFix64 to a scaled UInt256 by multiplying 10^8
    // Examples:
    //  1.23456789 -> 123456789
    //  1.00000000 -> 100000000
    pub fun UFix64ToRawUInt256(_ n: UFix64): UInt256 {
        let fractionalPart = n % 1.0
        return UInt256(n) * self.scaleUI256 + UInt256(fractionalPart * self.scaleUF64)
    }

    // Converts a scaled UInt256 back to UFix64 by dividing 10^8
    // Examples:
    //  123456789 -> 1.23456789
    //  100000000 -> 1.00000000
    pub fun rawUInt256ToUFix64(_ n: UInt256): UFix64 {
        let fractionalPart = n % self.scaleUI256
        return UFix64(n / self.scaleUI256) + UFix64(fractionalPart) / self.scaleUF64
    }

    // Computes the square root of the UInt256 input
    // Examples:
    //  0 -> 0
    //  4 -> 2
    //  5 -> 2
    pub fun sqrt(_ x: UInt256): UInt256 {
        var z = x / 2 + 1
        var y = x
        while z < y {
            y = z
            z = (x / z + z) / 2
        }
        return y
    }

    // Computes the new cumulative price for TWAP
    //
    // @param lastPrice1Cumulative The most recent cumulative price of token 1
    // @param reserve1 The reserve balance of token 1
    // @param reserve2 The reserve balance of token 2
    // @param timeElapsed The time elapsed since `lastPrice1Cumulative` was recorded
    // @return The new cumulative price for TWAP
    pub fun computePriceCumulative(
        lastPrice1Cumulative: Word64, 
        reserve1: UFix64, 
        reserve2: UFix64, 
        timeElapsed: UFix64
    ): Word64 {
        // newPriceCumulative = lastPrice1Cumulative + reserve2 * timeElapsed / reserve1
        let newPriceCumulative = UInt256(lastPrice1Cumulative)
            + self.UFix64ToRawUInt256(reserve2) * self.UFix64ToRawUInt256(timeElapsed) / self.UFix64ToRawUInt256(reserve1)
        
        // mod 2^64 to handle overflow
        // Note: overflow may happen, but it doesn't affect the accuracy of price delta 
        return Word64(newPriceCumulative % 18446744073709551616)
    }

    // Converts a 64-bit Address to be presented in UInt64
    // Examples:
    //  0x1 -> 1
    //  0xf8d6e0586b0a20c7 -> 17930765636779778247
    pub fun AddressToUInt64(address: Address): UInt64 {
        let addressBytes = address.toBytes()
        assert(addressBytes.length == 8, message: "Metapier PierMath: Address should be 64 bits")

        return UInt64(addressBytes[0]) << 56
            | UInt64(addressBytes[1]) << 48
            | UInt64(addressBytes[2]) << 40
            | UInt64(addressBytes[3]) << 32
            | UInt64(addressBytes[4]) << 24
            | UInt64(addressBytes[5]) << 16
            | UInt64(addressBytes[6]) << 8
            | UInt64(addressBytes[7])
    }

    init() {
        self.scaleUI256 = 100_000_000
        self.scaleUF64 = 100_000_000.0

        emit ContractInitialized()
    }
}
