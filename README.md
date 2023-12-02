# base-tools-debian

Howdy!

This repository builds the base docker image used by [PhotoStructure for
Docker](https://photostructure.com/server/photostructure-for-docker/) with a
Debian (rather than Alpine) base image. [The
Alpine-based base image is
here.](https://github.com/photostructure/base-tools)

Using this base image has a bunch of pros and cons:

Pros:

- There are many more `ffmpeg` codecs installed in the Debian image, so more video and audio formats are supported, but they seem to be mostly archaic.

- Some external tools are only compatible with Debian/glibc. For example, CUDA hardware acceleration may be easier on Debian than on Alpine.

Cons:

- The Debian image is 300+ MB larger than the Alpine image

- Alpine has newer versions of many tools. For example, Alpine has FFMpeg 5.1, Debian Bullseye is on 4.3.


See <https://photostructure.com/server/photostructure-for-docker/> and
<https://photostructure.com/> for more information.