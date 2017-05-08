# This class can be inherited by an arbitrary image recipe to install
# the "image-installer" command plus one or more image files into the
# image.
#
# Basically that turns the image using image-installer.bbclass into an
# "installer image" which can be booted from a removable media to
# install those other images permanently onto internal storage of a
# device.
#
# The "image-installer" is a shell script that gets assembled from
# several fragments provided by image-installer.bbclass, by the distro
# or by the image recipe. The expected usage is that distros using
# image-installer.bbclass will heavily customize the final script.
#
# Because the shell code is embedded in the recipe, regular bitbake
# variables can be injected easily and the shell syntax is checked
# already by the bitbake parser. The downside is that we are limited
# to shell code that the bitbake parser understands (no bash
# extensions, for example) and error reports about the shell syntax
# are a bit hard to read.

# INSTALLER_SOURCE_IMAGES contains one or more entries of the format
# <other image recipe name>:<image suffix> which then get copied into
# the rootfs of this image under INSTALLER_IMAGE_DATADIR for use by
# the installer script.
#
# The actual installer code and the input format are tightly coupled,
# so installer code below is just a fake stub which needs to be replaced
# with something that supports both the source images and the target
# hardware.
INSTALLER_SOURCE_IMAGES ??= ""

INSTALLER_IMAGE_DATADIR = "${libdir}/image-installer"
INSTALLER_BINARY = "${IMAGE_ROOTFS}${sbindir}/image-installer"

# Sanity check INSTALLER_SOURCE_IMAGES once.
python () {
    for entry in d.getVar('INSTALLER_SOURCE_IMAGES').split():
        components = entry.split(':')
        if len(components) != 2:
            bb.fatal('%s in INSTALLER_SOURCE_IMAGES must have the format <image recipe name>:<image suffix>' % entry)
}

python install_images () {
    import os
    import shutil
    import subprocess
    import stat

    deploy_dir_image = d.getVar('DEPLOY_DIR_IMAGE')
    install_dir = oe.path.join(d.getVar('IMAGE_ROOTFS'), d.getVar('INSTALLER_IMAGE_DATADIR'))
    machine = d.getVar('MACHINE')
    for image, suffix in [x.split(':') for x in d.getVar('INSTALLER_SOURCE_IMAGES').split()]:
        imagename = '%s-%s.%s' % (image, machine, suffix)
        path = os.path.join(deploy_dir_image, imagename)
        if not os.path.exists(path):
            bb.fatal('Image %s for INSTALLER_SOURCE_IMAGES entry %s:%s not found.' % (path, image, suffix))
        subprocess.check_output(['install', '-d', install_dir])
        # Preserve the symbolic links, because that makes images available
        # under a constant name while also keeping the information about the
        # exact version of the image which got included.
        dest = os.path.join(install_dir, imagename)
        if os.path.islink(path):
            link_dest = os.path.basename(os.readlink(path))
            os.symlink(link_dest, dest)
            os.lchown(dest, 0, 0)
            dest = os.path.join(os.path.dirname(dest), link_dest)
            path = os.path.realpath(path)
        # Hard-linking both saves space during the build *and*
        # sparseness of the image file. The fallback doesn't, but shouldn't
        # be needed most of the time.
        try:
            os.link(path, dest)
        except IOError as ex:
            bb.warn('Hard-linking from %s to %s failed. Falling back to full copy, which looses sparseness: %s' %
                    (path, dest, str(ex)))
            shutil.copy2(path, dest)
        # We run under pseudo, so chown/chmod does not really change the attributes
        # of the original image file.
        os.chown(dest, 0, 0)
        mode = stat.S_IRUSR | stat.S_IRGRP | stat.S_IROTH
        os.chmod(dest, mode)
}
do_rootfs[depends] += "${@ ' '.join([x.split(':')[0] + ':do_image_complete' for x in '${INSTALLER_SOURCE_IMAGES}'.split()]) }"
do_rootfs[postfuncs] += " install_images "


