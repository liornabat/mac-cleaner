#!/usr/bin/env python3
"""Read, validate, or increment the single app/repository version source."""
import argparse
import json
import re
from pathlib import Path

SOURCE = Path(__file__).resolve().parent.parent / 'Sources/MacClean/Resources/AppVersion.json'


def read_version(path=SOURCE):
    value = json.loads(path.read_text())
    if not isinstance(value, dict) or not isinstance(value.get('version'), str):
        raise ValueError('Version metadata must contain a version string and integer build.')
    if not re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)', value.get('version', '')):
        raise ValueError('Version must contain three nonnegative numbers, such as 0.1.0.')
    if type(value.get('build')) is not int or not 1 <= value['build'] <= 9999:
        raise ValueError('Build must be an integer between 1 and 9999.')
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['version', 'build', 'tag', 'validate', 'bump'])
    parser.add_argument('increment', nargs='?', choices=['major', 'minor', 'patch'])
    parser.add_argument('--expect-tag')
    args = parser.parse_args()
    try:
        value = read_version()
        if args.expect_tag and args.expect_tag != 'v' + value['version']:
            raise ValueError(f"Tag {args.expect_tag} does not match app version v{value['version']}.")
        if args.command == 'bump':
            if not args.increment:
                parser.error('bump needs major, minor, or patch')
            parts = list(map(int, value['version'].split('.')))
            index = ['major', 'minor', 'patch'].index(args.increment)
            parts[index] += 1
            for following in range(index + 1, 3):
                parts[following] = 0
            value = {'version': '.'.join(map(str, parts)), 'build': value['build'] + 1}
            if value['build'] > 9999:
                raise ValueError('Build exceeds the supported range.')
            SOURCE.write_text(json.dumps(value, indent=2) + '\n')
            print(f"Version {value['version']}, build {value['build']}. Commit this change before tagging.")
        elif args.command == 'version':
            print(value['version'])
        elif args.command == 'build':
            print(value['build'])
        elif args.command == 'tag':
            print('v' + value['version'])
        else:
            print(f"Version {value['version']}, build {value['build']} validated.")
    except (ValueError, OSError, json.JSONDecodeError) as error:
        parser.exit(1, str(error) + '\n')


if __name__ == '__main__':
    main()
