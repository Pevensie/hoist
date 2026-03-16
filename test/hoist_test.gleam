import gleam/list
import gleeunit
import hoist

pub fn main() {
  gleeunit.main()
}

pub fn parses_empty_args_test() {
  let assert Ok(validated_flag_specs) = hoist.validate_flag_specs([])
  let assert Ok(parsed) = hoist.parse([], validated_flag_specs)
  assert parsed == hoist.Args(arguments: [], flags: [])
}

// Positionals

pub fn parses_only_positionals_test() {
  let assert Ok(validated_flag_specs) = hoist.validate_flag_specs([])
  let assert Ok(parsed) =
    hoist.parse(["wibble", "wobble"], validated_flag_specs)
  assert parsed == hoist.Args(arguments: ["wibble", "wobble"], flags: [])
}

pub fn parse_bare_single_tack_as_positional_test() {
  let assert Ok(validated_flag_specs) = hoist.validate_flag_specs([])
  let assert Ok(parsed) =
    hoist.parse(["wibble", "-", "wobble"], validated_flag_specs)
  assert parsed == hoist.Args(arguments: ["wibble", "-", "wobble"], flags: [])
}

pub fn parses_bare_double_tack_with_nothing_after_test() {
  let assert Ok(validated_flag_specs) = hoist.validate_flag_specs([])
  let assert Ok(parsed) = hoist.parse(["wibble", "--"], validated_flag_specs)
  assert parsed == hoist.Args(arguments: ["wibble"], flags: [])
}

pub fn parses_all_args_after_bare_double_tack_as_positional_test() {
  let assert Ok(validated_flag_specs) = hoist.validate_flag_specs([])
  let assert Ok(parsed) =
    hoist.parse(
      ["wibble", "--", "--name", "lucy", "wobble"],
      validated_flag_specs,
    )
  assert parsed
    == hoist.Args(arguments: ["wibble", "--name", "lucy", "wobble"], flags: [])
}

// Long value flags

pub fn parses_long_flag_test() {
  let flags = [hoist.new_flag("name")]
  let assert Ok(validated_flag_specs) = hoist.validate_flag_specs(flags)
  let assert Ok(parsed) = hoist.parse(["--name", "Lucy"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ValueFlag(name: "name", value: "Lucy"),
    ])
}

pub fn parses_long_flag_with_equals_test() {
  let flags = [hoist.new_flag("name")]
  let assert Ok(validated_flag_specs) = hoist.validate_flag_specs(flags)
  let assert Ok(parsed) = hoist.parse(["--name=Lucy"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ValueFlag(name: "name", value: "Lucy"),
    ])
}

pub fn parses_flag_value_containing_equals_test() {
  let flags = [hoist.new_flag("name")]
  let assert Ok(validated_flag_specs) = hoist.validate_flag_specs(flags)
  let assert Ok(parsed) = hoist.parse(["--name=a=b"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ValueFlag(name: "name", value: "a=b"),
    ])
}

pub fn fails_long_flag_with_no_argument_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([hoist.new_flag("name")])
  let assert Error(hoist.ValueNotProvided("name")) =
    hoist.parse(["--name"], validated_flag_specs)
}

pub fn parses_long_alias_test() {
  let flags = [hoist.new_flag("name") |> hoist.with_long_alias("surname")]
  let assert Ok(validated_flag_specs) = hoist.validate_flag_specs(flags)
  let assert Ok(parsed) =
    hoist.parse(["--surname", "Lucy"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ValueFlag(name: "name", value: "Lucy"),
    ])
}

pub fn parses_long_alias_resolves_to_canonical_name_test() {
  let flags = [hoist.new_flag("name") |> hoist.with_long_alias("surname")]
  let assert Ok(validated_flag_specs) = hoist.validate_flag_specs(flags)
  let assert Ok(parsed) = hoist.parse(["--surname=Lucy"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ValueFlag(name: "name", value: "Lucy"),
    ])
}

pub fn fails_unknown_flag_test() {
  let assert Ok(validated_flag_specs) = hoist.validate_flag_specs([])
  let assert Error(hoist.UnknownFlag("name")) =
    hoist.parse(["--name"], validated_flag_specs)
}

