properties properties: [
    [
        $class: 'BuildDiscarderProperty',
        strategy: [$class: 'LogRotator', artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '', numToKeepStr: '30']
    ]
]

node('osx && ios') {
    def contributors = null
    def Utils
    def buildLabel
    currentBuild.result = "SUCCESS"

    stage ('Checkout Source') {
        deleteDir()
        checkout scm
        getUtils()
        // load pipeline utility functions
        Utils = load "utils/Utils.groovy"
        buildLabel = Utils.&getBuildLabel()
    }

    stage ('Create Change Logs') {
        sshagent(['38bf8b09-9e52-421a-a8ed-5280fcb921af']) {
            dir('./SCM') {
                sh '../utils/scmBuildDate > TIMESTAMP'
                writeFile file: "TAG", text: buildLabel
                writeFile file: "URL", text: env.BUILD_URL
                writeFile file: "BRANCH", text: env.BRANCH_NAME
                sh '../utils/scmBuildContributors > CONTRIBUTORS'
                sh '../utils/scmBuildOnHookEmail > ONHOOK_EMAIL'
                def htmlChangelog = Utils.&generateChangeLog(false)
                def mdChangelog = Utils.&generateChangeLog(true)
                currentBuild.description = htmlChangelog
                writeFile file: "CHANGELOG.md", text: mdChangelog
            }
        }
    }

    try {
        contributors = readFile './SCM/ONHOOK_EMAIL'

        stage ('Capture Build Environment') {
            sh 'env -u PWD -u HOME -u PATH -u \'BASH_FUNC_copy_reference_file()\' > SCM/build.env'
        }

        stage ('Notify Build Started') {
            Utils.&sendOnHookEmail(contributors)
        }

        stage ('Build Parallel') {
            stash name: 'Makefile', includes: 'Makefile,boost/**,patches/**'
            parallel (
                "armv7" : {
                    node('osx && ios') {
                        // Accept the license on first install and updates
                        Utils.&acceptXcodeLicense()
                        // clean workspace
                        deleteDir()
                        unstash 'Makefile'
                        sh 'make clean'
                        sh 'make ENABLE_BITCODE=YES BITCODE_GENERATION_MODE=bitcode ARCHS=armv7'
                        stash name: 'armv7', includes: '**/armv7/boost.framework/**'
                    }
                },
                "arm64" : {
                    node('osx && ios') {
                        // Accept the license on first install and updates
                        Utils.&acceptXcodeLicense()
                        // clean workspace
                        deleteDir()
                        unstash 'Makefile'
                        sh 'make clean'
                        sh 'make ENABLE_BITCODE=YES BITCODE_GENERATION_MODE=bitcode ARCHS=arm64'
                        stash name: 'arm64', includes: '**/arm64/boost.framework/**'
                    }
                }
            )
        }

        stage ('Assemble Framework') {
            unstash 'armv7'
            unstash 'arm64'
            // Accept the license on first install and updates
            Utils.&acceptXcodeLicense()
            sh 'make ARCHS="armv7 arm64" bundle'
        }

        stage ('Archive Artifacts') {
            // Archive the SCM logs, the framework directory
            step([$class: 'ArtifactArchiver',
                artifacts: 'SCM/**, boost.framework.tar.bz2',
                fingerprint: true,
                onlyIfSuccessful: true])
        }

    }
    catch(err) {
        currentBuild.result = "FAILURE"
        Utils.&sendFailureEmail(contributors, err)
        throw err
    }

    stage ('Notify Build Completion') {
        Utils.&sendOffHookEmail(contributors)
    }
}

def getUtils() {
    // Load the SCM util scripts first
    checkout([$class: 'GitSCM',
        branches: [[name: "*/${env.BRANCH_NAME}"]],
        doGenerateSubmoduleConfigurations: false,
        extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'utils']],
        submoduleCfg: [],
        userRemoteConfigs: [[url: 'git@github.com:Cogosense/JenkinsUtils.git', credentialsId: '38bf8b09-9e52-421a-a8ed-5280fcb921af']]])
}
