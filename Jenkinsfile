#!groovy
//
// Jenkins Pipeline script to produce builds and run tests
//
// Copyright (c) 2016, Intel Corporation.
//
// This program is free software; you can redistribute it and/or modify it
// under the terms and conditions of the GNU General Public License,
// version 2, as published by the Free Software Foundation.
//
// This program is distributed in the hope it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
// more details.
//

def is_pr = env.JOB_NAME.endsWith("_pull-requests")
def target_machine = "intel-corei7-64"

// JOB_NAME expected to be in form <layer>_<branch>
def current_project = "${env.JOB_NAME}".tokenize("_")[0]
def image_name = "${current_project}_build:${env.BUILD_TAG}"
def ci_build_id = "${env.BUILD_TIMESTAMP}-build-${env.BUILD_NUMBER}"
def test_runs = [:]
def testinfo_data = ""
def ci_git_commit = ""
def summary = ""
def added_commits = ""
def slot_name = "ci-"
// reasonable value: keep few recent, dont take risk to fill disk
int num_builds_to_keep = 4

def ci_pr_num = ""
if (is_pr) {
    if (params.containsKey("GITHUB_PR_NUMBER")) {
        ci_pr_num = "$GITHUB_PR_NUMBER"
    } else if (params.containsKey("ghprbPullId")) {
        ci_pr_num = "$ghprbPullId"
    } else {
        error("Can not detect PR_NUMBER from parameters")
    }
}

// Define global environment common for all docker sessions
def script_env = """
    export WORKSPACE=\$PWD
    export HOME=\$JENKINS_HOME
    export BUILD_CACHE_DIR=${env.PUBLISH_DIR}/bb-cache
    export GIT_PROXY_COMMAND=oe-git-proxy
    export CI_BUILD_ID=${ci_build_id}
    export GIT_COMMITTER_NAME="IOT Refkit CI"
    export GIT_COMMITTER_EMAIL='refkit-ci@yoctoproject.org'
    export TARGET_MACHINE=${target_machine}
    export CI_LOG=bitbake-${target_machine}-${ci_build_id}.log
"""

