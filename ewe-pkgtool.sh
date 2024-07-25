#!/bin/bash

program_path=$0
script_dir="$(dirname $program_path)"
if [ -d ${script_dir}/../share/ewe-pkgtool ]; then
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
	echo $1 1>&2
	exit 1
}

check_pkgbuild() {
	if ! [ -f $PWD/PKGBUILD ]; then
		die "PKGBUILD does not exist"
	fi
}

# $1: varname
is_not_set() {
	grep -q "%{$1}" $PWD/PKGBUILD
	return $?
}

# $1: varname
# $2: varvalue
substitute() {
	local quoted=$(printf '%s' "$2" | sed 's/[/#\]/\\\0/g')
	sed -i -e "s/%{$1}/${quoted}/g" PKGBUILD
}

source_pkgbuild() {
	if ! source $PWD/PKGBUILD; then
	die "failed to source PKGBUILD"
	fi
}

do_substitution() {
	check_pkgbuild

	if [[ (x$1 = x) || (x$2 = x) ]]; then
		die "usage: $program_path substitute VARNAME VARVALUE"
	fi

	substitute $1 $2
}

template_dir=$data_dir/templates
# $1: template name
do_template() {
	local tpl=$1

	if [ x$tpl = x ]; then
		die "usage: $program_path template TEMPLATE_NAME"
	fi

	if ! [ -f $template_dir/$tpl ]; then
		die "template $tpl does not exist"
	fi

	if [ -f $PWD/PKGBUILD ]; then
		die "PKGBUILD already exists"
	fi

	local name="$(git config user.name)"
	local email="$(git config user.email)"
	if [[ (x$name = x) || (x$email = x) ]]; then
		die "user.name or user.email is not set for git"
	fi

	install -Dm644 $template_dir/$tpl $PWD/PKGBUILD

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

	case $1 in
	*$pkgver*)
		;;
	*)
		die 'url does not contain $pkgver' ;;
	esac

	local src=${1//$pkgver/'$pkgver'}
	substitute "source" "$src"
}

help() {
	echo "Usage:"
	echo "$program_path OPERATION [ARG1] [ARG2] ..."
	echo ""
	echo "OPERATION:"
	echo "	showconf:	show ewe-pkgtool configuration"
	echo "	template:	initialize a PKGBUILD template"
	echo "	set:		substitute a variable in PKGBUILD"
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
	gensource)
		do_gensource "$@" ;;
	*)
		help ;;
esac
