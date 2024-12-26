#!/usr/bin/env bash
rsync -haP --delete /home/icy/Documents/codes/git/kdl-org/kdl/tests/test_cases/input/ /home/icy/Documents/codes/IceDragon/ex/kuddle/test/fixtures/v2/test_cases/input
rsync -haP --delete /home/icy/Documents/codes/git/kdl-org/kdl/tests/test_cases/expected_kdl/ /home/icy/Documents/codes/IceDragon/ex/kuddle/test/fixtures/v2/test_cases/output
