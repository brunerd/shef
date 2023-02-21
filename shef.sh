#!/bin/zsh
#!/bin/bash
#works in either (but zsh is actually MUCH faster)
: <<-LICENSE_BLOCK
shef - Shell Encoder and Formatter - Copyright (c) 2023 Joel Bruner (https://github.com/brunerd/shef)
Licensed under the MIT License
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
LICENSE_BLOCK

function shef()(
	version="1.0"
	versionLine="shef ($version) - Shell Encoder and Formatter (https://github.com/brunerd/shef)"
	helpText='Usage: shef [options] [input]\n\nEncoding Options:\n -E <option>\n    0 \\0nnn utf-8 octal [DEFAULT]\n    o \\nnn utf-8 octal \n    x \\xnn utf-8 hexadecimal\n    U \\Unnnnnnnn code point in hexdecimal\n\n Encoding workability varies between shells:\n  Octal encoding with leading zeroes(\\0nnn) works well across multiple shells and quote styles.\n  The other octal (\\nnn) works within ANSI-C quotes $'\''...'\'' for bash and zsh and quotes in dash.\n  Hex encoding (\\xnn) works well in bash and zsh and within a variety of quoting styles.\n  Unicode code points work in bash and zsh versions 4+\n\nQuoting Options:\n -Q <option> \n    d double quoted and escaped for shell\n    s single quoted and escaped for shell\n    u un-quoted and escaped for shell \n    D Dollar-sign (ANSI-C $'\'''\'') quoted and escaped\n    n not quoted or escaped for shell [DEFAULT]\n    \n  By default only solidus \\ and chars <0x20 and >0x7E will be escaped\n   This output is for non-shell tools that can pass this data to shell scripts for further processing\n  If output is intended for use as a shell parameter or variable, then specify a quoting style.\n    Quotes are included in output and all special shell characters are escaped.\n  The original string can usually be re-constituted using `echo -e <encoded string>`\n\nOutput Options:\n  -a Encode all characters (overrides -U)\n  -U Leave these whitespace formatting characters raw and un-encoded: \\b \\f \\n \\r \\t \\v\n  -V Variable character $ is not escaped within double quotes\n  -v print version and exit\n\n  All whitespace (except space) is encoded in ANSI-C style by default\n    Bell \\a and escape \\e are always encoded.\n\nInput:\n Can be a file path, string, file redirection, here-doc, here-string, or piped input.\n \nExamples can be found at: https://github.com/brunerd/shef'

	#enter with no argument to get the help
	function printHelp()(
		echo "${versionLine}" >&2
		echo -e "${helpText}" >&2
	)

	#options processing	
	while getopts ":aE:hUvVC:Q:" option; do
		case "${option}" in
			#encode all
			'a')flag_a=1;;
			#leave whitespace Untouched
			'U')wsenc_flag=0;;
			#help
			'h')printHelp;exit 0;;
			#version
			'v')echo "${versionLine}"; exit 0;;
			#exempt variable escaping in double quotes
			'V')exvar_flag=1;;
			#Encoding style
			"E")
				if [ -z "${encodeType}" ]; then
					case "${OPTARG}" in
						'x'|'U'|0|'o') encodeType="${OPTARG}";;
						*) echo >&2 "Invalid encoding option"; printHelp; exit 1;;
					esac
				fi
			;;
			#Quoting for shell style
			"Q")
				if [ -z "${quotingType}" ]; then
					case "${OPTARG}" in
						'd'|'s'|'u'|'D'|'n') quotingType="${OPTARG}";;
						*) echo >&2 "Invalid quoting option"; printHelp; exit 1;;
					esac
				fi
			;;
		esac
	done
		
	#shift if we had args so $1 is our string
	[ $OPTIND -ge 2 ] && shift $((OPTIND-1))

	#if string is a file get contents
	if [ -f "${1}" ]; then 
		set -- "$(< "${1}")"
	#otherwise if empty check other sources
	elif [ -z "${1}" ]; then 
		#/dev/stdin is a file if redirected input
		if [ -f /dev/stdin ]; then
			#set $1 to contents of stdin
			set -- "$(< /dev/stdin)"
		#if piped input -t is non-zero
		elif [ ! -t '0' ]; then
			#set $1 to piped input to cat
			set -- "$(cat)"
		#nothing then, print help
		else
			printHelp
			exit 0
		fi
	fi

	
	#default quoting is none
	case "${quotingType:=n}" in
		#double quotes for shell
		'd')
			#exclamation escape
			exc_esc='"\!"'
			#solidus escape
			sol_esc='\\\'
			#special character escape (" `)
			spc_esc='\'
			#quote type ""
			quote='"'
			#unless exempt (-V), escape dollar sign
			! ((exvar_flag)) && ds_esc='\'
		;;
		#single quotes for shell
		's')
			#solidus escape
			sol_esc='\'
			#single quote escape
			sinq_esc="'\''"
			#quote type ''
			quote="'"
		;;
		#unquoted for shell
		'u')
			#exclamation escape
			exc_esc='\!'
			#dollar sign $ escape
			ds_esc='\'
			#unquoted escape
			unq_esc='\'
			#extra escapes for printf process Unicode
			prtf_esc='\\'
			#solidus escape
			sol_esc='\\\'
			#special character escape (" `)
			spc_esc='\'
			#single quote escape
			sinq_esc="\'"
		;;	
		#Dollar sign ANSI-C quoting ($'') for shell
		'D')
			#solidus escape
			sol_esc='\'
			#single quote escape
			sinq_esc=$'\\\''
			#possible $ for $'' quoting option
			dollarsign='$'
			#quote type ''
			quote="'"
		;;	
		#no quotes, for use as parameter in non-shell tool. Escape only backslash, Unicode <0x20 >0x7E, and whitespace
		'n')
			#solidus escape
			sol_esc='\'
		;;
	esac

	#encode whitespace by default for all (-U to suppress)
	[ -z "${wsenc_flag}" ] && wsenc_flag=1

	#get length (use -m for multibyte Unicode chars NOT -c byte count)
	length=$(($(printf "%s" "${1}" | wc -m)))

	#begin with possible quoting
	echo -En "${dollarsign}${quote}"

	#go through each character
	for (( i=0; i<${length}; i++ )); do	
		#assign to variable (much faster for multiple uses)
		char="${1:$i:1}"

		#encode special characters and whitespace characters (or not if -a)
		case "${char}" in
			#whitespace may be printed C-style escaped or passed through unaltered
			$'\b')if ((wsenc_flag));then echo -En "${unq_esc}"'\b';continue; elif ! ((flag_a));then echo -n $'\b';continue;fi ;;
			$'\f')if ((wsenc_flag));then echo -En "${unq_esc}"'\f';continue; elif ! ((flag_a));then echo -n $'\f';continue;fi ;;
			$'\n')if ((wsenc_flag));then echo -En "${unq_esc}"'\n';continue; elif ! ((flag_a));then echo -n $'\n';continue;fi ;;
			$'\r')if ((wsenc_flag));then echo -En "${unq_esc}"'\r';continue; elif ! ((flag_a));then echo -n $'\r';continue;fi ;;
			$'\t')if ((wsenc_flag));then echo -En "${unq_esc}"'\t';continue; elif ! ((flag_a));then echo -n $'\t';continue;fi ;;
			$'\v')if ((wsenc_flag));then echo -En "${unq_esc}"'\v';continue; elif ! ((flag_a));then echo -n $'\v';continue;fi ;;
		esac

		if ! ((flag_a)); then
			case "${char}" in
				#always encode bell 0x07 as \a			
				$'\a')echo -En "${unq_esc}"'\a';continue;;
			
				#always encode escape 0x1b as \e 
				$'\e')echo -En "${unq_esc}"'\e';continue;;
				#FYI: bash 3.x only understands $'\e' and zsh echo cannot deal with unquoted version \\e

				#process these special characters depending on the output quoting
				'\')echo -En "${sol_esc}"'\';continue;;
				"'")echo -En ${sinq_esc:=\'};continue;;
				'!')echo -En "${exc_esc:=!}";continue;;
				'"'|'`')echo -En "${spc_esc}${char}";continue;;
				'$')echo -En "${ds_esc}\$";continue;;
				#if unquoted all these need escaping
				'='|'?'|'!'|'#'|'%'|'&'|'*'|'|'|':'|';'|'?'|'('|'['|'{'|'<'|'>'|'}'|']'|')')
					echo -En "${unq_esc}${char}";continue;;
			esac
		fi
				
		#encode if -a (all) OR outside printable ASCII range (less than 0x20 or greater than 0x7E)
		if ((flag_a)) || [[ "${char}" < $'\x20' ]] || [[ "${char}" > $'\x7E' ]]; then			
			#encode one of these ways
			case "${encodeType:=0}" in
				#utf-8 octal \nnn (-o or -O) or \0nnn (-0)
				"o"|"0")
					[ "${encodeType}" = "0" ] && zero="0"
					for byte in $(echo -En "${char}" | xxd -p -c1 -u); do 
						#use shell hex conversion along with printf
						printf "${prtf_esc}""\\\\${zero}%03o" $((0x${byte}))
					done
				;;
				#zsh code point \Unnnnnnnn (-U)
				"U")
					#printf in bash 3.x cannot print Code points but /usr/bin/printf can
					/usr/bin/printf "${prtf_esc}""\\\\U%08X" \'"${char}"
					;;
				#utf-8 \xnn escaped (-x) [DEFAULT]
				"x")
					#print UTF8 encoded \x escape style, leave xxd output unquoted to leverage each line as argument for printf
					printf "${prtf_esc}""\\\\x%s" $(echo -En "${char}" | xxd -p -c1 -u)
				;;
			esac
		else
			#print character as-is (some shell echoes don't like -, using printf)
			printf "%s" "${char}"
		fi
	done
	#add a newline to the end of the string and possible quote
	echo -E "${quote}"
)

shef "${@}"
