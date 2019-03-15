# i18n Dictionary Generator

Generates JSON/JS dictionary from TSV file

## Installation

(Not yet published to NPM)

1. Add dependency to your `devDependencies` of `package.json`:
    ```
    "i18n-dictionary-generator": "attitude/i18n-dictionary-generator#<commit SHA>",
    ```
2. Run `$ yarn` to install new dependency.

### Runining

```
$ yarn i18n-dictionary-generator <Options>
```

## Options

##### -h<br>-help
Shows usage.

##### -i &lt;FILEPATH&gt;<br>-inputFile &lt;FILEPATH&gt;
Path to source file. Should be TSV, tab separated values text file.

##### -o &lt;FILEPATH&gt;<br>-outputFile &lt;FILEPATH&gt;
Path to the output file. Expecting a `.js` file extension.

##### -t &lt;FILEPATH&gt;<br>-templateFile &lt;FILEPATH&gt;
Path to a template file to use when generating the output file. Use `%s` or `{}` placeholder to define place of insertion.

##### -s &lt;SORTING&gt;<br>-sortKeys &lt;SORTING&gt;
Set it to sort keys of dictionary. Any *trueish* string enables sorting. Use `SORT_REGULAR`, `SORT_NUMERIC`, `SORT_NATURAL` or `SORT_STRING` constants for specific [sorting type](http://php.net/manual/en/function.sort.php).

## Expected TSV Format

TSV stands for TAB separated values. See [strings.tsv](./strings.tsv) file for example.

## Template file

Use `%s` or `{}` placelhoder to specify where to place resulting JSON. If no template file is defined, default [template](./template.js) is used.
