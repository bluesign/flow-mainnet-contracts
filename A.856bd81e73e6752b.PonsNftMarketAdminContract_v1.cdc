import FungibleToken from 0xf233dcee88fe0abe
import PonsNftContractInterface from 0x856bd81e73e6752b
import PonsNftContract from 0x856bd81e73e6752b
import PonsNftContract_v1 from 0x856bd81e73e6752b
import PonsNftMarketContract from 0x856bd81e73e6752b
import PonsNftMarketContract_v1 from 0x856bd81e73e6752b
import PonsUtils from 0x856bd81e73e6752b



/*
	Pons NFT Market Admin Contract v1

	This smart contract contains the Pons NFT Market Admin resource.
	The resource allows updates to be delivered to NFTs, and allows the marketplace to retrieve and deliver directly NFTs when payment has been otherwise rendered.
*/
pub contract PonsNftMarketAdminContract_v1 {

	/* Storage path at which the NFT Admin resource will be stored */
	access(account) let AdminStoragePath : StoragePath

	/* Capability to the NFT Admin, for convenience of usage */
	access(account) let AdminCapability : Capability<&NftMarketAdmin_v1>


	/* PonsNftMarketAdminContractInit_v1 is emitted on initialisation of this contract */
	pub event PonsNftMarketAdminContractInit_v1 ()




/*
	Pons NFT Market v1 Admin resource

	This resource enables updates to Pons NFTs and maintenance of the marketplace.
*/
	pub resource NftMarketAdmin_v1 {

		/* Updates the royalty of the Pons NFT */
		pub fun updatePonsNftRoyalty (nftId : String, royalty : PonsUtils.Ratio) : Void {
			PonsNftContract_v1 .insertRoyalty (nftId: nftId, royalty: royalty) }

		/* Updates the edition label of the Pons NFT */
		pub fun updatePonsEditionLabel (nftId : String, editionLabel : String) : Void {
			PonsNftContract_v1 .insertEditionLabel (nftId: nftId, editionLabel: editionLabel) }

		/* Updates the metadata of the Pons NFT */
		pub fun updatePonsNftMetadata (nftId : String, metadata : {String: String}) : Void {
			PonsNftContract_v1 .insertMetadata (nftId: nftId, metadata: metadata) }

		/* Updates the price of the Pons NFT on the marketplace */
		pub fun updateSalePrice (nftId : String, price : PonsUtils.FlowUnits) : Void {
			let ponsNftMarketRef = & PonsNftMarketContract .ponsMarket as auth &{PonsNftMarketContract.PonsNftMarket}
			let ponsNftMarketV1Ref = ponsNftMarketRef as! &PonsNftMarketContract_v1.PonsNftMarket_v1
			ponsNftMarketV1Ref .insertSalePrice (nftId: nftId, price: price) }

		/* Borrows the NFT collection of the marketplace */
		pub fun borrowCollection () : &PonsNftContract_v1.Collection {
			let ponsNftMarketRef = & PonsNftMarketContract .ponsMarket as auth &{PonsNftMarketContract.PonsNftMarket}
			let ponsNftMarketV1Ref = ponsNftMarketRef as! &PonsNftMarketContract_v1.PonsNftMarket_v1
			return & ponsNftMarketV1Ref .collection as &PonsNftContract_v1.Collection } }

	

	init () {
		// Save the admin storage path
		self .AdminStoragePath = /storage/ponsMarketAdmin_v1

		// Save a NFT v1 Admin to the specified storage path
        	self .account .save (<- create NftMarketAdmin_v1 (), to: self .AdminStoragePath)

		// Create and save a capability to the admin for convenience
		self .AdminCapability = self .account .link <&NftMarketAdmin_v1> (/private/ponsMarketAdmin_v1, target: self .AdminStoragePath) !

		// Emit the Pons NFT Market Admin v1 contract initialisation event
		emit PonsNftMarketAdminContractInit_v1 () } }
