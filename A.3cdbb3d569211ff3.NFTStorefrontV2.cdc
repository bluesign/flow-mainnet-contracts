import FungibleToken from 0xf233dcee88fe0abe
import NonFungibleToken from 0x1d7e57aa55817448
import MetadataViews from 0x1d7e57aa55817448

import DapperUtilityCoin from 0xead892083b3e2c6c
import FlowUtilityToken from 0xead892083b3e2c6c

import Permitted from 0x3cdbb3d569211ff3
import FlowtyUtils from 0x3cdbb3d569211ff3
import RoyaltiesOverride from 0x3cdbb3d569211ff3

/// NFTStorefrontV2
///
/// A general purpose sale support contract for NFTs that implement the Flow NonFungibleToken standard.
///
/// Each account that wants to list NFTs for sale installs a Storefront,
/// and lists individual sales within that Storefront as Listings.
/// There is one Storefront per account, it handles sales of all NFT types
/// for that account.
///
/// Each Listing can have one or more "cuts" of the sale price that
/// goes to one or more addresses. Cuts can be used to pay listing fees
/// or other considerations.
/// Each Listing can include a commission amount that is paid to whoever facilitates
/// the purchase. The seller can also choose to provide an optional list of marketplace
/// receiver capabilities. In this case, the commission amount must be transferred to
/// one of the capabilities in the list.
///
/// Each NFT may be listed in one or more Listings, the validity of each
/// Listing can easily be checked.
///
/// Purchasers can watch for Listing events and check the NFT type and
/// ID to see if they wish to buy the listed item.
/// Marketplaces and other aggregators can watch for Listing events
/// and list items of interest.
///
pub contract NFTStorefrontV2 {

		pub event StorefrontInitialized(storefrontResourceID: UInt64)

		pub event StorefrontDestroyed(storefrontResourceID: UInt64)

		/// ListingAvailable
		/// A listing has been created and added to a Storefront resource.
		/// The Address values here are valid when the event is emitted, but
		/// the state of the accounts they refer to may change outside of the
		/// NFTStorefrontV2 workflow, so be careful to check when using them.
		///
		pub event ListingAvailable(
				storefrontAddress: Address,
				listingResourceID: UInt64,
				nftType: String,
				nftUUID: UInt64,
				nftID: UInt64,
				salePaymentVaultType: String,
				salePrice: UFix64,
				customID: String?,
				commissionAmount: UFix64,
				commissionReceivers: [Address]?,
				expiry: UInt64,
				buyer: Address?
		)

		/// ListingCompleted
		/// The listing has been resolved. It has either been purchased, removed or destroyed.
		///
		pub event ListingCompleted(
				listingResourceID: UInt64,
				storefrontResourceID: UInt64,
				storefrontAddress: Address?,
				purchased: Bool,
				nftType: String,
				nftUUID: UInt64,
				nftID: UInt64,
				salePaymentVaultType: String,
				salePrice: UFix64,
				customID: String?,
				commissionAmount: UFix64,
				commissionReceiver: Address?,
				expiry: UInt64,
				buyer: Address?
		)

		/// left here for legacy reasons, we do not use it.
		pub event UnpaidReceiver()

		/// MissingReceiver
		pub event MissingReceiver(receiver: Address, amount: UFix64)

		/// StorefrontStoragePath
		/// The location in storage that a Storefront resource should be located.
		pub let StorefrontStoragePath: StoragePath

		/// StorefrontPublicPath
		/// The public location for a Storefront link.
		pub let StorefrontPublicPath: PublicPath

		pub let AdminStoragePath: StoragePath

		access(contract) let CommissionRecipients: {Type: Address}

		/// SaleCut
		/// A struct representing a recipient that must be sent a certain amount
		/// of the payment when a token is sold.
		///
		pub struct SaleCut {
				/// The receiver for the payment.
				/// Note that we do not store an address to find the Vault that this represents,
				/// as the link or resource that we fetch in this way may be manipulated,
				/// so to find the address that a cut goes to you must get this struct and then
				/// call receiver.borrow()!.owner.address on it.
				/// This can be done efficiently in a script.
				pub let receiver: Capability<&{FungibleToken.Receiver}>

				/// The amount of the payment FungibleToken that will be paid to the receiver.
				pub let amount: UFix64

				/// initializer
				///
				init(receiver: Capability<&{FungibleToken.Receiver}>, amount: UFix64) {
						self.receiver = receiver
						self.amount = amount
				}
		}


		/// ListingDetails
		/// A struct containing a Listing's data.
		///
		pub struct ListingDetails {
				pub var storefrontID: UInt64
				/// Whether this listing has been purchased or not.
				pub var purchased: Bool
				/// The Type of the NonFungibleToken.NFT that is being listed.
				pub let nftType: Type
				/// The Resource ID of the NFT which can only be set in the contract
				pub let nftUUID: UInt64
				/// The unique identifier of the NFT that will get sell.
				pub let nftID: UInt64
				/// The Type of the FungibleToken that payments must be made in.
				pub let salePaymentVaultType: Type
				/// The amount that must be paid in the specified FungibleToken.
				pub let salePrice: UFix64
				/// This specifies the division of payment between recipients.
				pub let saleCuts: [SaleCut]
				/// Allow different dapp teams to provide custom strings as the distinguisher string
				/// that would help them to filter events related to their customID.
				pub var customID: String?
				/// Commission available to be claimed by whoever facilitates the sale.
				pub let commissionAmount: UFix64
				/// Expiry of listing
				pub let expiry: UInt64
				/// Optional specified purchasing address for private listings
				pub let buyer: Address?

				/// Irreversibly set this listing as purchased.
				///
				access(contract) fun setToPurchased() {
						self.purchased = true
				}

				access(contract) fun setCustomID(customID: String?){
						self.customID = customID
				}

				/// Initializer
				///
				init (
						nftType: Type,
						nftUUID: UInt64,
						nftID: UInt64,
						salePaymentVaultType: Type,
						saleCuts: [SaleCut],
						storefrontID: UInt64,
						customID: String?,
						commissionAmount: UFix64,
						expiry: UInt64,
						buyer: Address?
				) {
						pre {
							// Validate the expiry
							expiry > UInt64(getCurrentBlock().timestamp) : "Expiry should be in the future"
							// Validate the length of the sale cut
							saleCuts.length > 0: "Listing must have at least one payment cut recipient"
						}
						self.storefrontID = storefrontID
						self.purchased = false
						self.nftType = nftType
						self.nftUUID = nftUUID
						self.nftID = nftID
						self.salePaymentVaultType = salePaymentVaultType
						self.customID = customID
						self.commissionAmount = commissionAmount
						self.expiry = expiry
						self.saleCuts = saleCuts
						self.buyer = buyer

						// Calculate the total price from the cuts
						var salePrice = commissionAmount
						// Perform initial check on capabilities, and calculate sale price from cut amounts.

						for cut in self.saleCuts {
							// Add the cut amount to the total price
							salePrice = salePrice + cut.amount
						}
						assert(salePrice > 0.0, message: "Listing must have non-zero price")

						// Store the calculated sale price
						self.salePrice = salePrice
				}
		}

		pub resource interface ListingPublic {
				pub fun borrowNFT(): &NonFungibleToken.NFT?

				/// purchase
				/// Purchase the listing, buying the token.
				/// This pays the beneficiaries and returns the token to the buyer.
				///
				pub fun purchase(
						payment: @FungibleToken.Vault,
						commissionRecipient: Capability<&{FungibleToken.Receiver}>?,
						privateListingAcceptor: &Storefront{PrivateListingAcceptor}
				): @NonFungibleToken.NFT

				/// getDetails
				/// Fetches the details of the listing.
				pub fun getDetails(): ListingDetails

				/// getAllowedCommissionReceivers
				/// Fetches the allowed marketplaces capabilities or commission receivers.
				/// If it returns `nil` then commission is up to grab by anyone.
				pub fun getAllowedCommissionReceivers(): [Capability<&{FungibleToken.Receiver}>]?

				pub fun isValid(): Bool
		}

		pub resource Listing: ListingPublic {
				access(self) let details: ListingDetails

				access(contract) let nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>

				access(contract) let marketplacesCapability: [Capability<&{FungibleToken.Receiver}>]?

				pub fun borrowNFT(): &NonFungibleToken.NFT? {
						let ref = self.nftProviderCapability.borrow()!.borrowNFT(id: self.details.nftID)
						if ref.isInstance(self.details.nftType) && ref.id == self.details.nftID {
								return ref as! &NonFungibleToken.NFT
						}
						return nil
				}

				pub fun getDetails(): ListingDetails {
						return self.details
				}

				/// getAllowedCommissionReceivers
				/// Fetches the allowed marketplaces capabilities or commission receivers.
				/// If it returns `nil` then commission is up to grab by anyone.
				pub fun getAllowedCommissionReceivers(): [Capability<&{FungibleToken.Receiver}>]? {
						return self.marketplacesCapability
				}

				/// purchase
				/// Purchase the listing, buying the token.
				/// This pays the beneficiaries and commission to the facilitator and returns extra token to the buyer.
				/// This also cleans up duplicate listings for the item being purchased.
				pub fun purchase(
					payment: @FungibleToken.Vault,
					commissionRecipient: Capability<&{FungibleToken.Receiver}>?,
					privateListingAcceptor: &Storefront{PrivateListingAcceptor}
				): @NonFungibleToken.NFT {
						pre {
							self.details.purchased == false: "listing has already been purchased"
							payment.isInstance(self.details.salePaymentVaultType): "payment vault is not requested fungible token"
							payment.balance == self.details.salePrice: "payment vault does not contain requested price"
							self.details.expiry > UInt64(getCurrentBlock().timestamp): "Listing is expired"
							self.owner != nil : "Resource doesn't have the assigned owner"
							self.details.buyer == nil || self.details.buyer! == privateListingAcceptor.owner!.address: "incorrect buyer for private listing"
							commissionRecipient == nil || commissionRecipient!.address == NFTStorefrontV2.account.address: "invalid commission recipient"
						}

						post {
							Permitted.isPermitted(result): "type of nft is not permitted"
						}

						let tokenInfo = FlowtyUtils.getTokenInfo(self.details.salePaymentVaultType) ?? panic("unsupported payment token")

						// Make sure the listing cannot be purchased again.
						self.details.setToPurchased()

						if self.details.commissionAmount > 0.0 {
								// If commission recipient is nil, Throw panic.
								let commissionReceiver = commissionRecipient ?? panic("Commission recipient can't be nil")
								if self.marketplacesCapability != nil {
										var isCommissionRecipientHasValidType = false
										var isCommissionRecipientAuthorised = commissionReceiver.address == NFTStorefrontV2.account.address
										for cap in self.marketplacesCapability! {
												// Check 1: Should have the same type
												if cap.getType() == commissionReceiver.getType() {
														isCommissionRecipientHasValidType = true
														// Check 2: Should have the valid market address that holds approved capability.
														if cap.address == commissionReceiver.address && cap.check() {
																isCommissionRecipientAuthorised = true
																break
														}
												}
										}
										assert(isCommissionRecipientHasValidType, message: "Given recipient does not has valid type")
										assert(isCommissionRecipientAuthorised,	 message: "Given recipient has not authorised to receive the commission")
								}
								let commissionPayment <- payment.withdraw(amount: self.details.commissionAmount)
								let recipient = commissionReceiver.borrow() ?? panic("Unable to borrow the recipent capability")
								recipient.deposit(from: <- commissionPayment)
						}
						// Fetch the token to return to the purchaser.
						let nft <-self.nftProviderCapability.borrow()!.withdraw(withdrawID: self.details.nftID)
						// Neither receivers nor providers are trustworthy, they must implement the correct
						// interface but beyond complying with its pre/post conditions they are not gauranteed
						// to implement the functionality behind the interface in any given way.
						// Therefore we cannot trust the Collection resource behind the interface,
						// and we must check the NFT resource it gives us to make sure that it is the correct one.
						assert(nft.isInstance(self.details.nftType), message: "withdrawn NFT is not of specified type")
						assert(nft.id == self.details.nftID, message: "withdrawn NFT does not have specified ID")

						// Fetch the duplicate listing for the given NFT
						// Access the StoreFrontManager resource reference to remove the duplicate listings if purchase would happen successfully.
						let storeFrontPublicRef = self.owner!.getCapability<&NFTStorefrontV2.Storefront{NFTStorefrontV2.StorefrontPublic}>(NFTStorefrontV2.StorefrontPublicPath)
																				.borrow() ?? panic("Unable to borrow the storeFrontManager resource")
						let duplicateListings = storeFrontPublicRef.getDuplicateListingIDs(nftType: self.details.nftType, nftID: self.details.nftID, listingID: self.uuid)

						// Let's force removal of the listing in this storefront for the NFT that is being purchased.
						for listingID in duplicateListings {
							storeFrontPublicRef.cleanup(listingResourceID: listingID)
						}

						let isDapperToken = self.details.salePaymentVaultType == Type<@DapperUtilityCoin.Vault>() || self.details.salePaymentVaultType == Type<@FlowUtilityToken.Vault>()
						for cut in self.details.saleCuts {
							if isDapperToken && !cut.receiver.check() {
								emit MissingReceiver(receiver: cut.receiver.address, amount: cut.amount)
								continue
							}
							let paymentCut <- payment.withdraw(amount: cut.amount)
							// assert(false, message: "".concat(paymentCut.getType().identifier.concat(" ").concat(paymentCut.balance.toString().concat(" "))))
							FlowtyUtils.trySendFungibleTokenVault(vault: <-paymentCut, receiver: cut.receiver)
						}

						if payment.balance > 0.0 {
							// send whatever is left to the seller who is the last receiver
							FlowtyUtils.trySendFungibleTokenVault(vault: <-payment, receiver: self.details.saleCuts[self.details.saleCuts.length-1].receiver)
						} else {
							destroy payment
						}

						// If the listing is purchased, we regard it as completed here.
						// Otherwise we regard it as completed in the destructor.
						emit ListingCompleted(
							listingResourceID: self.uuid,
							storefrontResourceID: self.details.storefrontID,
							storefrontAddress: self.owner?.address,
							purchased: self.details.purchased,
							nftType: self.details.nftType.identifier,
							nftUUID: self.details.nftUUID,
							nftID: self.details.nftID,
							salePaymentVaultType: self.details.salePaymentVaultType.identifier,
							salePrice: self.details.salePrice,
							customID: self.details.customID,
							commissionAmount: self.details.commissionAmount,
							commissionReceiver: self.details.commissionAmount != 0.0 ? commissionRecipient!.address : nil,
							expiry: self.details.expiry,
							buyer: privateListingAcceptor.owner?.address
						)

						return <-nft
				}

				pub fun isValid(): Bool {
					if UInt64(getCurrentBlock().timestamp) > self.details.expiry {
						return false
					}

					if !self.nftProviderCapability.check() {
						return false
					}

					let collection = self.nftProviderCapability.borrow()!
					let ids = collection.getIDs()
					if !ids.contains(self.details.nftID) {
						return false
					}

					let nft = collection.borrowNFT(id: self.details.nftID)
					if nft.getType() != self.details.nftType || nft.uuid != self.details.nftUUID || nft.id != self.details.nftID {
						return false
					}

					return true
				}

				/// destructor
				///
				destroy () {
						if !self.details.purchased {
								emit ListingCompleted(
										listingResourceID: self.uuid,
										storefrontResourceID: self.details.storefrontID,
										storefrontAddress: self.owner?.address,
										purchased: self.details.purchased,
										nftType: self.details.nftType.identifier,
										nftUUID: self.details.nftUUID,
										nftID: self.details.nftID,
										salePaymentVaultType: self.details.salePaymentVaultType.identifier,
										salePrice: self.details.salePrice,
										customID: self.details.customID,
										commissionAmount: self.details.commissionAmount,
										commissionReceiver: nil,
										expiry: self.details.expiry,
										buyer: nil
								)
						}
				}

				/// initializer
				///
				init (
					nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
					nftType: Type,
					nftUUID: UInt64,
					nftID: UInt64,
					salePaymentVaultType: Type,
					saleCuts: [SaleCut],
					marketplacesCapability: [Capability<&{FungibleToken.Receiver}>]?,
					storefrontID: UInt64,
					customID: String?,
					commissionAmount: UFix64,
					expiry: UInt64,
					buyer: Address?
				) {
						// Store the sale information
						self.details = ListingDetails(
							nftType: nftType,
							nftUUID: nftUUID,
							nftID: nftID,
							salePaymentVaultType: salePaymentVaultType,
							saleCuts: saleCuts,
							storefrontID: storefrontID,
							customID: customID,
							commissionAmount: commissionAmount,
							expiry: expiry,
							buyer: buyer
						)

						// Store the NFT provider
						self.nftProviderCapability = nftProviderCapability
						self.marketplacesCapability = marketplacesCapability

						// Check that the provider contains the NFT.
						// We will check it again when the token is sold.
						// We cannot move this into a function because initializers cannot call member functions.
						let provider = self.nftProviderCapability.borrow()
						assert(provider != nil, message: "cannot borrow nftProviderCapability")

						// This will precondition assert if the token is not available.
						 let nft = provider!.borrowNFT(id: self.details.nftID)
						assert(nft.isInstance(self.details.nftType), message: "token is not of specified type")
						assert(nft.id == self.details.nftID, message: "token does not have specified ID")
				}
		}

		/// StorefrontManager
		/// An interface for adding and removing Listings within a Storefront,
		/// intended for use by the Storefront's owner
		///
		pub resource interface StorefrontManager {
				/// createListing
				/// Allows the Storefront owner to create and insert Listings.
				///
				pub fun createListing(
					nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
					paymentReceiver: Capability<&{FungibleToken.Receiver}>,
					nftType: Type,
					nftID: UInt64,
					salePaymentVaultType: Type,
					price: UFix64,
					customID: String?,
					expiry: UInt64,
					buyer: Address?
				): UInt64

				/// removeListing
				/// Allows the Storefront owner to remove any sale listing, acepted or not.
				///
				pub fun removeListing(listingResourceID: UInt64)
		}

		/// StorefrontPublic
		/// An interface to allow listing and borrowing Listings, and purchasing items via Listings
		/// in a Storefront.
		///
		pub resource interface StorefrontPublic {
			pub fun getListingIDs(): [UInt64]
			pub fun getDuplicateListingIDs(nftType: Type, nftID: UInt64, listingID: UInt64): [UInt64]
			pub fun borrowListing(listingResourceID: UInt64): &Listing{ListingPublic}?
			pub fun cleanupExpiredListings(fromIndex: UInt64, toIndex: UInt64)
			access(contract) fun cleanup(listingResourceID: UInt64)
			pub fun getExistingListingIDs(nftType: Type, nftID: UInt64): [UInt64]
			pub fun cleanupPurchasedListings(listingResourceID: UInt64)
			pub fun cleanupInvalidListing(listingResourceID: UInt64)
			access(contract) fun adminRemoveListing(listingResourceID: UInt64)
		}

		/// PrivateListingAcceptor
		/// Interface for accepting a private listing
		///
		/// Importantly, we will need to ensure that our Storefront is checking
		/// the entire type (&Storefront{PrivateListingAcceptor}) otherwise malicious actors might
		/// be able to impersonate a buyer.
		pub resource interface PrivateListingAcceptor {
						// Simple function just to ensure that we don't have an empty interface.
						// we'll use this method when purchasing a private listing to verify that a reference
						// is owned by the right address.
						pub fun getOwner(): Address?
		}

		/// Storefront
		/// A resource that allows its owner to manage a list of Listings, and anyone to interact with them
		/// in order to query their details and purchase the NFTs that they represent.
		///
		pub resource Storefront : StorefrontManager, StorefrontPublic, PrivateListingAcceptor {
				/// The dictionary of Listing uuids to Listing resources.
				access(contract) var listings: @{UInt64: Listing}
				/// Dictionary to keep track of listing ids for same NFTs listing.
				/// nftType.identifier -> nftID -> [listing resource ID]
				access(contract) var listedNFTs: {String: {UInt64 : [UInt64]}}

				pub fun getOwner(): Address? {
						return self.owner!.address
				}

				/// insert
				/// Create and publish a Listing for an NFT.
				///
				pub fun createListing(
					nftProviderCapability: Capability<&{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>,
					paymentReceiver: Capability<&{FungibleToken.Receiver}>,
					nftType: Type,
					nftID: UInt64,
					salePaymentVaultType: Type,
					price: UFix64,
					customID: String?,
					expiry: UInt64,
					buyer: Address?
				 ): UInt64 {
						pre {
							paymentReceiver.check(): "payment receiver is invalid"
						}

						if salePaymentVaultType == Type<@DapperUtilityCoin.Vault>() {
							assert(price >= 0.75, message: "price must be at least 0.75")
						}
						assert(price <= 10_000_000.0, message: "price must be less than 10 million")

						let commission = NFTStorefrontV2.getFee(p: price, t: salePaymentVaultType)

						let marketplacesCapability = [NFTStorefrontV2.getCommissionReceiver(t: salePaymentVaultType)]
						// let's ensure that the seller does indeed hold the NFT being listed
						let collectionRef = nftProviderCapability.borrow()
								?? panic("Could not borrow reference to collection")
						let nftRef = collectionRef.borrowNFT(id: nftID)
						assert(Permitted.isPermitted(nftRef), message: "type of nft is not permitted")

						let cuts = NFTStorefrontV2.getPaymentCuts(r: paymentReceiver, n: nftRef, p: price, tokenType: salePaymentVaultType)

						// Instead of letting an arbitrary value be set for the UUID of a given NFT, the contract
						// should fetch it itelf		
						let uuid = nftRef.uuid
						let listing <- create Listing(
							nftProviderCapability: nftProviderCapability,
							nftType: nftType,
							nftUUID: uuid,
							nftID: nftID,
							salePaymentVaultType: salePaymentVaultType,
							saleCuts: cuts,
							marketplacesCapability: marketplacesCapability,
							storefrontID: self.uuid,
							customID: customID,
							commissionAmount: commission,
							expiry: expiry,
							buyer: nil
						)

						let listingResourceID = listing.uuid
						let listingPrice = listing.getDetails().salePrice
						// Add the new listing to the dictionary.
						let oldListing <- self.listings[listingResourceID] <- listing
						destroy oldListing

						// Add the `listingResourceID` in the tracked listings.
						self.addDuplicateListing(nftIdentifier: nftType.identifier, nftID: nftID, listingResourceID: listingResourceID)

						// Scraping addresses from the capabilities to emit in the event.
						var allowedCommissionReceivers : [Address] = []
						for c in marketplacesCapability {
							allowedCommissionReceivers!.append(c.address)
						}

						emit ListingAvailable(
							storefrontAddress: self.owner?.address!,
							listingResourceID: listingResourceID,
							nftType: nftType.identifier,
							nftUUID: uuid,
							nftID: nftID,
							salePaymentVaultType: salePaymentVaultType.identifier,
							salePrice: listingPrice,
							customID: customID,
							commissionAmount: commission,
							commissionReceivers: allowedCommissionReceivers,
							expiry: expiry,
							buyer: buyer
						)

						return listingResourceID
				}

				/// addDuplicateListing
				/// Helper function that allows to add duplicate listing of given nft in a map.
				///
				access(contract) fun addDuplicateListing(nftIdentifier: String, nftID: UInt64, listingResourceID: UInt64) {
						 if !self.listedNFTs.containsKey(nftIdentifier) {
								self.listedNFTs.insert(key: nftIdentifier, {nftID: [listingResourceID]})
						} else {
								if !self.listedNFTs[nftIdentifier]!.containsKey(nftID) {
										self.listedNFTs[nftIdentifier]!.insert(key: nftID, [listingResourceID])
								} else {
										self.listedNFTs[nftIdentifier]![nftID]!.append(listingResourceID)
								}
						}
				}

				/// removeDuplicateListing
				/// Helper function that allows to remove duplicate listing of given nft from a map.
				///
				access(contract) fun removeDuplicateListing(nftIdentifier: String, nftID: UInt64, listingResourceID: UInt64) {
						// Remove the listing from the listedNFTs dictionary.
						let listingIndex = self.listedNFTs[nftIdentifier]![nftID]!.firstIndex(of: listingResourceID) ?? panic("Should contain the index")
						self.listedNFTs[nftIdentifier]![nftID]!.remove(at: listingIndex)
				}

				pub fun removeListing(listingResourceID: UInt64) {
						let listing <- self.listings.remove(key: listingResourceID)
								?? panic("missing Listing")
						let listingDetails = listing.getDetails()
						self.removeDuplicateListing(nftIdentifier: listingDetails.nftType.identifier, nftID: listingDetails.nftID, listingResourceID: listingResourceID)
						// This will emit a ListingCompleted event.
						destroy listing
				}

				pub fun getListingIDs(): [UInt64] {
						return self.listings.keys
				}

				pub fun getExistingListingIDs(nftType: Type, nftID: UInt64): [UInt64] {
						if self.listedNFTs[nftType.identifier] == nil || self.listedNFTs[nftType.identifier]![nftID] == nil {
								return []
						}
						var listingIDs = self.listedNFTs[nftType.identifier]![nftID]!
						return listingIDs
				}

				pub fun cleanupPurchasedListings(listingResourceID: UInt64) {
						pre {
								self.listings[listingResourceID] != nil: "could not find listing with given id"
								self.borrowListing(listingResourceID: listingResourceID)!.getDetails().purchased == true: "listing not purchased yet"
						}
						let listing <- self.listings.remove(key: listingResourceID)!
						let listingDetails = listing.getDetails()
						self.removeDuplicateListing(nftIdentifier: listingDetails.nftType.identifier, nftID: listingDetails.nftID, listingResourceID: listingResourceID)

						destroy listing
				}

				pub fun getDuplicateListingIDs(nftType: Type, nftID: UInt64, listingID: UInt64): [UInt64] {
						var listingIDs = self.getExistingListingIDs(nftType: nftType, nftID: nftID)

						// Verify that given listing Id also a part of the `listingIds`
						let doesListingExist = listingIDs.contains(listingID)
						// Find out the index of the existing listing.
						if doesListingExist {
								var index: Int = 0
								for id in listingIDs {
										if id == listingID {
												break
										}
										index = index + 1
								}
								listingIDs.remove(at:index)
								return listingIDs
						}
					 return []
				}

				pub fun cleanupExpiredListings(fromIndex: UInt64, toIndex: UInt64) {
						pre {
								fromIndex <= toIndex : "Incorrect start index"
								Int(toIndex - fromIndex) < self.getListingIDs().length : "Provided range is out of bound"
						}
						var index = fromIndex
						let listingsIDs = self.getListingIDs()
						while index <= toIndex {
								// There is a possibility that some index may not have the listing.
								// becuase of that instead of failing the transaction, Execution moved to next index or listing.

								if let listing = self.borrowListing(listingResourceID: listingsIDs[index]) {
										if listing.getDetails().expiry <= UInt64(getCurrentBlock().timestamp) {
												self.cleanup(listingResourceID: listingsIDs[index])
										}
								}
								index = index + UInt64(1)
						}
				}

				access(contract) fun adminRemoveListing(listingResourceID: UInt64) {
					pre {
						self.listings[listingResourceID] != nil: "could not find listing with given id"
					}
					let listing <- self.listings.remove(key: listingResourceID)
							?? panic("missing Listing")
					let listingDetails = listing.getDetails()
					self.removeDuplicateListing(nftIdentifier: listingDetails.nftType.identifier, nftID: listingDetails.nftID, listingResourceID: listingResourceID)
					// This will emit a ListingCompleted event.
					destroy listing
				}

				/// borrowSaleItem
				/// Returns a read-only view of the SaleItem for the given listingID if it is contained by this collection.
				///
				pub fun borrowListing(listingResourceID: UInt64): &Listing{ListingPublic}? {
						 if self.listings[listingResourceID] != nil {
								return &self.listings[listingResourceID] as &Listing{ListingPublic}?
						} else {
								return nil
						}
				}

				/// cleanup
				/// Remove an listing, When given listing is duplicate or expired
				/// Only contract is allowed to execute it.
				///
				access(contract) fun cleanup(listingResourceID: UInt64) {
						pre {
								self.listings[listingResourceID] != nil: "could not find listing with given id"
						}
						let listing <- self.listings.remove(key: listingResourceID)!
						let listingDetails = listing.getDetails()
						self.removeDuplicateListing(nftIdentifier: listingDetails.nftType.identifier, nftID: listingDetails.nftID, listingResourceID: listingResourceID)

						destroy listing
				}

				/*
				Removes a listing that is not valid anymore. This could be because the listed nft is no longer in
				an account's storage, or it could be because the listing has expired or is otherwise completed.
				*/
				pub fun cleanupInvalidListing(listingResourceID: UInt64) {
					pre {
						self.listings[listingResourceID] != nil: "could not find listing with given id"
					}
					let listing <- self.listings.remove(key: listingResourceID)!
					assert(!listing.isValid(), message: "listing is valid and cannot be removed")

					let listingDetails = listing.getDetails()
					self.removeDuplicateListing(nftIdentifier: listingDetails.nftType.identifier, nftID: listingDetails.nftID, listingResourceID: listingResourceID)

					destroy listing
				}

				destroy () {
						destroy self.listings

						// Let event consumers know that this storefront will no longer exist
						emit StorefrontDestroyed(storefrontResourceID: self.uuid)
				}

				init () {
						self.listings <- {}
						self.listedNFTs = {}

						// Let event consumers know that this storefront exists
						emit StorefrontInitialized(storefrontResourceID: self.uuid)
				}
		}

		pub resource Admin {
			pub fun removeListing(addr: Address, listingResourceID: UInt64) {
				let s = getAccount(addr).getCapability<&Storefront{StorefrontPublic}>(NFTStorefrontV2.StorefrontPublicPath).borrow() ?? panic("storefront not found")
				s.adminRemoveListing(listingResourceID: listingResourceID)
			}
		}

		pub fun getCommissionReceiver(t: Type): Capability<&{FungibleToken.Receiver}> {
			let tokenInfo = FlowtyUtils.getTokenInfo(t) ?? panic("invalid token type")
			return self.account.getCapability<&{FungibleToken.Receiver}>(tokenInfo.receiverPath)
		}

		pub fun createStorefront(): @Storefront {
			return <-create Storefront()
		}

		pub fun getFee(p: UFix64, t: Type): UFix64 {
			var fee = p * 0.01 // flowty has a fee of 1%
			var dwFee = 0.0
			if t == Type<@DapperUtilityCoin.Vault>() {
				dwFee = p * 0.01 // Dapper Wallet charges 1% to use DUC
				dwFee = dwFee > 0.44 ? dwFee : 0.44 // but the minimum it charges is 0.44 DUC
			}
			return fee + dwFee // flowty fee of 1% + Max(1%, 0.44)
		}

		pub fun getPaymentCuts(r: Capability<&{FungibleToken.Receiver}>, n: &NonFungibleToken.NFT, p: UFix64, tokenType: Type): [SaleCut] {
			let t = n.getType()
			let ti = FlowtyUtils.getTokenInfo(tokenType) ?? panic("unsupported token type")

			let fee = NFTStorefrontV2.getFee(p: p, t: tokenType)
			var royalties: MetadataViews.Royalties? = nil

			// collection royalties may be overridden for various reasons such as misconfiguration.
			//
			// if they are not in the override, pull them and then we will calculate our cuts.
			if !RoyaltiesOverride.get(t) {
				royalties = n.resolveView(Type<MetadataViews.Royalties>()) as! MetadataViews.Royalties?
			}

			let cuts: [SaleCut] = []
			var remainder = p - fee
			if royalties != nil {
				for c in royalties!.getRoyalties() {
					// make sure that receivers are pointing where we expect them to
					let rec = getAccount(c.receiver.address).getCapability<&{FungibleToken.Receiver}>(ti.receiverPath)
					cuts.append(SaleCut(receiver: rec, amount: p * c.cut))
					remainder = remainder - c.cut * p
				}
			}

			cuts.append(SaleCut(receiver: r, amount: remainder))

			return cuts
		}

		init () {
			let pathIdentifier = "NFTStorefrontV2".concat(self.account.address.toString())
			let adminIdentifier = "NFTStorefrontV2Admin".concat(self.account.address.toString())

			self.StorefrontStoragePath = StoragePath(identifier: pathIdentifier)!
			self.StorefrontPublicPath = PublicPath(identifier: pathIdentifier)!
			self.AdminStoragePath = StoragePath(identifier: adminIdentifier)!

			self.CommissionRecipients = {}

			NFTStorefrontV2.account.save(<- create Admin(), to: self.AdminStoragePath)
		}
}
 