---
layout: post
title: "Handling Multiple Choices Fields In The Dynamic Form Tag Helper"
date: 2017-04-10
categories: article
comments: true
---

If you have been following the dynamic form tag helpers series, you must know that by now our dynamic form tag helper is able to [generate a form for a given view model](http://blog.techdominator.com/article/first-dynamic-form-tag-helper-attempt.html). The `<dynamic-form>` tag helper [supports multiple levels of nested complex properties](http://blog.techdominator.com/article/supporting-complex-type-properties-in-the-dynamic-form-tag-helper.html) as well as [some customization via the `<tweak>` tag helper](http://blog.techdominator.com/article/customizing-dynamic-form-tag-helper-generation.html) and usual attributes(such as the [`DisplayAttribute`](https://msdn.microsoft.com/en-us/library/system.componentmodel.dataannotations.displayattribute(v=vs.110).aspx)).

In this post,we are going to tackle the support of form controls that allows the user to choose one or multiple values from a list.

Among these form controls we are going to focus on [select menus](https://www.w3schools.com/tags/tryit.asp?filename=tryhtml_select), [radio button groups](https://www.w3schools.com/html/tryit.asp?filename=tryhtml_radio) and [multi-select lists](https://www.w3schools.com/tags/att_select_multiple.asp).

As usual the full code is available in the [Github repository](https://github.com/MissaouiChedy/DynamicFormTagHelper). 

## Implementing Multi-Choice Selection
In ASP.NET Core, choice selection is typically realized by using the [`<select>` tag helper](http://www.davepaquette.com/archive/2015/05/18/mvc6-select-tag-helper.aspx).

Consider the following strongly typed cshtml view:
<script src="https://gist.github.com/MissaouiChedy/a51d317fb022d9dcbbb8e1005ec41e00.js"></script>

Here the `select` tag helper has been used with the `asp-for` and the `asp-items` attributes respectively containing the `SelectedItem` and the `ItemChoiceList` properties.

Under the hypothetical `SomeModel`:
- `ItemChoiceList` will usually be an `IEnumerable` of `SelectListItem` containing the actual choices that are going to be displayed. This property is obviously passed to `asp-items`
- `SelectedItem` will usually be a `string` or an integer (`int`, `long`...) that will contain the selected value when the form will be submitted. This property is obviously passed to `asp-for`

The previous `select` example will display a drop down menu that contains the elements specified in `ItemChoiceList` and that allows the user to select only one value as in the following screenshot:
<div class="img-container">
![Example drop down menu]({{ site.url }}/imgs/ExampleDropDown.png)
</div>


The select items belongs to the `SelectListItem` class which defines, among others, the `Value` and `Text` properties. A select list item is created as in the following expression `new SelectListItem() { Value="1", Text="Glove"}`.

The `Text` property contains the actual string that is going to be displayed for the item.

The `Value` property represents the identification data (usually a unique ID) that will be passed to the server to indicate which choice have been selected.

The selected choice's `Value` will be stored in the view model's `SelectedItem` property after the form submission. In our example if we select `Glove`, `SelectedItem` will contain `"1"`.

Ì usually refer to the property containing the selected choice as the *target property*.

If we wish to allow the user to select multiple values, all we have to do is to change the type of `SelectedItem` to a `List<string>` or a `List<int>` and perhaps also the name to `SelectedItems` to make it less confusing. This will cause the rendering of the following multi-select list:
<div class="img-container">
![Multi select list example]({{ site.url }}/imgs/MultiSelectListExample.PNG)
</div>

So, to sum it up in order to use the `select` tag helper we need to provide a *list of items* and a *target property*.

## Specifying an Items Source for a Property

In our dynamic tag helper, we would like to allow the developer to specify in the view model class the properties for which multi choice form controls should be generated.

The previous capability is made possible by the `[ItemsSource]` attribute, consider the following view model class:

<script src="https://gist.github.com/MissaouiChedy/abaaeb122057d140114b6b9befb1907c.js"></script>

First, we define the `Items` [expression bodied](https://davefancher.com/2014/08/25/c-6-0-expression-bodied-members/) and read-only property. As you can see this property contains a list of select items.

Then, the `[ItemsSource]` attribute is slapped on the `SelectedItem` property which will contain the selected item's value(target property). The `ItemsSourceAttribute.ItemsProperty` is used to supply the name of the property that contains the list of select items(`Items` in our example) which is going to be subsequently passed to the `<select>` tag helper internally.

Notice here how we used the new convenient [`nameof` operator](https://msdn.microsoft.com/en-us/library/dn986596.aspx) to avoid hard-coding the relevant property name.

The `[ItemsSource]` attribute allows the [`FormGroupBuilder`](https://github.com/MissaouiChedy/DynamicFormTagHelper/blob/master/TagHelpers/FormGroupBuilder.cs) to detect properties which form controls should be rendered as select elements. The `FormGroupBuilder` uses [the reflection API](http://stackoverflow.com/a/12814920/1182189) to read the [`[ItemsSource]`](https://github.com/MissaouiChedy/DynamicFormTagHelper/blob/master/TagHelpers/ItemsSourceAttribute.cs) attribute instance if it is present and uses its methods and properties to properly generate multi-choice form controls.

The `FormGroupBuilder` uses the `SelectTagHelper` internally to build the form control, leveraging the existing `SelectTagHelper` allows us to support multi select lists by only changing the type of the target property to a `List` as described in the previous section.

## Using a Group of Radio Buttons

Thanks to `[ItemSources]`'s `ChoicesType` property it is possible to use a radio button group instead of the usual drop down menu for single value selection cases.

Consider this alternative snippet from the `PersonViewModel`:
<script src="https://gist.github.com/MissaouiChedy/1ba1dec20ca66dd2bd7abb153c3cee61.js"></script>

Here we passed a `ChoicesTypes.RADIO` flag to the `[ItemSources]` attribute which will be picked by the `FormGroupBuilder` that will generate the following form group:
<div class="img-container">
![Radio Button Group]({{ site.url }}/imgs/RadioInput.PNG)
</div>

In the previous example an input of type `radio` has been generated for each item of the `Items` list, the selected value will be of course set in the `SingleSelected` property when the form is submitted.


## Specifying an Enum Type as a Source

It is possible to use an [enum type](https://msdn.microsoft.com/en-us/library/sbbt4032.aspx) as a list of items. By using the `[ItemSources]`'s `ItemEnums` which can contain a `Type` object representing the `enum`, consider the following snippet:

<script src="https://gist.github.com/MissaouiChedy/efc457a244e751df39c2a2716c9239ae.js"></script>

The `PersonViewModel.Gender` belongs to the `Sex` enum type and is slapped by the `[ItemsSource]` attribute. Here we used the `typeof` operator to pass the enumeration's `Type` object which will be used to generate a `List<SelectListItem>` internally.

The previous example generates the following drop down menu:
<div class="img-container">
![Drop down menu from enum]({{ site.url }}/imgs/DropDownFromEnum.png)
</div>

The selected value will be of course in the `Gender` property when the form is submitted. Furthermore, **it is possible to use a multiple choice list as well as a radio button group with enums**.

## Small Issue Encountered

Creating a radio button involves essentially creating an `<input>` element with the `type` attribute set to `radio`: `<input type="radio">`.

Some changes have been made to the `FormGroupBuilder.buildInputHtml` method to support the creation of a radio button, these changes include setting the `InputTagHelper.Type` property.

Setting the `InputTagHelper.Type` requires to add a `type` attribute to the `TagHelperAttributeList` used for rendering the `InputTagHelper`. Otherwise an `InvalidArgumentException` is thrown during the processing
of the tag helper.

## Closing Thoughts

Implementing support for multiple choices turned out to be easier than I thought, it only required the creation of the `[ItemsSource]` custom attribute and some changes to the existing `FormGroupBuilder`.

The changes made seemed trivial to me so I didn't really delve into the details which you can always look up in the usual [Github repository](https://github.com/MissaouiChedy/DynamicFormTagHelper).

In the next post we will probably see more functionality.