pub fn parses_duplicate_value_flag_keeps_all_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("name") |> hoist.with_short_alias("n"),
    ])
  let assert Ok(parsed) =
    hoist.parse(["--name", "A", "--name", "B", "-n", "C"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ValueFlag(name: "name", value: "A"),
      hoist.ValueFlag(name: "name", value: "B"),
      hoist.ValueFlag(name: "name", value: "C"),
    ])
}

pub fn parses_mixed_long_flags_and_positionals_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([hoist.new_flag("name")])
  let assert Ok(parsed) =
    hoist.parse(["wibble", "--name", "Lucy", "wobble"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: ["wibble", "wobble"], flags: [
      hoist.ValueFlag(name: "name", value: "Lucy"),
    ])
}

pub fn parses_long_toggle_flags_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([hoist.new_flag("verbose") |> hoist.as_toggle])
  let assert Ok(parsed) = hoist.parse(["--verbose"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ToggleFlag(name: "verbose"),
    ])
}

pub fn parses_args_after_long_toggle_flag_as_positional_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([hoist.new_flag("verbose") |> hoist.as_toggle])
  let assert Ok(parsed) =
    hoist.parse(["--verbose", "wobble"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: ["wobble"], flags: [
      hoist.ToggleFlag(name: "verbose"),
    ])
}

pub fn parses_duplicate_toggle_flag_deduplicates_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([hoist.new_flag("verbose") |> hoist.as_toggle])
  let assert Ok(parsed) =
    hoist.parse(["--verbose", "--verbose"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ToggleFlag(name: "verbose"),
    ])
}

pub fn fails_long_toggle_flag_with_value_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([hoist.new_flag("verbose") |> hoist.as_toggle])
  let assert Error(hoist.ValueNotSupported(flag: "verbose", given: "wobble")) =
    hoist.parse(["--verbose=wobble"], validated_flag_specs)
}

pub fn parses_mixed_long_toggle_flags_and_positionals_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([hoist.new_flag("verbose") |> hoist.as_toggle])
  let assert Ok(parsed) =
    hoist.parse(["wibble", "--verbose", "wobble"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: ["wibble", "wobble"], flags: [
      hoist.ToggleFlag(name: "verbose"),
    ])
}

pub fn parses_long_count_flags_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([hoist.new_flag("verbose") |> hoist.as_count])
  let assert Ok(parsed) = hoist.parse(["--verbose"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.CountFlag(name: "verbose", count: 1),
    ])
}

pub fn parses_multiple_long_count_flags_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([hoist.new_flag("verbose") |> hoist.as_count])
  let assert Ok(parsed) =
    hoist.parse(["--verbose", "--verbose", "--verbose"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.CountFlag(name: "verbose", count: 3),
    ])
}

pub fn parses_args_after_long_count_flag_as_positional_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([hoist.new_flag("verbose") |> hoist.as_count])
  let assert Ok(parsed) =
    hoist.parse(["--verbose", "wobble"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: ["wobble"], flags: [
      hoist.CountFlag(name: "verbose", count: 1),
    ])
}

pub fn fails_long_count_flag_with_value_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([hoist.new_flag("verbose") |> hoist.as_count])
  let assert Error(hoist.ValueNotSupported(flag: "verbose", given: "wobble")) =
    hoist.parse(["--verbose=wobble"], validated_flag_specs)
}

pub fn parses_mixed_long_count_flags_and_positionals_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([hoist.new_flag("verbose") |> hoist.as_count])
  let assert Ok(parsed) =
    hoist.parse(["wibble", "--verbose", "wobble"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: ["wibble", "wobble"], flags: [
      hoist.CountFlag(name: "verbose", count: 1),
    ])
}

pub fn parses_short_flag_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("name") |> hoist.with_short_alias("n"),
    ])
  let assert Ok(parsed) = hoist.parse(["-n", "Lucy"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ValueFlag(name: "name", value: "Lucy"),
    ])
}

pub fn parses_short_flag_with_equals_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("name") |> hoist.with_short_alias("n"),
    ])
  let assert Ok(parsed) = hoist.parse(["-n=Lucy"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ValueFlag(name: "name", value: "Lucy"),
    ])
}

pub fn parses_short_flag_value_attached_no_space_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("name") |> hoist.with_short_alias("n"),
    ])
  let assert Ok(parsed) = hoist.parse(["-nLucy"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ValueFlag(name: "name", value: "Lucy"),
    ])
}

