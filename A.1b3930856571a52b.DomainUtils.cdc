import Flowns from 0x233eb012d34b0070
import Domains from 0x233eb012d34b0070
import FIND from 0x097bafa4e0b48eef

pub contract DomainUtils {

    pub fun getAddressesOfDomains(names: [String], roots: [String]): {String: Address} {
        assert(names.length == roots.length, message: "names and roots should have the same length")
        let res: {String: Address} = {}
        for index, name in names {
            let root = roots[index]
            if let address = self.getAddressOfDomain(name: name, root: root) {
                let domain = name.concat(".").concat(root)
                res[domain] = address
            }
        }
        return res
    }

    pub fun getDefaultDomainsOfAddresses(_ addresses: [Address]): {Address: {String: String}} {
        let res: {Address: {String: String}} = {}
        for address in addresses {
            let domains = self.getDefaultDomainsOfAddress(address)
            res[address] = domains
        }
        return res
    }

    pub fun getAddressOfDomain(name: String, root: String): Address? {
        if let address = self.getFINDAddress(name: name, root: root) {
            return address
        }
        return self.getFlownsAddress(name: name, root: root)
    }

    pub fun getDefaultDomainsOfAddress(_ address: Address): {String: String} {
        let res: {String: String} = {}
        if let domainFIND = self.getFINDDefaultDomain(address: address) {
            res["find"] = domainFIND
        }
        if let domainFlowns = self.getFlownsDefaultDomain(address: address) {
            res["flowns"] = domainFlowns
        }
        return res
    }

    pub fun getFINDAddress(name: String, root: String): Address? {
        if root == "find" && FIND.validateFindName(name)  {
            return FIND.lookupAddress(name)
        }
        return nil
    }

    pub fun getFINDDefaultDomain(address: Address): String? {
        if let name = FIND.reverseLookup(address) {
            return name.concat(".find")
        }
        return nil
    }

    pub fun getFlownsAddress(name: String, root: String): Address? {
        let prefix = "0x"
        let rootHash = Flowns.hash(node: "", lable: root)
        let nameHash = prefix.concat(Flowns.hash(node: rootHash, lable: name))
        return Domains.getRecords(nameHash)
    }

    pub fun getFlownsDefaultDomain(address: Address): String? {
        let account = getAccount(address)
        let collectionCap = account.getCapability<&{Domains.CollectionPublic}>(Domains.CollectionPublicPath)
        if !collectionCap.check() {
            return nil
        }

        let collection = collectionCap.borrow()!
        let ids = collection.getIDs()
        if ids.length == 0 {
            return nil
        }

        var defaultDomainID: UInt64 = ids[0]
        for id in ids {
            let domain = collection.borrowDomain(id: id)
            let isDefault = domain.getText(key: "isDefault")
            if isDefault == "true" {
                defaultDomainID = id
                break
            }
        }

        let domain = collection.borrowDomain(id: defaultDomainID)
        return domain.getDomainName()
    }
}


