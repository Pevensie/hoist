# 🏴‍☠️ Hoist

[![Package Version](https://img.shields.io/hexpm/v/hoist)](https://hex.pm/packages/hoist)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/hoist/)

Hoist the flags and say arg, because it's time to sail the high seas!

Hoist is a [POSIX](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap12.html)- and
[CLIG](https://clig.dev/)-compliant command line option parser written in pure Gleam.

The library is primarily designed as a base for other Gleam CLI frameworks and libraries to be
built on top of, and doesn't provide high-level features like flag validation, help text, or
any sort of command structure. That said, it's definitely enough if all you need is simple
CLI tooling.

Hoist can parse:

- Positional arguments: `user create`
- Flags with values: `--name Lucy` (all values are represented as `String`s)
- Flags for toggling: `--dry-run`
- Counted flags: `--verbose --verbose`
- Short flags: `-vvdn Lucy`
- Flag aliases: `--first-name Lucy`
- Weird old Linux conventions: `-nLucy --surname=Star -c=20`

## Getting Started

Install Hoist:

```sh
gleam add hoist
```

Use `hoist.new_flag("flag-name")` to create a new flag, and pass a list of flags
and command arguments to `hoist.parse`.

```gleam
import argv
import hoist

pub fn main() {
  let flag_specs = [
    hoist.new_flag("target")
      |> hoist.with_short_alias("t"),
    hoist.new_flag("cannons")
      |> hoist.with_short_alias("c"),
    hoist.new_flag("verbose")
      |> hoist.with_short_alias("v")
      |> hoist.as_count,
    hoist.new_flag("dry-run")
      |> hoist.with_short_alias("d")
      |> hoist.as_toggle,
  ]

  let assert Ok(flags) = hoist.validate_flag_specs(flag_specs)
  let assert Ok(args) = hoist.parse(argv.load().arguments, flag_specs)

  // $ gleam dev attack --target "The Black Pearl" -vvd --cannons 12
  //
  // Args(
  //   arguments: ["attack"],
  //   flags: [
  //     ValueFlag("target", "The Black Pearl"),
  //     CountFlag("verbose", 2),
  //     ToggleFlag("dry-run"),
  //     ValueFlag("cannons", "12"),
  //   ],
  // )
}
```

The above example can be run using `gleam dev`.

Further documentation can be found at <https://hexdocs.pm/hoist>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
