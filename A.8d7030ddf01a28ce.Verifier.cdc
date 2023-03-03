/*
============================================================
Name: NFT Verifier Contract for Mindtrix
============================================================
This contract is inspired from FLOATVerifiers that comes from
Emerald City, Jacob Tucker.
It abstracts the verification logic out of the main conteact.
Therefore, this contract is scalable with other forms of
conditions.
*/
// import Mindtrix from "./Mindtrix.cdc"

//dev
// import Mindtrix from 0xf8d6e0586b0a20c7

// staging
// import Mindtrix from 0x1ed02a22a3821c65

// pro
import Mindtrix from 0x8d7030ddf01a28ce

pub contract Verifier {

    pub struct TimeLock: Mindtrix.IVerifier {

        pub let startTime: UFix64
        pub let endTime: UFix64

        // The _ (underscore) indicates that a parameter in a function has no argument label.
        pub fun verify(_ params: {String: AnyStruct}) {
            let currentTime = getCurrentBlock().timestamp
            log("essence start time:".concat(self.startTime.toString()))
            log("essence end time:".concat(self.endTime.toString()))
            assert(
                currentTime >= self.startTime,
                message: "This Mindtrix NFT is yet to start."
            )
            assert(
                 currentTime <= self.endTime,
                message: "Oops! The time has run out to mint this Mindtrix NFT."
            )
        }

        init(startTime: UFix64, duration: UFix64) {
            self.startTime = startTime
            self.endTime = self.startTime + duration
        }
    }

    pub struct LimitedQuantity: Mindtrix.IVerifier {
        pub var capacity: UInt64

        pub fun verify(_ params: {String: AnyStruct}){
            let totalSupply = Mindtrix.totalSupply;
            assert(
                totalSupply < self.capacity,
                message: "Oops! Run out of the supply!"
              )

        }
        init(capacity: UInt64) {
            self.capacity = capacity
        }
    }

}
