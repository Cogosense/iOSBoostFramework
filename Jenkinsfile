properties properties: [
    [
        $class: 'BuildDiscarderProperty',
        strategy: [$class: 'LogRotator', artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '', numToKeepStr: '30']
    ]
]

node('osx && ios') {
    def contributors = null
    currentBuild.result = "SUCCESS"

    // Accept the license on first install and updates
    acceptXcodeLicense()

    // clean workspace
    deleteDir()
    try {
        sshagent(['38bf8b09-9e52-421a-a8ed-5280fcb921af']) {
            stage 'Checkout Source'
            checkout scm

            stage name: 'Create Change Logs', concurrency: 1

            // Load the SCM util scripts first
            checkout([$class: 'GitSCM',
                branches: [[name: '*/master']],
                doGenerateSubmoduleConfigurations: false,
                extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'utils']],
                submoduleCfg: [],
                userRemoteConfigs: [[url: 'git@github.com:Cogosense/JenkinsUtils.git', credentialsId: '38bf8b09-9e52-421a-a8ed-5280fcb921af']]])

            dir('./SCM') {
                sh '../utils/scmBuildDate > TIMESTAMP'
                sh '../utils/scmBuildTag > TAG'
                sh '../utils/scmBuildContributors > CONTRIBUTORS'
                sh '../utils/scmBuildOnHookEmail > ONHOOK_EMAIL'
                sh '../utils/scmCreateChangeLogs -o CHANGELOG'
                sh '../utils/scmTagLastBuild'
            }
        }

        contributors = readFile './SCM/ONHOOK_EMAIL'

        stage 'Capture Build Environment'
        sh 'env -u PWD -u HOME -u PATH -u \'BASH_FUNC_copy_reference_file()\' > SCM/build.env'

        stage 'Notify Build Started'
        if(contributors && contributors != '') {
            mail subject: "Jenkins Build Started: (${env.JOB_NAME})",
                body: "You are on the hook.\nFor more information: ${env.JOB_URL}",
                to: contributors,
                from: 'support@cogosense.com'
        }

        stash name: 'Makefile', includes: 'Makefile'

        stage 'Build Parallel'
        parallel (
            "armv7" : {
                node('osx && ios') {
                    // clean workspace
                    deleteDir()
                    unstash 'Makefile'
                    sh 'make clean'
                    sh 'make ARCHS=armv7'
                    stash name: 'armv7', includes: '**/armv7/boost.framework/**'
                }
            },
            "arm64" : {
                node('osx && ios') {
                    // clean workspace
                    deleteDir()
                    unstash 'Makefile'
                    sh 'make clean'
                    sh 'make ARCHS=arm64'
                    stash name: 'arm64', includes: '**/arm64/boost.framework/**'
                }
            }
        )

        unstash 'armv7'
        unstash 'arm64'

        stage 'Assemble Framework'
        sh 'make ARCHS="armv7 arm64" framework-no-build'

        stage 'Archive Artifacts'
        // Archive the SCM logs, the framework directory
        step([$class: 'ArtifactArchiver',
            artifacts: 'SCM/**, boost.framework.tar.bz2',
            fingerprint: true,
            onlyIfSuccessful: true])

    } catch(err) {
        currentBuild.result = "FAILURE"
        mail subject: "Jenkins Build Failed: (${env.JOB_NAME})",
            body: "Project build error ${err}.\nFor more information: ${env.BUILD_URL}",
            to: contributors ? contributors : '',
            bcc: 'swilliams@cogosense.com',
            from: 'support@cogosense.com'
        throw err
    }

    stage 'Notify Build Completion'
    if(contributors && contributors != '') {
        mail subject: "Jenkins Build Completed Successfully: (${env.JOB_NAME})",
            body: "You are off the hook.\nFor more information: ${env.BUILD_URL}",
            to: contributors,
            from: 'support@cogosense.com'
    }
}

def acceptXcodeLicense() {
    withCredentials([[
                $class: 'UsernamePasswordMultiBinding',
                credentialsId: 'ab72d29c-1cd1-4f78-a6fa-603db58bcaf3',
                usernameVariable: 'USERNAME',
                passwordVariable: 'PASSWORD']]) {
        sh 'echo $PASSWORD | sudo -S xcodebuild -license accept'
    }
}
