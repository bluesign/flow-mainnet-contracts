import NonFungibleToken from 0x1d7e57aa55817448
import FindMarket from 0x097bafa4e0b48eef
import FindViews from 0x097bafa4e0b48eef
import FIND from 0x097bafa4e0b48eef

pub contract FindFurnace {

	pub event Burned(from: Address, fromName: String?, uuid: UInt64, nftInfo: FindMarket.NFTInfo, context: {String : String})

	pub fun burn(pointer: FindViews.AuthNFTPointer, context: {String : String}) {
		if !pointer.valid() {
			panic("Invalid NFT Pointer. Type : ".concat(pointer.itemType.identifier).concat(" ID : ").concat(pointer.uuid.toString()))
		}

		let vr = pointer.getViewResolver()
		let nftInfo = FindMarket.NFTInfo(vr, id: pointer.id, detail: true)
		let owner = pointer.owner()
		emit Burned(from: owner, fromName: FIND.reverseLookup(owner) , uuid: pointer.uuid, nftInfo: nftInfo, context: context)
		destroy pointer.withdraw()
	}

	pub fun burnWithoutValidation(pointer: FindViews.AuthNFTPointer, context: {String : String}) {
		let vr = pointer.getViewResolver()
		let nftInfo = FindMarket.NFTInfo(vr, id: pointer.id, detail: true)
		let owner = pointer.owner()
		emit Burned(from: owner, fromName: FIND.reverseLookup(owner) , uuid: pointer.uuid, nftInfo: nftInfo, context: context)
		destroy pointer.withdraw()
	}

}

