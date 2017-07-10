Handling System Updates Using OSTree
####################################

IoT Reference OS Kit ('refkit') has support for updating devices running
one of the refkit profile images using an HTTP/HTTPs server and OSTree.
OSTree is a library and suite of command line tools, largely inspired by
git, that provides version control and a distribution mechanism for bootable
OS filesystem trees, or other binaries. For a comprehensive introduction
to OSTree, an overview of its architecture and feature set, please refer
to its `documentation <http://ostree.readthedocs.io>_`.

If enabled, OSTree support in refkit

 * provides A/B-versioning (within a single block device partition)
 * creates a per-image OSTree repository for each image built
 * exposes builds in a common OSTree repository as a series of commits
 * can sign each commit (which is then verified during updates)
 * can provide a service for automatic image updates


Enabling OSTree Support
#######################

To enable end-to-end OSTree support with automatic image updates, you will
need to

 * enable OSTree support for your builds
 * ideally generate and use a pair of signing keys for your builds/updates
 * expose the OSTree repository of your builds over HTTP/HTTPS
 * point your clients to the exposed OSTree repository

To enable OSTree support, turn on the 'ostree' image feature. You can
do this by incuding the following configuration snippet in your local.conf
or other suitable global configuration file::

    REFKIT_IMAGE_EXTRA_FEATURES += "ostree"

To use your GPG signing key pair for signing and verifying the OSTree
repository commits, assuming your keys are in the keyrings in <gpg-home>
with key ID release@example.org, add the following to your local.conf or
other suitable global Yocto configuration file::

    OSTREE_GPGDIR = "<gpg-home>"
    OSTREE_GPGID  = "release@example.org"

Assuming you want to use your build machine, build.example.org, in this
example also as your update server, you can readily point the image for
updates to your update/build server by adding the following to your
local.conf or other suitable global configuration file::

    OSTREE_REMOTE = "http://build.example.org/ostree/"

You can also use HTTPS instead of HTTP if you want to and your server is
properly configured for serving HTTPS requests.

Next you need to expose the OSTree repository your builds are exported to
over HTTP/HTTPS for clients to consume. By default this repository is
located in build/tmp-glibc/deploy/ostree-repo, but you can change this
location by adding the following to your local.conf or other suitable
global configuration file::

    OSTREE_EXPORT = "<path-to-the-repository>"

Now assuming, you did not change the location, and you use Apache for
service HTTP/HTTPS requests, you can expose this repository with Apache
by adding the following to your Apache configuration::

    Alias "/ostree/" "<path-to-intel-iot-refkit>/build/tmp-glibc/deploy/ostree-repo/"
    
    <Directory <path-to-inte-iot-refkit>/build/tmp-glibc/deploy/ostree-repo>
        Options Indexes FollowSymLinks
        Require all granted
    </Directory>

Finally you should restart (or start) your Apache server to activate the
configuration changes. This might be a good time to also make sure that
any firewall rules you might have will allow your clients access to the
HTTP port of the server.

Another alternative is to use the built-in trivial HTTP server in ostree
available as the *ostree trivial-httpd* command (if it is enabled at
compile time). With that you could serve out the repository with the
following commands::

    cd build/tmp-glibc/deploy
    ln -sf ostree-repo ostree
    ostree trivial-httpd --port 80

A third alternative is use a simple Python HTTP server, for instance the
one from the project at::

    http://git.yoctoproject.org/cgit/cgit.cgi/poky/tree/meta/lib/oeqa/utils/httpserver.py

which is also available in the refkit source tree as::

    openembedded-core/meta/lib/oeqa/utils/httpserver.py

Now with teh above configuration in place, and an HTTP server running,
subsequent builds should get automatically exported and pulled in as
updates by the clients running one of your refkit images.


Disabling Automatic Updates
###########################

If you prefer not to pull in updates automatically to the clients, disable
the refkit-update systemd service. You can do this by running the following
command on the client device::

    systemctl stop refkit-update.service
    systemctl disable refkit-update.service


Pulling In Updates Manually
###########################

If you want to manually pull any potentially available updates, you can do
so by running the following command on a client device::

    refkit-ostree-update --one-shot

This will check the server for available updates, pull in any such one,
and request a reboot to activate the changes if the update was successfully
installed.


Preventing/Delaying Automatic Reboot
####################################

Note that by default after an update has been installed the system will be
rebooted to activate the latest changes. Any entity that needs to prevent
or delay the reboot to a more convenient time in the future should use
systemd-inhibit or the corresponding systemd(-logind) interfaces for doing
so.

For instance, if you have an interactive shell (or a login session via ssh)
while the updater is running, or you are running it yourself manually, and
you don't want the system to get rebooted under you in case an update does
get pulled in, you should do a::

    systemd-inhibit --what=shutdown $SHELL

Once you're done with whatever you were doing and want to allow any pending
updates to proceed to reboot, you can simply exit the innermost shell.

