#!/bin/bash

set -o pipefail
set -eux

display_usage() {
    cat <<EOT
Build script to start the docker build of fuse-console-operator.
Pass in the tag from the hawtio-operator repository to build.

Usage: build-image.sh [options] -t <hawtio-operator-tag> -v <hawtio-operator-version>

with options:

-d, --dry-run   Run without committing and changes or running in OSBS.
--scratch       Build OSBS image in scratch mode.
--help          This help message
EOT
}

cleanup() {
    rm -f hawtio-operator-*.tar.gz
    rm -rf hawtio-operator 2> /dev/null || true
}

update_commit_id() {
    local projectTag=$1
    local dryRun=$2

    commitId=$(git ls-remote -q --refs https://code.engineering.redhat.com/gerrit/hawtio/hawtio-operator ${projectTag} | cut -f 1 )

    echo "Updating container.yaml for tag ${projectTag} with commit ID ${commitId}"
    sed -i "s/ref:.*$/ref: $commitId/" container.yaml

    if [ "$dryRun" == "false" ]
    then
        git add container.yaml
    fi
}

osbs_build() {
    local version=$1
    local scratchBuild=$2

    num_files=$(git status --porcelain  | { egrep '^\s?[MADRC]' || true; } | wc -l)
    if ((num_files > 0)) ; then
        echo "Committing $num_files"
        git commit -m"Updated for build of fuse-console-operator $version"
        git push
    else
        echo "There are no files to be committed. Skipping commit + push"
    fi

    if [ "$scratchBuild" == "false" ]
    then
        echo "Starting OSBS build"
        rhpkg container-build
    else
        local branch=$(git rev-parse --abbrev-ref HEAD)
        local build_options=""

        # If we are building on a private branch, then we need to use the correct target
        if [[ $branch == *"private"* ]] ; then
            # Remove the private part of the branch name: from private-opiske-fuse-7.4-openshift-rhel-7
            # to fuse-7.4-openshift-rhel-7 and we add the containers candidate to the options
            local target="${branch#*-*-}-containers-candidate"

            build_options="${build_options} --target ${target}"
            echo "Using target ${target} for the private container build"
        fi

        echo "Starting OSBS scratch build"
        rhpkg container-build --scratch ${build_options}
    fi
}

main() {
    TAG=
    VERSION=
    DRY_RUN=false
    SCRATCH=false

    # Parse command line arguments
    while [ $# -gt 0 ]
    do
        arg="$1"

        case $arg in
          -h|--help)
            display_usage
            return 0
            ;;
          -d|--dry-run)
            DRY_RUN=true
            ;;
          --scratch)
            SCRATCH=true
            ;;
          -t|--tag)
            shift
            TAG="$1"
            ;;
          -v|--version)
            shift
            VERSION="$1"
            ;;
          *)
            echo "Unknonwn argument: $1"
            display_usage
            return 1
            ;;
        esac
        shift
    done

    # Check that console tag is specified
    if [ -z "$TAG" ]
    then
        echo "ERROR: Hawtio-operator tag wasn't specified."
        return 1
    fi

    update_commit_id $TAG $DRY_RUN

    if [ "$DRY_RUN" == "false" ]
    then
        osbs_build $VERSION $SCRATCH
    fi

    cleanup
}

main $*