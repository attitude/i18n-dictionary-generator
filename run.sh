#!/usr/bin/php
<?php

$config = [
  'inputFile' => 'strings.tsv',
  'outputFile' => 'dictionary.js',
  'templateFile' => '',
  'sortKeys' => false,
];

$arguments = array_slice($argv, 1);

$argumentAliases = [
  'i' => [ 'variableName' => 'inputFile', 'description' => 'Path to source file. Should be TSV, tab separated values text file.'],
  'o' => [ 'variableName' => 'outputFile', 'description' => 'Path to the output file. Expecting a `.js` file extension.'],
  't' => [ 'variableName' => 'templateFile', 'description' => 'Path to a template file to use when generating the output file. Use `%s` or `{}` placeholder to define place of insertion.'],
  's' => [ 'variableName' => 'sortKeys', 'description' => 'Set it to sort keys of dictionary. Any string enables sorting. Use `SORT_REGULAR`, `SORT_NUMERIC`, `SORT_NATURAL` or `SORT_STRING` constants for specific sorting type.'],
];

function printLine($message = "") {
  echo "${message}\n";
}

function exitWithMessage($message = '') {
  exit("[ERROR]: ${message}\n");
}

function getUsage($argumentAliases = []) {
  return
    "[USAGE]:\n\n".
    "-h,\t-help\t\tShows this help.\n".
    implode(
      "\n",
      array_map(function($abbr = '', $definition = []) {
        return "-${abbr},\t-{$definition['variableName']}\t{$definition['description']}";
      }, array_keys($argumentAliases), array_values($argumentAliases))
    );
}

if (
  in_array('-h', $arguments) ||
  in_array('-help', $arguments) ||
  in_array('--h', $arguments) ||
  in_array('--help', $arguments)
) {
  printLine(getUsage($argumentAliases));
  exit;
}

while (sizeof($arguments) > 0) {
  $argumentName = trim(array_shift($arguments), '-');
  $argumentValue = array_shift($arguments);

  if (array_key_exists($argumentName, $argumentAliases)) {
    $argumentName = $argumentAliases[$argumentName]['variableName'];
  }

  if (array_key_exists($argumentName, $config)) {
    if (!isset($argumentValue)) {
      exitWithMessage("Argument is missing value: `${$argumentName}`");
    }

    if (in_array($argumentName, ['sortKeys'])) {
      $config[$argumentName] = [
        'SORT_REGULAR' => SORT_REGULAR,
        'SORT_NUMERIC' => SORT_NUMERIC,
        'SORT_NATURAL' => SORT_NATURAL,
        'SORT_STRING' => SORT_STRING,
      ][$argumentValue];

      if (!is_int($config[$argumentName])) {
        $config[$argumentName] = !! $argumentValue;

        if (in_array($argumentValue, ['no', 'NO', 'false', 'FALSE', 0, '0', 'n'], true)) {
          $config[$argumentName] = false;
        }
      }
    } else {
      $config[$argumentName] = $argumentValue;
    }
  } else {
    exitWithMessage("Unknown argument `${argumentName}`.\n\n".getUsage($argumentAliases));
  }
}

extract($config);

if ($templateFile && file_exists($templateFile)) {
  $template = file_get_contents($templateFile);
} elseif ($templateFile !== '') {
  exitWithMessage("Template file does not exist.");
} else {
  $template =
    '// @flow'."\n".
    "\n".
    "export const dictionary = {}\n";
}

if (!file_exists($inputFile)) {
  exitWithMessage("Missing `${inputFile}` file.");
}

$rows = array_map(function($row) {
  return array_map('trim', explode("\t", $row));
}, explode("\n", file_get_contents(trim($inputFile))));

$headers = array_shift($rows);
$headersCount = count($headers);
$expectedHeaders = [
  'module',
  'component',
  'label',
  'key'
];
$expectedHeadersCount = count($expectedHeaders);

if (
  sizeof(array_diff(
    array_intersect($headers, $expectedHeaders),
    $expectedHeaders
  )) !== 0
) {
  exitWithMessage('UNEXPECTED HEADERS: '.implode(", ", $headers)."\n".'Script update required.');
}

$languages = array_values(array_diff($headers, $expectedHeaders));
$languagesCount = count($languages);

printLine("LANGUAGES: ".implode(", ", $languages));

$dictionary = array_map(function() { return []; }, array_flip($languages));

foreach ($rows as $row) {
  $key = implode(".", array_slice($row, 0, $expectedHeadersCount));

  foreach ($languages as $langColumn => $langKey) {
    $dictionary[$langKey][$key] = array_slice($row, $expectedHeadersCount, $languagesCount)[$langColumn];
  }
}

if ($sortKeys) {
  foreach ($dictionary as &$languageDictionary) {
    if (is_int($sortKeys)) {
      ksort($languageDictionary, $sortKeys);
    } else {
      ksort($languageDictionary);
    }
  }
}

$content = sprintf(str_replace('{}', "%s", $template), json_encode($dictionary, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));


if (file_put_contents($outputFile, $content)) {
  printLine("SUCCESS: Dictionary written to ${outputFile}");
} else {
  exitWithMessage("Failed to write to ${outputFile}");
}
