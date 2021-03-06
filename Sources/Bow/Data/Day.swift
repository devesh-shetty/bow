import Foundation

public final class ForDay {}
public final class DayPartial<F: Comonad, G: Comonad>: Kind2<ForDay, F, G> {}
public typealias DayOf<F: Comonad, G: Comonad, A> = Kind<DayPartial<F, G>, A>

public final class Day<F: Comonad, G: Comonad, A> : DayOf<F, G, A> {
    internal let left: Kind<F, Any /*B*/>
    internal let right: Kind<G, Any /*C*/>
    internal let f: (Any /*B*/, Any /*C*/) -> A

    public init<B, C>(left: Kind<F, B>,
                      right: Kind<G, C>,
                      _ f: @escaping (B, C) -> A) {
        self.left = left.map { b in b as Any }
        self.right = right.map { c in c as Any }
        self.f = { b, c in f(b as! B, c as! C) }
    }
    
    public static func fix(_ value: DayOf<F, G, A>) -> Day<F, G, A> {
        value as! Day<F, G, A>
    }

    public func run() -> A {
        extract()
    }
    
    internal func step<R>(_ ff: @escaping (Kind<F, Any>, Kind<G, Any>, @escaping (Any, Any) -> A) -> R) -> R {
        ff(left, right, f)
    }
    
    public func assoc<FF: Comonad, GG: Comonad>() -> Day<DayPartial<F, FF>, GG, A> where G == DayPartial<FF, GG> {
        let newLeft = Day<F, FF, Any>(
            left: self.left,
            right: self.right^.left) { a, b in (a, b) }
        
        return Day<DayPartial<F, FF>, GG, A>(
            left: newLeft,
            right: self.right^.right) { x, c in
                let xx = x as! (Any, Any)
                return self.f(xx.0, self.right^.f(xx.1, c))
        }
    }
    
    public func disassoc<FF: Comonad, GG: Comonad>() -> Day<FF, DayPartial<GG, G>, A> where F == DayPartial<FF, GG> {
        let newRight = Day<GG, G, Any>(
            left: self.left^.right,
            right: self.right) { a, b in (a, b) }
                
        return Day<FF, DayPartial<GG, G>, A>(
            left: self.left^.left,
            right: newRight) { a, x in
                let xx = x as! (Any, Any)
                return self.f(self.left^.f(a, xx.0), xx.1)
        }
    }
    
    public func swapped() -> Day<G, F, A> {
        Day<G, F, A>(left: right, right: left) { c, b in self.f(b, c) }
    }
    
    public func trans1<H: Comonad>(_ nat: FunctionK<F, H>) -> Day<H, G, A> {
        Day<H, G, A>(left: nat.invoke(left), right: right, f)
    }
    
    public func trans2<H: Comonad>(_ nat: FunctionK<G, H>) -> Day<F, H, A> {
        Day<F, H, A>(left: left, right: nat.invoke(right), f)
    }
}

public extension Day where F == G, F: Applicative {
    func dap() -> Kind<F, A> {
        F.map(left, right, f)
    }
}

public extension Day where F == ForId {
    static func intro1(_ right: Kind<G, A>) -> Day<ForId, G, A> {
        Day(left: Id(()), right: right.map { a in a as Any }) { _, a in a as! A }
    }
    
    func elim1() -> Kind<G, A> {
        right.map { x in self.f(self.left^.value, x) }
    }
}

public extension Day where G == ForId {
    static func intro2(_ left: Kind<F, A>) -> Day<F, ForId, A> {
        Day(left: left.map { a in a as Any }, right: Id(())) { a, _ in a as! A }
    }
    
    func elim2() -> Kind<F, A> {
        left.map { x in self.f(x, self.right^.value) }
    }
}

/// Safe downcast.
///
/// - Parameter value: Value in higher-kind form.
/// - Returns: Value cast to Day.
public postfix func ^<F, G, A>(_ value: DayOf<F, G, A>) -> Day<F, G, A> {
    Day.fix(value)
}

extension DayPartial: Functor {
    public static func map<A, B>(_ fa: DayOf<F, G, A>, _ f: @escaping (A) -> B) -> DayOf<F, G, B> {
        fa^.step { left, right, get in
            Day(left: left, right: right) { b, c in f(get(b, c)) }
        }
    }
}

extension DayPartial: Applicative where F: Applicative, G: Applicative {
    public static func pure<A>(_ a: A) -> DayOf<F, G, A> {
        Day(left: F.pure(()), right: G.pure(())) { _, _ in a }
    }
    
    public static func ap<A, B>(_ ff: DayOf<F, G, (A) -> B>, _ fa: DayOf<F, G, A>) -> DayOf<F, G, B> {
        fa^.step { left, right, get in
            ff^.step { lf, rf, getf in
                let l = F.map(left, lf) { x, y in (x, y) as Any }
                let r = G.map(right, rf) { x, y in (x, y) as Any }
                return Day(left: l, right: r) { x, y in
                    let xx = x as! (Any, Any)
                    let yy = y as! (Any, Any)
                    return getf(xx.1, yy.1)(get(xx.0, yy.0))
                }
            }
        }
    }
}

extension DayPartial: Comonad {
    public static func coflatMap<A, B>(_ fa: DayOf<F, G, A>, _ f: @escaping (DayOf<F, G, A>) -> B) -> DayOf<F, G, B> {
        fa^.step { left, right, get in
            let l = left.duplicate().map { x in x as Any }
            let r = right.duplicate().map { x in x as Any }
            return Day(left: l, right: r) { x, y in
                let xx = x as! Kind<F, Any>
                let yy = y as! Kind<G, Any>
                return f(Day(left: xx, right: yy, get))
            }
        }
    }
    
    public static func extract<A>(_ fa: DayOf<F, G, A>) -> A {
        fa^.step { left, right, get in
            get(left.extract(), right.extract())
        }
    }
}