try {
    timestamps {
        node('rk-docker') {
            ws("workspace/${slot_name}${ci_build_id}") {
                builder_node = "${env.NODE_NAME}"
                deleteDir() // although dir should be brand new, empty just in case
                stage('Checkout content') {
                    checkout_content(is_pr, ci_pr_num)
                }
                if ( !is_pr ) {
                    ci_git_commit = sh(returnStdout: true,
                                       script: "git rev-parse HEAD")
                    // This command expects that each new master build is based on a github merge
                    added_commits = sh(returnStdout: true,
                                       script: "git rev-list HEAD^...HEAD --oneline --no-merges | sed 's/[^ ]* /    /'")
                }
                stage('Build docker image') {
                    parallel(
                        "build-docker-image": { build_docker_image(image_name) },
                        "cleanup": { ws("workspace") { trim_build_dirs(slot_name, num_builds_to_keep) }}
                    )
                }
                run_args = ["--device=/dev/kvm -v ${env.PUBLISH_DIR}:${env.PUBLISH_DIR}:rw",
                            run_proxy_args()].join(" ")
                docker.image(image_name).inside(run_args) {
                    params = ["${script_env}", "docker/pre-build.sh"].join("\n")
                    stage('Pre-build tests') {
                        sh "${params}"
                        summary += sh(returnStdout: true,
                                      script: "docker/tester-create-summary.sh 'oe-selftest: pre-build' '' build.pre/TestResults_*/TEST- 0")
                    }
                    try {
                        params = ["${script_env}", "docker/build-project.sh"].join("\n")
                        stage('Build') {
                            sh "${params}"
                        }
                    } catch (Exception e) {
                        throw e
                    } finally {
                        stage('Store images') {
                            params = ["${script_env}", "docker/publish-project.sh"].join("\n")
                            sh "${params}"
                            params = ["${script_env}", "docker/publish-sstate.sh"].join("\n")
                            sh "${params}"
                        }
                    }
                } // docker_image
                tester_script = readFile "docker/tester-exec.sh"
                tester_summary = readFile "docker/tester-create-summary.sh"
                qemu_script = readFile "docker/run-qemu.exp"
                testinfo_data = readFile "${target_machine}.testinfo.csv"
            } // ws
        } // node
    } // timestamps

    // insert post-build test into same list where daft tests will be, for parallel run
    test_runs['post-build-test'] = {
        node(builder_node) {
            ws("workspace/${slot_name}${ci_build_id}") {
                build_docker_image(image_name)
                docker.image(image_name).inside(run_args) {
                    params = ["${script_env}", "docker/post-build.sh"].join("\n")
                    sh "${params}"
                    params = ["${script_env}", "docker/publish-sstate.sh"].join("\n")
                    sh "${params}"
                }
                lock(resource: "global_data") {
                    summary += sh(returnStdout: true,
                                  script: "docker/tester-create-summary.sh 'oe-selftest: post-build' '' build/TestResults_*/TEST- 0")
                    // note wildcard: handle pre-build reports in build.pre/ as well
                    archiveArtifacts allowEmptyArchive: true, artifacts: 'build*/TestResults_*/TEST-*.xml'
                    step_xunit('build*/TestResults_*/TEST-*.xml')
                }
            }
        }
    }

    test_targets = testinfo_data.split("\n")
    for(int i = 0; i < test_targets.size() && test_targets[i] != ""; i++) {
        def one_target_testinfo = test_targets[i]
        def test_device = one_target_testinfo.split(',')[5]
        def test_machine = one_target_testinfo.split(',')[4]
        def img = one_target_testinfo.split(",")[1]
        test_runs["test_${i}_${test_device}"] = {
            node('refkit-tester') {
                deleteDir() // clean workspace
                echo "image_info: ${one_target_testinfo}"
                writeFile file: 'tester-exec.sh', text: tester_script
                writeFile file: 'tester-create-summary.sh', text: tester_summary
                writeFile file: 'run-qemu.exp', text: qemu_script
                // append newline so that tester-exec.sh can parse it using "read"
                one_target_testinfo += "\n"
                // create testinfo.csv on this tester describing one image
                writeFile file: "testinfo.csv", text: one_target_testinfo
                try {
                    withEnv(["CI_BUILD_ID=${ci_build_id}",
                        "MACHINE=${test_machine}",
                        "TEST_DEVICE=${test_device}" ]) {
                            sh 'chmod a+x tester-exec.sh tester-create-summary.sh run-qemu.exp && ./tester-exec.sh'
                    }
                } catch (Exception e) {
                    throw e
                } finally {
                    // One tester adds it's summary piece to the global buffer.
                    // Without locking we may lose tester result set(s) if testers publish xunit
                    // data at nearly same time. Cover global summary add with same lock.
                    lock(resource: "global_data") {
                        summary += readFile "results-summary-${test_device}.${img}.log"
                        archiveArtifacts allowEmptyArchive: true, artifacts: '*.log, *.xml'
                        step_xunit('TEST-*.xml')
                    }
                }
            } // node
        } // test_runs =
    } // for i
    stage('Parallel test run') {
        timestamps {
            try {
                parallel test_runs
            } catch (Exception e) {
                currentBuild.result = 'UNSTABLE'
            }
        }
    }
} catch (Exception e) {
    echo "Error: ${e}"
    if (currentBuild.result == null) {
        // Set currentBuild.result as FAILURE if there is an error in building
        currentBuild.result = 'FAILURE'
    }
    throw e
} finally {
    //  If tests stage was skipped because of no tests, then currentBuild.result
    //  remains null until end so manually set it as SUCCESS
    if (currentBuild.result == null) {
        currentBuild.result = 'SUCCESS'
    }
    echo "Finally: build result is ${currentBuild.result}\nSummary:\n${summary}"
    if (!is_pr) {
        // send summary email after non-PR build
        email = "Git commit hash: ${ci_git_commit}\n"
        email += "Added commits:\n\n${added_commits}\n"
        email += "Test results:\n\n${summary}"
        def subject = "${currentBuild.result}: Job ${env.JOB_NAME} [${env.BUILD_NUMBER}]"
        echo "${email}"
        node('rk-mailer') {
            writeFile file: 'msg.txt', text: email
            sh "cat msg.txt |mailx -s '${subject}' ${env.RK_NOTIFICATION_MAIL_RECIPIENTS}"
        }
    }
}

echo "End of pipeline, build result is ${currentBuild.result}"

