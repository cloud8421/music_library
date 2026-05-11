import { parse } from "unbash";

/**
 * Walk a parsed `unbash` AST and collect all command names from executable
 * positions (simple commands, subshell bodies, command/substitution bodies,
 * pipeline members). Non-executed text (comments, quoted strings, echo
 * arguments) is structurally excluded and never inspected.
 *
 * Returns a `Set<string>` of lowercased command names, or an empty set if
 * parsing fails.
 */
export function extractCommandNames(command: string): Set<string> {
  const names = new Set<string>();

  try {
    const script = parse(command);
    if (script && typeof script === "object" && script.commands) {
      walkScript(script, names);
    }
  } catch {
    // Parse failure — return empty set so caller can fall back to regex
  }

  return names;
}

function walkScript(script: any, names: Set<string>): void {
  const commands = script?.commands;
  if (!Array.isArray(commands)) return;
  for (const stmt of commands) {
    walkStatement(stmt, names);
  }
}

function walkStatement(stmt: any, names: Set<string>): void {
  if (!stmt) return;
  walkNode(stmt.command, names);
}

function walkCompoundList(node: any, names: Set<string>): void {
  if (!node?.commands || !Array.isArray(node.commands)) return;
  for (const stmt of node.commands) {
    walkStatement(stmt, names);
  }
}

/** Recursively walk a command node and collect executable command names. */
function walkNode(node: any, names: Set<string>): void {
  if (!node) return;

  switch (node.type) {
    case "Command": {
      if (node.name) {
        // Collect the command name text
        const nameText = node.name.text || node.name.value;
        if (nameText && typeof nameText === "string") {
          names.add(nameText.toLowerCase());
        }
        // Walk name parts for CommandExpansion/ProcessSubstitution
        if (node.name.parts && Array.isArray(node.name.parts)) {
          for (const part of node.name.parts) {
            walkNode(part, names);
          }
        }
      }

      // Walk prefix (assignment) value parts for nested expansions
      if (node.prefix && Array.isArray(node.prefix)) {
        for (const p of node.prefix) {
          if (p?.value?.parts && Array.isArray(p.value.parts)) {
            for (const part of p.value.parts) {
              walkNode(part, names);
            }
          }
        }
      }

      // Walk suffix parts for nested expansions (do NOT collect suffix
      // text — arguments are not commands)
      if (node.suffix && Array.isArray(node.suffix)) {
        for (const s of node.suffix) {
          if (s?.parts && Array.isArray(s.parts)) {
            for (const part of s.parts) {
              walkNode(part, names);
            }
          }
        }
      }
      break;
    }

    case "Pipeline": {
      if (node.commands && Array.isArray(node.commands)) {
        for (const cmd of node.commands) {
          walkNode(cmd, names);
        }
      }
      break;
    }

    case "AndOr": {
      if (node.commands && Array.isArray(node.commands)) {
        for (const cmd of node.commands) {
          walkNode(cmd, names);
        }
      }
      break;
    }

    case "Subshell": {
      walkCompoundList(node.body, names);
      break;
    }

    case "If": {
      walkCompoundList(node.clause, names);
      walkCompoundList(node.then, names);
      if (node.else) {
        walkCompoundList(node.else, names);
      }
      break;
    }

    case "While": {
      walkCompoundList(node.clause, names);
      walkCompoundList(node.body, names);
      break;
    }

    case "For":
    case "Select": {
      // Walk the wordlist for command substitutions (e.g. for f in $(env);)
      if (node.wordlist && Array.isArray(node.wordlist)) {
        for (const w of node.wordlist) {
          if (w?.parts && Array.isArray(w.parts)) {
            for (const part of w.parts) {
              walkNode(part, names);
            }
          }
        }
      }
      walkCompoundList(node.body, names);
      break;
    }

    case "Case": {
      // Walk the word being matched for command substitutions (e.g. case $(env) in)
      if (node.word?.parts && Array.isArray(node.word.parts)) {
        for (const part of node.word.parts) {
          walkNode(part, names);
        }
      }
      if (node.items && Array.isArray(node.items)) {
        for (const item of node.items) {
          // Walk patterns for command substitutions
          if (item.pattern && Array.isArray(item.pattern)) {
            for (const p of item.pattern) {
              if (p?.parts && Array.isArray(p.parts)) {
                for (const part of p.parts) {
                  walkNode(part, names);
                }
              }
            }
          }
          walkCompoundList(item.body, names);
        }
      }
      break;
    }

    case "Function": {
      // Function definition — walk the body for blocked commands
      if (node.body) {
        walkNode(node.body, names);
      }
      break;
    }

    case "BraceGroup": {
      // { cmd; } grouping
      walkCompoundList(node.body, names);
      break;
    }

    case "ArithmeticFor": {
      // for ((i=0; i<10; i++)); do ...; done
      walkCompoundList(node.body, names);
      break;
    }

    case "Coproc": {
      // coproc cmd — the body is a Command node
      if (node.body) {
        walkNode(node.body, names);
      }
      break;
    }

    case "CommandExpansion":
    case "ProcessSubstitution": {
      if (node.script) {
        walkScript(node.script, names);
      }
      break;
    }

    case "CompoundList": {
      walkCompoundList(node, names);
      break;
    }
  }
}
