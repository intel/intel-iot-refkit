#!/usr/bin/env python
# ex:ts=4:sw=4:sts=4:et
# -*- tab-width: 4; c-basic-offset: 4; indent-tabs-mode: nil -*-
#
# This module offers an API to find out if an image contains any licensing
# conflicts if certain license classes (typically (LGPLv3)) are not allowed.
#
# There are several problems which we are trying to solve:
#
#   1. Bitbake doesn't allow us to find out runtime dependencies without
#   building the whole image. We can't use the tinfoil API for this reason, but
#   instead we are using oe-pkg-util for finding out package (not recipe)
#   licenses and runtime dependencies. See bug
#   https://bugzilla.yoctoproject.org/show_bug.cgi?id=10932 for discussion.
#
#   2. Many components are dual-licensed, for example using LGPLv3 and GPLv2.
#   This means that if we have a non-GPLv3 configuration, we must use the
#   component under the other license (in this case GPLv2). Many licenses are
#   not GPLv2-compatible however. This test tries to propagate the licenses
#   through the runtime dependency tree to find out if any usable licenses
#   remain on top level.
#
#   3. Runtime dependencies do not always propagate licenses. GPLv2 and GPLv3
#   are propagated by linking, but many runtime dependencies are for D-Bus APIs
#   and process execution. This test uses a whitelist file to find out which
#   components can be depended against without having to consider their licenses
#   for the top-level component.
#
# Important: This test does by no means guarantee that there is license
# compliance. Having the license compatibility rules in a map is not precise
# enough, and many licenses are just omitted. This test is just meant to help
# detect obvious image problems, and it might not do even that in all cases.
# Especially the dual-licensing rules are not very accurate due to the way
# Bitbake recipes express dual-licensing and multi-licensing.
#
# AUTHORS
# Ismo Puustinen <ismo.puustinen@intel.com>

import os
import unittest
import re
import glob
from shutil import rmtree, copy
import subprocess

class LicenseNode():

    # Node licenses mean the licenses which can be alternatively be used for
    # using the software. In essence, "dual-licensing". The more complex cases,
    # where the different source parts can be licensed with different licenses,
    # are not handled.
    def __init__(self, licenses, children, name=""):
        self.licenses = set(licenses)
        self.propagated = []
        self.children = children
        self.name = name

    def __str__(self):
        return self.name + ": " + str(list(self.licenses)) + " -> " + str(list(self.propagated))

    def printTree(self, indent=0):
        print(indent * "\t" + str(self))
        for child in self.children:
            child.printTree(indent + 1)

