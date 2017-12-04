from oeqa.selftest.systemupdate.httpupdate import HTTPUpdate

import os

class RefkitOSTreeUpdateBase(HTTPUpdate):
    """
    System update tests for refkit-image-common using OSTree.
    """

    # We test the normal refkit-image-common with
    # OSTree system update enabled.
    IMAGE_PN = 'refkit-image-update-ostree'
    IMAGE_PN_UPDATE = IMAGE_PN
    IMAGE_BBAPPEND = IMAGE_PN + '.bbappend'
    IMAGE_BBAPPEND_UPDATE = IMAGE_BBAPPEND

    def setUp(self):
        # We cannot get the actual OSTREE_REPO for the
        # image here, so we just assume that it is in the usual place.
        self.REPO_DIR = os.path.join(HTTPUpdate.BB_VARS['DEPLOY_DIR'], 'ostree-repo')
        super().setUp()

    def stop_update_service(self, qemu):
        cmd = '''systemctl stop refkit-update.service'''
        status, output = qemu.run_serial(cmd, timeout=600)
        self.assertEqual(1, status, 'Failed to run command "%s":\n%s' % (cmd, output))
        self.logger.info('Successfully stopped refkit-update systemd service:\n%s' % output)
        return True

    def update_image(self, qemu):
        # We need to stop the refkit-udpate systemd service before starting
        # the HTTP server (and thus making any update available) to prevent
        # the service from racing with us and potentially winning, doing a
        # full update cycle including a final reboot.
        self.stop_update_service(qemu)

        return super().update_image(qemu)

    def update_image_via_http(self, qemu):
        # Use the updater, refkit-ostree-update, in a one-shot mode
        # attempting just a single update cycle for the test case.
        # Also override the post-apply hook to only run the UEFI app
        # update hook. It is a bit of a hack but we don't want the rest
        # of the hooks run, especially not the reboot hook, to avoid
        # prematurely rebooting the qemu instance and this is the easiest
        # way to achieve just that for now.
        cmd = '''ostree config set 'remote "updates".url' http://%s && refkit-ostree-update --one-shot --post-apply-hook /usr/share/refkit-ostree/hooks/post-apply.d/00-update-uefi-app''' % self.HTTPD_SERVER
        status, output = qemu.run_serial(cmd, timeout=600)
        self.assertEqual(1, status, 'Failed to run command "%s":\n%s' % (cmd, output))
        self.logger.info('Successful (?) update with %s:\n%s' % (cmd, output))
        return True


class RefkitOSTreeUpdateTestAll(RefkitOSTreeUpdateBase):
    def test_update_all(self):
        """
        Test all possible changes at once.
        """
        self.do_update('test_update_all', self.IMAGE_MODIFY.UPDATES)

class RefkitOSTreeUpdateMeta(type):
    """
    Generates individual instances of test_update_<update>, one for each type of change.
    """
    def __new__(mcs, name, bases, dict):
        def add_test(update):
            test_name = 'test_update_' + update
            def test(self):
                self.do_update(test_name, [update])
            dict[test_name] = test
        for update in RefkitOSTreeUpdateBase.IMAGE_MODIFY.UPDATES:
            add_test(update)
        return type.__new__(mcs, name, bases, dict)

class RefkitOSTreeUpdateTestIndividual(RefkitOSTreeUpdateBase, metaclass=RefkitOSTreeUpdateMeta):
    pass

class RefkitOSTreeUpdateTestDev(RefkitOSTreeUpdateTestAll, metaclass=RefkitOSTreeUpdateMeta):
    """
    This class avoids rootfs rebuilding by using two separate image
    recipes. It's using slight tricks like overriding the OSTREE_BRANCH,
    so the other tests are more realistic. Use this one when debugging problems.
    """

    IMAGE_PN_UPDATE = 'refkit-image-update-ostree-modified'
    IMAGE_BBAPPEND_UPDATE = IMAGE_PN_UPDATE + '.bbappend'
