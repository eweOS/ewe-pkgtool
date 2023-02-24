#!/usr/bin/env lua

--[[
--	ewe-pkgtool: ewepkg-create
--	This is a tool to create pacman's PKGBUILDs
--	Date:2023.02.24
--	By MIT License.
--	Copyright (C) 2023 Ziyao.
--	Need Lua5.4 or above to run
--]]

local io		= require "io"
local string		= require "string"

local confSkeleton = [==[
# Maintainer: ${maintainer} <${maintainerEmail}>

pkgname=${packagename}
pkgver=${packagever}
pkgrel=0
pkgdesc='${pkgdesc}'
url='${url}'
arch=(${arch})
license=(${license})
depends=(${depends})
source=()
sha256sums=()
${makedepends}

build () {
	cd ${packagename}-$[pkgver}
	${buildcode}
}

check() {
	cd ${packagename}-${pkgver}
	${checkcode}
}

package() {
	cd ${packagename}-${pkgver}
	${packagecode}
}
]==];

local buildSystemList = {
	a = {
		buildcode	= [[
./configure --prefix=/usr
	make]],
		checkcode	= [[
make check]],
		packagecode	= [[
make install DESTDIR=${pkgdir}]],
		makedepends	= "",
	    },
	m = {
		buildcode	= "",
		checkcode	= "",
		packagecode	= "",
		makedepends	= "",
	    },
};

local confArgList <const> = {
	"packagename","packagever","url","pkgdesc","arch","license",
	"depends"
};

local function templateRender(tpl,arg)
	return (string.gsub(tpl,"${(.-)}",
		function(key)
			return arg[key] or ("${%s}"):format(key);
		end));
end

local function askFor(name)
	io.write(name .. ": ");
	io.flush();
	return io.read("l");
end

local function getMaintainerInfo()
	local output = io.popen("git config --global -l","r"):read("a");
	return {
		maintainer	= string.match(output,"user%.name=(.-)\n");
		maintainerEmail	= string.match(output,"user%.email=(.-)\n");
	       };
end

local argTable = getMaintainerInfo();
argTable.maintainer	= argTable.maintainer		or askFor("Maintainer");
argTable.maintainerEmail= argTable.maintainerEmail	or
			  askFor("Maintainer Email");

local pkgbuild = io.open("PKGBUILD","r");
if pkgbuild
then
	io.stderr:write("PKGBUILD already exists\n");
	return;
end
pkgbuild = io.open("PKGBUILD","w");

for _,var in ipairs(confArgList)
do
	argTable[var] = askFor(var);
end

buildSystem = askFor([[
Build System:
(a) Autotools(-like)
(m) Manually Specified]]);
local buildCode = buildSystemList[buildSystem];
argTable.buildcode	= buildCode.buildcode;
argTable.checkcode	= buildCode.checkcode;
argTable.packagecode	= buildCode.packagecode;
argTable.makedepends	= buildCode.makedepends;
pkgbuild:write(templateRender(confSkeleton,argTable));
pkgbuild:close();
