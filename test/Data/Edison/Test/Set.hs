-- Copyright (c) 1999 Chris Okasaki.  
-- See COPYRIGHT file for terms and conditions.

-- WARNING: The Set operations (insertWith...) are not adequately tested.
-- To be thorough, they should be tested on a type where distinguishable
-- values can still be "equal", and the results should be tested to make
-- sure that the "With" function was called on the right values.

module Data.Edison.Test.Set where

import Prelude hiding (concat,reverse,map,concatMap,foldr,foldl,foldr1,foldl1,
                       filter,takeWhile,dropWhile,lookup,take,drop,splitAt,
                       zip,zip3,zipWith,zipWith3,unzip,unzip3,null)
import qualified Prelude
import qualified List -- not ListSeq!

import Test.QuickCheck
import Test.HUnit (Test(..))

import Data.Edison.Prelude
import Data.Edison.Coll
import Data.Edison.Test.Utils
import qualified Data.Edison.Seq.ListSeq as L

import Data.Edison.Seq.JoinList (Seq)
import qualified Data.Edison.Seq.JoinList as S

----------------------------------------------------
-- Set implementations to test

import qualified Data.Edison.Coll.UnbalancedSet as US

-------------------------------------------------------
-- A utility class to propigate class contexts down
-- to the quick check properites

class (Eq (set a), Arbitrary (set a), Show (set a),
       OrdSet (set a) a) => SetTest a set

instance (Ord a, Show a, Arbitrary a) => SetTest a US.Set


--------------------------------------------------------
-- List all permutations of set types to test

allSetTests :: Test
allSetTests = TestList
   [ setTests (empty :: Ord a => US.Set a)
   ]

---------------------------------------------------------
-- List all the tests to run for each type

setTests set = TestLabel ("Set Test "++(instanceName set)) . TestList $
   [ qcTest $ prop_single set
   ]

-----------------------------------------------------
-- Utility operations


lmerge :: [Int] -> [Int] -> [Int]
lmerge xs [] = xs
lmerge [] ys = ys
lmerge xs@(x:xs') ys@(y:ys')
  | x < y     = x : lmerge xs' ys
  | y < x     = y : lmerge xs ys'
  | otherwise = x : lmerge xs' ys'


