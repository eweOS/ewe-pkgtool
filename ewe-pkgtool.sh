#!/bin/bash
# shellcheck disable=SC2016,SC2155

program_path=$0
script_dir=$(dirname "$program_path")
if [ -d "${script_dir}"/../share/ewe-pkgtool ]; then
	data_dir=${script_dir}/../share/ewe-pkgtool/
else
	data_dir=$script_dir
fi

do_showconf() {
	echo "program path:		$program_path"
	echo "script directory:	$script_dir"
	echo "data directory:		$data_dir"
}

die() {
	echo "$1" 1>&2
	exit 1
}

do_ask_yes() {
	local line

	printf "%s? (Y/n): " "$1"
	read -r line
	if [ "$line" = n ]; then
		exit 1
	fi
}

do_backup() {
	if [ -f "$PWD"/PKGBUILD ]; then
		cp "$PWD"/PKGBUILD "$PWD"/.PKGBUILD.backup
	fi
}

do_show_changes() {
	if [ -f "$PWD"/.PKGBUILD.backup ]; then
		diff .PKGBUILD.backup "$PWD"/PKGBUILD
	fi
}

do_rollback() {
	check_pkgbuild

	if ! [ -f "$PWD"/.PKGBUILD.backup ]; then
		die "no backup, cannot rollback"
	fi

	diff "$PWD"/PKGBUILD "$PWD"/.PKGBUILD.backup
	do_ask_yes "Do you want to rollback"
	mv .PKGBUILD.backup "$PWD"/PKGBUILD
}

check_pkgbuild() {
	if ! [ -f "$PWD"/PKGBUILD ]; then
		die "PKGBUILD does not exist"
	fi
}

# $1: varname
is_not_set() {
	grep -q "%{$1}" "$PWD"/PKGBUILD
	return $?
}

# $1: original text
# $2: replaced text
plain_substitute() {
	local quoted1=$(printf '%s' "$1" | sed 's/[/#\]/\\\0/g')
	local quoted2=$(printf '%s' "$2" | sed 's/[/#\]/\\\0/g')
	sed -i -e "s/${quoted1}/${quoted2}/g" PKGBUILD
}

# $1: varname
# $2: varvalue
substitute() {
	plain_substitute "%{$1}" "$2"
}

source_pkgbuild() {
	# shellcheck disable=SC1091
	if ! source "$PWD"/PKGBUILD; then
		die "failed to source PKGBUILD"
	fi
}

do_substitution() {
	check_pkgbuild

	if [[ ! "$1" || ! "$2" ]]; then
		die "usage: $program_path substitute VARNAME VARVALUE"
	fi

	do_backup
	substitute "$1" "$2"
	do_show_changes
}

template_dir=$data_dir/templates
# $1: template name
do_template() {
	local tpl=$1

	[ "$tpl" ] || die "usage: $program_path template TEMPLATE_NAME"

	[ -f "$template_dir/$tpl" ] || die "template $tpl does not exist"

	[ -f "$PWD"/PKGBUILD ] && die "PKGBUILD already exists"

	local name="$(git config user.name)"
	local email="$(git config user.email)"
	if [[ ! "$name" || ! "$email" ]]; then
		die "user.name or user.email is not set for git"
	fi

	install -Dm644 "$template_dir/$tpl" "$PWD"/PKGBUILD

	substitute maintainer_name "$name"
	substitute maintainer_email "$email"
}

# $1: user specified download link
do_gensource() {
	check_pkgbuild

	if is_not_set "pkgver"; then
		die "pkgver is not set"
	fi

	if ! is_not_set "source"; then
		die "source has been already set"
	fi

	source_pkgbuild

	# shellcheck disable=SC2154
	case $1 in
	*$pkgver*)
		;;
	*)
		die 'url does not contain $pkgver' ;;
	esac

	do_backup

	local src=${1//$pkgver/'$pkgver'}
	substitute "source" "$src"

	do_show_changes
}

do_genchecksum() {
	check_pkgbuild
	source_pkgbuild

	if is_not_set "source"; then
		die "source is not set"
	fi


	local checksum=$(makepkg -g)
	if ! [ "$checksum" ]; then
		die "cannot generate checksum"
	fi

	do_backup

	plain_substitute 'sha256sums=()' "$checksum"

	do_show_changes
}

do_listunset() {
	check_pkgbuild

	if ! grep -E '%\{\w+\}' "$PWD"/PKGBUILD; then
		echo "NO UNSET VARIABLES :)"
	fi
}

do_trypr() {
	local arg=$1
	local url

	check_pkgbuild

	[ -d "$PWD"/trypr ] && die "Another trypr is in progress"

	# Assume it is a Pull Request No.
	if [[ "$arg" =~ ^[0-9]+$ ]]; then
		url="https://github.com/eweOS/packages/pull/$arg.patch"
	elif [[ "$arg" == https://github.com/eweOS/packages/pull/* ]]; then
		url=$arg.patch
	else
		die "Unknown Pull Request $arg"
	fi

	local name=$(basename "$url")
	curl -L "$url" -o "$name" || die "failed to fetch patch"

	if ! git am --keep-non-patch "$name"; then
		git am --abort
		die "failed to apply the patch"
	fi

	mkdir -p "$PWD"/trypr || die "Cannot create working directory"

	mv "$name" trypr
	cp "$PWD"/* trypr
	cd trypr || die "Cannot enter working directory"

	if makepkg -s; then
		echo ===========================================================
		echo build success
		echo ===========================================================
	else
		echo ===========================================================
		echo build failure
		echo ===========================================================
	fi
}

do_get() {
	check_pkgbuild
	source_pkgbuild

	[ "$1" ] || die "var name is needed"

	local v=$(declare -p "$1" | sed -e 's/declare[ a-zA-Z-]*=//')
	[ "$v" ] || die "$1: not set"

	echo "$v"
}

help() {
	echo "Usage:"
	echo "$program_path OPERATION [ARG1] [ARG2] ..."
	echo ""
	echo "OPERATION:"
	echo "	showconf:	show ewe-pkgtool configuration"
	echo "	template:	initialize a PKGBUILD template"
	echo "	set:		substitute a variable in PKGBUILD"
	echo "	get:		get a PKGBUILD variable"
	echo "	gensource:	generate source array"
	echo "	genchecksum:	generate checksum array"
	echo "	rollback:	revert last changes"
	echo "	listunset	list unset template variables in PKGBUILD"
	echo "	trypr		test build of a Pull Request"
}

opt=$1
shift

case $opt in
	showconf)
		do_showconf ;;
	template)
		do_template "$@" ;;
	set)
		do_substitution "$@" ;;
	get)
		do_get "$@" ;;
	gensource)
		do_gensource "$@" ;;
	genchecksum)
		do_genchecksum "$@" ;;
	rollback)
		do_rollback ;;
	listunset)
		do_listunset ;;
	trypr)
		do_trypr "$@" ;;
	*)
		help ;;
esac
