import Bow

// MARK: Optics extensions
public extension Validated {
    static var fixIso: Iso<Validated<E, A>, ValidatedOf<E, A>> {
        return Iso(get: id, reverseGet: Validated.fix)
    }
    
    static var fold: Fold<Validated<E, A>, A> {
        return fixIso + foldK
    }
    
    static var traversal: Traversal<Validated<E, A>, A> {
        return fixIso + traversalK
    }
}

// MARK: Instance of `Each` for `Validated`
extension Validated: Each {
    public typealias EachFoci = A
    
    public static var each: Traversal<Validated<E, A>, A> {
        return traversal
    }
}