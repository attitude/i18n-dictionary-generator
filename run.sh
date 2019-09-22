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
  'o' => [ 'variableName' => 'outputFile', 'description' => 'Path to the output file. Expecting a `.js` file extension. A `.json` file is also generated to be able to compare semantic version.'],
  't' => [ 'variableName' => 'templateFile', 'description' => 'Path to a template file to use when generating the output file. Use `%s` or `{}` placeholder to define place of insertion.'],
  's' => [ 'variableName' => 'sortKeys', 'description' => 'Set it to sort keys of dictionary. Any string enables sorting. Use `SORT_REGULAR`, `SORT_NUMERIC`, `SORT_NATURAL` or `SORT_STRING` constants for specific sorting type.'],
];

define('SEMVER_REGEX', '/v?(?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)/');

function parseVersion ($version = '') {
  if (!preg_match(SEMVER_REGEX, $version, $versionPieces)) {
    exitWithErrorMessage("Failed to parse sem-version of `${version}`. See semver.org for more details");
  }

  return [
    'major' => intval($versionPieces['major']),
    'minor' => intval($versionPieces['minor']),
    'patch' => intval($versionPieces['patch']),
  ];
}

function bumpVersion($version, $majorBump = 0, $minorBump = 0, $patchBump = 0): string {
  $versionPieces = is_string($version) ? parseVersion($version) : $version;

  if ($majorBump) {
    $minorBump = null;
    $patchBump = null;
  } elseif ($minorBump) {
    $patchBump = null;
  }

  return  $versionPieces['prefix'].
    implode('.', [
      intval($versionPieces['major']) + $majorBump,
    $minorBump === null ? '0' : intval($versionPieces['minor']) + $minorBump,
    $patchBump === null ? '0' : intval($versionPieces['patch']) + $patchBump,
    ]);
}

// Warn: Naive implementation
function stripExtension ($filePath = "") {
  return substr($filePath, 0, strrpos($filePath, '.'));
}

function nullIfEmptyString($string = '') {
  return strlen(trim($string)) === 0 ? null : trim($string);
}

function jsonToData ($json): array {
  $result = json_decode($json, true);

  if (!is_array($result)) {
    throw new Exception("Unable to parse JSON");
  }
  return $result;
}

function getJsonContent ($filePath) {
  return jsonToData(nullIfEmptyString(file_get_contents($filePath)));
}

function dataToJson ($data) {
  return json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
}

function putJsonContent ($fileName = '', $data) {
  if (!file_put_contents($fileName, dataToJson($data))) {
    exitWithErrorMessage("Failed to write `${fileName}` to disk");
  }
}

function printLine($message = "") {
  echo "${message}\n";
}

function exitWithMessage($message = '') {
  exit("${message}\n");
}

function exitWithErrorMessage($message = '') {
  exit("[ERROR]: ${message}\n");
}

function findVersionTaggedJsonFile ($outputFile = ''): ?string {
  $pattern = stripExtension($outputFile).'.*.*.*.json';

  $files = glob($pattern);

  return count($files) > 0 ? $files[0] : null;
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
      exitWithErrorMessage("Argument is missing value: `${$argumentName}`");
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
    exitWithErrorMessage("Unknown argument `${argumentName}`.\n\n".getUsage($argumentAliases));
  }
}

extract($config);

if ($templateFile && file_exists($templateFile)) {
  $template = file_get_contents($templateFile);
} elseif ($templateFile !== '') {
  exitWithErrorMessage("Template file does not exist.");
} else {
  $template = file_get_contents(dirname(__FILE__).'/template.js');
}

if (!file_exists($inputFile)) {
  exitWithErrorMessage("Missing `${inputFile}` file.");
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
  exitWithErrorMessage('UNEXPECTED HEADERS: '.implode(", ", $headers)."\n".'Script update required.');
}

$languages = array_values(array_diff($headers, $expectedHeaders));
$languagesCount = count($languages);

printLine("LANGUAGES: ".implode(", ", $languages));

$dictionary = array_map(function() { return []; }, array_flip($languages));

foreach ($rows as $row) {
  $key = implode(".", array_slice($row, 0, $expectedHeadersCount));

  foreach ($languages as $langColumn => $langKey) {
    $dictionary[$langKey][$key] = strtr(
      array_slice($row, $expectedHeadersCount, $languagesCount)[$langColumn],
      [
        '\t' => "\t",
        '\n' => "\n",
      ]
    );
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

$previousJsonFile = findVersionTaggedJsonFile($outputFile);

if ($previousJsonFile) {
  printLine('Previous version file: '.$previousJsonFile);
}

$versionInfo = $previousJsonFile ? parseVersion($previousJsonFile) : parseVersion('0.0.0');

printLine('Current version: '.implode('.', $versionInfo));

$previousDictionaryJson = null;

$jsonContent = dataToJson($dictionary);

if (file_exists($previousJsonFile)) {
  $previousDictionaryJson = nullIfEmptyString(file_get_contents($previousJsonFile));

  if (md5($previousDictionaryJson) === md5($jsonContent)) {
    exitWithMessage('All up to date.');
  }

  $previousDictionary = $previousDictionaryJson ? jsonToData($previousDictionaryJson) : null;

  if (!$previousDictionary) {
    exitWithErrorMessage('Last dictionary data is corrpt.');
  }

  // Compare languages
  printLine('Comparing...');

  $dictionaryLanguageCodes = array_keys($dictionary);
  $previousDictionaryLanguageCodes = array_keys($previousDictionary);

  $majorBump = 0;
  $minorBump = 0;
  $patchBump = 0;

  // Only removal produces an array with any elements:
  // E.g.: array_diff(['en', 'sk'], ['en']); >>> ["sk"]
  // E.g.: array_diff(['en', 'sk'], ['en', 'sk', 'cz']); >>> []
  if (count(array_diff($previousDictionaryLanguageCodes, $dictionaryLanguageCodes)) === 0) {
    // No new language added:
    $newLanguages = array_diff($dictionaryLanguageCodes, $previousDictionaryLanguageCodes);

    if (count($newLanguages) === 0) {
      $firstLanguage = $previousDictionaryLanguageCodes[0];

      $localisationKeys = array_keys($dictionary[$firstLanguage]);
      $lastLocalisationKeys = array_keys($previousDictionary[$firstLanguage]);

      $removedLocalisationKeys = array_diff($lastLocalisationKeys, $localisationKeys);
      $removedLocalisationKeysCount = count($removedLocalisationKeys);

      if ($removedLocalisationKeysCount > 0) {
        printLine('Breking change: Removing '. $removedLocalisationKeysCount .' keys');
        $minorBump = $minorBump + 1;
      } else {
        $patchBump = $patchBump + 1;
      }
    } else {
      printLine('New languages added: '. implode(', ', $newLanguages));
      $patchBump = $patchBump + 1;
    }
  }

  $newVersion = bumpVersion($versionInfo, $majorBump, $minorBump, $patchBump);
} else {
  $newVersion = bumpVersion($versionInfo, 0, 0, 1);
}

$newJsonFile = stripExtension($outputFile).'.v'.$newVersion.'.json';

putJsonContent($newJsonFile, $dictionary);

if (file_exists($previousJsonFile)) {
  unlink($previousJsonFile);
}

$content = str_replace(
  '/* version */',
  $newVersion,
  str_replace(
    '{/* dictionary */}',
    $jsonContent,
    $template
  )
);

if (file_put_contents($outputFile, $content)) {
  printLine("SUCCESS: Dictionary written to ${outputFile}");
} else {
  exitWithErrorMessage("Failed to write to ${outputFile}");
}