#!/usr/bin/env bash

# Quick and dirty. From the first part of a chunked .tar file containing a
# .txt.gz file, estimates the uncompressed size of the .txt.

set -e

TAR_FILE_NAME=sources/ebird/ebd_relApr-2020.tar.part0000

echo "Tar archive: $TAR_FILE_NAME"
GZ_FILE_NAME=$(python -c "import tarfile; print(tarfile.open('$TAR_FILE_NAME').next().name)")
echo "First file inside archive: $GZ_FILE_NAME"
COMPRESSED_SIZE=$(python -c "import tarfile; print(tarfile.open('$TAR_FILE_NAME').next().size)")
echo "Compressed total size: $COMPRESSED_SIZE"
COMPRESSED_CHUNK_SIZE=$(stat -c%s $TAR_FILE_NAME)
echo "Compressed size of first chunk: $COMPRESSED_CHUNK_SIZE"
UNCOMPRESSED_CHUNK_SIZE=$(tar -Oxf "$TAR_FILE_NAME" "$GZ_FILE_NAME" | pigz -cd | wc -c)
echo "Uncompressed size of first chunk: $COMPRESSED_SIZE"
UNCOMPRESSED_SIZE=$(python -c "print(round($COMPRESSED_SIZE * $UNCOMPRESSED_CHUNK_SIZE / $COMPRESSED_CHUNK_SIZE))")
echo "Estimated uncompressed total size: $UNCOMPRESSED_SIZE"
