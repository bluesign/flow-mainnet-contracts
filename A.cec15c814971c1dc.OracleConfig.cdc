/**

# Desc This contract stores some commonly used paths for PriceOracle

# Author Increment Labs

*/

pub contract OracleConfig {
    // Admin resource stored in every PriceOracle contract
    pub let OracleAdminPath: StoragePath
    // Reader public interface exposed in every PriceOracle contract
    pub let OraclePublicInterface_ReaderPath: PublicPath
    // Feeder public interface exposed in every PriceOracle contract
    pub let OraclePublicInterface_FeederPath: PublicPath
    // Recommended storage path of reader's certificate
    pub let ReaderCertificateStoragePath: StoragePath

    init() {
        self.OracleAdminPath = /storage/increment_oracle_admin
        self.OraclePublicInterface_ReaderPath = /public/increment_oracle_reader_public
        self.OraclePublicInterface_FeederPath = /public/increment_oracle_feeder_public
        self.ReaderCertificateStoragePath = /storage/increment_oracle_reader_certificate
    }
}