pub fn fails_unknown_short_flag_test() {
  let assert Ok(validated_flag_specs) = hoist.validate_flag_specs([])
  let assert Error(hoist.UnknownFlag("x")) =
    hoist.parse(["-x"], validated_flag_specs)
}

pub fn fails_short_value_flag_with_no_argument_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("name") |> hoist.with_short_alias("n"),
    ])
  let assert Error(hoist.ValueNotProvided("n")) =
    hoist.parse(["-n"], validated_flag_specs)
}

pub fn parses_short_toggle_flag_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("verbose")
      |> hoist.with_short_alias("v")
      |> hoist.as_toggle,
    ])
  let assert Ok(parsed) = hoist.parse(["-v"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ToggleFlag(name: "verbose"),
    ])
}

pub fn parses_short_count_flag_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("verbose") |> hoist.with_short_alias("v") |> hoist.as_count,
    ])
  let assert Ok(parsed) = hoist.parse(["-v"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.CountFlag(name: "verbose", count: 1),
    ])
}

pub fn parses_combined_short_flags_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("name") |> hoist.with_short_alias("n"),
      hoist.new_flag("verbose") |> hoist.with_short_alias("v") |> hoist.as_count,
      hoist.new_flag("dry-run")
        |> hoist.with_short_alias("d")
        |> hoist.as_toggle,
    ])
  let assert Ok(parsed) = hoist.parse(["-vdn", "Lucy"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.CountFlag(name: "verbose", count: 1),
      hoist.ToggleFlag("dry-run"),
      hoist.ValueFlag("name", "Lucy"),
    ])
}

pub fn parses_combined_short_count_flags_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("verbose") |> hoist.with_short_alias("v") |> hoist.as_count,
    ])
  let assert Ok(parsed) = hoist.parse(["-vvv"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.CountFlag(name: "verbose", count: 3),
    ])
}

pub fn parses_combined_short_toggle_flags_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("verbose")
        |> hoist.with_short_alias("v")
        |> hoist.as_toggle,
      hoist.new_flag("dry-run")
        |> hoist.with_short_alias("d")
        |> hoist.as_toggle,
    ])
  let assert Ok(parsed) = hoist.parse(["-vd"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ToggleFlag(name: "verbose"),
      hoist.ToggleFlag(name: "dry-run"),
    ])
}

pub fn parses_combined_short_value_flag_consumes_rest_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("name") |> hoist.with_short_alias("n"),
      hoist.new_flag("verbose")
        |> hoist.with_short_alias("v")
        |> hoist.as_toggle,
    ])
  let assert Ok(parsed) = hoist.parse(["-nv"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ValueFlag(name: "name", value: "v"),
    ])
}

pub fn parses_combined_short_flags_value_attached_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("verbose") |> hoist.with_short_alias("v") |> hoist.as_count,
      hoist.new_flag("dry-run")
        |> hoist.with_short_alias("d")
        |> hoist.as_toggle,
      hoist.new_flag("name") |> hoist.with_short_alias("n"),
    ])
  let assert Ok(parsed) = hoist.parse(["-vdnLucy"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.CountFlag("verbose", 1),
      hoist.ToggleFlag("dry-run"),
      hoist.ValueFlag("name", "Lucy"),
    ])
}

pub fn fails_short_toggle_with_equals_value_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("verbose")
      |> hoist.with_short_alias("v")
      |> hoist.as_toggle,
    ])
  let assert Error(hoist.ValueNotSupported(flag: "v", given: "foo")) =
    hoist.parse(["-v=foo"], validated_flag_specs)
}

pub fn fails_short_count_with_equals_value_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("verbose") |> hoist.with_short_alias("v") |> hoist.as_count,
    ])
  let assert Error(hoist.ValueNotSupported(flag: "v", given: "foo")) =
    hoist.parse(["-v=foo"], validated_flag_specs)
}

pub fn parses_mixed_short_and_long_flags_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("verbose")
        |> hoist.with_short_alias("v")
        |> hoist.as_toggle,
      hoist.new_flag("name"),
    ])
  let assert Ok(parsed) =
    hoist.parse(["-v", "--name", "Lucy"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ToggleFlag(name: "verbose"),
      hoist.ValueFlag(name: "name", value: "Lucy"),
    ])
}

// --- validate_flag_specs error tests ---

pub fn validate_empty_flag_name_test() {
  let assert Error(errors) = hoist.validate_flag_specs([hoist.new_flag("")])
  let assert [hoist.EmptyName(_)] = errors
}

