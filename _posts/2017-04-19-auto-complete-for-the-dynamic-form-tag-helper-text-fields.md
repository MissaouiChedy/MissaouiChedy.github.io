---
layout: post
title: "Auto-complete for the Dynamic Form Tag Helper"
date: 2017-04-19
categories: article
comments: true
---

The dynamic tag helper prototype is getting richer in functionality, in this post we are going to add support for text fields auto-completion.

When a user is inputting text in a text field, auto-complete allows the user to select text from a list of suggestions. The suggestions are updated as the user is typing in order to display the most relevant possibilities.

This feature can be observed in most search boxes all over the internet, consider google's search box for example:
<div class="img-container">
![Example auto-complete]({{ site.url }}/imgs/ExampleAutoComplete.PNG)
</div>

Thanks to auto-complete, when searching for *"Italian pizza recipes"*, the user can avoid typing the whole query into the search box. Simply typing *"Italian pizza"* will bring some suggestions containing *"Italian pizza recipes"* that the user can select.

We are going to see how our dynamic form tag helper supports this.
Full code is available in the [Github repository](https://github.com/MissaouiChedy/DynamicFormTagHelper).

## Setting up auto-complete for a text input field?

One way to implement auto-complete for a form text field is to place a list element `<ul>` somewhere under the `<input>` field.

Then, it is possible to register a key press listener on the `<input>` element that will populate the list with relevant suggestions for each key stroke as the `<input>` field is getting filled.

For each key press, the listener fetches the content of the `<input>` field and searches inside a suggestions source for strings containing or starting with the typed characters. It then updates the content of the suggestion list, take a look at the following animation from [this johnjohnston.info post](http://johnjohnston.info/106/automating-autocomplete-gifs/):

<div class="img-container">
![Auto complete in action](http://johnjohnston.info/106/wp-content/uploads/2013/12/google_autocomplete.gif)
</div>

The suggestions source is usually a list(array in JavaScript) of strings that is either available locally on the web page or fetched dynamically from a remote endpoint via Ajax.

In addition, a modern auto-complete solution must provide an acceptable user experience by highlighting the selected suggestions and by allowing to select a suggestion via keyboard(arrow keys and Enter).

It is needless to say that implementing auto-complete properly from scratch requires some effort on the front end, but fortunately numerous JavaScript auto-complete libraries exist and are usually customizable.

For our prototype, we are going to use the [Typeahead.js](https://twitter.github.io/typeahead.js/) front-end library which we will talk about further but first let's see how to activate auto-complete for a specific class property on the server side.


## Enabling auto-completion with the AutoComplete attribute

Activating auto-complete for a specific `string` property on a given view model class is just a matter of slapping the `[AutoComplete]` attribute on it, as we can see in the following snippet:

<script src="https://gist.github.com/MissaouiChedy/5abb9debd5eb4fb53d7939c5d62b0e03.js"></script>

The `[AutoComplete]` attribute contains two notable properties:
- `SuggestionsProperty` that allows to specify the name which is a read-only `List<string>` property representing the suggestion source that is going to be made available as a local source on the client side.

- `SuggestionsEndpoint` that allows to specify the path of an http endpoint that is going to be used on the client side to query for the list of suggestions.

Consider the following snippet, where the `SuggestionsEndpoint` property is used:
<script src="https://gist.github.com/MissaouiChedy/1566ddf8a24ca6bd2e001eee1dd1a898.js"></script>

Queries for dog names suggestions will be directed to the `/Home/DogNames` endpoint which leads to the following action on the `HomeController`:
<script src="https://gist.github.com/MissaouiChedy/20cab373e2bfb1b950bab87b553aca4f.js"></script>

The previous action method takes a `string` of typed characters as an argument, so it will be used, for instance, as follows: `GET /Home/DogNames?typed=Daw`.
You can see that it is responsible for returning a list of strings matching the given typed characters as a [JSON](https://tools.ietf.org/html/rfc7159). 

### How this works?

History based suggestion on the generated form has been disabled by adding the `autocomplete="off"` html attribute to the generated `<form>` element.It has been disabled so it does not conflict with our auto-completion.

The [`FormGroupBuilder`](https://github.com/MissaouiChedy/DynamicFormTagHelper/blob/master/TagHelpers/FormGroupBuilder.cs) is the class responsible for generating the actual form by leveraging the metadata available on the given view model. This class has been modified to detect the `[AutoComplete]` attribute.

When it detects an `[AutoComplete]` attribute on a given property it makes sure that the resulting `<input>` element has the `autocomplete` css class then depending on the type of suggestions(local or remote) it makes sure that the relevant html attribute is present in the resulting `<input>` element.

The relevant html attribute is one of these two:
- `data-source-local` which will contain the suggestion source which will be usually an array of strings.
- `data-source-ajax` which will contain the suggestions endpoint as described earlier.

On the client side, the `autocomplete` class, the `data-source-local` and `data-source-ajax` attributes are going to be used to enable auto-completion.

## Achieving Auto-complete with Typeahead.js

[Typeahead.js](https://twitter.github.io/typeahead.js/) is a JavaScript library that plays nice with JQuery (that we already use in our prototype).

All we have to do is to include the library(usually in the `Shared/_Layout.cshtml` view) and call the `typeahead` function on the relevant `<input>` elements with the desired parameters, consider the following JavaScript snippet:

<script src="https://gist.github.com/MissaouiChedy/5a9643a7b78d78f2abcdc651a0986c53.js"></script>

The previous snippet is executed when the page is ready i.e. under the `$(document).ready` function to initialize the auto-completion.
Here we selected all the `<input>` elements having the `autocomplete` css class, then for each element we apply the `typeahead` function with some options.

The first argument is an object in which we specify for example that suggestion highlighting must be enabled.

In the second argument we specify the suggestions source via the `suggestionsEngine`.

The `suggestionsEngine` is actually a `Bloodhound` object; [Bloodhound](https://github.com/twitter/typeahead.js/blob/master/doc/bloodhound.md) is the suggestion engine used by [Typeahead.js](https://twitter.github.io/typeahead.js/), it can handle local and remote sources as well as suggestions caching and pre-fetching.

The following snippet contains the creation of two `Bloodhound` objects, the first is configured with a local suggestion source and the second is configured with a remote one:

<script src="https://gist.github.com/MissaouiChedy/e0f0a713ae2f08e0289c81f3a5a3b929.js"></script>

Creating a `Bloodhound` object involves supplying some tokenizers, I suspect they are used to split the typed characters into distinct words. Then we can set an array of strings as a local source or an object containing a template url of the remote endpoint containing a wildcard that is going to be replaced by the typed characters(`%QUERY` in the previous example).

To sum it up, in order to use Typeahead.js for autocompletion we perform the following steps:
1. include the Typeahead library
2. For each `<input>` needing auto-complete we call the `typeahead` function by supplying an appropriate suggestion source

This is sufficient to display the suggestions when typing in the relevant fields, the only catch is that the suggestion list is not styled so you will probably need to crank out some css.

In our prototype the initialization of the auto-complete field is done under the `intializeAutoComplete` function under the [`site.js`](https://github.com/MissaouiChedy/DynamicFormTagHelper/blob/master/wwwroot/js/site.js) file, I invite you to take look at it in the [Github repository](https://github.com/MissaouiChedy/DynamicFormTagHelper) along with the [`site.css`](https://github.com/MissaouiChedy/DynamicFormTagHelper/blob/master/wwwroot/css/site.css) file if you want to see how things are put together.

The `PersonViewModel.Name` and `DogViewModel.Name` properties have been slapped with `[AutoComplete]` attribute which yields the following behavior:
<div class="img-container">
![Auto complete demo]({{ site.url }}/imgs/AutoCompleteDemo.gif)
</div>

## Closing Thoughts

Most of the effort in implementing auto-complete lies on the client side, it is crucial to use a good library or to build a good one from scratch if it is more appropriate.

The current prototype imposes the usage of [Typeahead.js](https://twitter.github.io/typeahead.js/), it would be better to give the developer the possibility to use an alternative, maybe self made, library for auto-completion.

We can also leverage pre-fetching and caching to give faster suggestions and to minimize queries to the server when using a remote suggestion source.