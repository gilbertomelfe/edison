-- |
--   Module      :  Data.Edison
--   Copyright   :  Copyright (c) 2006 Robert Dockins
--   License     :  BSD3; see COPYRIGHT file for terms and conditions
--
--   Maintainer  :  robdockins AT fastmail DOT fm
--   Stability   :  provisional
--   Portability :  non-portable (MPTC and FD)
--
--   Edison is a library of purely functional data structures written by
--   Chris Okasaki.  It is named after Thomas Alva Edison and for the
--   mnemonic value /ED/i/S/on (/E/fficent /D/ata /S/tructures).
--
--   Edison provides several families of abstractions, each with
--   multiple implementations.  The main abstractions provided by Edison are:
--
--   * /Sequences/ such as stacks, queues, and dequeues,
--
--   * /Collections/ such as sets, bags and heaps, and
--
--   * /Associative Collections/ such as finite maps and priority queues
--     where the priority and element are distinct.
--
--
--
--   /Conventions:/
--
--   Each data structure is implemented as a separate module.  These modules
--   should always be imported @qualified@ to prevent a flood of name clashes,
--   and it is recommended to rename the module using the @as@ keyword to reduce
--   the overhead of qualified names and to make substituting one implementation
--   for another as painless as possible.
--
--   Names have been chosen to match standard usage as much as possible.  This
--   means that operations for abstractions frequently share the same name
--   (for example, @empty@, @null@, @size@, etc).  It also means that in many
--   cases names have been reused from the Prelude.  However, the use of
--   @qualified@ imports will prevent name reuse from becoming name clashes.  If
--   for some reason you chose to import an Edison data structure unqualified,
--   you will likely need to import the Prelude @hiding@ the relevant names.
--
--   Edison modules also frequently share type names.  For example, most sequence
--   type constructors are named @Seq@.  This additionally aids substituting
--   implementations by simply importing a different module.
--
--   Argument orders are selected with the following points in mind:
--
--   * /Partial application:/ arguments more likely to be static usually
--     appear before other arguments in order to facilitate partial
--     application.
--
--   * /Collection appears last:/ in all cases where an operation queries a
--     single collection or modifies an existing collection, the collection
--     argument will appear last.  This is something of a de facto standard
--     for Haskell datastructure libraries
--     and lends a degree of consistency to the API.
--
--   * /Most usual order:/ where an operation represents a well-known
--     mathematical function on more than one datastructure, the arguments
--     are chosen to match the most usual argument order for the function.
--
--
--   /Type classes:/
--
--   Each family of abstractions is defined as a set of classes: a main class
--   that every implementation of that abstraction should support and several
--   auxiliary subclasses that an implementation may or may not support. However,
--   not all applications require the power of type classes, so each method
--   is also directly accessible from the implementation module.  Thus you can
--   choose to use overloading or not, as appropriate for your particular
--   application.
--
--   Documentation about the behavior of data structure operations is defined
--   in the modules "Data.Edison.Seq", "Data.Edison.Coll" and
--   "Data.Edison.Assoc".  Implementations are required to respect
--   the descriptions and axioms found in these modules.  In some cases time
--   complexity is also given.  Implementations may differ from these time
--   complexities; if so, the differences will be given in the documentation for
--   the individual implementation module.
--
--
--
--   /Notes on Eq and Ord instances:/
--
--   Many Edison data structures require @Eq@ or @Ord@ contexts to define equivalence
--   and total ordering on elements or keys.  Edison makes the following assumptions
--   about all such required instances:
--
--   * An @Eq@ instance correctly defines an equivalence relation (but not necessarily
--     structural equality); that is, we assume @(==)@ (considered as a
--     relation) is reflexive, symmetric and transitive, but allow that equivalent
--     items may be distinguishable by other means.
--
--   * An @Ord@ instance correctly defines a total order which is consistent with
--     the @Eq@ instance for that type.
--
--   These assumptions correspond to the usual meanings assigned to these classes.  If
--   an Edison data structure is used with an @Eq@ or @Ord@ instance which violates these
--   assumptions, then the behavior of that data structure is undefined.
--
--
--
--   /Notes on Read and Show instances:/
--
--   The usual Haskell convention for @Read@ and @Show@ instances (as championed by the
--   Haskell \"deriving\" mechanism), is that @show@ generates a string which is a
--   valid Haskell expression built up
--   using the data type's data constructors such that, if interpreted as Haskell code, the
--   string would generate an identical data item.  Furthermore, the derived  @Read@
--   instances are able to parse such strings, such that @(read . show) === id@.
--   So, derived instances of @Read@ and @Show@ exhibit
--   the following useful properties:
--
--   * @read@ and @show@ are complementary; that is, @read@ is a useful inverse for @show@
--
--   * @show@ generates a string which is legal Haskell code representing the data item
--
--   For concrete data types, the deriving mechanism is usually quite sufficent.
--   However, for abstract types the derived @Read@ instance may allow users to create data
--   which violates invariants. Furthermore, the strings resulting from @show@ reference hidden
--   data constructors which violates good software engineering principles and also
--   cannot be compiled because the constructors are not available outside the defining module.
--
--   Edison avoids most of these problems and still maintains the above useful properties by
--   doing conversions to and from lists and inserting explicit calls to the list conversion
--   operations.  The corresponding @Read@ instance strips the list conversion call before
--   parsing the list.  In this way, private data constructors are not revealed and @show@ strings
--   are still legal, compilable Haskell code.  Furthermore, the showed strings gain a degree of
--   independence from the underlying datastructure implementation.
--
--   For example, calling @show@ on an empty Banker's queue will result in the following string:
--
-- > Data.Edison.Seq.BankersQueue.fromList []
--
--   Datatypes which are not native Edison data structures (such as StandardSet and StandardMap)
--   may or may not provide @Read@ or @Show@ instances and, if they exist, they may or may
--   not also provide the properties that Edison native @Read@ and @Show@ instances do.
--
--
--
--   /Notes on unsafe functions:/
--
--   There are a number of different notions of what constitutes an unsafe function.
--   In Haskell, a function is generally called \"unsafe\" if it can subvert
--   type safety or referential integrity, such as @unsafePerformIO@ or @unsafeCoerce#@.
--   In Edison, however, we downgrade the meaning of \"unsafe\" somewhat.  An
--   \"unsafe\" Edison function is one which, if misused, can violate the structural
--   invariants of a data structure.  Misusing an Edison \"unsafe\" function should
--   never cause your runtime to crash or break referential integrity, but it may cause
--   later uses of a data structure to behave in undefined ways.  Almost all unsafe functions
--   in Edison are labeled with the @unsafe@ prefix.  An exception to this rule is the
--   @With@ functions in the 'Set' class, which are also unsafe but do not have
--   the prefix.  Unsafe functions will have explicit preconditions listed in their
--   documentation.
--
--
--
--   /Notes on ambiguous functions:/
--
--   Edison also contains some functions which are labeled \"ambiguous\".  These
--   functions cannot violate the structural invariants of a data structure, but, under
--   some conditions, the result of applying an ambiguous function is not well defined.
--   For ambiguous functions, the result of applying the function may depend on otherwise
--   unobservable internal state of the data structure, such as the actual shape of a
--   balanced tree.  For example, the 'AssocX' class contains the @fold@ function, which
--   folds over the elements in the collection in an arbitrary order.  If the combining
--   function passed to @fold@ is not fold-commutative (see below), then the result of
--   the fold will depend on the actual order that elements are presented to the
--   combining function, which is not defined.
--
--   To aid programmers, each API function is labeled /ambiguous/ or /unambiguous/ in its
--   documentation.  If a function is unambiguous only under some circumstances,
--   that will also be explicitly stated.
--
--   An \"unambiguous\" operation is one where all correct implementations of the operation
--   will return \"indistinguishable\" results.  For concrete data types, \"indistinguishable\"
--   means structural equality.  An instance of an abstract data type is considered
--   indistinguishable from another if all possible applications of unambiguous
--   operations to both yield indistinguishable results.  (Note: this definition is
--   impredicative and rather imprecise.  Should it become an issue, I will attempt to
--   develop a better definition.  I hope the intent is sufficiently clear).
--
--   A higher-order unambiguous operation may be rendered ambiguous if passed a \"function\" which
--   does not respect referential integrity (one containing @unsafePerformIO@ for example).
--   Only do something like this if you are 110% sure you know what you are doing, and even then
--   think it over two or three times.
--
--
--
--   /How to choose a fold:/
--
--   /Folds/ are an important class of operations on data structures in a functional
--   language; they perform essentially the same role that iterators perform in
--   imperative languages.  Edison provides a dizzying array of folds which (hopefully)
--   correspond to all the various ways a programmer might want to fold over a data
--   structure.  However, it can be difficult to know which fold to choose for a
--   particular application.  In general, you should choose a fold which provides
--   the /fewest/ guarantees necessary for correctness.  The folds which have fewer
--   guarantees give data structure implementers more leeway to provide efficient
--   implementations.  For example, if you which to fold a commutative, associative
--   function, you should chose @fold@ (which does not guarantee an order) over @foldl@
--   or @foldr@, which specify particular orders.
--
--   Also, if your function is strict in
--   the accumulating argument, you should prefer the strict folds (eg, @fold'@); they will
--   often provide better space behavior.  /Be aware/, however, that the \"strict\" folds
--   are not /necessarily/ more strict than the \"non-strict\" folds; they merely give
--   implementers the option to provide additional strictness if it improves performance.
--
--   For associative collections, only use with @WithKey@ folds if you actually need the
--   value of the key.
--
--
--   /Painfully detailed information about ambiguous folds:/
--
--   All of the folds that are listed ambiguous are ambiguous because they do not or cannot
--   guarantee a stable order with which the folding function will be applied.  However,
--   some functions are order insensitive, and the result will be unambiguous regardless
--   of the fold order chosen.  Here we formalize this property, which we call
--   \"fold commutativity\".
--
--   We say @f :: a -> b -> b@ is /fold-commutative/ iff @f@ is unambiguous and
--
-- >    forall w, z :: b; m, n :: a
-- >
-- >       w = z ==> f m (f n w) = f n (f m z)
-- >
--
--   where @=@ means indistinguishability.
--
--   This property is sufficient (but not necessary) to ensure that, for any
--   collection of elements to
--   fold over, folds over all permutations of those elements will generate
--   indistinguishable results.  In other words, an ambiguous fold applied to a
--   fold-commutative combining function becomes /unambiguous/.
--
--   Some fold combining functions take their arguments in the reverse order.  We
--   straightforwardly extend the notion of fold commutativity to such functions
--   by reversing the arguments.  More formally, we say @g :: b -> a -> b@ is fold
--   commutative iff @flip g :: a -> b -> b@ is fold commutative.
--
--   For folds which take both a key and an element value, we extend the notion of fold
--   commutativity by considering the key and element to be a single, uncurried argument.
--   More formally, we say @g :: k -> a -> b -> b@ is fold commutative iff
--
-- >    \(k,x) z -> g k x z :: (k,a) -> b -> b
--
--   is fold commutative according to the above definition.
--
--   Note that for @g :: a -> a -> a@, if @g@ is unambiguous,
--   commutative, and associative, then @g@ is fold-commutative.
--
--   Proof:
--
-- >    let w = z, then
-- >    g m (g n w) = g m (g n z)     g is unambiguous
-- >                = g (g n z) m     commutative property of g
-- >                = g n (g z m)     associative property of g
-- >                = g n (g m z)     commutative property of g
--
--   Qed.
--
--   Thus, many common numeric combining functions, including @(+)@ and @(*)@ at
--   integral types, are fold commutative and can be safely used with ambiguous
--   folds.
--
--   /Be aware/ however, that @(+)@ and @(*)@ at floating point types are only
--   /approximately/ commutative and associative due to rounding errors; using
--   ambiguous folds with these operations may result in subtle differences in
--   the results.  As always, be aware of the limitations and numeric
--   properties of floating point representations.
--
--
--
--   /About this module:/
--
--   This module re-exports the various data structure abstraction classes, but
--   not their methods. This allows you to write type signatures which have
--   contexts that mention Edison type classes without having to import the
--   appropriate modules @qualified@.  The class methods are not exported to
--   avoid name clashes.  Obviously, to use the methods of these classes, you
--   will have to import the appropriate modules.  This module additionally
--   re-exports the entire "Data.Edison.Prelude" module.
--
--
--
--   /Miscellaneous points:/
--
--   Some implementations export a few extra functions beyond those included
--   in the relevant classes.  These are typically operations that are
--   particularly efficient for that implementation, but are not general enough
--   to warrant inclusion in a class.
--
--   Since qualified infix symbols are fairly ugly, they have been largely avoided.
--   However, the "Data.Edison.Sym" module defines a number of infix operators
--   which alias the prefix operators; this module is intended to be imported
--   unqualified.
--
--   Most of the operations on most of the data structures are strict.  This is
--   inevitable for data structures with non-trivial invariants. Even given
--   that, however, many of the operations are stricter than necessary.  In
--   fact, operations are never deliberately made lazy unless the laziness is
--   required by the algorithm, as can happen with amortized data structures.
--
--   Note, however, that the various sequence implementations are always lazy
--   in their elements.  Similarly, associative collections are always lazy in
--   their elements (but usually strict in their keys).  Non-associative
--   collections are usually strict in their elements.

module Data.Edison (

-- * Sequence class
  Sequence

-- * Collection classes
-- ** Non-observable collections
, CollX
, OrdCollX
, SetX
, OrdSetX
-- ** Observable collections
, Coll
, OrdColl
, Set
, OrdSet

-- * Associative collection classes
-- ** Non-observable associative collections
, AssocX
, OrdAssocX
, FiniteMapX
, OrdFiniteMapX
-- ** Observable associative collections
, Assoc
, OrdAssoc
, FiniteMap
, OrdFiniteMap

, module Data.Edison.Prelude
) where

import Data.Edison.Prelude
import Data.Edison.Seq
import Data.Edison.Coll
import Data.Edison.Assoc