nub :: [Int] -> [Int]
nub (x : xs@(x' : _)) = if x==x' then nub xs else x : nub xs
nub xs = xs

sort = nub . List.sort

---------------------------------------------------------------
-- CollX operations

prop_single :: SetTest Int set => set Int -> Int -> Bool
prop_single set x =
    toOrdList (single x `asTypeOf` set) == [x]

{-
prop_fromSeq :: Seq Int -> Bool
prop_fromSeq xs =
    tol (fromSeq xs) == sort (S.toList xs)

prop_insert :: Int -> Set Int -> Bool
prop_insert x xs =
    if member x xs then
      tol (insert x xs) == tol xs
    else
      tol (insert x xs) == List.insert x (tol xs)

prop_insertSeq :: Seq Int -> Set Int -> Bool
prop_insertSeq xs ys =
    insertSeq xs ys == union (fromSeq xs) ys

prop_union :: Set Int -> Set Int -> Bool
prop_union xs ys =
    tol (union xs ys) == lmerge (tol xs) (tol ys)

prop_unionSeq :: Seq (Set Int) -> Bool
prop_unionSeq xss =
    unionSeq xss == S.foldr union empty xss

prop_delete :: Int -> Set Int -> Bool
prop_delete x xs =
    tol (delete x xs) == List.delete x (tol xs)

prop_deleteAll :: Int -> Set Int -> Bool
prop_deleteAll x xs =
    deleteAll x xs == delete x xs

prop_deleteSeq :: Seq Int -> Set Int -> Bool
prop_deleteSeq xs ys =
    deleteSeq xs ys == S.foldr delete ys xs

prop_null_size :: Set Int -> Bool
prop_null_size xs =
    null xs == (size xs == 0)
    &&
    size xs == Prelude.length (tol xs)

prop_member_count :: Int -> Set Int -> Bool
prop_member_count x xs =
    mem == not (Prelude.null (Prelude.filter (== x) (tol xs)))
    &&
    count x xs == (if mem then 1 else 0)
  where mem = member x xs


-- Coll operations

prop_toSeq :: Set Int -> Bool
prop_toSeq xs =
    List.sort (S.toList (toSeq xs)) == tol xs

prop_lookup :: Set Int -> Int -> Bool
prop_lookup xs x =
    if member x xs then
      lookup x xs == x
      &&
      lookupM x xs == Just x
      &&
      lookupWithDefault 999 x xs == x
      &&
      lookupAll x xs == Prelude.take (count x xs) (repeat x)
    else
      lookupM x xs == Nothing
      &&
      lookupWithDefault 999 x xs == 999
      &&
      lookupAll x xs == []

prop_fold :: Set Int -> Bool
prop_fold xs =
    List.sort (fold (:) [] xs) == tol xs
    &&
    (null xs || fold1 (+) xs == sum (tol xs))

prop_filter_partition :: Set Int -> Bool
prop_filter_partition xs =
    tol (filter p xs) == Prelude.filter p (tol xs)
    &&
    partition p xs == (filter p xs, filter (not . p) xs)
  where p x = x `mod` 3 == 2


-- OrdCollX operations

prop_deleteMin_Max :: Set Int -> Bool
prop_deleteMin_Max xs =
    tol (deleteMin xs) == L.ltail (tol xs)
    &&
    tol (deleteMax xs) == L.rtail (tol xs)

prop_unsafeInsertMin_Max :: Int -> Set Int -> Bool
prop_unsafeInsertMin_Max i xs =
    if null xs then
      unsafeInsertMin 0 xs == single 0
      &&
      unsafeInsertMax 0 xs == single 0
    else
      unsafeInsertMin lo xs == insert lo xs
      &&
      unsafeInsertMax hi xs == insert hi xs
  where lo = minElem xs - 1
        hi = maxElem xs + 1
    
prop_unsafeFromOrdSeq :: [Int] -> Bool
prop_unsafeFromOrdSeq xs =
    unsafeFromOrdSeq (sort xs) == fromSeq xs

prop_unsafeAppend :: Int -> Set Int -> Set Int -> Bool
prop_unsafeAppend i xs ys =
    if null xs || null ys then
      unsafeAppend xs ys == union xs ys
    else
      unsafeAppend xs ys' == union xs ys'
  where delta = maxElem xs - minElem ys + 1
        ys' = unsafeMapMonotonic (+delta) ys
  -- if unsafeMapMonotonic does any reorganizing in addition
  -- to simply replacing the elements, then this test will
  -- not provide even coverage

prop_filter :: Int -> Set Int -> Bool
prop_filter x xs =
    tol (filterLT x xs) == Prelude.filter (< x) (tol xs)
    &&
    tol (filterLE x xs) == Prelude.filter (<= x) (tol xs)
    &&
    tol (filterGT x xs) == Prelude.filter (> x) (tol xs)
    &&
    tol (filterGE x xs) == Prelude.filter (>= x) (tol xs)

prop_partition :: Int -> Set Int -> Bool
prop_partition x xs =
    partitionLT_GE x xs == (filterLT x xs, filterGE x xs)
    &&
    partitionLE_GT x xs == (filterLE x xs, filterGT x xs)
    &&
    partitionLT_GT x xs == (filterLT x xs, filterGT x xs)


-- OrdColl operations

prop_minView_maxView :: Set Int -> Bool
prop_minView_maxView xs =
    minView xs == (if null xs then Nothing
                              else Just (minElem xs, deleteMin xs))
    &&
    maxView xs == (if null xs then Nothing
                              else Just (maxElem xs, deleteMax xs))

prop_minElem_maxElem :: Set Int -> Property
prop_minElem_maxElem xs =
    not (null xs) ==>
      minElem xs == Prelude.head (tol xs)
      &&
      maxElem xs == Prelude.last (tol xs)

prop_foldr_foldl :: Set Int -> Bool
prop_foldr_foldl xs =
    foldr (:) [] xs == tol xs
    &&
    foldl (flip (:)) [] xs == Prelude.reverse (tol xs)

prop_foldr1_foldl1 :: Set Int -> Property
prop_foldr1_foldl1 xs =
    not (null xs) ==>
      foldr1 f xs == foldr f 1333 xs
      &&
      foldl1 (flip f) xs == foldl (flip f) 1333 xs
  where f x 1333 = x
        f x y = 3*x - 7*y

prop_toOrdSeq :: Set Int -> Bool
prop_toOrdSeq xs =
    S.toList (toOrdSeq xs) == tol xs

-- SetX operations
prop_intersect_difference :: Set Int -> Set Int -> Bool
prop_intersect_difference xs ys =
    intersect xs ys == filter (\x -> member x xs) ys
    &&
    difference xs ys == filter (\x -> not (member x ys)) xs

prop_subset_subsetEq :: Set Int -> Set Int -> Bool
prop_subset_subsetEq xs ys =
    subset xs ys == (subsetEq xs ys && xs /= ys)
    &&
    subsetEq xs ys == (intersect xs ys == xs)

-- Set operations
prop_fromSeqWith :: Seq Int -> Bool
prop_fromSeqWith xs =
    fromSeqWith const xs == fromSeq xs

prop_insertWith :: Int -> Set Int -> Bool
prop_insertWith x xs =
    insertWith const x xs == insert x xs

prop_insertSeqWith :: Seq Int -> Set Int -> Bool
prop_insertSeqWith xs ys =
    insertSeqWith const xs ys == insertSeq xs ys

prop_unionl_unionr_unionWith :: Set Int -> Set Int -> Bool
prop_unionl_unionr_unionWith xs ys =
    unionl xs ys == u
    &&
    unionr xs ys == u
    &&
    unionWith const xs ys == u
  where u = union xs ys

prop_unionSeqWith :: Seq (Set Int) -> Bool
prop_unionSeqWith xss =
    unionSeqWith const xss == unionSeq xss

prop_intersectWith :: Set Int -> Set Int -> Bool
prop_intersectWith xs ys =
    intersectWith const xs ys == intersect xs ys

-- bonus operation, not supported by all ordered collections

prop_unsafeMapMonotonic :: Set Int -> Bool
prop_unsafeMapMonotonic xs =
    tol (unsafeMapMonotonic (2*) xs) == Prelude.map (2*) (tol xs)
-}