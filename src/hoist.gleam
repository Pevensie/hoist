import gleam/dict
import gleam/list
import gleam/regexp
import gleam/result
import gleam/set
import gleam/string

pub type ParseError(error) {
  /// A flag was encountered that was not defined upfront.
  UnknownFlag(String)
  /// A value was not defined for a value-type flag.
  ValueNotProvided(flag: String)
  /// A value was passed to a count-kind or toggle-kind flag.
  ValueNotSupported(flag: String, given: String)
  /// A user provided error.
  CustomError(value: error)
}

fn replace_error_flag_name(error: ParseError(error), flag_name: String) {
  case error {
    CustomError(_) | UnknownFlag(_) -> error
    ValueNotProvided(_) -> ValueNotProvided(flag_name)
    ValueNotSupported(given:, ..) -> ValueNotSupported(flag: flag_name, given:)
  }
}

/// A type defining the behaviour of a flag.
type FlagKind {
  /// Flag takes a value
  ValueKind
  /// Flag is a boolean toggle
  ToggleKind
  /// Flag is a count
  CountKind
}

/// A specification for a flag in Hoist.
pub opaque type FlagSpec {
  FlagSpec(
    name: String,
    aliases: set.Set(String),
    short: set.Set(String),
    kind: FlagKind,
  )
}

/// A collection of validated flag specs.
pub opaque type ValidatedFlagSpecs {
  ValidatedFlagSpecs(
    long_flags: dict.Dict(String, FlagSpec),
    short_flags: dict.Dict(String, FlagSpec),
  )
}

/// Creates a new flag with the given long name, e.g. `--name`. Case sensitive.
pub fn new_flag(name: String) -> FlagSpec {
  FlagSpec(name:, aliases: set.new(), short: set.new(), kind: ValueKind)
}

/// Adds a long alias for a command, e.g. `--name, --first-name`.
///
/// A flag can have multiple long aliases. These are stored in a
/// set and will be deduplicated. Case sensitive.
pub fn with_long_alias(flag: FlagSpec, alias: String) -> FlagSpec {
  FlagSpec(..flag, aliases: set.insert(flag.aliases, alias))
}

/// Adds a short alias for a command, e.g. `--name, -n`.
///
/// A flag can have multiple short aliases. These are stored in a
/// set and will be deduplicated. Case sensitive.
pub fn with_short_alias(flag: FlagSpec, short: String) -> FlagSpec {
  FlagSpec(..flag, short: set.insert(flag.short, short))
}

/// Designates this flag as a toggle-kind flag. Generally used to enable
/// or disable an option, e.g. `--colour`, `--no-colour`. Does not
/// receive a value.
pub fn as_toggle(flag: FlagSpec) -> FlagSpec {
  FlagSpec(..flag, kind: ToggleKind)
}

/// Designates this flag as a count-kind flag. Often used for verbosity levels,
/// e.g. `-vvv` would have a count of 3.
pub fn as_count(flag: FlagSpec) -> FlagSpec {
  FlagSpec(..flag, kind: CountKind)
}

/// Errors that occur when building flags
pub type FlagSpecValidationError {
  EmptyName(FlagSpec)
  InvalidNameOrAlias(name: String, flag_spec: FlagSpec)
  InvalidShortAlias(short: String, flag_spec: FlagSpec)
}

fn flag_name_validation_regex() -> regexp.Regexp {
  let assert Ok(pattern) =
    regexp.compile(
      "^[a-zA-Z0-9][a-zA-Z0-9_-]*$",
      regexp.Options(case_insensitive: False, multi_line: False),
    )

  pattern
}

fn validate_single_flag_spec(
  flag_spec: FlagSpec,
  validation_regex: regexp.Regexp,
) -> Result(FlagSpec, FlagSpecValidationError) {
  let all_long_names = [flag_spec.name, ..set.to_list(flag_spec.aliases)]

  let long_name_validation_result =
    list.try_each(all_long_names, fn(name) {
      case name {
        "" -> Error(EmptyName(flag_spec))
        name -> {
          case regexp.check(validation_regex, name) {
            True -> Ok(Nil)
            False -> Error(InvalidNameOrAlias(name, flag_spec))
          }
        }
      }
    })

  use _ <- result.try(long_name_validation_result)

  let short_name_validation_result =
    list.try_each(set.to_list(flag_spec.short), fn(short) {
      case string.length(short) {
        0 -> Error(EmptyName(flag_spec))
        1 -> {
          case regexp.check(validation_regex, short) {
            True -> Ok(Nil)
            False -> Error(InvalidShortAlias(short, flag_spec))
          }
        }
        _ -> Error(InvalidShortAlias(short, flag_spec))
      }
    })

  use _ <- result.try(short_name_validation_result)

  Ok(flag_spec)
}

