#! /bin/bash

set -e -x

make -f Makefile.repo
make package

# run the osc source validator to check the .spec and .changes locally
(cd package && /usr/lib/obs/service/source_validator)

# Build the binary package locally, use plain "rpmbuild" to make it simple.
# "osc build" is too resource hungry (builds a complete chroot from scratch).
# Moreover it does not work in a Docker container (it fails when trying to mount
# /proc and /sys in the chroot).
cp package/* /usr/src/packages/SOURCES/
rpmbuild -bb --with coverage -D "jobs `nproc`" package/*.spec

# test the %pre/%post scripts by installing/updating/removing the built packages
# ignore the dependencies to make the test easier, as a smoke test it's good enough
rpm -iv --force --nodeps /usr/src/packages/RPMS/*/*.rpm
rpm -Uv --force --nodeps /usr/src/packages/RPMS/*/*.rpm

# smoke test, make sure snapper at least starts
snapper --version

# Run the integration test
# Running it in the source tree ensures that the coverage report finds it
pushd /usr/src/packages/BUILD/snapper-*/testsuite-real
./setup-and-run-all
popd

# Coverage report
pushd /usr/src/packages/BUILD/snapper-*
make coverage
popd
# Must call coveralls-lcov from the git directory
BUILDDIR=(/usr/src/packages/BUILD/snapper-*) # expand glob
make -f Makefile.repo coveralls BUILDDIR="${BUILDDIR[@]}"

# get the plain package names and remove all packages at once
rpm -ev --nodeps `rpm -q --qf '%{NAME} ' -p /usr/src/packages/RPMS/**/*.rpm`
