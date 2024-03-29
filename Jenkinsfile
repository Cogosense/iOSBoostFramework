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

        stage ('Build') {
            // Accept the license on first install and updates
            Utils.&acceptXcodeLicense()
            sh 'make ENABLE_BITCODE=YES BITCODE_GENERATION_MODE=bitcode SDK=macosx install'
            sh 'make ENABLE_BITCODE=YES BITCODE_GENERATION_MODE=bitcode SDK=iphoneos install'
            sh 'make ENABLE_BITCODE=YES BITCODE_GENERATION_MODE=bitcode SDK=iphonesimulator install'
        }

        stage ('Assemble Framework') {
            sh 'make xcframework'
        }

        stage ('Archive Artifacts') {
            // Archive the SCM logs, the framework directory
            step([$class: 'ArtifactArchiver',
                artifacts: 'SCM/**, boost.framework.tar.bz2, boost.framework.zip',
                fingerprint: true,
                onlyIfSuccessful: true])
            // Release to GitHub if on main branch
            withCredentials([string(credentialsId: '3ad153e6-ab28-48a1-80cf-845c30b29e94', variable: 'GH_TOKEN')]) {
                withEnv(['PATH=./utils:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin']) {
                Utils.upgradeBrew()
                    Utils.brewUpstall('gh')
                    sh "make GITBRANCH=${env.BRANCH_NAME} release"
                }
            }
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
    try {
        // Load the SCM util scripts first using the branch name of the main repo
        checkout([$class: 'GitSCM',
            branches: [[name: "*/${env.BRANCH_NAME}"]],
            doGenerateSubmoduleConfigurations: false,
            extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'utils']],
            submoduleCfg: [],
            userRemoteConfigs: [[url: 'git@github.com:Cogosense/JenkinsUtils.git', credentialsId: '38bf8b09-9e52-421a-a8ed-5280fcb921af']]])
    } catch(err) {
        // Load the SCM util scripts falling back to the master branch
        checkout([$class: 'GitSCM',
            branches: [[name: "*/master"]],
            doGenerateSubmoduleConfigurations: false,
            extensions: [[$class: 'RelativeTargetDirectory', relativeTargetDir: 'utils']],
            submoduleCfg: [],
            userRemoteConfigs: [[url: 'git@github.com:Cogosense/JenkinsUtils.git', credentialsId: '38bf8b09-9e52-421a-a8ed-5280fcb921af']]])
    }
}