# The default installer can be used interactively or
# configured to run automatically by setting environment
# variables in advance.
#
# The flow is:
# - determine which image is to be installed
# - determine which disks are suitable as target, automatically
#   filtering out the boot disk and everything that is read-only
#   or completely unusable (removable media)
# - determine which target to install to
# - execute installation
#
# See below for the commands used by each step.
#
# The default installer code is free of bashisms and passed
# checks with checkbashisms.pl and shellsheck. The "local"
# keyword (although supported by bash and dash) is avoided
# in favor of wrapping function bodies with local variables
# in a subshell.
INSTALLER_DEFAULT () {
#!/bin/sh -e

${INSTALLER_LOGGING}
${INSTALLER_UTILS}
${INSTALLER_PICK_INPUT}
${INSTALLER_FIND_OUTPUT}
${INSTALLER_PICK_OUTPUT}
${INSTALLER_INSTALL}

pick_input
find_output
pick_output
install_image
info "Installed $CHOSEN_INPUT on $CHOSEN_OUTPUT successfully."
}

INSTALLER ??= "${INSTALLER_DEFAULT}"

# Ensure that whatever runtime tools are needed by the installer
# script are actually in the image.
INSTALLER_RDEPENDS ??= " \
    util-linux \
"
IMAGE_INSTALL_append = " ${INSTALLER_RDEPENDS}"

# Installs whatever is contained in ${INSTALLER} as ${INSTALLER_BINARY}.
python install_installer () {
    import stat

    destfile = d.getVar('INSTALLER_BINARY')
    bb.utils.mkdirhier(os.path.dirname(destfile))
    with open(destfile, 'w') as f:
        f.write(d.getVar('INSTALLER'))
    os.chown(destfile, 0, 0)
    mode = stat.S_IRUSR | stat.S_IRGRP | stat.S_IROTH | \
        stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH
    os.chmod(destfile, mode)
}
do_rootfs[postfuncs] += " install_installer "

# Utility code for reporting to the user of the script.
INSTALLER_LOGGING[shellcheck] = "sh"
INSTALLER_LOGGING () {
    fatal () {
        echo >&2 "ERROR: $*"
        exit 1
    }

    error () {
        echo >&2 "ERROR: $*"
    }

    info () {
        echo >/dev/tty "$*"
    }
}

# Cleanup handling, common code for selecting among different input and output
# options interactively, etc.
INSTALLER_UTILS[shellcheck] = "sh"
INSTALLER_UTILS () {
    # Skip user interaction. Can be set also in the environment before
    # calling the script.
    FORCE=${FORCE:-no}

    # Checks whether a variable is "yes" or "no", then returns
    # with 0 when "yes". Uses fatal() and thus exits for other values.
    istrue () {
        istrue_var=$1
        eval istrue_value="\$$istrue_var"
        case "$istrue_value" in
            yes) return 0;;
            no) return 1;;
            *) fatal "$istrue_var should have been set to yes or no: $istrue_value"
        esac
    }

    # log and run a command
    execute () {
        info "Running: $*"
        "$@"
    }

    # cleanup commands which are to be run when exiting
    CLEANUP_CMDS=
    add_cleanup () {
       CLEANUP_CMDS="$*; $CLEANUP_CMDS"
    }
    remove_cleanup () {
       CLEANUP_CMDS=$(echo "$CLEANUP_CMDS" | sed -e "s|$*; ||")
    }
    cleanup () {
        eval "$CLEANUP_CMDS"
    }
    trap cleanup EXIT

    pick_option () (
        ambiguous_msg="$1"; shift
        prompt="$1"; shift
        chosen="$1"; shift
        num_options=$#

        # If something was set already, just use it.
        if [ "$chosen" ]; then
            echo "$chosen"
            return
        fi

        if istrue FORCE; then
            if [ "$num_options" -ne 1 ]; then
                fatal "$ambiguous_msg, cannot proceed: $*"
            fi
            echo "$1"
        else
            while true; do
                if [ "$num_options" -eq 0 ]; then
                    printf >/dev/tty "%s" "$prompt [no defaults]: "
                    read answer
                    if [ "$answer" ]; then
                        echo "$answer"
                        return
                    fi
                else
                    printf >/dev/tty "%s" "$prompt ["
                    i=0
                    for option in "$@"; do
                        if [ $i -eq 0 ]; then
                            printf >/dev/tty "%s" "(RETURN) = (0) = $option"
                        else
                            printf >/dev/tty "%s" ", ($i) = $option"
                        fi
                        i=$( expr $i + 1 )
                    done
                    printf >/dev/tty "%s" "]: "

                    get_option () (
                        number=$1; shift
                        i=0
                        for option in "$@"; do
                            if [ $i -eq "$number" ]; then
                               echo "$option"
                               return 0
                            fi
                            i=$( expr $i + 1 )
                        done
                        error "$answer is not a valid shortcut number, try again."
                        return 1
                    )

                    read answer
                    if [ ! "$answer" ]; then
                        get_option 0 "$@" && return
                    elif echo "$answer" | grep -q -e '^[0-9]*$'; then
                        # Might be an invalid number, so do not return unconditionally!
                        get_option "$answer" "$@" && return
                    else
                        echo "$answer"
                        return
                    fi
                fi
            done
        fi
    )

    confirm_install () (
        if ! istrue FORCE; then
            while true; do
                printf "%s" 'Proceed? Type "yes" to confirm and "no" to abort: '
                read answer
                case $answer in
                    yes) break;;
                    no) info "Aborting as requested."; return 1;;
                esac
            done
        fi
    )
}

