# shef
Shell Encoder and Formatter - Transform arbitrary text into 7-bit ASCII using a variety of shell encoding and quoting styles. Output can be used in shell scripts or passed into shell script by other tools that don't require shell quoting. Useful for systems that don't support 4-byte UTF-8 encoded characters. Encode your text with `shef` and reconstitute the original string using `echo -e` or similar methods.

Check my blog for other musings: https://www.brunerd.com/blog/category/projects/shef

## Help Output
```
shef (1.0) - Shell Encoder and Formatter (https://github.com/brunerd/shef)
Output text in various quoting styles and transform Unicode into escaped UTF-8
Usage: shef [options] [input]

Encoding Style:
 -E <option>
    x \xnn utf-8 hexadecimal [DEFAULT]
    0 \0nnn utf-8 octal
    o \nnn utf-8 octal
    U \Unnnnnnnn code point in hexdecimal

Encoding Options:
 Characters <0x20 and >0x7E are encoded by default
 Whitespace characters are encoded in ANSI-C style by default: \a \b \e \f \n \r \t \v 

  -a Encode ALL characters in the specified style
  -P Pass-thru all characters except whitespace characters
  -U Leave whitespace untouched and unescaped in ANSI-C style
     Combine with -a to encode in selected octal or hex style

 Encoding workability varies between shells:
  Hex encoding (\xnn) is compact and works well in bash, zsh and sh in a variety of quoting styles.
  Octal encoding with leading zeroes(\0nnn) works well across multiple shells and quote styles.
  Three digit octal (\nnn) works in ANSI-C quotes $'...' for bash, zsh and sh; quotes in dash.
  Unicode code points (\Unnnnnnnn) work in bash and zsh versions 4+

Quoting Style:
 -Q <option> 
    n not quoted or escaped for shell [DEFAULT]
    d double quoted and escaped for shell
    s single quoted and escaped for shell
    u un-quoted and escaped for shell 
    D Dollar-sign single quoted (ANSI-C $'') for shell

  The default quoting style (n) is for use in non-shell tools that pass arguments to scripts
   This only escapes solidus \ as \\ and does not do any escaping for special shell characters
  If intended for use as a shell variable or argument, specify a quoting style (d,s,u,or D)
    Output will be within specified quotes and all special shell characters are escaped.  

 Encoded strings can be restored with: `echo -e <encoded_string>` in bash
  sh, zsh and dash simply use: `echo <enc_string>` (no -e argument)
 Avoid over-processing ANSI-C quotes in zsh, use: `echo -E $'...'`
  bash, sh and dash simply use: `echo $'...'` (-E is not needed)

  -V Variable character $ is not escaped when double quotes (-Qd) is selected
     Use this to leverage command or variable substitution 

Other Options:
  -v print version and exit

Input:
 Can be a file path, string, file redirection, here-doc, here-string, or piped input.
 
Examples can be found at: https://github.com/brunerd/shef
```

## Examples

### "Not Quoted" for use in Jamf script parameters
If you are using the output for a non-shell tool like Jamf, which doesn't require escaping special characters, just use the default behavior of **no quotes** (`-Qn`) and hexadecimal encoding (`-Ex`), this will encode Unicode, backslashes and whitespace only:
```
$ shef <<-EOF                                                                                        
🛑 Stop.
⚙️ Run your updates!
🙏 Thanks!
EOF
\xF0\x9F\x9B\x91 Stop.\n\xE2\x9A\x99\xEF\xB8\x8F Run your updates!\n\xF0\x9F\x99\x8F Thanks!

#this data is not quoted nor are special shell characters escaped it will be passed using non-shell tool like Jamf
#the recieving script however, will need to apply `echo -e` to the incoming string to reconstitute it
```

### Encoding strings for use in shell variables
If you want to save a string for a script variable, choose a quoting style, `-Qs` for example is single quotes is the most compact and requires the least amount of escaping. In this example the encoding style is octal with leading zeroes `-E0`, which has surprisingly wide recognition within many shells (sh, bash, dash, fish, zsh). We are using a here-doc but you can also supply a path to any text file or use file redirection:
```
$ shef -E0 -Qs <<-EOF                                                                                        
🛑 Stop.
⚙️ Run your updates!
🙏 Thanks!      
EOF
'\0360\0237\0233\0221 Stop.\n\0342\0232\0231\0357\0270\0217 Run your updates!\n\0360\0237\0231\0217 Thanks!'

# Assign the data to a variable and reconstitute the original string using `echo -e`
% message='\0360\0237\0233\0221 Stop.\n\0342\0232\0231\0357\0270\0217 Run your updates!\n\0360\0237\0231\0217 Thanks!'
% echo -e "${message}"
🛑 Stop.
⚙️ Run your updates!
🙏 Thanks!

```

### Exempting $ from Escaping for Parameter Expansion or Command Substitution Later
You can also choose to **not** escape `$` within double quotes. You can then leverage variable expansion during runtime. In this here-doc example note that you must use the single quoted delimiter `<<-'EOF'` so $ is not processed immediately.
```
$ shef -Ex -Qd -V <<-'EOF'                                                                                        
🛑 Stop.
⚙️ Run your updates!
🙏 Thanks $(stat -f %Su /dev/console)!
EOF
"\xF0\x9F\x9B\x91 Stop.\n\xE2\x9A\x99\xEF\xB8\x8F Run your updates"\!"\n\xF0\x9F\x99\x8F Thanks $(stat -f %Su /dev/console)"\!""

$ echo -e "\xF0\x9F\x9B\x91 Stop.\n\xE2\x9A\x99\xEF\xB8\x8F Run your updates"\!"\n\xF0\x9F\x99\x8F Thanks $(stat -f %Su /dev/console)"\!""
🛑 Stop.
⚙️ Run your updates!
🙏 Thanks brunerd!
```

### A Note on `zsh` and default `echo` behavior
Watch out for `zsh` and ANSI-C quote style. By default `zsh` echo processes escaped text, the same as if `echo -e` was invoked. When using ANSI-C (aka Dollar sign quoting), it represents the actual data, no further processing is necessary. You don't want to **double** process the results, to ensure this is the case, always use `echo -E $'...'` for ANSI-C quotes. For example:
```
#-E keeps the solidus in this\that from being processed, the tab after that needs no help
% echo -E $'this\\that\ttab'
this\that     tab

#zsh echo processes escapes by default unlike bash and other shells
% echo $'this\\that\ttab' 
this	    hat	   tab
```

### A Note on exclation marks!
`shef` escapes `!` to an over-bearing degree to guard against misinterpretation by shells as **history expansion**. This makes it easier to test out strings in an interactive shell _without_ needing to turn **off** history expansion (`set +H`), of course maybe you shouldn't use so many exclamation marks!?

```
#bash 3.2 hates exclamations at the end of double quotes
#whether assigning to a variable
bash-3.2$ msg="hello!"
bash: !": event not found
#or as an argument 
bash-3.2$ echo "hello!"
bash: !": event not found

#output in double quotes with -Qd
bash-3.2$ shef -Qd <<< $'hello!'
"hello"\!""

#no problem, we've escaped the heck out of it (it escapes all not just the last fyi)
bash-3.2$ msg="hello"\!""
bash-3.2$ echo $msg
hello!
#direct usage
bash-3.2$ echo "hello"\!""
hello!

#un-quoted gets the special treatment too
bash-3.2$ shef -Qu <<< $'hello!'
hello\!

#works like a charm
bash-3.2$ echo hello\!
hello!
```



