/**
  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
**/
import MetadataViews from 0x1d7e57aa55817448

pub contract AnchainUtils {
  // ResolverCollection
  // A MetadataViews.File with an added file extension.
  //
  // One inconvenience with the new NFT metadata standard is that you 
  // cannot return nil from borrowViewResolver(id: UInt64). Consider 
  // the case when we call the function with an ID that doesn't exist 
  // in the collection. In this scenario, we're forced to either panic 
  // or let a dereference error occcur, which may not be preferred in 
  // some situations. In order to prevent these errors from occuring we 
  // could write more code to check if the ID exists via getIDs() OR we 
  // can simply use the interface below. This interface allows nil to be
  // returned when the input ID does not exist allowing for a cleaner 
  // (and more efficient) way of handling errors.
  //
  pub resource interface ResolverCollection {
    pub fun borrowViewResolverSafe(id: UInt64): &{MetadataViews.Resolver}?
  }

  // File
  // A MetadataViews.File with an added file extension.
  //
  // IMPORTANT: this struct should NOT be used anymore 
  // because the MetadataViews contract now has a view 
  // that supports this. This struct is only here for 
  // backwards compatability with the MetaPanda contract.
  //
  pub struct File {
    pub let extension: String
    pub let thumbnail: AnyStruct{MetadataViews.File}

    init(
      extension: String,
      thumbnail: AnyStruct{MetadataViews.File}
    ) {
      self.extension = extension
      self.thumbnail = thumbnail
    }
  }
}