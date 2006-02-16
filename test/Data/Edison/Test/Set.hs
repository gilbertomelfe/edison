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
import qualified Data.Edison.Coll.StandardSet as SS


-------------------------------------------------------
-- A utility class to propigate class contexts down
-- to the quick check properites

class (Eq (set a), Arbitrary (set a), Show (set a),
       OrdSet (set a) a) => SetTest a set

instance (Ord a, Show a, Arbitrary a) => SetTest a US.Set
instance (Ord a, Show a, Arbitrary a) => SetTest a SS.Set


--------------------------------------------------------
-- List all permutations of set types to test

allSetTests :: Test
allSetTests = TestList
   [ setTests (empty :: Ord a => US.Set a)
   , setTests (empty :: Ord a => SS.Set a)
   ]


---------------------------------------------------------
-- List all the tests to run for each type

setTests set = TestLabel ("Set Test "++(instanceName set)) . TestList $
   [ qcTest $ prop_single set
   , qcTest $ prop_single set
   , qcTest $ prop_fromSeq set
   , qcTest $ prop_insert set
   , qcTest $ prop_insertSeq set
   , qcTest $ prop_union set
   , qcTest $ prop_unionSeq set
   , qcTest $ prop_delete set
   , qcTest $ prop_deleteAll set
   , qcTest $ prop_deleteSeq set            -- 10
   , qcTest $ prop_null_size set
   , qcTest $ prop_member_count set
   , qcTest $ prop_toSeq set
   , qcTest $ prop_lookup set
   , qcTest $ prop_fold set
   , qcTest $ prop_filter_partition set
   , qcTest $ prop_deleteMin_Max set
   , qcTest $ prop_unsafeInsertMin_Max set
   , qcTest $ prop_unsafeFromOrdSeq set
   , qcTest $ prop_unsafeAppend set         -- 20
   , qcTest $ prop_filter set
   , qcTest $ prop_partition set
   , qcTest $ prop_minView_maxView set
   , qcTest $ prop_minElem_maxElem set
   , qcTest $ prop_foldr_foldl set
   , qcTest $ prop_foldr1_foldl1 set
   , qcTest $ prop_toOrdSeq set
   , qcTest $ prop_intersect_difference set
   , qcTest $ prop_subset_subsetEq set
   , qcTest $ prop_fromSeqWith set         -- 30
   , qcTest $ prop_insertWith set
   , qcTest $ prop_insertSeqWith set
   , qcTest $ prop_unionl_unionr_unionWith set
   , qcTest $ prop_unionSeqWith set
   , qcTest $ prop_intersectWith set
   , qcTest $ prop_unsafeMapMonotonic set
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


prop_fromSeq :: SetTest Int set => set Int -> Seq Int -> Bool
prop_fromSeq set xs =
    toOrdList (fromSeq xs `asTypeOf` set) == sort (S.toList xs)

prop_insert :: SetTest Int set => set Int -> Int -> set Int -> Bool
prop_insert set x xs =
    if member x xs then
      toOrdList (insert x xs) == toOrdList xs
    else
      toOrdList (insert x xs) == List.insert x (toOrdList xs)

prop_insertSeq :: SetTest Int set => set Int -> Seq Int -> set Int -> Bool
prop_insertSeq set xs ys =
    insertSeq xs ys == union (fromSeq xs) ys

prop_union :: SetTest Int set => set Int -> set Int -> set Int -> Bool
prop_union set xs ys =
    toOrdList (union xs ys) == lmerge (toOrdList xs) (toOrdList ys)

prop_unionSeq :: SetTest Int set => set Int -> Seq (set Int) -> Bool
prop_unionSeq set xss =
    unionSeq xss == S.foldr union empty xss

prop_delete :: SetTest Int set => set Int -> Int -> set Int -> Bool
prop_delete set x xs =
    toOrdList (delete x xs) == List.delete x (toOrdList xs)

prop_deleteAll :: SetTest Int set => set Int -> Int -> set Int -> Bool
prop_deleteAll set x xs =
    deleteAll x xs == delete x xs

prop_deleteSeq :: SetTest Int set => set Int -> Seq Int -> set Int -> Bool
prop_deleteSeq set xs ys =
    deleteSeq xs ys == S.foldr delete ys xs

prop_null_size :: SetTest Int set => set Int -> set Int -> Bool
prop_null_size set xs =
    null xs == (size xs == 0)
    &&
    size xs == Prelude.length (toOrdList xs)

prop_member_count :: SetTest Int set => set Int -> Int -> set Int -> Bool
prop_member_count set x xs =
    mem == not (Prelude.null (Prelude.filter (== x) (toOrdList xs)))
    &&
    count x xs == (if mem then 1 else 0)
  where mem = member x xs

---------------------------------------------------------------
-- Coll operations

prop_toSeq :: SetTest Int set => set Int -> set Int -> Bool
prop_toSeq set xs =
    List.sort (S.toList (toSeq xs)) == toOrdList xs

prop_lookup :: SetTest Int set => set Int -> Int -> set Int -> Bool
prop_lookup set x xs =
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

prop_fold :: SetTest Int set => set Int -> set Int -> Bool
prop_fold set xs =
    List.sort (fold (:) [] xs) == toOrdList xs
    &&
    (null xs || fold1 (+) xs == sum (toOrdList xs))

prop_filter_partition :: SetTest Int set => set Int -> set Int -> Bool
prop_filter_partition set xs =
    toOrdList (filter p xs) == Prelude.filter p (toOrdList xs)
    &&
    partition p xs == (filter p xs, filter (not . p) xs)
  where p x = x `mod` 3 == 2

------------------------------------------------------------------
-- OrdCollX operations

prop_deleteMin_Max :: SetTest Int set => set Int -> set Int -> Bool
prop_deleteMin_Max set xs =
    toOrdList (deleteMin xs) == (let l = toOrdList xs 
                                 in if L.null l then L.empty else L.ltail l)
    &&
    toOrdList (deleteMax xs) == (let l = toOrdList xs
                                 in if L.null l then L.empty else L.rtail l)


prop_unsafeInsertMin_Max :: SetTest Int set => 
	set Int -> Int -> set Int -> Bool
prop_unsafeInsertMin_Max set i xs =
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
    
prop_unsafeFromOrdSeq :: SetTest Int set => set Int -> [Int] -> Bool
prop_unsafeFromOrdSeq set xs =
    unsafeFromOrdSeq (sort xs) == fromSeq xs `asTypeOf` set

prop_unsafeAppend :: SetTest Int set => 
	set Int -> Int -> set Int -> set Int -> Bool
prop_unsafeAppend set i xs ys =
    if null xs || null ys then
      unsafeAppend xs ys == union xs ys
    else
      unsafeAppend xs ys' == union xs ys'
  where delta = maxElem xs - minElem ys + 1
        ys' = unsafeMapMonotonic (+delta) ys
  -- if unsafeMapMonotonic does any reorganizing in addition
  -- to simply replacing the elements, then this test will
  -- not provide even coverage

prop_filter :: SetTest Int set => set Int -> Int -> set Int -> Bool
prop_filter set x xs =
    toOrdList (filterLT x xs) == Prelude.filter (< x) (toOrdList xs)
    &&
    toOrdList (filterLE x xs) == Prelude.filter (<= x) (toOrdList xs)
    &&
    toOrdList (filterGT x xs) == Prelude.filter (> x) (toOrdList xs)
    &&
    toOrdList (filterGE x xs) == Prelude.filter (>= x) (toOrdList xs)

prop_partition :: SetTest Int set => set Int -> Int -> set Int -> Bool
prop_partition set x xs =
    partitionLT_GE x xs == (filterLT x xs, filterGE x xs)
    &&
    partitionLE_GT x xs == (filterLE x xs, filterGT x xs)
    &&
    partitionLT_GT x xs == (filterLT x xs, filterGT x xs)

-- OrdColl operations

prop_minView_maxView :: SetTest Int set => set Int -> set Int -> Bool
prop_minView_maxView set xs =
    minView xs == (if null xs then Nothing
                              else Just (minElem xs, deleteMin xs))
    &&
    maxView xs == (if null xs then Nothing
                              else Just (maxElem xs, deleteMax xs))

prop_minElem_maxElem :: SetTest Int set => set Int -> set Int -> Property
prop_minElem_maxElem set xs =
    not (null xs) ==>
      minElem xs == Prelude.head (toOrdList xs)
      &&
      maxElem xs == Prelude.last (toOrdList xs)

prop_foldr_foldl :: SetTest Int set => set Int -> set Int -> Bool
prop_foldr_foldl set xs =
    foldr (:) [] xs == toOrdList xs
    &&
    foldl (flip (:)) [] xs == Prelude.reverse (toOrdList xs)

prop_foldr1_foldl1 :: SetTest Int set => set Int -> set Int -> Property
prop_foldr1_foldl1 set xs =
    not (null xs) ==>
      foldr1 f xs == foldr f 1333 xs
      &&
      foldl1 (flip f) xs == foldl (flip f) 1333 xs
  where f x 1333 = x
        f x y = 3*x - 7*y

prop_toOrdSeq :: SetTest Int set => set Int -> set Int -> Bool
prop_toOrdSeq set xs =
    S.toList (toOrdSeq xs) == toOrdList xs

-----------------------------------------------------------------------
-- SetX operations

prop_intersect_difference :: SetTest Int set => 
	set Int -> set Int -> set Int -> Bool
prop_intersect_difference set xs ys =
    intersect xs ys == filter (\x -> member x xs) ys
    &&
    difference xs ys == filter (\x -> not (member x ys)) xs

prop_subset_subsetEq :: SetTest Int set => 
	set Int -> set Int -> set Int -> Bool
prop_subset_subsetEq set xs ys =
    subset xs ys == (subsetEq xs ys && xs /= ys)
    &&
    subsetEq xs ys == (intersect xs ys == xs)


--------------------------------------------------------------------------
-- Set operations

prop_fromSeqWith :: SetTest Int set => set Int -> Seq Int -> Bool
prop_fromSeqWith set xs =
    fromSeqWith const xs == fromSeq xs `asTypeOf` set

prop_insertWith :: SetTest Int set => set Int -> Int -> set Int -> Bool
prop_insertWith set x xs =
    insertWith const x xs == insert x xs

prop_insertSeqWith :: SetTest Int set => set Int -> Seq Int -> set Int -> Bool
prop_insertSeqWith set xs ys =
    insertSeqWith const xs ys == insertSeq xs ys

prop_unionl_unionr_unionWith :: SetTest Int set => 
	set Int -> set Int -> set Int -> Bool
prop_unionl_unionr_unionWith set xs ys =
    unionl xs ys == u
    &&
    unionr xs ys == u
    &&
    unionWith const xs ys == u
  where u = union xs ys

prop_unionSeqWith :: SetTest Int set => set Int -> Seq (set Int) -> Bool
prop_unionSeqWith set xss =
    unionSeqWith const xss == unionSeq xss

prop_intersectWith :: SetTest Int set => set Int -> set Int -> set Int -> Bool
prop_intersectWith set xs ys =
    intersectWith const xs ys == intersect xs ys

prop_unsafeMapMonotonic :: SetTest Int set => set Int -> set Int -> Bool
prop_unsafeMapMonotonic set xs =
    toOrdList (unsafeMapMonotonic (2*) xs) == Prelude.map (2*) (toOrdList xs)