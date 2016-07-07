properties properties: [
    [
        $class: 'BuildDiscarderProperty',
        strategy: [$class: 'LogRotator', artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '', numToKeepStr: '30']
    ]
]

node('osx && ios') {
    def contributors = null
    def scmLogWs = 'scmLogs' + env.BUILD_NUMBER
    currentBuild.result = "SUCCESS"

    // clean workspace
    deleteDir()
    sshagent(['38bf8b09-9e52-421a-a8ed-5280fcb921af']) {
	stage 'Checkout Source'
	checkout scm
    }

    try {
	stage name: 'Create Change Logs', concurrency: 1
	ws("workspace/${env.JOB_NAME}/../${scmLogWs}") {
	    sshagent(['38bf8b09-9e52-421a-a8ed-5280fcb921af']) {
		checkout scm

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
	    stash name: 'SCM', includes: 'SCM/**'
	    // remove workspace
	    deleteDir()
	}

	unstash 'SCM'
	contributors = readFile './SCM/ONHOOK_EMAIL'

	stage 'Notify Build Started'
	if(contributors && contributors != '') {
	    mail subject: "Jenkins Build Started: (${env.JOB_NAME})",
		    body: "You are on the hook}.\nFor more information: ${env.JOB_URL}",
		    to: contributors,
		    from: 'support@cogosense.com'
	}

	stage 'Build'
	sh 'build.sh'

	stage 'Archive Artifacts'
	// Archive the SCM logs, the framework directory
	step([$class: 'ArtifactArchiver',
		artifacts: 'SCM/**',
		fingerprint: true,
		onlyIfSuccessful: true])
	dir('ios/Frameworks') {
	    step([$class: 'ArtifactArchiver',
		    artifacts: 'boost.framework/**',
		    fingerprint: true,
		    onlyIfSuccessful: true])
	}

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
		body: "You are off the hook}.\nFor more information: ${env.BUILD_URL}",
		to: contributors,
		from: 'support@cogosense.com'
    }
}
