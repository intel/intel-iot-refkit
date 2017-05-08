# Copyright (c) 2017, Intel Corporation.
# All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# DESCRIPTION
# This source plugin can be used for a partition following sometime after
# the main rootfs in a wic file to generate a partition containing
# dm-verity hash data for the rootfs.
#
# AUTHORS
# Patrick Ohly
#

import base64
import glob
import logging
import os
import re
import shutil
import tempfile

from wic import WicError
from wic.pluginbase import SourcePlugin
from wic.utils.misc import (exec_cmd, exec_native_cmd, get_bitbake_var)

logger = logging.getLogger('wic')

class DMVerityPlugin(SourcePlugin):
    """
    Creates dm-verity hash data for one rootfs partition, as identified by
    the --label parameter.
    """

    name = 'dm-verity'

    @classmethod
    def do_prepare_partition(cls, part, source_params, creator, cr_workdir,
                             oe_builddir, bootimg_dir, kernel_dir,
                             rootfs_dir, native_sysroot):
        """
        Called to do the actual content population for a partition i.e. it
        'prepares' the partition to be incorporated into the image.
        In this case, locate the temporary root partition and hash it.
        """

        # We rely on the --label parameter and the naming convention
        # in partition.py prepare_rootfs() here to find the already
        # prepared rootfs partition image.
        pattern = '%s/rootfs_%s.*' % (cr_workdir, part.label)
        rootfs = glob.glob(pattern)
        if len(rootfs) != 1:
            raise WicError("%s shell pattern does not match exactly one rootfs image (missing --label parameter?): %s" % (pattern, rootfs))
        else:
            rootfs = rootfs[0]
        logger.debug("Calculating dm-verity hash for rootfs %s (native %s)." % (rootfs, native_sysroot))

        hashimg = '%s/dm-verity_%s.img' % (cr_workdir, part.label)
        # Reserve some fixed amount of space at the start of the hash image
        # for our own data (in particular, the signed root hash).
        # The content of that part is:
        # roothash=<....>
        # <potentially some more assignments in the future>
        # signature=<single line of base64 encoded OpenSSL sha256 digest>
        header_size = 4096
        ret, out = exec_native_cmd("veritysetup format '%s' '%s' --hash-offset=%d" %
                                   (rootfs, hashimg, header_size),
                                   native_sysroot)
        m = re.search(r'^Root hash:\s*(\S+)$', out, re.MULTILINE)
        if ret or not m:
            raise WicError('veritysetup failed: %s' % out)
        else:
            root_hash = m.group(1)
            privkey = get_bitbake_var('REFKIT_DMVERITY_PRIVATE_KEY')
            password = get_bitbake_var('REFKIT_DMVERITY_PASSWORD')
            tmp = tempfile.mkdtemp(prefix='dm-verity-')
            try:
                data_filename = os.path.join(tmp, 'data')
                header = ('roothash=%s\nheadersize=%d\n' % (root_hash, header_size)).encode('ascii')
                with open(data_filename, 'wb') as data:
                    data.write(header)
                # Must use a temporary file, exec_native_cmd() only supports UTF-8 output.
                signature = os.path.join(tmp, 'sig')
                ret, out = exec_native_cmd("openssl dgst -sha256 -passin '%s' -sign '%s' -out '%s' '%s'" %
                                           (password, privkey, signature, data_filename),
                                           native_sysroot)
                if ret:
                    raise WicError('openssl signing failed')
                with open(signature, 'rb') as f:
                    header += b'signature=' + base64.standard_b64encode(f.read()) + b'\n'
                if len(header) + 1 >= header_size:
                    raise WicError('reserved space for dm-verity header too small')
                with open(hashimg, 'rb+') as hash:
                    hash.write(header)
            finally:
                shutil.rmtree(tmp)

            data_bytes = os.stat(rootfs).st_size
            hash_bytes = os.stat(hashimg).st_size
            logger.debug("dm-verity data partition %d bytes, hash partition %d bytes, ratio %f." %
                        (data_bytes, hash_bytes, data_bytes / hash_bytes))
            part.size = data_bytes // 1024
            part.source_file = hashimg
