README
======

A simple command line client that leverages the API of the [Facts server](http://github.com/brandur/facts) to manipulate a Facts database.

Requirements
------------

A working installation of the [Facts server](http://github.com/brandur/facts), ideally one for which you have credentials for write access. Additionally, you'll need working Ruby and Rubygems installations.

Installation
------------

Installation is accomplished through Rubygems, and has been abstracted into a Simple rake task:

```
rake install
```

Usage
-----

Usage takes the form of:

```
facts <action>_<object> <args> <options>
```

Where the combination of action and object create a task name such as `edit_category` or `new_fact`. Next, arguments for that task are submitted, and finally flags and other options that should be taken into account.

Each task name has a much shorter alias which is normally the first letter of the action combined with the first letter of the object such as `ec` or `nf`.

### Tasks

The following tasks are available:

* `configure`: Configures a Facts connection and stores it to `.factsrc`.
* `daily_facts` (`d`): Prints a daily digest of facts for consumption and memorization.
* `destroy_category` (`rc`): Removes category(s).
* `destroy_fact` (`rf`): Removes fact(s).
* `edit_category` (`ec`): Edits the name of a category.
* `edit_fact` (`ef`): Edits the content of a fact.
* `move_category` (`mc`): Moves a category or set of categories to a new parent or to the root.
* `move_fact` (`mf`): Moves a fact or set of facts to a new parent.
* `new_category` (`nc`): Creates new category(s).
* `new_fact` (`nf`): Creates new fact(s).
* `query_category` (`qc`): Queries categories.
* `query_fact` (`qf`): Queries facts.

### Examples

#### Query

Query for category information matching a specific pattern:

```
facts qc ruby
```

Query for a category by ID:

```
facts qc 123
```

Query for facts that have content matching a specific pattern:

```
facts qf "warren buffett"
```

Query for facts that match _warren_ and _finance_:

```
facts qf warren finance
```

Query for facts that match _warren_ or _finance_:

```
facts qf warren finance --or
```

#### New

Create a top-level category:

```
facts nc "Politics" --no-parent
```

Create a new child category by specifying a unique query for some parent category as the first argument:

```
facts nc "politics" "The Senate"
```

Multiple new categories can be created at once:

```
facts nc "politics" "Canadian Politics" "American Politics" ...
```

Facts can be created in a similar manner:

```
facts nf "politics" "Politicians are crooks"
```

Categories or facts can be edited with $EDITOR by leaving off all "new" arguments:

```
facts nf "politics"
```

#### Edit

Edit a category name by specifying a search string followed by the new name:

```
facts ec politics "Global Politics"
```

Same for facts but with content:

```
facts ef crooks "Politicians are lovely people"
```

Leave off the second argument to edit the new name/content with $EDITOR: 

```
facts ec politics
facts ef crooks
```

#### Move

Move one category to another (all arguments should be queries that will match only a single category):

```
facts mc "dinosaurs" "zoology"
```

Many categories can be moved at once, just keep in mind that the last argument is always the destination:

```
facts mc "biology" "physics" ... "science"
```

Facts are moved in the same fashion:

```
facts mf "biology is the study of" biology
```

#### Destroy

Destroy facts or categories by specifying a series of search strings (each of which matches exactly one fact or category):

```
facts rc ruby
facts rf apple "steve jobs"
```

Contact
-------

Send comments and suggestions to **brandur@mutelight.org**.