pub fn validate_invalid_flag_name_test() {
  let assert Error(errors) = hoist.validate_flag_specs([hoist.new_flag("-bad")])
  let assert [hoist.InvalidNameOrAlias("-bad", _)] = errors
}

pub fn validate_flag_name_with_spaces_test() {
  let assert Error(errors) =
    hoist.validate_flag_specs([hoist.new_flag("has space")])
  let assert [hoist.InvalidNameOrAlias("has space", _)] = errors
}

pub fn validate_invalid_long_alias_test() {
  let assert Error(errors) =
    hoist.validate_flag_specs([
      hoist.new_flag("name") |> hoist.with_long_alias("--bad"),
    ])
  let assert [hoist.InvalidNameOrAlias("--bad", _)] = errors
}

pub fn validate_empty_long_alias_test() {
  let assert Error(errors) =
    hoist.validate_flag_specs([
      hoist.new_flag("name") |> hoist.with_long_alias(""),
    ])
  let assert [hoist.EmptyName(_)] = errors
}

pub fn validate_invalid_short_alias_multichar_test() {
  let assert Error(errors) =
    hoist.validate_flag_specs([
      hoist.new_flag("name") |> hoist.with_short_alias("ab"),
    ])
  let assert [hoist.InvalidShortAlias("ab", _)] = errors
}

pub fn validate_invalid_short_alias_special_char_test() {
  let assert Error(errors) =
    hoist.validate_flag_specs([
      hoist.new_flag("name") |> hoist.with_short_alias("-"),
    ])
  let assert [hoist.InvalidShortAlias("-", _)] = errors
}

pub fn validate_empty_short_alias_test() {
  let assert Error(errors) =
    hoist.validate_flag_specs([
      hoist.new_flag("name") |> hoist.with_short_alias(""),
    ])
  let assert [hoist.EmptyName(_)] = errors
}

pub fn validate_multiple_errors_test() {
  let assert Error(errors) =
    hoist.validate_flag_specs([
      hoist.new_flag(""),
      hoist.new_flag("-bad"),
    ])
  assert list.length(errors) == 2
}

pub fn validate_valid_flag_names_test() {
  let assert Ok(_) =
    hoist.validate_flag_specs([
      hoist.new_flag("name"),
      hoist.new_flag("dry-run"),
      hoist.new_flag("output_dir"),
      hoist.new_flag("v2"),
    ])
}

// --- parse_with_hook tests ---

pub fn parse_with_hook_swaps_flags_test() {
  let initial_flags = [hoist.new_flag("global") |> hoist.with_short_alias("g")]
  let sub_flags = [hoist.new_flag("file") |> hoist.with_short_alias("f")]

  let assert Ok(initial_validated) = hoist.validate_flag_specs(initial_flags)
  let assert Ok(sub_validated) = hoist.validate_flag_specs(sub_flags)

  let assert #(True, Ok(parsed)) =
    hoist.parse_with_hook(
      ["--global", "gval", "sub", "--file", "test.txt"],
      initial_validated,
      False,
      fn(seen_sub, arg, _args, flags) {
        case seen_sub, arg {
          False, "sub" -> Ok(#(True, sub_validated))
          _, _ -> Ok(#(seen_sub, flags))
        }
      },
    )

  assert parsed
    == hoist.Args(arguments: ["sub"], flags: [
      hoist.ValueFlag(name: "global", value: "gval"),
      hoist.ValueFlag(name: "file", value: "test.txt"),
    ])
}

pub fn parse_with_hook_error_test() {
  let assert Ok(validated) = hoist.validate_flag_specs([])

  let assert #(Nil, Error(_)) =
    hoist.parse_with_hook(
      ["allowed", "rejected"],
      validated,
      Nil,
      fn(_, arg, _, flags) {
        case arg {
          "rejected" -> Error(Nil)
          _ -> Ok(#(Nil, flags))
        }
      },
    )
}

// --- Short flag edge cases ---

pub fn fails_unknown_short_flag_in_combined_group_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("verbose")
      |> hoist.with_short_alias("v")
      |> hoist.as_toggle,
    ])
  let assert Error(hoist.UnknownFlag("x")) =
    hoist.parse(["-vx"], validated_flag_specs)
}

