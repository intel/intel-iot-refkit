#!/usr/bin/env python
#
# parse_changelog.py: Parse changelog.xml file and write it to changelog.txt.
#
# Copyright (c) 2017, Intel Corporation.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#

import sys

changelog_file = sys.argv[1]
with open(changelog_file, "r") as f:
    new_commit = 0
    commit_count = 0
    changes = f.read().split("\n")
    commits = ""
    for line in changes:
        if not line:
            pass
        elif line[0].isspace() and new_commit:
            commits += line + "\n"
            new_commit = 0
            commit_count += 1
        elif not line[0].isspace():
            new_commit = 1

with open("changelog.txt", "w") as f:
    if commit_count == 1:
        f.write("This build added one commit:\n\n")
    else:
        f.write("This build added " + str(commit_count) + " commits:\n\n")
    f.write(commits)
