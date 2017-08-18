# JMadlibs

A gem intended to provide slightly deeper functionality than other
madlib-engine gems the author has found. Given a list of words and a pattern,
it produces a final string with some degree of randomness.

## Installation

JMadlibs can be found on Rubygems [here](https://rubygems.org/gems/jmadlibs/).
It can be installed like any other gem:

```
sudo gem install jmadlibs
```


## Usage

For operation, JMadlibs requires a Library and a Pattern.  These can be
provided in one of three ways:

* Passed at instantiation  
  `madlibs = JMadlibs.new("Pattern", {"wordlist1" => ["word", "word", "word"]}`

* Passed directly:  
  `madlibs.setPattern(pattern_string)`  
`madlibs.setLibrary(library_hash)`

* Loaded from a file:  
  `madlibs.loadList(filename)`

Once both Pattern and Library are set, output of text can be triggered by
calling `madlibs.generate()`

### Library

The library is a Ruby hash with each key pointing to a list of words. Word
list names should be lowercase to avoid interfering with post-processing.

### Pattern

The pattern dictates how the library word lists should be used. It is made up
of tokens, which can be any of the following:

#### Plain text

Text not belonging to any other token type will be reproduced as-is: `Hello.`
will give the simple output `Hello.`

#### &lt;Substitutions>

`<key>` specifies the wordlist from which to substitute: `I'm going to
<verb>` will replace `<verb>` with one of the words in the 'verb' word list.

Substitutions can join wordlists: `I like my <family+pet>` will replace with
a word from either of the lists specified, and an arbitrary number of lists
can be supplied.

Substitutions allow some limited post-processing:
* <key$A> will prepend the substituted word with 'an ' if the returned text
  begins with a vowel, and 'a ' else; for example, `I am <snake$A>` might produce
```
I am a cobra
I am an anaconda
```
* <key$U>  will cause the returned word to be
  capitalised.  
```
I work as <job$A> => I work as a geologist
I work as <Job$AU> => I work as an Archaeologist
```

These post-processing flags can be used at the end of any substitution token and in any order:

```
<job+hobby+role$UA>
```

#### [Optionals]

`[text]` will be randomly included or ignored. The default frequency is 50%,
but this can be overridden by adding `%50` (with the specified percentage) at
the end of the token; for example, `I [sometimes %30] like to dance` can output

```
I like to dance
I sometimes like to dance
I like to dance
I like to dance
```

#### {Alternatives}

`{option1|option2|option3}` will include only one of the options with
approximately equal frequency; for example, `I prefer {tea|coffee|juice}` may
produce

```
I prefer tea
I prefer coffee
I prefer juice
```

At present, alternatives cannot be nested in the form
`{option1|{option2|option3}}`; this will be added in a future version.

## Loading from a file

When loading from a file, word list names are given between two pairs of `=`,
for instance as `==pet==`. Any following words are added to the current word
list, until another word list name is given.  Lines beginning with `#` are
comments, blank lines are ignored, and any line with text before the first word
list name is considered to be a pattern.

## Examples

For these examples, we will be using the following file (input.txt):
```
==food==
burger
pie
salad
apple

==pet==
cat
dog
fish

==family==
brother
sister
{father|mother}

```
The following ruby code
```
require 'jmadlibs'

madlibs = JMadlibs.new()
madlibs.loadFile('./input.txt')
madlibs.setPattern("My <family> fed <food%a> to my <pet+family>")
print madlibs.generate
```

can result in

```
My mother fed a pie to my fish
My father fed a salad to my cat
My sister fed a burger to my brother
My brother fed an apple to my cat
```

It's important to note that all token types can appear in the return strings
from parsing of other tokens. A wordlist might contain in its list items that
include further substitutions, options or alternatives as outlined above.
Patterns can also be nested: Substitutions may appear within both optional and
alternative sections, and optional and alternative tokens can appear within each
other:

```
madlibs.setPattern("{[<Salutation> %50] <Surname>|<Surname>} is a <jobtitle>[ and is paid {well|poorly}%10]")
```

## Other settings

Various informational and debugging messages can be made visible. Log levels
are `ERROR`, `WARN`, `INFO`, `DEBUG` or `ALL`, with each level outputting all
messages further down the scale.  The default log level is `INFO`, and can be
set using `madlibs.logLevel(3)` or `madlibs.logLevel("INFO")`


## Future Plans (TODO)

* Nested parsing of alternatives as outlined above.
* exploration of pluralisation via `<word$p>` (a difficult problem, with how
  complicated plurals are in any language - this can currently be emulated with
  careful word list construction).
* Escaping of token signifiers (so e.g. `\<verb>` is treated as plain text and
  output accordingly).

## Changelist

* 25/04/2017 - Updated methods to properly use seeded RNG rather than default rand() (0.8.3)

* 28/10/2016 - initial public release (0.8.2)
