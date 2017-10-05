---
layout: post
title: "Small functional programming exercise in Elixir"
date: 2017-10-05
categories: article
comments: true
---

Yesterday, I found a [question on Stack Overflow](https://stackoverflow.com/questions/46553433/how-do-i-think-of-this-sequence-generator-in-elixir) that essentially asked if an Elixir implementation was properly written in the functional style of programming.

The implementation suggested by [the original poster](https://stackoverflow.com/users/1870446/konnigun) contained too much `if` statements which is somewhat a smell in the functional style. In fact , loops and `if` statements should be avoided in favor of *pattern matching* and *recursion*.

Back in the day, when I was playing around with [Haskell](https://www.haskell.org/), I remember that it was simply impossible to diverge from the functional style at least when avoiding monads.

I decided to implement a solution to the problem in order to have some deliberate practice in the functional style in Elixir.

## Problem

The problem is simple to state.

Generate the first `n` elements of the following sequence:

`[1, (previous + m),...]` 

Where `m = 2` initially and is incremented by `2` each `4` elements:

`[1, (previous + 2), (previous + 2), (previous + 2), (previous + 2), (previous + 4), (previous + 4), (previous + 4), (previous + 4), (previous + 6), (previous + 6), (previous + 6), (previous + 6)]`

Here are the first `16` elements of the list that must be generated:

`[1, 3, 5, 7, 9, 13, 17, 21, 25, 31, 37, 43, 49, 57, 65, 73, 81]`


## Solution

The solution that I came up with is to basically:

1. Generate an infinite list of even numbers with each numbers duplicated 4 times, essentially this list `[2, 2, 2, 2, 4, 4, 4, 4, 6, 6, 6, 6...]`
2. Take the count of elements needed in the final sequence
3. Using reduce, iterate over the duplicated even numbers which represents the `m` in our problem and build the final list

<script src="https://gist.github.com/MissaouiChedy/90d056d2c8de25c5c7ec4c8a644fafda.js"></script>


### Step 1: Infinite stream of duplicated even numbers

Recall the `m` from the problem definition, each 4 iteration it is incremented by 2, so why not generate a list of all the `m` that are going to be added to the elements of the final list? 

Once the previous is done, all we have to do is to iterate over these `m` to figure out the value of `m` for a specific element.

Here we are basically "pre-computing" an infinite sequence of `m`. 

Consider the following `get_stream_of_duplicated_evens` function:

<script src="https://gist.github.com/MissaouiChedy/9976ccac60fc1a036c838e127f0261ba.js"></script>

First, we used the `Stream` module to create an infinite list starting from 1 and having its elements successively incremented by 1, then we filter out the odd numbers from the sequence keeping only the even numbers.

Each element(even number) of the infinite list is duplicated 4 times which produces a list of lists of duplicated numbers (`[[int]]`) that looks something like this `[[2, 2, 2, 2], [4, 4, 4, 4]...].` Finally the previous list of lists is flattened to a list of integers (`[int]`).

Here we used the `Stream` module to generate the sequence, which allows us to build sequences that can be processed lazily, this is similar to LINQ methods that returns an `IEnumerable` in C# and which are evaluated lazily as well.

### Step 2: Evaluating the needed count of elements

By using the `Enum.take` function we can get a list having the desired elements count:

<script src="https://gist.github.com/MissaouiChedy/50c0845ffef563bd4da5428f93b9cd3a.js"></script>

This evaluates the sequence eagerly for the exact number of desired elements (16 in the previous case).

### Step 3: Generating the result sequence

In order to generate the result sequence we simply feed the list of duplicated evens to the `get_result_list` function:

<script src="https://gist.github.com/MissaouiChedy/9b54192797c4f21f39b9fffc25aabe04.js"></script>

For each even number `m`, if the intial list is empty then add the first element, otherwise append to the list the last inserted element + m.
    
This build the desired list but in reverse and without 1 as the first element, all we have to do is to reverse the list then prepend 1.

## A more compact solution

[One answer](https://stackoverflow.com/a/46553811/1182189) has been suggested to the question in Stack Overflow and I must admit that it is more compact but involves using one `if` statement.

Here we iterate over a sequence containing the desired count of elements and `m` is actually figured out in each iteration as follows:

<script src="https://gist.github.com/MissaouiChedy/a00ad1df1c1921e5117e311526ec7759.js"></script>

Although not strictly functional, I think that this solution is more pragmatic. By leveraging the flexibility of Elixir that allows to use some imperative constructs this solution is more compact and may cause less cognitive load.

## Closing thoughts

Every time you find yourself using `if` statements in Elixir there may be something wrong, but different situations may require different approaches and `if` statements are there for a reason... 