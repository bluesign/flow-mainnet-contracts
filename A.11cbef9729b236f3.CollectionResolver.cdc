/*
    Provides access to a set of metadata views for contracts
    Works the same as MetadataViews.Resolver but for contracts 
 */
pub contract interface CollectionResolver {
    pub fun getViews(): [Type]
    pub fun resolveView(_ view: Type): AnyStruct?
}
