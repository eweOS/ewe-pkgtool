#!/usr/bin/env lua

--[[
--	ewe-pkgtool: ewepkg-create
--	This is a tool to create pacman's PKGBUILDs
--	Date:2023.02.20
--	By MIT License.
--	Copyright (C) 2023 Ziyao.
--	Need Lua5.4 or above to run
--]]

local io		= require "io"
local string		= require "string"

local confSkeleton = [==[
# Maintainer: ${maintainer} <${maintainerEmail}>

pkgname=${pkgname}
pkgver=${pkgver}
pkgrel=0
pkgdesc='${pkgdesc}'
url='${url}'
arch=(${arch})
license=(${license})
depends=(${depends})
source=()
sha256sums=()

build () {
}

package() {
}
]==];

local confArgList <const> = {
	"pkgname","pkgver","url","pkgdesc","arch","license",
	"depends",
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
	io.stderr:write("PKGBUILD already exists");
	return;
end
pkgbuild = io.open("PKGBUILD","w");

for _,var in ipairs(confArgList)
do
	argTable[var] = askFor(var);
end

pkgbuild:write(templateRender(confSkeleton,argTable));
pkgbuild:close();
