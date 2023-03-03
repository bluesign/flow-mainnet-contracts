/// AthleteStudioMintCache is a utility contract to keep track of Athlete Studio editions
/// that have been minted in order to prevent duplicate mints.
///
/// It should be deployed to the same account as the AthleteStudio contract.
///
pub contract AthleteStudioMintCache {

    /// This dictionary indexes editions by their mint ID.
    ///
    /// It is populated at mint time and used to prevent duplicate mints.
    /// The mint ID can be any unique string value,
    /// for example the hash of the edition metadata.
    ///
    access(self) let editionsByMintID: {String: UInt64}

    /// Get an edition ID by its mint ID.
    ///
    /// This function returns nil if the edition is not in this index.
    ///
    pub fun getEditionByMintID(mintID: String): UInt64? {
        return AthleteStudioMintCache.editionsByMintID[mintID]
    }

    /// Insert an edition mint ID into the index.
    /// 
    /// This function can only be called by other contracts deployed to this account.
    /// It is intended to be called by the AthleteStudio contract when
    /// creating new editions.
    ///
    access(account) fun insertEditionMintID(mintID: String, editionID: UInt64) {
        AthleteStudioMintCache.editionsByMintID[mintID] = editionID
    }

    init() {
        self.editionsByMintID = {}
    }
}