INSTALLER_PICK_INPUT[shellcheck] = "sh"
INSTALLER_PICK_INPUT () {
    # We know what's going to be available, therefore we don't need code which looks
    # for images.
    AVAILABLE_INPUT="${@ ' '.join(['%s-${MACHINE}.%s' % (image, suffix) for image, suffix in [x.split(':') for x in d.getVar('INSTALLER_SOURCE_IMAGES').split()]])}"
    CHOSEN_INPUT="${CHOSEN_INPUT:-}"

    pick_input () {
        # shellcheck disable=SC2086
        CHOSEN_INPUT=$(pick_option "ambiguous input images" "Pick an image file" "$CHOSEN_INPUT" $AVAILABLE_INPUT) || exit 1
    }
}


INSTALLER_FIND_OUTPUT[shellcheck] = "sh"
INSTALLER_FIND_OUTPUT () {
    AVAILABLE_OUTPUT=""

    _find_output () (
        # Find block devices and filter out our boot device and read-only devices.
        root_device=$(findmnt / --output SOURCE --noheadings)
        # Might have been a symlink.
        root_device=$(readlink -f "$root_device")
        info "Boot device is $root_device."
        if [ "$root_device" ]; then
            # lsblk knows about the device topology and orders accordingly
            # when the NAME column is enabled. Here we are relying on the
            # fact that dependent items appear below the disk they are
            # rooted in.
            # shellcheck disable=SC2034
            exclude=$( lsblk --output NAME,KNAME,TYPE --ascii --noheadings | while read name kname type; do
                if [ "$type" = "disk" ]; then
                    disk=$kname
                fi
                if [ "/dev/$kname" = "$root_device" ]; then
                    echo "$disk"
                    break
                fi
            done )
        fi

        # ignore:
        # boot device,
        # CD-ROM,
        # devices which aren't readable (for example removable device with no media)
        AVAILABLE_OUTPUT=$( lsblk --nodeps --output KNAME,TYPE --noheadings | while read kname type; do
            if [ "$kname" != "$exclude" ] &&
               [ "$type" != "rom" ] &&
               dd "if=/dev/$kname" of=/dev/null bs=1 count=1 2>/dev/null; then
                printf " %s" "$kname"
            fi
        done )
        info "Found the following additional disk(s):$AVAILABLE_OUTPUT"
        echo "$AVAILABLE_OUTPUT"
    )
    find_output () {
        AVAILABLE_OUTPUT=$(_find_output)
    }
}

INSTALLER_PICK_OUTPUT[shellcheck] = "sh"
INSTALLER_PICK_OUTPUT () {
    CHOSEN_OUTPUT=${CHOSEN_OUTPUT:-}
    pick_output () {
        # shellcheck disable=SC2086
        CHOSEN_OUTPUT=$(pick_option "ambiguous target devices" "Pick a target device" "$CHOSEN_OUTPUT" $AVAILABLE_OUTPUT) || exit 1
    }
}

# This is a non-functional stub which needs to be replaced.
INSTALLER_EMPTY[shellcheck] = "sh"
INSTALLER_EMPTY () {
    install_image () (
        input="${INSTALLER_IMAGE_DATADIR}/$CHOSEN_INPUT"
        output="/dev/$CHOSEN_OUTPUT"
        info "Installing from $input to $output."

        confirm_install || exit 1
        fatal "installation not implemented"
    )
}
INSTALLER_INSTALL ??= "${INSTALLER_EMPTY}"