/// Validates flag specs
pub fn validate_flag_specs(
  flags: List(FlagSpec),
) -> Result(ValidatedFlagSpecs, List(FlagSpecValidationError)) {
  let #(_, flag_validation_errors) =
    list.map(flags, validate_single_flag_spec(_, flag_name_validation_regex()))
    |> result.partition

  case flag_validation_errors {
    [] -> {
      let #(long_flags, short_flags) =
        list.fold(flags, #(dict.new(), dict.new()), fn(dicts, flag) {
          let #(lf, stl) = dicts

          let lf = dict.insert(lf, flag.name, flag)
          let lf =
            set.fold(flag.aliases, lf, fn(curr, alias) {
              dict.insert(curr, alias, flag)
            })

          let stl =
            set.fold(flag.short, stl, fn(curr, short) {
              dict.insert(curr, short, flag)
            })

          #(lf, stl)
        })

      Ok(ValidatedFlagSpecs(long_flags:, short_flags:))
    }

    errors -> Error(errors)
  }
}

/// A parsed flag.
pub type Flag {
  /// A flag with a value, e.g. from `--name=val`, `--name val`, `-n val` or `-nval`.
  ValueFlag(name: String, value: String)
  /// A flag toggle (bool), e.g. from `--dry-run` or `-d`.
  ToggleFlag(name: String)
  /// A flag count, e.g. from `-vvv`.
  CountFlag(name: String, count: Int)
}

/// The result of parsing CLI arguments.
pub type Args {
  Args(
    /// Positional arguments.
    arguments: List(String),
    /// Parsed flags.
    flags: List(Flag),
  )
}

