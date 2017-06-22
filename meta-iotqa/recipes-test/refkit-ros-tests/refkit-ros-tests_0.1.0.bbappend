inherit deploy-files
DEPLOY_FILES_FROM[target] = "${WORKDIR}/sysroot-destdir/opt"

# Originally deploy_files gets added before do_build, but we need
# to copy full package onto SUT thus run the task after do_build.
deltask deploy_files
addtask deploy_files after do_build
