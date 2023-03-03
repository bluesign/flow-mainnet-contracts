/**

# Common lending config

# Author: Increment Labs

*/
pub contract LendingConfig {
    /// TwoSegmentsInterestRateModel.InterestRateModelPublicPath
    pub var InterestRateModelPublicPath: PublicPath
    /// SimpleOracle.OraclePublicPath
    pub var OraclePublicPath: PublicPath
    /// SimpleOracle.UpdaterPublicPath
    pub var UpdaterPublicPath: PublicPath
    /// value taken from LendingComptroller.ComptrollerPublicPath
    pub var ComptrollerPublicPath: PublicPath
    /// value taken from LendingComptroller.UserCertificateStoragePath
    pub var UserCertificateStoragePath: StoragePath
    /// value taken from LendingComptroller.UserCertificatePrivatePath
    pub var UserCertificatePrivatePath: PrivatePath
    /// value taken from LendingPool.PoolPublicPublicPath
    pub var PoolPublicPublicPath: PublicPath

    /// Scale factor applied to fixed point number calculation. For example: 1e18 means the actual baseRatePerBlock should
    /// be baseRatePerBlock / 1e18. Note: The use of scale factor is due to fixed point number in cadence is only precise to 1e-8:
    /// https://docs.onflow.org/cadence/language/values-and-types/#fixed-point-numbers
    /// It'll be truncated and lose accuracy if not scaled up. e.g.: APR 20% (0.2) => 0.2 / 12614400 blocks => 1.5855e-8
    ///  -> truncated as 1e-8.
    pub let scaleFactor: UInt256
    /// 100_000_000.0, i.e. 1.0e8
    pub let ufixScale: UFix64
    /// Reserved parameter fields: {ParamName: Value}
    access(self) let _reservedFields: {String: AnyStruct}

    /// Utility function to convert a UFix64 number to its scaled equivalent in UInt256 format
    /// e.g. 184467440737.09551615 (UFix64.max) => 184467440737095516150000000000
    pub fun UFix64ToScaledUInt256(_ f: UFix64): UInt256 {
        let integral = UInt256(f)
        let fractional = f % 1.0
        let ufixScaledInteger =  integral * UInt256(self.ufixScale) + UInt256(fractional * self.ufixScale)
        return ufixScaledInteger * self.scaleFactor / UInt256(self.ufixScale)
    }

    /// Utility function to convert a fixed point number in form of scaled UInt256 back to UFix64 format
    /// e.g. 184467440737095516150000000000 => 184467440737.09551615
    pub fun ScaledUInt256ToUFix64(_ scaled: UInt256): UFix64 {
        let integral = scaled / self.scaleFactor
        let ufixScaledFractional = (scaled % self.scaleFactor) * UInt256(self.ufixScale) / self.scaleFactor
        return UFix64(integral) + (UFix64(ufixScaledFractional) / self.ufixScale)
    }

    init() {
        self.InterestRateModelPublicPath = /public/InterestRateModel
        self.OraclePublicPath = /public/oracleModule
        self.UpdaterPublicPath = /public/oracleUpdaterProxy
        self.ComptrollerPublicPath = /public/comptrollerModule
        self.UserCertificateStoragePath = /storage/userCertificate_increment
        self.UserCertificatePrivatePath = /private/userCertificate_increment
        self.PoolPublicPublicPath = /public/incrementLendingPoolPublic

        // 1e18
        self.scaleFactor = 1_000_000_000_000_000_000
        // 1.0e8
        self.ufixScale = 100_000_000.0
        self._reservedFields = {}
    }
}