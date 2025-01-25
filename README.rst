Bazzite Kernel
==============

This repository contains the Bazzite kernel, built directly
from the Fedora Always Ready Kernel
(`kernel-ark <https://gitlab.com/cki-project/kernel-ark>`__) repository.

The repository itself or the build process have had no changes, with the
one addition being the large set of handheld and performance
optimization patches Bazzite users have come to expect. These include
the latest in handheld compatibility patches (OneXPlayer, ROG Ally,
Steam Deck LCD/OLED, Surface devices), as well as the scheduler BORE.

Those patches are applied directly on top of the Fedora patchset
`here <./handheld.patch>`__, after being rebased on top of the ARK
kernel tree in the patchwork
`repo <https://github.com/hhd-dev/patchwork>`__.

To make it Github friendly, this repository contains actions and
containers to build the kernel and generate the RPMs in Github. As a
bonus point, each release includes a repackaged version of the kernel
for Arch.

Installing
----------

Fedora is TODO. Of course, you can always install Bazzite :).

For Arch, you can install the kernel from releases by downloading it and
running ``sudo pacman -U <file>``:

.. code:: bash

   # Find linux-bazzite-X.bazzite.fc41-1-x86_64.pkg.tar.zst, right click, copy.
   wget https://github.com/hhd-dev/kernel-bazzite/releases/download/6.11.3-303.2/linux-bazzite-6.11.3.300.bazzite.fc41-1-x86_64.pkg.tar.zst
   sudo pacman -U linux-bazzite-6.11.3.300.bazzite.fc41-1-x86_64.pkg.tar.zst

Contributing
------------

If you find that a patch is missing, or you have a patch that you think
should be included, please open an issue with a link to the patch or
the lore.

DO NOT OPEN A PULL REQUEST. The `handheld.patch` file is generated
automatically from the patchwork repository, and any changes to it
will be overwritten.