class LicenseCheck():

    # This table contains the "allowed" licenses. It means that a package
    # licensed with the table "key" can link against packages licensed with
    # table "values", and still retain the original outbound license. For
    # instance, if GPLv2 code links against a BSD3-licensed component, the
    # outbould license is still allowed to be GPLv2.

    # Assumption: GCC exception criteria are always fulfilled.

    allowed = {
            "MIT" : [ "MIT", "LGPLv2", "LGPLv2.1", "LGPLv3", "BSD3", "Zlib", "PD", "Unicode", "MPL-2.0", "PSFv2", "GPL-3.0-with-GCC-exception", "Apache-2.0", "bzip2" ],
            "Apache-2.0" : [ "Apache-2.0", "MIT", "LGPLv2", "LGPLv2.1", "LGPLv3", "BSD3", "Zlib", "PD", "Unicode", "MPL-2.0", "PSFv2", "GPL-3.0-with-GCC-exception", "bzip2" ],
            "BSD3" : [ "BSD3", "LGPLv2", "LGPLv2.1", "LGPLv3", "MIT", "Zlib", "PD", "Unicode", "MPL-2.0", "PSFv2", "GPL-3.0-with-GCC-exception", "Apache-2.0", "bzip2" ],
            "LGPLv2" : [ "LGPLv2", "LGPLv2.1", "LGPLv3", "BSD3", "MIT", "Zlib", "PD", "Unicode", "PSFv2", "GPL-3.0-with-GCC-exception", "Apache-2.0", "bzip2" ],
            "LGPLv2.1" : [ "LGPLv2.1", "LGPLv2", "LGPLv3", "BSD3", "MIT", "Zlib", "PD", "Unicode", "PSFv2", "GPL-3.0-with-GCC-exception", "Apache-2.0", "bzip2" ],
            "LGPLv3" : [ "LGPLv2", "LGPLv2.1", "LGPLv3", "BSD3", "MIT", "Zlib", "PD", "Unicode", "PSFv2", "GPL-3.0-with-GCC-exception", "Apache-2.0", "bzip2" ],
            "GPLv2" : [ "GPLv2", "LGPLv2", "LGPLv2.1", "LGPLv3", "MIT", "BSD3", "Zlib", "PD", "Unicode", "PSFv2", "GPL-3.0-with-GCC-exception", "bzip2" ],
            "GPLv3" : [ "GPLv3", "LGPLv2", "LGPLv2.1", "LGPLv3", "MIT", "BSD3", "Zlib", "PD", "Unicode", "PSFv2", "GPL-3.0-with-GCC-exception", "Apache-2.0", "bzip2" ],
            "openssl" : [ "openssl", "LGPLv2", "LGPLv2.1", "LGPLv3", "MIT", "BSD3", "Zlib", "PD", "Unicode", "MPL-2.0", "PSFv2", "GPL-3.0-with-GCC-exception", "Apache-2.0", "bzip2" ],
            "Zlib" : [ "Zlib", "LGPLv2", "LGPLv2.1", "LGPLv3", "MIT", "BSD3", "Zlib", "PD", "Unicode", "MPL-2.0", "PSFv2", "GPL-3.0-with-GCC-exception", "Apache-2.0", "bzip2" ],
            "AFL-2" : [ "AFL-2", "LGPLv2", "LGPLv2.1", "LGPLv3", "MIT", "BSD3", "Zlib", "PD", "Unicode", "MPL-2.0", "PSFv2", "GPL-3.0-with-GCC-exception", "Apache-2.0", "bzip2" ],
            "PD" : [ "PD", "LGPLv2", "LGPLv2.1", "LGPLv3", "MIT", "BSD3", "Zlib", "Unicode", "MPL-2.0", "PSFv2", "GPL-3.0-with-GCC-exception", "Apache-2.0", "bzip2" ],
            "MPL-2.0" : [ "MPL-2.0", "LGPLv2", "LGPLv2.1", "LGPLv3", "MIT", "BSD3", "Zlib", "PD", "Unicode", "PSFv2", "GPL-3.0-with-GCC-exception", "Apache-2.0", "bzip2" ],
            "PSFv2" : [ "PSFv2", "MPL-2.0", "LGPLv2", "LGPLv2.1", "LGPLv3", "MIT", "BSD3", "Zlib", "PD", "Unicode", "GPL-3.0-with-GCC-exception", "Apache-2.0", "openssl", "bzip2" ],
            "GPL-3.0-with-GCC-exception" : [ "GPL-3.0-with-GCC-exception", "PSFv2", "LGPLv2", "LGPLv2.1", "LGPLv3", "MIT", "BSD3", "Zlib", "PD", "Unicode", "Apache-2.0", "bzip2" ],
            "bzip2" : [ "bzip2", "GPL-3.0-with-GCC-exception", "PSFv2", "LGPLv2", "LGPLv2.1", "LGPLv3", "MIT", "BSD3", "Zlib", "PD", "Unicode", "Apache-2.0", "MPL-2.0" ],
            "Unicode" : [ "Unicode", "bzip2", "GPL-3.0-with-GCC-exception", "PSFv2", "LGPLv2", "LGPLv2.1", "LGPLv3", "MIT", "BSD3", "Zlib", "PD", "Apache-2.0", "MPL-2.0" ],
    }

    # Some combinations are explicitly disallowed for linking. For example,
    # GPLv2 code can't be linked against GPLv3 code.

    disallowed = {
            "GPLv2" : [ "GPLv3", "openssl", "AFL-2" ],
            "GPLv3" : [ "GPLv2", "openssl", "AFL-2" ],
            "openssl" : [ "GPLv2", "GPLv3" ],
            "AFL-2" : [ "GPLv2", "GPLv3" ],
            "Apache-2.0" : [ "GPLv2" ],
    }

    # However, if (for example) MIT-licensed code links against a GPLv2-licensed
    # library, the outbound license "degrades" to GPLv2. This is the default
    # case if the result is not found in allowed or disallowed tables. Later,
    # consider changing this to have an explicit degrade table.

    # A conversion table for "or later" clauses in recipes and other
    # substitutions which might be safely done.

    orlater = {
            "GPLv2+" : [ "GPLv2", "GPLv3" ],
            "GPLv2.0+" : [ "GPLv2", "GPLv3" ],
            "GPL-2.0+" : [ "GPLv2", "GPLv3" ],
            "GPLv3+" : [ "GPLv3" ],
            "AGPL-3.0" : [ "GPLv3" ],
            "GPL-3.0-with-autoconf-exception" : [ "GPLv3" ],
            "LGPLv2+" : [ "LGPLv2", "LGPLv2.1", "LGPLv3" ],
            "LGPLv2.1+" : [ "LGPLv2.1", "LGPLv3" ],
            "LGPL-2.1+" : [ "LGPLv2.1", "LGPLv3" ],
            "LGPLv3+" : [ "LGPLv3" ],
            "MIT-style" : [ "MIT" ],
            "ICU" : [ "Unicode" ],
            "BSD" : [ "BSD3" ],
            "BSD-3-Clause" : [ "BSD3" ],
            "BSD-2-Clause" : [ "BSD3" ], # license compatibility is close enough
            "Libpng" : [ "Zlib" ],
    }

    # The oe-pkg-util lookups are very slow. Cache the returned values.
    packageCache = {}
    recipeCache = {}
    rdepsCache = {}
    licenseCache = {}

    def __init__(self, whitelistFile=None, prohibited=[]):
        """Initialize the licensecheck object.
        
        A LicenseCheck object is used to analyse runtime licensing of
        packages. In order to use this class, you have to first build
        the package you want to inspect. This is due to the limitations
        in how BitBake handles runtime dependencies.

        The 'whitelistFile' parameter contains a filename, which points
        to a file containing a '\\n'-separated list of packages which
        can be excluded from the runtime dependecy tree, typically for
        the reason that they are known not to propagate licenses for the
        components which have a runtime dependency on them. This
        happens, for example, when a component uses a D-Bus API or execs
        another process. The 'prohibited' parameter contains a list of
        licenses which are prohibited for any reason. For example, to
        prevent (L)GPLv3 licenses, set prohibited = ["GPLv3", "LGPLv3"].
        """

        self.whiteList = []
        self.prohibited = prohibited
        if whitelistFile:
            with open(whitelistFile) as f:
                lines = f.readlines()
                for line in lines:
                    self.whiteList.append(line.strip())

    def _parseLicenseString(self, s):
        # Replace & with |. The reasoning is that typically for projects with
        # multiple licenses the most liberal licenses are used for libraries.
        # This is of course not certain, but a good approximation.
        s = s.replace("&", "|")

        # Remove "(" and ")", because we don't deal with complex licensing
        # schemes.
        s = s.replace("(", "").replace(")", "")

        # Split the string into a list. Remove duplicates.
        licenses = set([l.strip() for l in s.split("|")])

        # Convert the "+"-licenses to real ones.
        finalLicenses = []
        for l in licenses:
            if l in LicenseCheck.orlater:
                finalLicenses += LicenseCheck.orlater[l]
            else:
                finalLicenses.append(l)

        return finalLicenses

    def _calculateConstraints(self, constraints, licenses, degradedLicenses):
        # Every sublist in constraints list is how a single package dependency
        # is licensed. Find the least restrictive outbound licenses for this
        # package.

        # Go through all the licenses that are compatible with the top package
        # and see if all dependencies could be used from code licensed with that
        # license.

        if len(licenses) == 0 or len(licenses - degradedLicenses) == 0:
            return set()

        candidateLicenses = licenses.copy()

        for license in licenses:
            if license in LicenseCheck.disallowed:
                bad = LicenseCheck.disallowed[license]
            else:
                bad = []

            if license in LicenseCheck.allowed:
                good = LicenseCheck.allowed[license]
            else:
                good = []

            for dependencyLicenses in constraints:
                possible = False
                compatibleLicenses = set()
                for dependencyLicense in dependencyLicenses:
                    if dependencyLicense in bad:
                        # Can't use this license, see other top-level licenses
                        # for this dependency.
                        continue
                    elif dependencyLicense in good:
                        possible = True
                        # This license can be used as-is. Cancel previous
                        # degradations.
                        compatibleLicenses.clear()
                        break
                    else:
                        possible = True
                        # We can possibly degrade to this license. Save it for
                        # next round if the top-level license candidate hasn't
                        # been already degraded.
                        if not license in degradedLicenses:
                            compatibleLicenses.add(dependencyLicense)

                # Can we handle this dependency with this top-level license?
                if not possible:
                    if license in candidateLicenses:
                        candidateLicenses.remove(license)
                elif len(compatibleLicenses) > 0:
                    # We need to degrade our top-level license into something
                    # that is supported by the dependency license. Then we need
                    # to go through the dependencies again to see if this
                    # license fits. The algorithm doesn't yet support finding
                    # "common ancestor" licenses, but instead we just degrade to
                    # the licenses that the dependency has and are compatible.
                    candidateLicenses = candidateLicenses.union(compatibleLicenses)
                    degradedLicenses.add(license)
                # Else we can directly use this license.

        if candidateLicenses == licenses:
            # The license set didn't change and is stable. We can go with it.
            return licenses - degradedLicenses - set(self.prohibited)

        # Else check the dependencies again with the new candidateLicenses. This
        # is guaranteed to finish if the license degradation graph is acyclical.
        return self._calculateConstraints(constraints, candidateLicenses, degradedLicenses)

    def _getRecipe(self, package):
        if package in LicenseCheck.packageCache:
            return LicenseCheck.packageCache[package]

        rRecipeProp = subprocess.check_output(["oe-pkgdata-util", "lookup-recipe", package]).decode("utf-8").strip()

        LicenseCheck.packageCache[package] = rRecipeProp
        return rRecipeProp

    def _getPackage(self, recipe):
        rPackageProp = None
        if recipe in LicenseCheck.recipeCache:
            return LicenseCheck.recipeCache[recipe]
        try:
            rPackageProp = subprocess.check_output(["oe-pkgdata-util", "lookup-pkg", recipe]).decode("utf-8").strip()
        except subprocess.CalledProcessError:
            print("'oe-pkgdata-util lookup-pkg %s' failed!" % recipe)

        LicenseCheck.recipeCache[recipe] = rPackageProp
        return rPackageProp

    def _getRdeps(self, package):
        if package in LicenseCheck.rdepsCache:
            return LicenseCheck.rdepsCache[package]

        rundepsProp = subprocess.check_output(["oe-pkgdata-util", "read-value", "RDEPENDS", package]).decode("utf-8")
        rundeps = [token for token in rundepsProp.strip().split() if not token[0] == "(" and not token[-1] == ")"]
        rRundeps = filter(None, [self._getPackage(package) for package in rundeps])

        LicenseCheck.rdepsCache[package] = rRundeps
        return rRundeps

    def _getLicenses(self, package):
        if package in LicenseCheck.licenseCache:
            return LicenseCheck.licenseCache[package]

        licenseProp = subprocess.check_output(["oe-pkgdata-util", "read-value", "LICENSE", package]).decode("utf-8")

        LicenseCheck.licenseCache[package] = licenseProp
        return licenseProp

    def _findChildren(self, name, chain=[]):
        results = []

        rundeps = self._getRdeps(name)

        for d in rundeps:
            recipe = self._getRecipe(d)
            if recipe in self.whiteList:
                # Do not process whitelisted dependencies.
                continue
            if d in chain:
                # Take away possible loops.
                continue

            # print(str(chain) + " -> " + d + ": " + str(rundeps))

            licenses = self._parseLicenseString(self._getLicenses(d))

            children = self._findChildren(d, chain + [d])
            childNode = LicenseNode(licenses, children, d)

            results.append(childNode)

        return results

    # Public API methods: propagate, createTree and testPackage.

    def propagate(self, node):
        """Propagate licenses for a runtime dependency tree.


        Set value to 'propagated' for every node in the runtime
        dependency tree (with parameter 'node' as root). The value will
        be the calculated set of possible runtime licenses. If a value
        is empty after this call, the runtime licensing script was not
        able to find a suitable license for this package (or one of its
        dependencies). Missing the license from the licence maps is a
        common reason for this.
        """

        childNodes = node.children
        if len(childNodes) == 0:
            # Push local constraints up!

            # If some licenses are prohibited, just don't propagate them.
            node.propagated = node.licenses.copy()

            for p in self.prohibited:
                if p in node.propagated:
                    node.propagated.remove(p)

            return node.propagated.copy()

        constraints = []

        for childNode in childNodes:
            constraints.append(self.propagate(childNode))

        cs = self._calculateConstraints(constraints, node.licenses, set())

        node.propagated = cs.copy()
        return cs

    def createTree(self, package):
        """Create a runtime dependency tree for a package.

        Return a runtime dependency tree for package in 'package'
        parameter.
        """

        rundeps = self._getRdeps(package)

        licenses = self._parseLicenseString(self._getLicenses(package))

        children = self._findChildren(package, [package])
        root = LicenseNode(licenses, children, package)

        return root

    def testPackage(self, package):
        """Test whether a package passes the license check.

        Return True if the package in 'package' parameter passes the
        license check. Return False if the license check fails. This is
        a helper method using 'createTree' and 'propagate' methods.
        """

        tree = self.createTree(package)
        if tree:
            licenses = self.propagate(tree)
            if licenses:
                return True
            else:
                # did not find a suitable license, print the tree for debugging
                print("No suitable license found for %s:" % package)
                tree.printTree()
        else:
            print("No such package (%s)" % package)
        return False
