# shef
Shell Encoder and Formatter - Transform text into 7-bit ASCII using a variety of encoding and quoting styles. Output can be used in shell scripts or passed into shell script by other tools that don't require shell quoting. Useful for systems that don't support 4-byte UTF-8 encoded characters. Encode your text with `shef` and reconstitute the original string using `echo -e` or similar methods.

# Help Output
```
shef (1.0) - Shell Encoder and Formatter (https://github.com/brunerd/shef)
Usage: shef [options] [input]

Encoding Options:
 -E <option>
    0 \0nnn utf-8 octal [DEFAULT]
    o \nnn utf-8 octal 
    x \xnn utf-8 hexadecimal
    U \Unnnnnnnn code point in hexdecimal

 Encoding workability varies between shells:
  Octal encoding with leading zeroes(\0nnn) works well across multiple shells and quote styles.
  The other octal (\nnn) works within ANSI-C quotes $'...' for bash and zsh and quotes in dash.
  Hex encoding (\xnn) works well in bash and zsh and within a variety of quoting styles.
  Unicode code points work in bash and zsh versions 4+

Quoting Options:
 -Q <option> 
    d double quoted and escaped for shell
    s single quoted and escaped for shell
    u un-quoted and escaped for shell 
    D Dollar-sign (ANSI-C $'') quoted and escaped
    n not quoted or escaped for shell [DEFAULT]
    
  By default only solidus \ and chars <0x20 and >0x7E will be escaped
   This output is for non-shell tools that can pass this data to shell scripts for further processing
  If output is intended for use as a shell parameter or variable, then specify a quoting style.
    Quotes are included in output and all special shell characters are escaped.
  The original string can usually be re-constituted using `echo -e <encoded string>`

Output Options:
  -a Encode all characters (overrides -U)
  -U Leave these whitespace formatting characters raw and un-encoded: \b \f \n \r \t \v
  -V Variable character $ is not escaped within double quotes
  -v print version and exit

  All whitespace (except space) is encoded in ANSI-C style by default
    Bell \a and escape \e are always encoded.

Input:
 Can be a file path, string, file redirection, here-doc, here-string, or piped input.
 
 
Examples can be found at: https://github.com/brunerd/shef

```
