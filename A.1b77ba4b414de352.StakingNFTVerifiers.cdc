/**
    A set of NFT eligibility verifiers to check whether a given nft is allowed.
    Use cases: e.g. All floats are in the same Collection, even if they belong to different FLOATEvents.

    More verifier can be added, and the interface is defined in StakingNFT.cdc

    Author: Increment Labs
*/

import NonFungibleToken from 0x1d7e57aa55817448
import FLOAT from 0x2d4c3caffbeab845
import StakingNFT from 0x1b77ba4b414de352

pub contract StakingNFTVerifiers {

    // Verifier to check if the given nft (FLOAT) belongs to a specific FloatEvent.
    pub struct FloatVerifier: StakingNFT.INFTVerifier {
        pub let eligibleEventId: UInt64

        pub fun verify(nftRef: auth &NonFungibleToken.NFT, extraParams: {String: AnyStruct}): Bool {
            let floatRef = (nftRef as? &FLOAT.NFT) ?? panic("Hmm...this nft is not a float")
            // Pool creator / admin should make sure float pool is correctly created with "eventId" && "hostAddr" parameters
            let eventIdFromParam = (extraParams["eventId"] ?? panic("Float eventId not set")) as! UInt64
            let hostFromParam = (extraParams["hostAddr"] ?? panic("FloatEvent host address not set")) as! Address
            return (floatRef.eventId == self.eligibleEventId) && (floatRef.eventId == eventIdFromParam) && (floatRef.eventHost == hostFromParam)
        }

        init(eventId: UInt64) {
            self.eligibleEventId = eventId
        }
    }

    // You're welcome to implement extra Verifier if necessary
}