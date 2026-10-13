// Read local Xcode service settings without logging configuration values.
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const settingsPath = path.join(__dirname, '../ios/Flutter/LocalServices.xcconfig');
const names = [
  'GOOGLE_MAPS_IOS_API_KEY',
  'GOOGLE_SIGN_IN_IOS_CLIENT_ID',
  'GOOGLE_SIGN_IN_REVERSED_CLIENT_ID',
];

function validate(text) {
  const values = {};
  const issues = [];
  for (const line of text.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('//')) continue;
    const match = trimmed.match(/^([A-Z_]+)\s*=\s*([^\s]+)?\s*$/);
    if (!match || !names.includes(match[1])) {
      issues.push('Use only the three plain assignments in LocalServices.xcconfig.example; content withheld.');
      continue;
    }
    if (Object.hasOwn(values, match[1])) issues.push(`${match[1]} has duplicate assignments; value withheld.`);
    values[match[1]] = match[2] || '';
  }
  for (const name of names) {
    const value = values[name] || '';
    if (!value || /\$[({]|[<>]|^(YOUR_|REPLACE_|EXAMPLE_|PLACEHOLDER)/i.test(value)) {
      issues.push(`${name} is unset or a placeholder; value withheld.`);
    }
  }
  const key = values[names[0]] || '';
  const client = values[names[1]] || '';
  const scheme = values[names[2]] || '';
  if (key && !/^AIza[A-Za-z0-9_-]{35}$/.test(key)) issues.push('Maps key format is invalid; value withheld.');
  const clientMatch = client.match(/^([A-Za-z0-9_-]+)\.apps\.googleusercontent\.com$/);
  if (client && !clientMatch) issues.push('iOS OAuth client ID format is invalid; value withheld.');
  if (clientMatch && scheme !== `com.googleusercontent.apps.${clientMatch[1]}`) {
    issues.push('Google Sign-In reversed client ID does not match its client ID; values withheld.');
  }
  return [...new Set(issues)];
}

function validateBuiltPlist(info, text) {
  const issues = validate(text);
  if (issues.length) return issues;
  const expected = names.map(name => text.match(new RegExp(`^\\s*${name}\\s*=\\s*(\\S+)\\s*$`, 'm'))[1]);
  if (info.CFBundleIdentifier !== 'com.mekidoapps.vendingnavi') issues.push('Built Bundle ID does not match the reviewed iOS identity.');
  if (info.GoogleMapsAPIKey !== expected[0]) issues.push('Built Maps setting differs from local configuration; values withheld.');
  if (info.GIDClientID !== expected[1]) issues.push('Built OAuth client differs from local configuration; values withheld.');
  const types = Array.isArray(info.CFBundleURLTypes) ? info.CFBundleURLTypes : [];
  const schemes = types.flatMap(type => Array.isArray(type.CFBundleURLSchemes) ? type.CFBundleURLSchemes : []);
  if (!schemes.includes(expected[2])) issues.push('Built Google Sign-In URL scheme is missing or mismatched; values withheld.');
  return issues;
}

if (require.main === module) {
  const args = process.argv.slice(2);
  if (args.length && (args.length !== 2 || args[0] !== '--built-plist')) {
    console.error('Usage: node tool/check_ios_runtime_config.cjs [--built-plist path/to/Runner.app/Info.plist]');
    process.exit(1);
  }
  if (!fs.existsSync(settingsPath)) {
    console.error('iOS runtime configuration is missing. Copy LocalServices.xcconfig.example to LocalServices.xcconfig and fill confirmed values. Compile-only builds do not need this file.');
    process.exitCode = 1;
  } else {
    const text = fs.readFileSync(settingsPath, 'utf8');
    let issues = validate(text);
    if (!issues.length && args.length) {
      try {
        const json = execFileSync('/usr/bin/plutil', ['-convert', 'json', '-o', '-', args[1]], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
        issues = validateBuiltPlist(JSON.parse(json), text);
      } catch {
        issues = ['Built Info.plist could not be checked. Use this option on macOS with a built app; configuration contents withheld.'];
      }
    }
    for (const issue of issues) console.error(issue);
    if (issues.length) process.exitCode = 1;
    else console.log('Local iOS service configuration syntax and OAuth pairing pass. Cloud validity, restrictions, built Info.plist, signing and App Check still require verification.');
  }
}

module.exports = { validate, validateBuiltPlist };
