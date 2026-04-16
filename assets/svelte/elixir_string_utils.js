/**
 * Emulates Elixir's IO.puts/1 behavior:
 * Strips surrounding quotes and interprets escape sequences.
 *
 * Handles both regular strings ("...") and heredocs (\"\"\"...\"\"\").
 *
 * @param {string} rawString - The raw Elixir string literal (with quotes)
 * @returns {string} The interpreted string content
 */
export function elixirStringToPuts(rawString) {
  if (!rawString || typeof rawString !== "string") return "";

  let inner;

  // Handle heredoc strings (triple-quoted)
  if (rawString.startsWith('"""') && rawString.endsWith('"""')) {
    inner = rawString.slice(3, -3);
    // Heredocs typically have a leading newline after opening """
    if (inner.startsWith("\n")) inner = inner.slice(1);
    // Remove common leading whitespace (heredoc indentation)
    inner = dedentHeredoc(inner);
  } else if (rawString.startsWith('"') && rawString.endsWith('"')) {
    // Regular double-quoted string
    inner = rawString.slice(1, -1);
  } else {
    // Not a recognized string format — return as-is
    return rawString;
  }

  return interpretEscapes(inner);
}

/**
 * Remove common leading whitespace from heredoc lines
 * (mimics Elixir's heredoc indentation stripping).
 */
function dedentHeredoc(str) {
  const lines = str.split("\n");
  // Find the minimum indentation (ignoring empty lines)
  let minIndent = Infinity;
  for (const line of lines) {
    if (line.trim().length === 0) continue;
    const indent = line.match(/^(\s*)/)[1].length;
    if (indent < minIndent) minIndent = indent;
  }
  if (minIndent === Infinity || minIndent === 0) return str;
  return lines.map((line) => line.slice(minIndent)).join("\n");
}

/**
 * Interpret Elixir escape sequences in a string.
 */
function interpretEscapes(str) {
  let result = "";
  let i = 0;
  while (i < str.length) {
    if (str[i] === "\\" && i + 1 < str.length) {
      const next = str[i + 1];
      switch (next) {
        case "n":
          result += "\n";
          i += 2;
          break;
        case "t":
          result += "\t";
          i += 2;
          break;
        case "r":
          result += "\r";
          i += 2;
          break;
        case "\\":
          result += "\\";
          i += 2;
          break;
        case '"':
          result += '"';
          i += 2;
          break;
        case "a":
          result += "\x07"; // bell
          i += 2;
          break;
        case "b":
          result += "\b";
          i += 2;
          break;
        case "d":
          result += "\x7F"; // delete
          i += 2;
          break;
        case "e":
          result += "\x1B"; // escape
          i += 2;
          break;
        case "f":
          result += "\f";
          i += 2;
          break;
        case "v":
          result += "\v";
          i += 2;
          break;
        case "0":
          result += "\0";
          i += 2;
          break;
        case "x": {
          // \xNN (hex byte) or \x{NNNN} (unicode hex)
          if (i + 2 < str.length && str[i + 2] === "{") {
            const close = str.indexOf("}", i + 3);
            if (close !== -1) {
              const hex = str.slice(i + 3, close);
              const code = parseInt(hex, 16);
              result += isNaN(code) ? str.slice(i, close + 1) : String.fromCodePoint(code);
              i = close + 1;
            } else {
              result += "\\x";
              i += 2;
            }
          } else if (i + 3 < str.length) {
            const hex = str.slice(i + 2, i + 4);
            const code = parseInt(hex, 16);
            result += isNaN(code) ? "\\x" + hex : String.fromCharCode(code);
            i += 4;
          } else {
            result += "\\x";
            i += 2;
          }
          break;
        }
        case "u": {
          // \u{NNNN} (unicode codepoint)
          if (i + 2 < str.length && str[i + 2] === "{") {
            const close = str.indexOf("}", i + 3);
            if (close !== -1) {
              const hex = str.slice(i + 3, close);
              const code = parseInt(hex, 16);
              result += isNaN(code) ? str.slice(i, close + 1) : String.fromCodePoint(code);
              i = close + 1;
            } else {
              result += "\\u";
              i += 2;
            }
          } else {
            result += "\\u";
            i += 2;
          }
          break;
        }
        default:
          // Unrecognized escape — keep as-is
          result += "\\" + next;
          i += 2;
          break;
      }
    } else {
      result += str[i];
      i++;
    }
  }
  return result;
}
