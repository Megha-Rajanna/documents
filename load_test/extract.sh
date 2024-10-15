#!/bin/bash
# Extract Instana load test results

# Get the list of tarballs to extract
for TARBALL in $(ls *.tar);
do
    # Get the experiment directory name
    DIR_NAME=$(echo ${TARBALL} | cut -d_ -f3)

    # Try creating the directory, ignore if already present
    mkdir -p ${DIR_NAME}

    echo "Extracting ${TARBALL}..."
    tar xf ${TARBALL} -C ${DIR_NAME}
done