// Support functions:
def build_proxy_args() {
    return ["--build-arg http_proxy=${env.http_proxy}",
            "--build-arg https_proxy=${env.https_proxy}",
            "--build-arg ALL_PROXY=${env.ALL_PROXY}"].join(" ")
}

def run_proxy_args() {
    return [ "-e http_proxy=${env.http_proxy}",
             "-e https_proxy=${env.https_proxy}",
             "-e ALL_PROXY=${env.ALL_PROXY}",
             "-e no_proxy=${env.NO_PROXY}"].join(" ")
}

def build_user_args() {
    dir(pwd([tmp:true])+"/.build_user_args") {
        // get jenkins user uid/gid
        sh "id -u > jenkins_uid && id -g > jenkins_gid"
        jenkins_uid = readFile("jenkins_uid").trim()
        jenkins_gid = readFile("jenkins_gid").trim()
    }
    return "--build-arg uid=${jenkins_uid} --build-arg gid=${jenkins_gid}"
}

def checkout_content(is_pr, pr_num) {
    if (is_pr) {
        // we are building pull request
        echo "Checkout: PR case"
        checkout([$class: 'GitSCM',
            branches: [
                [name: "origin-pull/$pr_num/merge"]
            ],
            doGenerateSubmoduleConfigurations: false,
            extensions: [
                [$class: 'SubmoduleOption',
                    disableSubmodules: false,
                    recursiveSubmodules: true,
                    reference: "${env.PUBLISH_DIR}/bb-cache/.git-mirror",
                    trackingSubmodules: false],
                [$class: 'CleanBeforeCheckout']
            ],
            submoduleCfg: [],
            userRemoteConfigs: [
                [credentialsId: "${GITHUB_AUTH}",
                    name: 'origin-pull',
                    refspec: "+refs/pull/$pr_num/*:refs/remotes/origin-pull/$pr_num/*",
                    url: "${GITHUB_PROJECT}"]
            ]
        ])
    } else {
        echo "Checkout: MASTER case"
        checkout poll: false, scm: scm
    }
}

def build_docker_image(image_name) {
    // Base container OS to use, see docker configs in docker/
    def build_os = "opensuse-42.2"
    def build_args = [ build_proxy_args(), build_user_args()].join(" ")
    sh "docker build -t ${image_name} ${build_args} docker/${build_os}"
    dockerFingerprintFrom dockerfile: "docker/${build_os}/Dockerfile", image: "${image_name}"
}

def step_xunit(_pattern) {
    step([$class: 'XUnitPublisher',
    testTimeMargin: '3000',
    thresholdMode: 1,
    thresholds: [
        [$class: 'FailedThreshold',
            failureNewThreshold: '0',
            failureThreshold: '0',
            unstableNewThreshold: '99999',
            unstableThreshold: '99999'],
        [$class: 'SkippedThreshold',
            failureNewThreshold: '99999',
            failureThreshold: '99999',
            unstableNewThreshold: '99999',
            unstableThreshold: '99999']],
    tools: [
        [$class: 'JUnitType',
            deleteOutputFiles: true,
            failIfNotNew: true,
            pattern: "${_pattern}",
            skipNoTestFiles: false,
            stopProcessingIfError: true]]])
}

// Delete older builder trees.
// While majority/regular workspaces are named ci-CI_BUILD_ID,
// Jenkins may create additional trees as ci-build-CI_BUILD_ID_<NUM>
// Regex with underscore should cover all such workspaces.
def trim_build_dirs(slotname, num_to_keep) {
    sh """
# tmpdirs in separate pass
dirs=`find . -mindepth 1 -maxdepth 1 -type d -regex ".*/${slotname}[0-9_-]*-build-[0-9_]*.*tmp\$" |sort -n |head -n -${num_to_keep} |tr '\n' ' '`
if [ -n "\${dirs}" ]; then
    ionice -c 3 rm -fr \$dirs
fi
dirs=`find . -mindepth 1 -maxdepth 1 -type d -regex ".*/${slotname}[0-9_-]*-build-[0-9_]*\$" |sort -n |head -n -${num_to_keep} |tr '\n' ' '`
if [ -n "\${dirs}" ]; then
    ionice -c 3 rm -fr \$dirs
fi
"""
}