/// Parses positional args and flags from a list of args.
///
/// Note: this function does not sanitise input in any way. If you require
/// sanitisation, e.g. removal of whitespace-only arguments, you must handle
/// that yourself.
pub fn parse(
  input: List(String),
  flags: ValidatedFlagSpecs,
) -> Result(Args, ParseError(error)) {
  let #(_hook_state, outcome) =
    parse_with_hook(input, flags, Nil, fn(state, _, _, flags) {
      Ok(#(state, flags))
    })

  outcome
}

/// Similar to [`parse`](#parse) but allows passing a custom hook that gets called
/// after a positional argument is parsed.
///
/// The hook accepts the current hook state, the most recent positional argument,
/// the currently parsed arguments and flags, and the available flag specs.
///
/// The hook can return a new set of flags to be used for parsing the next argument,
/// along with a new state value.
///
/// Useful when the flags available for parsing depend on the value of a previous
/// positional argument.
pub fn parse_with_hook(
  input: List(String),
  flags: ValidatedFlagSpecs,
  hook_state: hook_state,
  parse_hook: fn(hook_state, String, Args, ValidatedFlagSpecs) ->
    Result(#(hook_state, ValidatedFlagSpecs), error),
) -> #(hook_state, Result(Args, ParseError(error))) {
  let state = Args(flags: [], arguments: [])
  do_parse(input, flags, Ok(state), hook_state, parse_hook)
}

fn do_parse(
  remaining_input: List(String),
  flag_specs: ValidatedFlagSpecs,
  state: Result(Args, ParseError(error)),
  hook_state: hook_state,
  parse_hook: fn(hook_state, String, Args, ValidatedFlagSpecs) ->
    Result(#(hook_state, ValidatedFlagSpecs), error),
) -> #(hook_state, Result(Args, ParseError(error))) {
  case state {
    Error(error) -> #(hook_state, Error(error))
    Ok(state) -> {
      case remaining_input {
        [] -> #(hook_state, Ok(state))

        // Treat anything after bare `--` as positional args and end parsing here.
        ["--", ..rest] -> {
          let arguments = list.append(state.arguments, rest)
          #(hook_state, Ok(Args(..state, arguments:)))
        }

        // Treat `--` followed by a string as a flag. May have a value with
        // `=`, or may be a bare flag with the value in the next arg.
        ["--" <> flag_name, ..rest] ->
          handle_long_flag(
            flag_name,
            rest,
            flag_specs,
            state,
            hook_state,
            parse_hook,
          )

        // Treat bare `-` as positional.
        ["-" as arg, ..rest] ->
          handle_positional(
            arg,
            rest,
            flag_specs,
            state,
            hook_state,
            parse_hook,
          )

        // `-` followed by a value is one or more short flags.
        ["-" <> flag_names, ..rest] ->
          handle_short_flag(
            flag_names,
            rest,
            flag_specs,
            state,
            hook_state,
            parse_hook,
          )

        // Anything else is positional
        [arg, ..rest] ->
          handle_positional(
            arg,
            rest,
            flag_specs,
            state,
            hook_state,
            parse_hook,
          )
      }
    }
  }
}

fn handle_positional(
  new_arg: String,
  remaining_input: List(String),
  flag_specs: ValidatedFlagSpecs,
  state: Args,
  hook_state: hook_state,
  parse_hook: fn(hook_state, String, Args, ValidatedFlagSpecs) ->
    Result(#(hook_state, ValidatedFlagSpecs), error),
) -> #(hook_state, Result(Args, ParseError(error))) {
  let new_args =
    Args(..state, arguments: list.append(state.arguments, [new_arg]))

  case parse_hook(hook_state, new_arg, new_args, flag_specs) {
    Error(error) -> #(hook_state, Error(CustomError(error)))
    Ok(#(new_hook_state, new_flag_specs)) ->
      do_parse(
        remaining_input,
        new_flag_specs,
        Ok(new_args),
        new_hook_state,
        parse_hook,
      )
  }
}

fn handle_long_flag(
  flag_name: String,
  remaining_input: List(String),
  flag_specs: ValidatedFlagSpecs,
  state: Args,
  hook_state: hook_state,
  parse_hook: fn(hook_state, String, Args, ValidatedFlagSpecs) ->
    Result(#(hook_state, ValidatedFlagSpecs), error),
) -> #(hook_state, Result(Args, ParseError(error))) {
  // If the flag contains a `=` character, treat that as the value
  // and prepend it to the rest of the args to make processing easier
  // later (i.e. so we only have to process the case where the flag
  // value is the first item in the list).
  let #(parsed_flag_name, has_equals_value, remaining_input) = case
    string.split_once(flag_name, "=")
  {
    Ok(#(name, value)) -> #(name, True, [value, ..remaining_input])
    Error(_) -> #(flag_name, False, remaining_input)
  }

  case dict.get(flag_specs.long_flags, parsed_flag_name) {
    Error(_) -> #(hook_state, Error(UnknownFlag(parsed_flag_name)))
    Ok(flag_spec) -> {
      case flag_spec.kind, has_equals_value {
        ValueKind, _ ->
          case remaining_input {
            [value, ..rest] ->
              do_parse(
                rest,
                flag_specs,
                Ok(
                  // We don't upsert here. Keep all value-kind flags
                  // so we can support lists.
                  Args(
                    ..state,
                    flags: list.append(state.flags, [
                      ValueFlag(flag_spec.name, value),
                    ]),
                  ),
                ),
                hook_state,
                parse_hook,
              )

            [] -> #(hook_state, Error(ValueNotProvided(parsed_flag_name)))
          }

        // If we had a value after `=` but this is not a value-kind
        // flag, then error.
        // TODO: decide if count-kind and toggle-kind flags can contain values
        ToggleKind, True -> {
          // This zero value will never be reached - we've already validated
          // that there's another value in the list.
          let given = result.unwrap(list.first(remaining_input), "")
          let parse_error = ValueNotSupported(flag: parsed_flag_name, given:)
          #(hook_state, Error(parse_error))
        }

        CountKind, True -> {
          let given = result.unwrap(list.first(remaining_input), "")
          let parse_error = ValueNotSupported(flag: parsed_flag_name, given:)
          #(hook_state, Error(parse_error))
        }

        ToggleKind, False -> {
          let flag = ToggleFlag(name: flag_spec.name)
          let flags = upsert_flag(flag, state.flags)
          do_parse(
            remaining_input,
            flag_specs,
            Ok(Args(..state, flags:)),
            hook_state,
            parse_hook,
          )
        }

        CountKind, False -> {
          let flags = upsert_count_flag(flag_spec, state.flags)
          do_parse(
            remaining_input,
            flag_specs,
            Ok(Args(..state, flags:)),
            hook_state,
            parse_hook,
          )
        }
      }
    }
  }
}

fn handle_short_flag(
  flag_names: String,
  remaining_input: List(String),
  flag_specs: ValidatedFlagSpecs,
  state: Args,
  hook_state: hook_state,
  parse_hook: fn(hook_state, String, Args, ValidatedFlagSpecs) ->
    Result(#(hook_state, ValidatedFlagSpecs), error),
) -> #(hook_state, Result(Args, ParseError(error))) {
  let graphemes = string.to_graphemes(flag_names)

  case graphemes {
    [] ->
      do_parse(remaining_input, flag_specs, Ok(state), hook_state, parse_hook)

    [short_flag, ..rest_flags] ->
      case dict.get(flag_specs.short_flags, short_flag) {
        Error(_) -> #(hook_state, Error(UnknownFlag(short_flag)))
        Ok(flag) -> {
          case rest_flags {
            // For a length 1 list (e.g. `-x`), we can just look up the corresponding
            // long flag name and parse that.
            [] -> {
              let #(hook_state, result) =
                handle_long_flag(
                  flag.name,
                  remaining_input,
                  flag_specs,
                  state,
                  hook_state,
                  parse_hook,
                )
              let result =
                result.map_error(result, replace_error_flag_name(_, short_flag))
              #(hook_state, result)
            }

            // If the rest of the graphemes follow `=`, we assume the current flag is
            // the last one and any remaining graphemes make up the value passed
            // to the flag.
            ["=", ..value_graphemes] -> {
              let value = string.concat(value_graphemes)

              case flag.kind {
                ToggleKind | CountKind -> {
                  let error = ValueNotSupported(flag: short_flag, given: value)
                  #(hook_state, Error(error))
                }

                // Continue with regular parsing loop. We don't upsert value flags
                // so they can be used for lists.
                ValueKind -> {
                  let flag = ValueFlag(name: flag.name, value:)
                  let flags = list.append(state.flags, [flag])
                  do_parse(
                    remaining_input,
                    flag_specs,
                    Ok(Args(..state, flags:)),
                    hook_state,
                    parse_hook,
                  )
                }
              }
            }

            rest_flags ->
              case flag.kind {
                // For a value flag we consume any remaining input as the value for
                // that flag, then continue with the parse loop.
                ValueKind -> {
                  let flag =
                    ValueFlag(name: flag.name, value: string.concat(rest_flags))
                  let flags = upsert_flag(flag, state.flags)
                  do_parse(
                    remaining_input,
                    flag_specs,
                    Ok(Args(..state, flags:)),
                    hook_state,
                    parse_hook,
                  )
                }

                ToggleKind -> {
                  let flag = ToggleFlag(name: flag.name)
                  let flags = upsert_flag(flag, state.flags)

                  handle_short_flag(
                    string.concat(rest_flags),
                    remaining_input,
                    flag_specs,
                    Args(..state, flags: flags),
                    hook_state,
                    parse_hook,
                  )
                }

                CountKind ->
                  handle_short_flag(
                    string.concat(rest_flags),
                    remaining_input,
                    flag_specs,
                    Args(..state, flags: upsert_count_flag(flag, state.flags)),
                    hook_state,
                    parse_hook,
                  )
              }
          }
        }
      }
  }
}

fn upsert_flag(new_flag: Flag, flags: List(Flag)) -> List(Flag) {
  list.filter(flags, fn(input) { input.name != new_flag.name })
  |> list.append([new_flag])
}

fn upsert_count_flag(flag_spec: FlagSpec, flags: List(Flag)) -> List(Flag) {
  let existing_flag_count_result =
    list.find_map(flags, fn(input) {
      case input {
        CountFlag(name: n, count:) if n == flag_spec.name -> Ok(count)
        _ -> Error(Nil)
      }
    })

  let count = case existing_flag_count_result {
    Ok(count) -> count + 1
    Error(_) -> 1
  }

  // Replace the existing input if it exists
  upsert_flag(CountFlag(name: flag_spec.name, count:), flags)
}
