---
layout: post
title: "Automated Testing"
date: 2018-02-16
categories: article
comments: true
---

I remember, when I was a student, my first attempt at making a [Swing](https://docs.oracle.com/javase/tutorial/uiswing/) based desktop application that used an Oracle database to persist data in which I basically built a big ball of mud with duplicated SQL queries scattered all over the [smart UI](https://learnbycode.wordpress.com/2015/03/13/anti-pattern-smart-ui-part-1/).

Shortly after, I discovered two essential concepts in software development which are [layering](https://www.codeproject.com/Articles/16253/Layered-approach-in-software-development-A-clean-w) and automated testing.

Decoupling business logic from the UI started to make a lot of sense and the decoupled domain layer became very easy to test. In this post, we are going to see some approaches to automated testing and some of its benefits.

## Automated testing FTW

Automating the testing of software is very easy for CPU/Memory bound code. 

In fact, if we have a layer that does not depend on 3rd party services (such as databases, message brokers or APIs) and that contains code which is *"numbers in numbers out"*, all we have to do is to create a routine that:

1. Instantiates the unit under test (when needed)
2. Operates the behavior under test
3. Checks whether the returned result is has expected

Consider this example:
```csharp
public static class Util {
    public static int Add(int a, int b) {
        return a + b;
    }    
}

```

In order, to test the `Add` method we can create the following script which can be executed to verify the desired behavior:

```csharp
public class Main {
    public static void Main(string[] args) {
        int expected = 3;
        int actual = Util.Add(1, 2);
        if (expected == actual) {
            Console.WriteLine('Test Pass')
        }
        else {
            Console.WriteLine('Test FAIL!')
        } 
    }
}
```

Of course, there are today multiple automated testing frameworks available nearly for each programming language so no need to roll your own, here is for example a test case that uses the [xUnit](https://xunit.github.io/) testing tool:

```csharp
public class UtilTest
{
    [Fact]
    public void ShouldSumTwoIntegers()
    {
        int expected = 3;
        int actual = Util.Add(1, 2);
        Assert.Equal(expected, actual);
    }
}
```

These testing frameworks packs a lot of useful features such as test runners and assertion libraries. They allow to create multiple test cases and the set of test cases is usually called the *test suite.*

In my experience, having a test suite available when working on a code base boosts productivity enormously by shortening the feedback cycle. **Running the automated tests can usually takes seconds**(but not always) which is a huge time saver compared to manual testing. 

The style of testing described previously is called *example based testing*, because we provide example inputs then we verify the output against an expected value(or state). 

It is essential to come up with good examples that covers ideally all the possible cases which can be difficult to achieve in practice. Still, example based tests are a very good start in building a feedback loop.

## Test driven development

Automated tests allows us to practice [test driven development](https://technologyconversations.com/2013/12/20/test-driven-development-tdd-example-walkthrough/)(TDD) which basically writing tests cases before writing actual production code.

[Rules of TDD](http://butunclebob.com/ArticleS.UncleBob.TheThreeRulesOfTdd) state that after writing one failing test case we write just enough production code to pass that test case, then we incrementally add test cases by making sure that we written enough production code for passing one test case before moving on to the next.

This process yields the following advantages in my opinion:
- the software produced is **testable** since we are forced to reason on how to test before writing the production code
- the software produced **is kept lean** and does not include unneeded behaviors or unused code
- the test suite produced can act as **runnable documentation** that contains information on how a piece of code is supposed to be used 

Note also that focusing on testability also forces us to manage and to reason about the dependencies between the components of the software.


Following the rules of TDD blindly will not always yield perfect code and I will readily admit that I am always violating the rules by writing production code that is generalized and not meant to just pass the test cases.

I also find it a bit tedious to start by writing tests when building I/O bound code which interacts directly with 3rd party services. That is why I usually practice TDD only when building domain layer and more generally CPU/Memory bound code. 

## The case for CPU/Memory bound code

As we mentioned earlier, the kind of code that only exercises CPU and memory is very easy to test because creating test cases does not require configuring or launching 3rd party services.

It does not also require making sure that some files exist in the file system or that an internet connection is available, thus making it very opportune to [*unit testing.*](http://softwaretestingfundamentals.com/unit-testing/)

Unit testing is defined as testing a unit of software without testing it dependencies, a unit is usually a class or a function.

Dependencies are usually mocked i.e. replaced by fake objects that mimics the behavior of a real implementation.

In his excellent article [Mocks Aren't Stubs](https://martinfowler.com/articles/mocksArentStubs.html), [Martin Fowler](https://martinfowler.com/) describes two types of developers practicing TDD: 
- Mockist testers who aggressively mock every dependency in their unit tests
- classical testers who only mocks dependencies that are effectively I/O bound and requires some configuration and setup in order to run in the test suite

I am personally a classical TDD, because in my opinion mocking every single dependency burns time unnecessarily. In addition, testing against actual CPU/Mem bound dependencies allows to expose more defects and issues sooner.

For CPU/Mem bound code, and especially on domain logic code, I always like to practice TDD for the reasons mentioned previously and because I also get a fix from seeing the red and green of tests failing and passing as a build some part of the software. It just makes me feel that I am making progress and I like it.

## Closing thoughts

Things are not always so easily testable, in fact all code is not CPU/Memory bound and when working on a web application for example we expect to have a lot of code interacting with databases, message queues, APIs and HTTP requests/responses. We will discuss the testability of this kind of code in an upcoming post.

*Example based testing* is a good start as we mentioned earlier, but **property based testing** is a superior approach to automated testing specifically for CPU/Mem bound code. We are going to discuss this subject in the upcoming post.




