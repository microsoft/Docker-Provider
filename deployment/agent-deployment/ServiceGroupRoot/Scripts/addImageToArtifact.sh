#!/bin/bash

echo "Adding Agent Image Tarball to existing artifact.tar.gz for Ev2 Shell Script"

ls

tar rvf ../artifacts.tar.gz ../drop/outputs/package/agentimage.tar.gz

ls

"Finished adding Agent Image Tarball"