pub fn parses_separate_short_count_flags_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("verbose") |> hoist.with_short_alias("v") |> hoist.as_count,
    ])
  let assert Ok(parsed) = hoist.parse(["-v", "-v", "-v"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.CountFlag(name: "verbose", count: 3),
    ])
}

pub fn parses_short_value_flag_equals_containing_equals_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("name") |> hoist.with_short_alias("n"),
    ])
  let assert Ok(parsed) = hoist.parse(["-n=a=b"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ValueFlag(name: "name", value: "a=b"),
    ])
}

// --- Alias + kind combos ---

pub fn parses_toggle_flag_via_long_alias_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("dry-run")
      |> hoist.with_long_alias("dryrun")
      |> hoist.as_toggle,
    ])
  let assert Ok(parsed) = hoist.parse(["--dryrun"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.ToggleFlag(name: "dry-run"),
    ])
}

pub fn parses_count_flag_via_long_alias_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("verbose")
      |> hoist.with_long_alias("verb")
      |> hoist.as_count,
    ])
  let assert Ok(parsed) =
    hoist.parse(["--verb", "--verb"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.CountFlag(name: "verbose", count: 2),
    ])
}

pub fn parses_count_flag_mixed_long_and_short_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("verbose")
      |> hoist.with_short_alias("v")
      |> hoist.as_count,
    ])
  let assert Ok(parsed) =
    hoist.parse(["--verbose", "-v", "-vv"], validated_flag_specs)
  assert parsed
    == hoist.Args(arguments: [], flags: [
      hoist.CountFlag(name: "verbose", count: 4),
    ])
}

pub fn everything_test() {
  let assert Ok(validated_flag_specs) =
    hoist.validate_flag_specs([
      hoist.new_flag("verbose")
        |> hoist.with_short_alias("v")
        |> hoist.as_count,
      hoist.new_flag("foo")
        |> hoist.with_short_alias("f"),
      hoist.new_flag("bar") |> hoist.with_short_alias("b"),
      hoist.new_flag("wibble")
        |> hoist.with_long_alias("wib"),
      hoist.new_flag("dry-run")
        |> hoist.with_short_alias("d")
        |> hoist.as_toggle,
    ])
  let assert Ok(parsed) =
    hoist.parse(
      [
        "thing",
        "-vv",
        "args",
        "in",
        "the",
        "-",
        "-fbar",
        "-db",
        "baz",
        "middle",
        "--wib=wobble",
        "-dv",
        "more",
        "--",
        "--verbose",
        "here",
      ],
      validated_flag_specs,
    )

  assert parsed
    == hoist.Args(
      arguments: [
        "thing",
        "args",
        "in",
        "the",
        "-",
        "middle",
        "more",
        "--verbose",
        "here",
      ],
      flags: [
        hoist.ValueFlag("foo", "bar"),
        hoist.ValueFlag("bar", "baz"),
        hoist.ValueFlag("wibble", "wobble"),
        hoist.ToggleFlag("dry-run"),
        hoist.CountFlag("verbose", 3),
      ],
    )
}

pub fn parse_with_hook_and_custom_error() {
  let assert Ok(validated_flag_specs) = hoist.validate_flag_specs([])
  assert #(Nil, Error(hoist.CustomError(1)))
    == hoist.parse_with_hook(
      ["hello"],
      validated_flag_specs,
      Nil,
      fn(_, _, _, _) { Error(1) },
    )
}

pub fn parse_with_hook_returns_updated_state_on_error() {
  let assert Ok(validated_flag_specs) = hoist.validate_flag_specs([])

  assert #(1, Error(hoist.CustomError("unknown command")))
    == hoist.parse_with_hook(
      ["first", "second"],
      validated_flag_specs,
      0,
      fn(_, argument, _, specs) {
        case argument {
          "first" -> Ok(#(1, specs))
          "second" -> Error("unknown command")
          _ -> panic
        }
      },
    )
}

pub fn parse_with_hook_returns_updated_state_on_success() {
  let assert Ok(validated_flag_specs) = hoist.validate_flag_specs([])

  let assert #(2, Ok(args)) =
    hoist.parse_with_hook(
      ["first", "second"],
      validated_flag_specs,
      0,
      fn(acc, argument, _, specs) {
        case argument {
          "first" -> Ok(#(acc + 1, specs))
          "second" -> Ok(#(acc + 1, specs))
          _ -> panic
        }
      },
    )

  assert hoist.Args(["first", "second"], flags: []) == args
}
