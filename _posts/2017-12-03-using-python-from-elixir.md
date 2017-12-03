---
layout: post
title: "Using python from elixir"
date: 2017-12-03
categories: article
comments: true
---

Elixir, being based on the Erlang VM, makes building highly concurrent applications easier. However, the Erlang VM as its weak spots.

It is widely known that [Erlang is bad at number crunching](https://stackoverflow.com/questions/11214336/what-makes-erlang-unsuitable-for-computationally-expensive-work) but this does not make it necessarily irrelevant for these kind of applications. In fact, there is multiple ways to interface with external code (which is not Elixir or Erlang) and to use it from Elixir and Erlang.

Applications that uses machine learning for example are characterized mostly as CPU bound problems that require a lot of calculations. In such problems it is essential to use all the features available in our modern CPUs such as the parallelism provided by the multiple cores of the CPU as well as by the [SIMD instructions.](https://en.wikipedia.org/wiki/SIMD)

Python as been huge in the machine learning space thanks to the [scikit learn ecosystem](http://scikit-learn.org/stable/) that builds on top of the [numpy](http://www.numpy.org/) library that contains a lot of mathematical functions implemented in C and leveraging the SIMD instructions such as the [`dot`](https://docs.scipy.org/doc/numpy-1.13.0/reference/generated/numpy.dot.html) product function.

In this post, we are going to see how to use Python code from Elixir by using the [`erlport`](http://erlport.org/) Erlang library.

## Erlport, treating python processes as if they where elixir processes

The erlport library allows to basically launch a python vm in a separate OS process and to communicate with it synchronously or asynchronously via message passing.

On the python side the `erlport` python package allows the python script to send messages to Elixir/Erlang processes by *pid* and it makes some Erlang specific types available on the python side as well(such as atoms).

Consider the following diagram:

<div class="img-container">
![Elixir to python communication]({{ site.url }}/imgs/ErlToPy.PNG)
</div>

Here we have an Elixir application with multiple erlang processes, remember that these are very lightweight and not actual OS processes. This sample application creates a process that launches and manages a python vm that acts as worker for heavy CPU bound operations.

Usually, we make sure to start a very sensible number of python VMs as they imply the creation of a new OS process, [OS processes imposes heavy management overhead on the operating system](https://stackoverflow.com/questions/6004069/lightweight-vs-heavyweight-processes) and it is usually a good idea to keep their count as low as possible.

Python processes can be linked to the Erlang process that creates them or not, of course a crash in a linked python process can cause the entire Erlang vm to crash and it is not the case with an unlinked process.

## Using erlport with python3

Erlport defaults to using the `python` binary when launching a python process. In most linux installation this resolves to python2.7, if you would like to use python3 you have to explicitly indicate the python3 binary.

As of the time of this writing, I had a small issue with using python3, in fact it seems that the erlport python3 package is not correctly populated in [the Github repository](https://github.com/hdima/erlport), I was basically unable to launch any python3 process and I was getting the following error:
```
/usr/bin/python3: No module named erlport.cli

10:53:31.320 [error] GenServer #PID<0.116.0> terminating
** (stop) {:port_closed, {:code, 1}}
Last message: {#Port<0.3572>, {:exit_status, 1}}
State: {:state, :infinity, 0, #Port<0.3572>, [], []}
```

[The solution was to manually place](https://github.com/hdima/erlport/issues/42) the erlport python package under `/usr/local/lib/python3.5/dist-packages` as follows:

1. Copy [`erlport/priv/python2/erlport/`](https://github.com/hdima/erlport/tree/master/priv/python2/erlport) to `/usr/local/lib/python3.5/dist-packages`
2. Copy the files under [`erlport/priv/python3/erlport/`](https://github.com/hdima/erlport/tree/master/priv/python3/erlport) to `/usr/local/lib/python3.5/dist-packages/erlport` and make sure they erase any existing files

## Using erlport in elixir

Let's now take a look at how to use the library in Elixir.

### Adding the mix dependency
First and foremost, you have to add the erlport denpendecy in the `mix.exs` file as in the following snippet:
```ex
defp deps do
  [
    {:erlport, git: "https://github.com/hdima/erlport.git"},
  ]
end
```
Then run `mix deps.get`. You may need to have [Rebar](https://github.com/erlang/rebar3) installed in order to build the erlport dependency.

### Starting and stopping a process
In order to use python code you have to first start a python process, this is done via the `:python.start` function:
```ex
{:ok, pid} = :python.start([
      {:python, 'python3'},
      {:python_path, './'},
    ])
    
:python.stop(pid)
```
As we mentioned previously, the `start` function defaults to starting the `python` binary which is usually python2.x. In the previous example we used an options list to explicitly tell erlport to use python3 and to use the current directory as the base path for our python scripts.

After calling `start`, `pid` will contain the identifier of the erlang process managing the python OS process.

Of course, don't forget to stop the python OS process otherwise it will keep running!

### Calling python functions synchronously

It is possible to call functions defined in a python file once we launched a python process, the python file needs to be reachable of course:

```ex
{:ok, pid} = :python.start([
      {:python, 'python3'},
      {:python_path, './'},
]) 
    
:python.call(pid, :py, :add, [1, 2])
|> IO.inspect #3
    
:python.call(pid, :sys, :"version.__str__", [])
|> IO.inspect #'3.5.2 (default, Nov 23 2017, 16:37:01) \n[GCC 5.4.0 20160609]'

:python.stop(pid)
```

The `call` function allows us to specify the name of the python module, the name of the function within the module that we wish to call as well as the arguments list. 
In the first call we invoked the `add` function contained in the `py.py` file which performs a simple addition:

```py
# py.py
def add(a, b):
    return a + b
```
The result is returned to Elixir as an integer.

In the second call, we called the `version.__str__` function contained in the standard `sys` python module, the result is then returned to elixir as a string. Note here how module and function names are passed as atoms.

### Sending messages to and from the python process

It is also possible to send messages from and to the python process, this is obviously very useful for asynchronous communication:
```ex
{:ok, pid} = :python.start([
 {:python, 'python3'},
 {:python_path, './'},
]) 
    
:python.call(pid, :py, :register, [self()])
|> IO.inspect # :kablam

:python.cast(pid, {:yo, 'Hi', %{k: 'v'}})
    
receive do
  msg -> IO.inspect msg # {:yo, 'Hi', %{k: 'v'}}
end

:python.stop(pid)
```

In the previous listing, we first called the `py.register` function(explained further) on the python side, this allows us to register a message listener and to communicate the *pid* of the erlang process to the python process.

The `:python.cast` function allows to send an asynchronous message to the python process, it takes the pid of the python process and the message to send, very simple.

Let's take a look at the python side:
```py
from erlport.erlterms import Atom
from erlport.erlang import set_message_handler, cast

def register(pid):

    def handler(message):
        cast(pid, message)
    
    set_message_handler(handler)
    return Atom(b'kablam')
```

The `register` function takes a erlang pid as an argument and defines the `handler` function which is registered as a message handler via the `erlport.erlang.set_message_handler` function. `register` returns finally an erlang atom, this is made possible in the python side by the `erlport.erlterms.Atom` class.

The `handler` function is very simple, it sends back the message it received to the registered `pid`. Note here how the asynchronous communication is possible in both ways, very exciting!

## Closing Thoughts

In addition to python erlport supports also ruby, so if you need to use ruby from Erlang/Elixir its there. Of course this a very superficial introduction and there is more to learn, that is why I invite you to checkout [the official documentation](http://erlport.org/docs/python.html).

Their are also ways to interface with c and c++ code, I am looking forward to play a bit with that...

