# base-tools-debian

Howdy!

This repository builds the base docker image used by [PhotoStructure for
Docker](https://photostructure.com/server/photostructure-for-docker/) with a
Debian (rather than Alpine) base image. [The
Alpine-based base image is
here.](https://github.com/photostructure/base-tools)

The image compiles static binaries of [LibRaw](https://www.libraw.org/), [SQLite](https://sqlite.org/), and [jpegtran](https://libjpeg-turbo.org/) from pinned commits, placed in `/opt/photostructure/tools/`. These same binaries are also extracted by PhotoStructure's `tools/Dockerfile` for Desktop and Node editions that are based on glibc.

Using this base image has a bunch of pros and cons:

Pros:

- Some external tools are only compatible with Debian/glibc. For example, CUDA hardware acceleration may be easier on Debian than on Alpine.

Cons:

- The Debian image is many MB larger than the Alpine image

See <https://photostructure.com/server/photostructure-for-docker/> and
<https://photostructure.com/> for more information.
