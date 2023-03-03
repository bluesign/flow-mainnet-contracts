
import Genies from 0x12450e4bb3b7666e
import NonFungibleToken from 0x1d7e57aa55817448

pub contract GeniesAirdrop {
	
	pub event ContractInitialized()

	pub event GeniesNFTAirdropVaultCreateted(geniesVaultID: UInt64)

	// when Airdrop is created
	pub event AirdropCreated(
		nftId: UInt64,
		owner: Address?,
		receiver: Address?
	)

	// when Airdrop is claimed or deleted
	pub event AirdropCompleted(
		nftId: UInt64,
		owner: Address?,
		receiver: Address?,
		claimed: Bool
	)

	pub event CapabilityAdded(
		address: Address
	)

	pub let GeniesAdminStoragePath: StoragePath
 	pub let GeniesNFTAirdropVaultStoragePath: StoragePath
	pub let GeniesNFTAirdropVaultPrivatePath: PrivatePath
	pub let GeniesNFTAirdropVaultPublicPath: PublicPath

	pub resource Admin {
		access(self) var claimCapabilities: {Address: Capability<&{GeniesNFTAirdropVaultClaim}>}

		init() {
			self.claimCapabilities = {}
		}

		// This gives Admin the capability to claim the Airdrop on behalf of you.
		pub fun addClaimCapability(cap: Capability<&{GeniesNFTAirdropVaultClaim}>) {
			self.claimCapabilities[cap.address] = cap
			emit CapabilityAdded(address: cap.address)
		}

		// get the GeniesNFTAirdropVaultClaim capability for the resource owner
		pub fun getClaimCapability(address: Address): Capability<&{GeniesNFTAirdropVaultClaim}>? {
			pre {
				self.claimCapabilities[address] != nil: "No capability for this address."
			}
			return self.claimCapabilities[address]
		}

		pub fun createEmptyGeniesNFTAirdropVault(): @GeniesAirdrop.GeniesNFTAirdropVault {
			return <-create GeniesNFTAirdropVault()
		}
	}

	pub resource interface GeniesNFTAirdropVaultPublic {
		pub fun getIDs(): [UInt64]
	}

	pub resource interface GeniesNFTAirdropVaultClaim {
		pub fun claim(nftId: UInt64, address: Address)
	}

	pub resource GeniesNFTAirdropVault: GeniesNFTAirdropVaultPublic,  GeniesNFTAirdropVaultClaim {

		pub var ownerships: {UInt64: Address}
		pub var giftNFTs: {UInt64: Capability<&Genies.Collection{NonFungibleToken.Provider, Genies.GeniesNFTCollectionPublic}>}

		init() {
			self.giftNFTs = {}
			self.ownerships = {}
		}
		destroy() {
			self.giftNFTs = {}
			self.ownerships = {}
		}
		// nft owner can create airdrop and store the nft in their vault with optional receiverAddress.
		// If the receiverAddress is provided, only that address will be able to claim this nft. Otherwise, anyone can claim.
		pub fun createAirdrop(nftProviderCap: Capability<&Genies.Collection{NonFungibleToken.Provider, Genies.GeniesNFTCollectionPublic}>, nftId: UInt64, receiverAddress: Address?) {
			// Make sure the dictionary doesn't contain this nft id, so we don't accidentally destroy resource.
			// This should not happen in theory given nft id is unique.
			pre {
				!self.giftNFTs.containsKey(nftId): "Duplicate NFT Id"
				nftProviderCap.address == self.owner!.address: "Capability owner should be the same as the Vault resource owner"
			}
			self.giftNFTs[nftId] = nftProviderCap
			// setting the ownership of the nft if address is provided. Otherwise, this nft is ownershipless.
			if receiverAddress != nil {
				self.ownerships[nftId] = receiverAddress
			}
				
			emit AirdropCreated(nftId: nftId, owner: self.owner?.address, receiver: receiverAddress)
		}

		// claim an airdrop. nftId has to be valid.
		pub fun claim(nftId: UInt64, address: Address) {
			pre {
				self.giftNFTs.containsKey(nftId): "Invalid nftId to claim"
				
				// if the nft being claimed has assigned ownership, check the claimer's address first.
				!self.ownerships.containsKey(nftId) || self.ownerships[nftId] == address: "Invalid owner to claim"
			}

			let receiverAccount = getAccount(address)
			let claimerCollection = receiverAccount.getCapability(Genies.CollectionPublicPath)
				.borrow<&Genies.Collection{NonFungibleToken.Receiver}>()!

			let nftProviderCap = self.giftNFTs.remove(key: nftId) ?? panic("missing NFT id")
			let token <- nftProviderCap.borrow()!.withdraw(withdrawID: nftId)
			
			// Remove the nft id from the ownership table if the table contains. 
			if self.ownerships.containsKey(nftId) {
				self.ownerships.remove(key: nftId)
			}
			claimerCollection.deposit(token: <-token)
			
			emit AirdropCompleted(nftId: nftId, owner: self.owner?.address, receiver: address, claimed: true)

		}

		// delisting the Airdrop back to the owner, nftId must be valid.
		pub fun delistingAirdrop(nftId: UInt64) {
			pre {
				self.giftNFTs.containsKey(nftId): "Invalid nftId to remove"
			}
			
			self.giftNFTs.remove(key: nftId) ?? panic("missing NFT id")
			
			if self.ownerships.containsKey(nftId) {
				self.ownerships.remove(key: nftId)
			}

			emit AirdropCompleted(nftId: nftId, owner: self.owner?.address, receiver: self.owner?.address, claimed: false)			
		}

		// remove all Airdrops and store them back to the Genies.Collection resource.
		pub fun delistingAllAirdrops(claimerCollection: &Genies.Collection{NonFungibleToken.Receiver}) {
			let keys = self.getIDs()
			for key in keys {
				self.delistingAirdrop(nftId: key)
			}
		}

		pub fun getIDs(): [UInt64] {
        	return self.giftNFTs.keys
        }
	}

	init() {
		// set the named paths
		self.GeniesNFTAirdropVaultStoragePath = /storage/GeniesNFTAirdropVaultStoragePath
		self.GeniesNFTAirdropVaultPrivatePath = /private/GeniesNFTAirdropVaultPrivatePath
		self.GeniesNFTAirdropVaultPublicPath = /public/GeniesNFTAirdropVaultPublicPath

		self.GeniesAdminStoragePath = /storage/GeniesAdminStoragePath
		
		// create Admin resource. 
		let admin <- create Admin()
		self.account.save(<-admin, to: self.GeniesAdminStoragePath)
		emit ContractInitialized()

		// create GeniesNFTAirdropVault resource 
		let vault <- create GeniesNFTAirdropVault()
		self.account.save(<-vault, to: self.GeniesNFTAirdropVaultStoragePath)
		self.account.link<&GeniesAirdrop.GeniesNFTAirdropVault{GeniesAirdrop.GeniesNFTAirdropVaultPublic}>(
			GeniesAirdrop.GeniesNFTAirdropVaultPublicPath,
			target: GeniesAirdrop.GeniesNFTAirdropVaultStoragePath
		)
		self.account.link<&GeniesAirdrop.GeniesNFTAirdropVault{GeniesAirdrop.GeniesNFTAirdropVaultClaim}>(
			GeniesAirdrop.GeniesNFTAirdropVaultPrivatePath,
			target: GeniesAirdrop.GeniesNFTAirdropVaultStoragePath
		)
	}
}