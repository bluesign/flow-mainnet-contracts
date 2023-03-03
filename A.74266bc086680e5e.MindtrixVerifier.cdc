/*
============================================================
Name: NFT Verifier Contract for Mindtrix
============================================================
This contract is inspired from FLOATVerifiers that comes from
Emerald City, Jacob Tucker.
It abstracts the verification logic out of the main contract.
Therefore, this contract is scalable with other forms of
conditions.
*/

import MindtrixViews from 0x74266bc086680e5e
import MindtrixEssence from 0x74266bc086680e5e

pub contract MindtrixVerifier {

    pub struct TimeLock: MindtrixViews.IVerifier {

        pub let startTime: UFix64
        pub let endTime: UFix64
        
        pub fun verify(_ params: {String: AnyStruct}) {
            let currentTime = getCurrentBlock().timestamp
            assert(
                currentTime >= self.startTime,
                message: "This Mindtrix NFT is yet to start."
            )
            assert(
                currentTime <= self.endTime,
                message: "Oops! The time has run out to mint this Mindtrix NFT."
            )
        }

        init(startTime: UFix64, endTime: UFix64) {
            self.startTime = startTime
            self.endTime = endTime
        }
    }

    // deprecated, use LimitedQuantityV2 instead
    pub struct LimitedQuantity: MindtrixViews.IVerifier {
        pub var maxEdition: UInt64
        pub var maxMintTimesPerAddress: UInt64

        pub fun verify(_ params: {String: AnyStruct}){
            let currentEdition = params["currentEdition"]! as! UInt64
            let recipientAddress: Address = params["recipientAddress"]! as! Address
            let recipientMintTimes = params["recipientMintQuantityPerTransaction"]! as! UInt64
        
            assert(currentEdition < self.maxEdition, message: "Oops! Run out of the supply!")
            assert(recipientMintTimes < self.maxMintTimesPerAddress, message: "The address has reached the max mint times.")
        }

        init(maxEdition: UInt64, maxMintTimesPerAddress: UInt64, maxQuantityPerTransaction: UInt64) {
            self.maxEdition = maxEdition
            self.maxMintTimesPerAddress = maxMintTimesPerAddress
        }
    }

    pub struct LimitedQuantityV2: MindtrixViews.IVerifier {
        pub var intDic: {String: UInt64}
        pub var fixDic: {String: UFix64}

        pub fun verify(_ params: {String: AnyStruct}){
            let maxEdition = self.intDic["maxEdition"]!
            let maxMintTimesPerAddress = self.intDic["maxMintTimesPerAddress"]!
            let maxMintQuantityPerTransaction = self.intDic["maxMintQuantityPerTransaction"]!

            let currentEdition = params["currentEdition"]! as! UInt64
            let recipientAddress: Address = params["recipientAddress"]! as! Address
            let recipientMaxMintTimesPerAddress = params["recipientMaxMintTimesPerAddress"]! as! UInt64
            let recipientMintQuantityPerTransaction = params["recipientMintQuantityPerTransaction"]! as! UInt64
        
            assert(currentEdition < maxEdition, message: "Oops! Run out of the supply!")
            assert(recipientMaxMintTimesPerAddress < maxMintTimesPerAddress, message: "The address has reached the max mint times.")
            assert(recipientMintQuantityPerTransaction <= maxMintQuantityPerTransaction, 
                message: "Cannot mint over ".concat(maxMintQuantityPerTransaction.toString()).concat(" per transaction!"))
        }

        init(intDic: {String: UInt64}, fixDic: {String: UFix64} ) {
            self.intDic = intDic
            self.fixDic = fixDic
        }
    }

}
 