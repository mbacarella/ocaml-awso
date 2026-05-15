(lang dune 3.8)

;; dune-project is auto-generated, see bin/awso_bootstrap

(name awso)

(generate_opam_files true)

(opam_file_location inside_opam_directory)

(license MIT)

(authors "Solvuu Inc.")

(maintainers "Michael Bacarella <m@bacarella.com>")

(homepage "https://github.com/solvuu/awso")

(source
 (github mbacarella/awso))

(package
 (name awso)
 (synopsis "AWS API base library")
 (depends
  awso-codegen
  (base64
   (>= 3.1.0))
  (cohttp
   (>= 0.21.0))
  cryptokit
  xmlm
  zarith))

(package
 (name awso-async)
 (synopsis "AWS API base library Async")
 (depends
  awso
  cohttp-async
  (async
   (>= v0.11.0))
  async_ssl))

(package
 (name awso-lwt)
 (synopsis "AWS API base library Lwt")
 (depends awso lwt cohttp-lwt-unix))

(package
 (name awso-codegen)
 (synopsis "AWS botocore code generator")
 (depends
  cohttp
  ocamlgraph
  ppxlib
  (re
   (>= 1.7.2))
  (sedlex
   (>= 2.3))
  xmlm
  yojson))

(package
 (name awso-unix)
 (synopsis "AWS API base library Unix"))

;; Packages above this line are base packages needed by all services.

;; The following SRP packages provide support for Cognito SRP.

(package
 (name awso-srp)
 (synopsis "AWS API for SRP")
 (depends awso))

(package
 (name awso-srp-async)
 (synopsis "AWS Async API for SRP")
 (depends awso-async awso-cognito-idp-async awso-srp))

;; Packages after this line each regard a specific service.

(package
 (name awso-accessanalyzer)
 (synopsis "AWS API for Accessanalyzer")
 (depends awso))

(package
 (name awso-accessanalyzer-async)
 (synopsis "AWS Async API for Accessanalyzer")
 (depends awso-async awso-accessanalyzer))

(package
 (name awso-accessanalyzer-lwt)
 (synopsis "AWS Lwt API for Accessanalyzer")
 (depends awso-lwt awso-accessanalyzer))

(package
 (name awso-account)
 (synopsis "AWS API for Account")
 (depends awso))

(package
 (name awso-account-async)
 (synopsis "AWS Async API for Account")
 (depends awso-async awso-account))

(package
 (name awso-account-lwt)
 (synopsis "AWS Lwt API for Account")
 (depends awso-lwt awso-account))

(package
 (name awso-acm)
 (synopsis "AWS API for Acm")
 (depends awso))

(package
 (name awso-acm-async)
 (synopsis "AWS Async API for Acm")
 (depends awso-async awso-acm))

(package
 (name awso-acm-lwt)
 (synopsis "AWS Lwt API for Acm")
 (depends awso-lwt awso-acm))

(package
 (name awso-acm-pca)
 (synopsis "AWS API for Acm-pca")
 (depends awso))

(package
 (name awso-acm-pca-async)
 (synopsis "AWS Async API for Acm-pca")
 (depends awso-async awso-acm-pca))

(package
 (name awso-acm-pca-lwt)
 (synopsis "AWS Lwt API for Acm-pca")
 (depends awso-lwt awso-acm-pca))

(package
 (name awso-alexaforbusiness)
 (synopsis "AWS API for Alexaforbusiness")
 (depends awso))

(package
 (name awso-alexaforbusiness-async)
 (synopsis "AWS Async API for Alexaforbusiness")
 (depends awso-async awso-alexaforbusiness))

(package
 (name awso-alexaforbusiness-lwt)
 (synopsis "AWS Lwt API for Alexaforbusiness")
 (depends awso-lwt awso-alexaforbusiness))

(package
 (name awso-amp)
 (synopsis "AWS API for Amp")
 (depends awso))

(package
 (name awso-amp-async)
 (synopsis "AWS Async API for Amp")
 (depends awso-async awso-amp))

(package
 (name awso-amp-lwt)
 (synopsis "AWS Lwt API for Amp")
 (depends awso-lwt awso-amp))

(package
 (name awso-amplify)
 (synopsis "AWS API for Amplify")
 (depends awso))

(package
 (name awso-amplify-async)
 (synopsis "AWS Async API for Amplify")
 (depends awso-async awso-amplify))

(package
 (name awso-amplify-lwt)
 (synopsis "AWS Lwt API for Amplify")
 (depends awso-lwt awso-amplify))

(package
 (name awso-amplifybackend)
 (synopsis "AWS API for Amplifybackend")
 (depends awso))

(package
 (name awso-amplifybackend-async)
 (synopsis "AWS Async API for Amplifybackend")
 (depends awso-async awso-amplifybackend))

(package
 (name awso-amplifybackend-lwt)
 (synopsis "AWS Lwt API for Amplifybackend")
 (depends awso-lwt awso-amplifybackend))

(package
 (name awso-amplifyuibuilder)
 (synopsis "AWS API for Amplifyuibuilder")
 (depends awso))

(package
 (name awso-amplifyuibuilder-async)
 (synopsis "AWS Async API for Amplifyuibuilder")
 (depends awso-async awso-amplifyuibuilder))

(package
 (name awso-amplifyuibuilder-lwt)
 (synopsis "AWS Lwt API for Amplifyuibuilder")
 (depends awso-lwt awso-amplifyuibuilder))

(package
 (name awso-apigatewaymanagementapi)
 (synopsis "AWS API for Apigatewaymanagementapi")
 (depends awso))

(package
 (name awso-apigatewaymanagementapi-async)
 (synopsis "AWS Async API for Apigatewaymanagementapi")
 (depends awso-async awso-apigatewaymanagementapi))

(package
 (name awso-apigatewaymanagementapi-lwt)
 (synopsis "AWS Lwt API for Apigatewaymanagementapi")
 (depends awso-lwt awso-apigatewaymanagementapi))

(package
 (name awso-appflow)
 (synopsis "AWS API for Appflow")
 (depends awso))

(package
 (name awso-appflow-async)
 (synopsis "AWS Async API for Appflow")
 (depends awso-async awso-appflow))

(package
 (name awso-appflow-lwt)
 (synopsis "AWS Lwt API for Appflow")
 (depends awso-lwt awso-appflow))

(package
 (name awso-appintegrations)
 (synopsis "AWS API for Appintegrations")
 (depends awso))

(package
 (name awso-appintegrations-async)
 (synopsis "AWS Async API for Appintegrations")
 (depends awso-async awso-appintegrations))

(package
 (name awso-appintegrations-lwt)
 (synopsis "AWS Lwt API for Appintegrations")
 (depends awso-lwt awso-appintegrations))

(package
 (name awso-application-autoscaling)
 (synopsis "AWS API for Application-autoscaling")
 (depends awso))

(package
 (name awso-application-autoscaling-async)
 (synopsis "AWS Async API for Application-autoscaling")
 (depends awso-async awso-application-autoscaling))

(package
 (name awso-application-autoscaling-lwt)
 (synopsis "AWS Lwt API for Application-autoscaling")
 (depends awso-lwt awso-application-autoscaling))

(package
 (name awso-application-insights)
 (synopsis "AWS API for Application-insights")
 (depends awso))

(package
 (name awso-application-insights-async)
 (synopsis "AWS Async API for Application-insights")
 (depends awso-async awso-application-insights))

(package
 (name awso-application-insights-lwt)
 (synopsis "AWS Lwt API for Application-insights")
 (depends awso-lwt awso-application-insights))

(package
 (name awso-applicationcostprofiler)
 (synopsis "AWS API for Applicationcostprofiler")
 (depends awso))

(package
 (name awso-applicationcostprofiler-async)
 (synopsis "AWS Async API for Applicationcostprofiler")
 (depends awso-async awso-applicationcostprofiler))

(package
 (name awso-applicationcostprofiler-lwt)
 (synopsis "AWS Lwt API for Applicationcostprofiler")
 (depends awso-lwt awso-applicationcostprofiler))

(package
 (name awso-appmesh)
 (synopsis "AWS API for Appmesh")
 (depends awso))

(package
 (name awso-appmesh-async)
 (synopsis "AWS Async API for Appmesh")
 (depends awso-async awso-appmesh))

(package
 (name awso-appmesh-lwt)
 (synopsis "AWS Lwt API for Appmesh")
 (depends awso-lwt awso-appmesh))

(package
 (name awso-apprunner)
 (synopsis "AWS API for Apprunner")
 (depends awso))

(package
 (name awso-apprunner-async)
 (synopsis "AWS Async API for Apprunner")
 (depends awso-async awso-apprunner))

(package
 (name awso-apprunner-lwt)
 (synopsis "AWS Lwt API for Apprunner")
 (depends awso-lwt awso-apprunner))

(package
 (name awso-appstream)
 (synopsis "AWS API for Appstream")
 (depends awso))

(package
 (name awso-appstream-async)
 (synopsis "AWS Async API for Appstream")
 (depends awso-async awso-appstream))

(package
 (name awso-appstream-lwt)
 (synopsis "AWS Lwt API for Appstream")
 (depends awso-lwt awso-appstream))

(package
 (name awso-athena)
 (synopsis "AWS API for Athena")
 (depends awso))

(package
 (name awso-athena-async)
 (synopsis "AWS Async API for Athena")
 (depends awso-async awso-athena))

(package
 (name awso-athena-lwt)
 (synopsis "AWS Lwt API for Athena")
 (depends awso-lwt awso-athena))

(package
 (name awso-auditmanager)
 (synopsis "AWS API for Auditmanager")
 (depends awso))

(package
 (name awso-auditmanager-async)
 (synopsis "AWS Async API for Auditmanager")
 (depends awso-async awso-auditmanager))

(package
 (name awso-auditmanager-lwt)
 (synopsis "AWS Lwt API for Auditmanager")
 (depends awso-lwt awso-auditmanager))

(package
 (name awso-autoscaling)
 (synopsis "AWS API for Autoscaling")
 (depends awso))

(package
 (name awso-autoscaling-async)
 (synopsis "AWS Async API for Autoscaling")
 (depends awso-async awso-autoscaling))

(package
 (name awso-autoscaling-lwt)
 (synopsis "AWS Lwt API for Autoscaling")
 (depends awso-lwt awso-autoscaling))

(package
 (name awso-autoscaling-plans)
 (synopsis "AWS API for Autoscaling-plans")
 (depends awso))

(package
 (name awso-autoscaling-plans-async)
 (synopsis "AWS Async API for Autoscaling-plans")
 (depends awso-async awso-autoscaling-plans))

(package
 (name awso-autoscaling-plans-lwt)
 (synopsis "AWS Lwt API for Autoscaling-plans")
 (depends awso-lwt awso-autoscaling-plans))

(package
 (name awso-backup)
 (synopsis "AWS API for Backup")
 (depends awso))

(package
 (name awso-backup-async)
 (synopsis "AWS Async API for Backup")
 (depends awso-async awso-backup))

(package
 (name awso-backup-lwt)
 (synopsis "AWS Lwt API for Backup")
 (depends awso-lwt awso-backup))

(package
 (name awso-backup-gateway)
 (synopsis "AWS API for Backup-gateway")
 (depends awso))

(package
 (name awso-backup-gateway-async)
 (synopsis "AWS Async API for Backup-gateway")
 (depends awso-async awso-backup-gateway))

(package
 (name awso-backup-gateway-lwt)
 (synopsis "AWS Lwt API for Backup-gateway")
 (depends awso-lwt awso-backup-gateway))

(package
 (name awso-batch)
 (synopsis "AWS API for Batch")
 (depends awso))

(package
 (name awso-batch-async)
 (synopsis "AWS Async API for Batch")
 (depends awso-async awso-batch))

(package
 (name awso-batch-lwt)
 (synopsis "AWS Lwt API for Batch")
 (depends awso-lwt awso-batch))

(package
 (name awso-billingconductor)
 (synopsis "AWS API for Billingconductor")
 (depends awso))

(package
 (name awso-billingconductor-async)
 (synopsis "AWS Async API for Billingconductor")
 (depends awso-async awso-billingconductor))

(package
 (name awso-billingconductor-lwt)
 (synopsis "AWS Lwt API for Billingconductor")
 (depends awso-lwt awso-billingconductor))

(package
 (name awso-braket)
 (synopsis "AWS API for Braket")
 (depends awso))

(package
 (name awso-braket-async)
 (synopsis "AWS Async API for Braket")
 (depends awso-async awso-braket))

(package
 (name awso-braket-lwt)
 (synopsis "AWS Lwt API for Braket")
 (depends awso-lwt awso-braket))

(package
 (name awso-budgets)
 (synopsis "AWS API for Budgets")
 (depends awso))

(package
 (name awso-budgets-async)
 (synopsis "AWS Async API for Budgets")
 (depends awso-async awso-budgets))

(package
 (name awso-budgets-lwt)
 (synopsis "AWS Lwt API for Budgets")
 (depends awso-lwt awso-budgets))

(package
 (name awso-ce)
 (synopsis "AWS API for Ce")
 (depends awso))

(package
 (name awso-ce-async)
 (synopsis "AWS Async API for Ce")
 (depends awso-async awso-ce))

(package
 (name awso-ce-lwt)
 (synopsis "AWS Lwt API for Ce")
 (depends awso-lwt awso-ce))

(package
 (name awso-chime)
 (synopsis "AWS API for Chime")
 (depends awso))

(package
 (name awso-chime-async)
 (synopsis "AWS Async API for Chime")
 (depends awso-async awso-chime))

(package
 (name awso-chime-lwt)
 (synopsis "AWS Lwt API for Chime")
 (depends awso-lwt awso-chime))

(package
 (name awso-chime-sdk-identity)
 (synopsis "AWS API for Chime-sdk-identity")
 (depends awso))

(package
 (name awso-chime-sdk-identity-async)
 (synopsis "AWS Async API for Chime-sdk-identity")
 (depends awso-async awso-chime-sdk-identity))

(package
 (name awso-chime-sdk-identity-lwt)
 (synopsis "AWS Lwt API for Chime-sdk-identity")
 (depends awso-lwt awso-chime-sdk-identity))

(package
 (name awso-chime-sdk-meetings)
 (synopsis "AWS API for Chime-sdk-meetings")
 (depends awso))

(package
 (name awso-chime-sdk-meetings-async)
 (synopsis "AWS Async API for Chime-sdk-meetings")
 (depends awso-async awso-chime-sdk-meetings))

(package
 (name awso-chime-sdk-meetings-lwt)
 (synopsis "AWS Lwt API for Chime-sdk-meetings")
 (depends awso-lwt awso-chime-sdk-meetings))

(package
 (name awso-chime-sdk-messaging)
 (synopsis "AWS API for Chime-sdk-messaging")
 (depends awso))

(package
 (name awso-chime-sdk-messaging-async)
 (synopsis "AWS Async API for Chime-sdk-messaging")
 (depends awso-async awso-chime-sdk-messaging))

(package
 (name awso-chime-sdk-messaging-lwt)
 (synopsis "AWS Lwt API for Chime-sdk-messaging")
 (depends awso-lwt awso-chime-sdk-messaging))

(package
 (name awso-cloud9)
 (synopsis "AWS API for Cloud9")
 (depends awso))

(package
 (name awso-cloud9-async)
 (synopsis "AWS Async API for Cloud9")
 (depends awso-async awso-cloud9))

(package
 (name awso-cloud9-lwt)
 (synopsis "AWS Lwt API for Cloud9")
 (depends awso-lwt awso-cloud9))

(package
 (name awso-cloudcontrol)
 (synopsis "AWS API for Cloudcontrol")
 (depends awso))

(package
 (name awso-cloudcontrol-async)
 (synopsis "AWS Async API for Cloudcontrol")
 (depends awso-async awso-cloudcontrol))

(package
 (name awso-cloudcontrol-lwt)
 (synopsis "AWS Lwt API for Cloudcontrol")
 (depends awso-lwt awso-cloudcontrol))

(package
 (name awso-clouddirectory)
 (synopsis "AWS API for Clouddirectory")
 (depends awso))

(package
 (name awso-clouddirectory-async)
 (synopsis "AWS Async API for Clouddirectory")
 (depends awso-async awso-clouddirectory))

(package
 (name awso-clouddirectory-lwt)
 (synopsis "AWS Lwt API for Clouddirectory")
 (depends awso-lwt awso-clouddirectory))

(package
 (name awso-cloudformation)
 (synopsis "AWS API for Cloudformation")
 (depends awso))

(package
 (name awso-cloudformation-async)
 (synopsis "AWS Async API for Cloudformation")
 (depends awso-async awso-cloudformation))

(package
 (name awso-cloudformation-lwt)
 (synopsis "AWS Lwt API for Cloudformation")
 (depends awso-lwt awso-cloudformation))

(package
 (name awso-cloudfront)
 (synopsis "AWS API for Cloudfront")
 (depends awso))

(package
 (name awso-cloudfront-async)
 (synopsis "AWS Async API for Cloudfront")
 (depends awso-async awso-cloudfront))

(package
 (name awso-cloudfront-lwt)
 (synopsis "AWS Lwt API for Cloudfront")
 (depends awso-lwt awso-cloudfront))

(package
 (name awso-cloudhsmv2)
 (synopsis "AWS API for Cloudhsmv2")
 (depends awso))

(package
 (name awso-cloudhsmv2-async)
 (synopsis "AWS Async API for Cloudhsmv2")
 (depends awso-async awso-cloudhsmv2))

(package
 (name awso-cloudhsmv2-lwt)
 (synopsis "AWS Lwt API for Cloudhsmv2")
 (depends awso-lwt awso-cloudhsmv2))

(package
 (name awso-cloudsearch)
 (synopsis "AWS API for Cloudsearch")
 (depends awso))

(package
 (name awso-cloudsearch-async)
 (synopsis "AWS Async API for Cloudsearch")
 (depends awso-async awso-cloudsearch))

(package
 (name awso-cloudsearch-lwt)
 (synopsis "AWS Lwt API for Cloudsearch")
 (depends awso-lwt awso-cloudsearch))

(package
 (name awso-cloudsearchdomain)
 (synopsis "AWS API for Cloudsearchdomain")
 (depends awso))

(package
 (name awso-cloudsearchdomain-async)
 (synopsis "AWS Async API for Cloudsearchdomain")
 (depends awso-async awso-cloudsearchdomain))

(package
 (name awso-cloudsearchdomain-lwt)
 (synopsis "AWS Lwt API for Cloudsearchdomain")
 (depends awso-lwt awso-cloudsearchdomain))

(package
 (name awso-cloudtrail)
 (synopsis "AWS API for Cloudtrail")
 (depends awso))

(package
 (name awso-cloudtrail-async)
 (synopsis "AWS Async API for Cloudtrail")
 (depends awso-async awso-cloudtrail))

(package
 (name awso-cloudtrail-lwt)
 (synopsis "AWS Lwt API for Cloudtrail")
 (depends awso-lwt awso-cloudtrail))

(package
 (name awso-cloudwatch)
 (synopsis "AWS API for Cloudwatch")
 (depends awso))

(package
 (name awso-cloudwatch-async)
 (synopsis "AWS Async API for Cloudwatch")
 (depends awso-async awso-cloudwatch))

(package
 (name awso-cloudwatch-lwt)
 (synopsis "AWS Lwt API for Cloudwatch")
 (depends awso-lwt awso-cloudwatch))

(package
 (name awso-codeartifact)
 (synopsis "AWS API for Codeartifact")
 (depends awso))

(package
 (name awso-codeartifact-async)
 (synopsis "AWS Async API for Codeartifact")
 (depends awso-async awso-codeartifact))

(package
 (name awso-codeartifact-lwt)
 (synopsis "AWS Lwt API for Codeartifact")
 (depends awso-lwt awso-codeartifact))

(package
 (name awso-codebuild)
 (synopsis "AWS API for Codebuild")
 (depends awso))

(package
 (name awso-codebuild-async)
 (synopsis "AWS Async API for Codebuild")
 (depends awso-async awso-codebuild))

(package
 (name awso-codebuild-lwt)
 (synopsis "AWS Lwt API for Codebuild")
 (depends awso-lwt awso-codebuild))

(package
 (name awso-codecommit)
 (synopsis "AWS API for Codecommit")
 (depends awso))

(package
 (name awso-codecommit-async)
 (synopsis "AWS Async API for Codecommit")
 (depends awso-async awso-codecommit))

(package
 (name awso-codecommit-lwt)
 (synopsis "AWS Lwt API for Codecommit")
 (depends awso-lwt awso-codecommit))

(package
 (name awso-codedeploy)
 (synopsis "AWS API for Codedeploy")
 (depends awso))

(package
 (name awso-codedeploy-async)
 (synopsis "AWS Async API for Codedeploy")
 (depends awso-async awso-codedeploy))

(package
 (name awso-codedeploy-lwt)
 (synopsis "AWS Lwt API for Codedeploy")
 (depends awso-lwt awso-codedeploy))

(package
 (name awso-codeguru-reviewer)
 (synopsis "AWS API for Codeguru-reviewer")
 (depends awso))

(package
 (name awso-codeguru-reviewer-async)
 (synopsis "AWS Async API for Codeguru-reviewer")
 (depends awso-async awso-codeguru-reviewer))

(package
 (name awso-codeguru-reviewer-lwt)
 (synopsis "AWS Lwt API for Codeguru-reviewer")
 (depends awso-lwt awso-codeguru-reviewer))

(package
 (name awso-codepipeline)
 (synopsis "AWS API for Codepipeline")
 (depends awso))

(package
 (name awso-codepipeline-async)
 (synopsis "AWS Async API for Codepipeline")
 (depends awso-async awso-codepipeline))

(package
 (name awso-codepipeline-lwt)
 (synopsis "AWS Lwt API for Codepipeline")
 (depends awso-lwt awso-codepipeline))

(package
 (name awso-codestar)
 (synopsis "AWS API for Codestar")
 (depends awso))

(package
 (name awso-codestar-async)
 (synopsis "AWS Async API for Codestar")
 (depends awso-async awso-codestar))

(package
 (name awso-codestar-lwt)
 (synopsis "AWS Lwt API for Codestar")
 (depends awso-lwt awso-codestar))

(package
 (name awso-codestar-connections)
 (synopsis "AWS API for Codestar-connections")
 (depends awso))

(package
 (name awso-codestar-connections-async)
 (synopsis "AWS Async API for Codestar-connections")
 (depends awso-async awso-codestar-connections))

(package
 (name awso-codestar-connections-lwt)
 (synopsis "AWS Lwt API for Codestar-connections")
 (depends awso-lwt awso-codestar-connections))

(package
 (name awso-codestar-notifications)
 (synopsis "AWS API for Codestar-notifications")
 (depends awso))

(package
 (name awso-codestar-notifications-async)
 (synopsis "AWS Async API for Codestar-notifications")
 (depends awso-async awso-codestar-notifications))

(package
 (name awso-codestar-notifications-lwt)
 (synopsis "AWS Lwt API for Codestar-notifications")
 (depends awso-lwt awso-codestar-notifications))

(package
 (name awso-cognito-identity)
 (synopsis "AWS API for Cognito-identity")
 (depends awso))

(package
 (name awso-cognito-identity-async)
 (synopsis "AWS Async API for Cognito-identity")
 (depends awso-async awso-cognito-identity))

(package
 (name awso-cognito-identity-lwt)
 (synopsis "AWS Lwt API for Cognito-identity")
 (depends awso-lwt awso-cognito-identity))

(package
 (name awso-cognito-idp)
 (synopsis "AWS API for Cognito-idp")
 (depends awso))

(package
 (name awso-cognito-idp-async)
 (synopsis "AWS Async API for Cognito-idp")
 (depends awso-async awso-cognito-idp))

(package
 (name awso-cognito-idp-lwt)
 (synopsis "AWS Lwt API for Cognito-idp")
 (depends awso-lwt awso-cognito-idp))

(package
 (name awso-cognito-sync)
 (synopsis "AWS API for Cognito-sync")
 (depends awso))

(package
 (name awso-cognito-sync-async)
 (synopsis "AWS Async API for Cognito-sync")
 (depends awso-async awso-cognito-sync))

(package
 (name awso-cognito-sync-lwt)
 (synopsis "AWS Lwt API for Cognito-sync")
 (depends awso-lwt awso-cognito-sync))

(package
 (name awso-comprehend)
 (synopsis "AWS API for Comprehend")
 (depends awso))

(package
 (name awso-comprehend-async)
 (synopsis "AWS Async API for Comprehend")
 (depends awso-async awso-comprehend))

(package
 (name awso-comprehend-lwt)
 (synopsis "AWS Lwt API for Comprehend")
 (depends awso-lwt awso-comprehend))

(package
 (name awso-comprehendmedical)
 (synopsis "AWS API for Comprehendmedical")
 (depends awso))

(package
 (name awso-comprehendmedical-async)
 (synopsis "AWS Async API for Comprehendmedical")
 (depends awso-async awso-comprehendmedical))

(package
 (name awso-comprehendmedical-lwt)
 (synopsis "AWS Lwt API for Comprehendmedical")
 (depends awso-lwt awso-comprehendmedical))

(package
 (name awso-compute-optimizer)
 (synopsis "AWS API for Compute-optimizer")
 (depends awso))

(package
 (name awso-compute-optimizer-async)
 (synopsis "AWS Async API for Compute-optimizer")
 (depends awso-async awso-compute-optimizer))

(package
 (name awso-compute-optimizer-lwt)
 (synopsis "AWS Lwt API for Compute-optimizer")
 (depends awso-lwt awso-compute-optimizer))

(package
 (name awso-config)
 (synopsis "AWS API for Config")
 (depends awso))

(package
 (name awso-config-async)
 (synopsis "AWS Async API for Config")
 (depends awso-async awso-config))

(package
 (name awso-config-lwt)
 (synopsis "AWS Lwt API for Config")
 (depends awso-lwt awso-config))

(package
 (name awso-connect)
 (synopsis "AWS API for Connect")
 (depends awso))

(package
 (name awso-connect-async)
 (synopsis "AWS Async API for Connect")
 (depends awso-async awso-connect))

(package
 (name awso-connect-lwt)
 (synopsis "AWS Lwt API for Connect")
 (depends awso-lwt awso-connect))

(package
 (name awso-connect-contact-lens)
 (synopsis "AWS API for Connect-contact-lens")
 (depends awso))

(package
 (name awso-connect-contact-lens-async)
 (synopsis "AWS Async API for Connect-contact-lens")
 (depends awso-async awso-connect-contact-lens))

(package
 (name awso-connect-contact-lens-lwt)
 (synopsis "AWS Lwt API for Connect-contact-lens")
 (depends awso-lwt awso-connect-contact-lens))

(package
 (name awso-connectparticipant)
 (synopsis "AWS API for Connectparticipant")
 (depends awso))

(package
 (name awso-connectparticipant-async)
 (synopsis "AWS Async API for Connectparticipant")
 (depends awso-async awso-connectparticipant))

(package
 (name awso-connectparticipant-lwt)
 (synopsis "AWS Lwt API for Connectparticipant")
 (depends awso-lwt awso-connectparticipant))

(package
 (name awso-cur)
 (synopsis "AWS API for Cur")
 (depends awso))

(package
 (name awso-cur-async)
 (synopsis "AWS Async API for Cur")
 (depends awso-async awso-cur))

(package
 (name awso-cur-lwt)
 (synopsis "AWS Lwt API for Cur")
 (depends awso-lwt awso-cur))

(package
 (name awso-customer-profiles)
 (synopsis "AWS API for Customer-profiles")
 (depends awso))

(package
 (name awso-customer-profiles-async)
 (synopsis "AWS Async API for Customer-profiles")
 (depends awso-async awso-customer-profiles))

(package
 (name awso-customer-profiles-lwt)
 (synopsis "AWS Lwt API for Customer-profiles")
 (depends awso-lwt awso-customer-profiles))

(package
 (name awso-databrew)
 (synopsis "AWS API for Databrew")
 (depends awso))

(package
 (name awso-databrew-async)
 (synopsis "AWS Async API for Databrew")
 (depends awso-async awso-databrew))

(package
 (name awso-databrew-lwt)
 (synopsis "AWS Lwt API for Databrew")
 (depends awso-lwt awso-databrew))

(package
 (name awso-datapipeline)
 (synopsis "AWS API for Datapipeline")
 (depends awso))

(package
 (name awso-datapipeline-async)
 (synopsis "AWS Async API for Datapipeline")
 (depends awso-async awso-datapipeline))

(package
 (name awso-datapipeline-lwt)
 (synopsis "AWS Lwt API for Datapipeline")
 (depends awso-lwt awso-datapipeline))

(package
 (name awso-datasync)
 (synopsis "AWS API for Datasync")
 (depends awso))

(package
 (name awso-datasync-async)
 (synopsis "AWS Async API for Datasync")
 (depends awso-async awso-datasync))

(package
 (name awso-datasync-lwt)
 (synopsis "AWS Lwt API for Datasync")
 (depends awso-lwt awso-datasync))

(package
 (name awso-dax)
 (synopsis "AWS API for Dax")
 (depends awso))

(package
 (name awso-dax-async)
 (synopsis "AWS Async API for Dax")
 (depends awso-async awso-dax))

(package
 (name awso-dax-lwt)
 (synopsis "AWS Lwt API for Dax")
 (depends awso-lwt awso-dax))

(package
 (name awso-detective)
 (synopsis "AWS API for Detective")
 (depends awso))

(package
 (name awso-detective-async)
 (synopsis "AWS Async API for Detective")
 (depends awso-async awso-detective))

(package
 (name awso-detective-lwt)
 (synopsis "AWS Lwt API for Detective")
 (depends awso-lwt awso-detective))

(package
 (name awso-devicefarm)
 (synopsis "AWS API for Devicefarm")
 (depends awso))

(package
 (name awso-devicefarm-async)
 (synopsis "AWS Async API for Devicefarm")
 (depends awso-async awso-devicefarm))

(package
 (name awso-devicefarm-lwt)
 (synopsis "AWS Lwt API for Devicefarm")
 (depends awso-lwt awso-devicefarm))

(package
 (name awso-devops-guru)
 (synopsis "AWS API for Devops-guru")
 (depends awso))

(package
 (name awso-devops-guru-async)
 (synopsis "AWS Async API for Devops-guru")
 (depends awso-async awso-devops-guru))

(package
 (name awso-devops-guru-lwt)
 (synopsis "AWS Lwt API for Devops-guru")
 (depends awso-lwt awso-devops-guru))

(package
 (name awso-directconnect)
 (synopsis "AWS API for Directconnect")
 (depends awso))

(package
 (name awso-directconnect-async)
 (synopsis "AWS Async API for Directconnect")
 (depends awso-async awso-directconnect))

(package
 (name awso-directconnect-lwt)
 (synopsis "AWS Lwt API for Directconnect")
 (depends awso-lwt awso-directconnect))

(package
 (name awso-discovery)
 (synopsis "AWS API for Discovery")
 (depends awso))

(package
 (name awso-discovery-async)
 (synopsis "AWS Async API for Discovery")
 (depends awso-async awso-discovery))

(package
 (name awso-discovery-lwt)
 (synopsis "AWS Lwt API for Discovery")
 (depends awso-lwt awso-discovery))

(package
 (name awso-dlm)
 (synopsis "AWS API for Dlm")
 (depends awso))

(package
 (name awso-dlm-async)
 (synopsis "AWS Async API for Dlm")
 (depends awso-async awso-dlm))

(package
 (name awso-dlm-lwt)
 (synopsis "AWS Lwt API for Dlm")
 (depends awso-lwt awso-dlm))

(package
 (name awso-dms)
 (synopsis "AWS API for Dms")
 (depends awso))

(package
 (name awso-dms-async)
 (synopsis "AWS Async API for Dms")
 (depends awso-async awso-dms))

(package
 (name awso-dms-lwt)
 (synopsis "AWS Lwt API for Dms")
 (depends awso-lwt awso-dms))

(package
 (name awso-docdb)
 (synopsis "AWS API for Docdb")
 (depends awso))

(package
 (name awso-docdb-async)
 (synopsis "AWS Async API for Docdb")
 (depends awso-async awso-docdb))

(package
 (name awso-docdb-lwt)
 (synopsis "AWS Lwt API for Docdb")
 (depends awso-lwt awso-docdb))

(package
 (name awso-drs)
 (synopsis "AWS API for Drs")
 (depends awso))

(package
 (name awso-drs-async)
 (synopsis "AWS Async API for Drs")
 (depends awso-async awso-drs))

(package
 (name awso-drs-lwt)
 (synopsis "AWS Lwt API for Drs")
 (depends awso-lwt awso-drs))

(package
 (name awso-ds)
 (synopsis "AWS API for Ds")
 (depends awso))

(package
 (name awso-ds-async)
 (synopsis "AWS Async API for Ds")
 (depends awso-async awso-ds))

(package
 (name awso-ds-lwt)
 (synopsis "AWS Lwt API for Ds")
 (depends awso-lwt awso-ds))

(package
 (name awso-dynamodb)
 (synopsis "AWS API for Dynamodb")
 (depends awso))

(package
 (name awso-dynamodb-async)
 (synopsis "AWS Async API for Dynamodb")
 (depends awso-async awso-dynamodb))

(package
 (name awso-dynamodb-lwt)
 (synopsis "AWS Lwt API for Dynamodb")
 (depends awso-lwt awso-dynamodb))

(package
 (name awso-dynamodbstreams)
 (synopsis "AWS API for Dynamodbstreams")
 (depends awso))

(package
 (name awso-dynamodbstreams-async)
 (synopsis "AWS Async API for Dynamodbstreams")
 (depends awso-async awso-dynamodbstreams))

(package
 (name awso-dynamodbstreams-lwt)
 (synopsis "AWS Lwt API for Dynamodbstreams")
 (depends awso-lwt awso-dynamodbstreams))

(package
 (name awso-ebs)
 (synopsis "AWS API for Ebs")
 (depends awso))

(package
 (name awso-ebs-async)
 (synopsis "AWS Async API for Ebs")
 (depends awso-async awso-ebs))

(package
 (name awso-ebs-lwt)
 (synopsis "AWS Lwt API for Ebs")
 (depends awso-lwt awso-ebs))

(package
 (name awso-ec2)
 (synopsis "AWS API for Ec2")
 (depends awso))

(package
 (name awso-ec2-async)
 (synopsis "AWS Async API for Ec2")
 (depends awso-async awso-ec2))

(package
 (name awso-ec2-lwt)
 (synopsis "AWS Lwt API for Ec2")
 (depends awso-lwt awso-ec2))

(package
 (name awso-ec2-instance-connect)
 (synopsis "AWS API for Ec2-instance-connect")
 (depends awso))

(package
 (name awso-ec2-instance-connect-async)
 (synopsis "AWS Async API for Ec2-instance-connect")
 (depends awso-async awso-ec2-instance-connect))

(package
 (name awso-ec2-instance-connect-lwt)
 (synopsis "AWS Lwt API for Ec2-instance-connect")
 (depends awso-lwt awso-ec2-instance-connect))

(package
 (name awso-ecr)
 (synopsis "AWS API for Ecr")
 (depends awso))

(package
 (name awso-ecr-async)
 (synopsis "AWS Async API for Ecr")
 (depends awso-async awso-ecr))

(package
 (name awso-ecr-lwt)
 (synopsis "AWS Lwt API for Ecr")
 (depends awso-lwt awso-ecr))

(package
 (name awso-ecr-public)
 (synopsis "AWS API for Ecr-public")
 (depends awso))

(package
 (name awso-ecr-public-async)
 (synopsis "AWS Async API for Ecr-public")
 (depends awso-async awso-ecr-public))

(package
 (name awso-ecr-public-lwt)
 (synopsis "AWS Lwt API for Ecr-public")
 (depends awso-lwt awso-ecr-public))

(package
 (name awso-ecs)
 (synopsis "AWS API for Ecs")
 (depends awso))

(package
 (name awso-ecs-async)
 (synopsis "AWS Async API for Ecs")
 (depends awso-async awso-ecs))

(package
 (name awso-ecs-lwt)
 (synopsis "AWS Lwt API for Ecs")
 (depends awso-lwt awso-ecs))

(package
 (name awso-efs)
 (synopsis "AWS API for Efs")
 (depends awso))

(package
 (name awso-efs-async)
 (synopsis "AWS Async API for Efs")
 (depends awso-async awso-efs))

(package
 (name awso-efs-lwt)
 (synopsis "AWS Lwt API for Efs")
 (depends awso-lwt awso-efs))

(package
 (name awso-eks)
 (synopsis "AWS API for Eks")
 (depends awso))

(package
 (name awso-eks-async)
 (synopsis "AWS Async API for Eks")
 (depends awso-async awso-eks))

(package
 (name awso-eks-lwt)
 (synopsis "AWS Lwt API for Eks")
 (depends awso-lwt awso-eks))

(package
 (name awso-elastic-inference)
 (synopsis "AWS API for Elastic-inference")
 (depends awso))

(package
 (name awso-elastic-inference-async)
 (synopsis "AWS Async API for Elastic-inference")
 (depends awso-async awso-elastic-inference))

(package
 (name awso-elastic-inference-lwt)
 (synopsis "AWS Lwt API for Elastic-inference")
 (depends awso-lwt awso-elastic-inference))

(package
 (name awso-elasticache)
 (synopsis "AWS API for Elasticache")
 (depends awso))

(package
 (name awso-elasticache-async)
 (synopsis "AWS Async API for Elasticache")
 (depends awso-async awso-elasticache))

(package
 (name awso-elasticache-lwt)
 (synopsis "AWS Lwt API for Elasticache")
 (depends awso-lwt awso-elasticache))

(package
 (name awso-elasticbeanstalk)
 (synopsis "AWS API for Elasticbeanstalk")
 (depends awso))

(package
 (name awso-elasticbeanstalk-async)
 (synopsis "AWS Async API for Elasticbeanstalk")
 (depends awso-async awso-elasticbeanstalk))

(package
 (name awso-elasticbeanstalk-lwt)
 (synopsis "AWS Lwt API for Elasticbeanstalk")
 (depends awso-lwt awso-elasticbeanstalk))

(package
 (name awso-elastictranscoder)
 (synopsis "AWS API for Elastictranscoder")
 (depends awso))

(package
 (name awso-elastictranscoder-async)
 (synopsis "AWS Async API for Elastictranscoder")
 (depends awso-async awso-elastictranscoder))

(package
 (name awso-elastictranscoder-lwt)
 (synopsis "AWS Lwt API for Elastictranscoder")
 (depends awso-lwt awso-elastictranscoder))

(package
 (name awso-elb)
 (synopsis "AWS API for Elb")
 (depends awso))

(package
 (name awso-elb-async)
 (synopsis "AWS Async API for Elb")
 (depends awso-async awso-elb))

(package
 (name awso-elb-lwt)
 (synopsis "AWS Lwt API for Elb")
 (depends awso-lwt awso-elb))

(package
 (name awso-elbv2)
 (synopsis "AWS API for Elbv2")
 (depends awso))

(package
 (name awso-elbv2-async)
 (synopsis "AWS Async API for Elbv2")
 (depends awso-async awso-elbv2))

(package
 (name awso-elbv2-lwt)
 (synopsis "AWS Lwt API for Elbv2")
 (depends awso-lwt awso-elbv2))

(package
 (name awso-emr)
 (synopsis "AWS API for Emr")
 (depends awso))

(package
 (name awso-emr-async)
 (synopsis "AWS Async API for Emr")
 (depends awso-async awso-emr))

(package
 (name awso-emr-lwt)
 (synopsis "AWS Lwt API for Emr")
 (depends awso-lwt awso-emr))

(package
 (name awso-emr-containers)
 (synopsis "AWS API for Emr-containers")
 (depends awso))

(package
 (name awso-emr-containers-async)
 (synopsis "AWS Async API for Emr-containers")
 (depends awso-async awso-emr-containers))

(package
 (name awso-emr-containers-lwt)
 (synopsis "AWS Lwt API for Emr-containers")
 (depends awso-lwt awso-emr-containers))

(package
 (name awso-es)
 (synopsis "AWS API for Es")
 (depends awso))

(package
 (name awso-es-async)
 (synopsis "AWS Async API for Es")
 (depends awso-async awso-es))

(package
 (name awso-es-lwt)
 (synopsis "AWS Lwt API for Es")
 (depends awso-lwt awso-es))

(package
 (name awso-events)
 (synopsis "AWS API for Events")
 (depends awso))

(package
 (name awso-events-async)
 (synopsis "AWS Async API for Events")
 (depends awso-async awso-events))

(package
 (name awso-events-lwt)
 (synopsis "AWS Lwt API for Events")
 (depends awso-lwt awso-events))

(package
 (name awso-evidently)
 (synopsis "AWS API for Evidently")
 (depends awso))

(package
 (name awso-evidently-async)
 (synopsis "AWS Async API for Evidently")
 (depends awso-async awso-evidently))

(package
 (name awso-evidently-lwt)
 (synopsis "AWS Lwt API for Evidently")
 (depends awso-lwt awso-evidently))

(package
 (name awso-finspace)
 (synopsis "AWS API for Finspace")
 (depends awso))

(package
 (name awso-finspace-async)
 (synopsis "AWS Async API for Finspace")
 (depends awso-async awso-finspace))

(package
 (name awso-finspace-lwt)
 (synopsis "AWS Lwt API for Finspace")
 (depends awso-lwt awso-finspace))

(package
 (name awso-finspace-data)
 (synopsis "AWS API for Finspace-data")
 (depends awso))

(package
 (name awso-finspace-data-async)
 (synopsis "AWS Async API for Finspace-data")
 (depends awso-async awso-finspace-data))

(package
 (name awso-finspace-data-lwt)
 (synopsis "AWS Lwt API for Finspace-data")
 (depends awso-lwt awso-finspace-data))

(package
 (name awso-firehose)
 (synopsis "AWS API for Firehose")
 (depends awso))

(package
 (name awso-firehose-async)
 (synopsis "AWS Async API for Firehose")
 (depends awso-async awso-firehose))

(package
 (name awso-firehose-lwt)
 (synopsis "AWS Lwt API for Firehose")
 (depends awso-lwt awso-firehose))

(package
 (name awso-fis)
 (synopsis "AWS API for Fis")
 (depends awso))

(package
 (name awso-fis-async)
 (synopsis "AWS Async API for Fis")
 (depends awso-async awso-fis))

(package
 (name awso-fis-lwt)
 (synopsis "AWS Lwt API for Fis")
 (depends awso-lwt awso-fis))

(package
 (name awso-fms)
 (synopsis "AWS API for Fms")
 (depends awso))

(package
 (name awso-fms-async)
 (synopsis "AWS Async API for Fms")
 (depends awso-async awso-fms))

(package
 (name awso-fms-lwt)
 (synopsis "AWS Lwt API for Fms")
 (depends awso-lwt awso-fms))

(package
 (name awso-forecast)
 (synopsis "AWS API for Forecast")
 (depends awso))

(package
 (name awso-forecast-async)
 (synopsis "AWS Async API for Forecast")
 (depends awso-async awso-forecast))

(package
 (name awso-forecast-lwt)
 (synopsis "AWS Lwt API for Forecast")
 (depends awso-lwt awso-forecast))

(package
 (name awso-forecastquery)
 (synopsis "AWS API for Forecastquery")
 (depends awso))

(package
 (name awso-forecastquery-async)
 (synopsis "AWS Async API for Forecastquery")
 (depends awso-async awso-forecastquery))

(package
 (name awso-forecastquery-lwt)
 (synopsis "AWS Lwt API for Forecastquery")
 (depends awso-lwt awso-forecastquery))

(package
 (name awso-frauddetector)
 (synopsis "AWS API for Frauddetector")
 (depends awso))

(package
 (name awso-frauddetector-async)
 (synopsis "AWS Async API for Frauddetector")
 (depends awso-async awso-frauddetector))

(package
 (name awso-frauddetector-lwt)
 (synopsis "AWS Lwt API for Frauddetector")
 (depends awso-lwt awso-frauddetector))

(package
 (name awso-fsx)
 (synopsis "AWS API for Fsx")
 (depends awso))

(package
 (name awso-fsx-async)
 (synopsis "AWS Async API for Fsx")
 (depends awso-async awso-fsx))

(package
 (name awso-fsx-lwt)
 (synopsis "AWS Lwt API for Fsx")
 (depends awso-lwt awso-fsx))

(package
 (name awso-gamelift)
 (synopsis "AWS API for Gamelift")
 (depends awso))

(package
 (name awso-gamelift-async)
 (synopsis "AWS Async API for Gamelift")
 (depends awso-async awso-gamelift))

(package
 (name awso-gamelift-lwt)
 (synopsis "AWS Lwt API for Gamelift")
 (depends awso-lwt awso-gamelift))

(package
 (name awso-gamesparks)
 (synopsis "AWS API for Gamesparks")
 (depends awso))

(package
 (name awso-gamesparks-async)
 (synopsis "AWS Async API for Gamesparks")
 (depends awso-async awso-gamesparks))

(package
 (name awso-gamesparks-lwt)
 (synopsis "AWS Lwt API for Gamesparks")
 (depends awso-lwt awso-gamesparks))

(package
 (name awso-glacier)
 (synopsis "AWS API for Glacier")
 (depends awso))

(package
 (name awso-glacier-async)
 (synopsis "AWS Async API for Glacier")
 (depends awso-async awso-glacier))

(package
 (name awso-glacier-lwt)
 (synopsis "AWS Lwt API for Glacier")
 (depends awso-lwt awso-glacier))

(package
 (name awso-globalaccelerator)
 (synopsis "AWS API for Globalaccelerator")
 (depends awso))

(package
 (name awso-globalaccelerator-async)
 (synopsis "AWS Async API for Globalaccelerator")
 (depends awso-async awso-globalaccelerator))

(package
 (name awso-globalaccelerator-lwt)
 (synopsis "AWS Lwt API for Globalaccelerator")
 (depends awso-lwt awso-globalaccelerator))

(package
 (name awso-glue)
 (synopsis "AWS API for Glue")
 (depends awso))

(package
 (name awso-glue-async)
 (synopsis "AWS Async API for Glue")
 (depends awso-async awso-glue))

(package
 (name awso-glue-lwt)
 (synopsis "AWS Lwt API for Glue")
 (depends awso-lwt awso-glue))

(package
 (name awso-grafana)
 (synopsis "AWS API for Grafana")
 (depends awso))

(package
 (name awso-grafana-async)
 (synopsis "AWS Async API for Grafana")
 (depends awso-async awso-grafana))

(package
 (name awso-grafana-lwt)
 (synopsis "AWS Lwt API for Grafana")
 (depends awso-lwt awso-grafana))

(package
 (name awso-greengrass)
 (synopsis "AWS API for Greengrass")
 (depends awso))

(package
 (name awso-greengrass-async)
 (synopsis "AWS Async API for Greengrass")
 (depends awso-async awso-greengrass))

(package
 (name awso-greengrass-lwt)
 (synopsis "AWS Lwt API for Greengrass")
 (depends awso-lwt awso-greengrass))

(package
 (name awso-greengrassv2)
 (synopsis "AWS API for Greengrassv2")
 (depends awso))

(package
 (name awso-greengrassv2-async)
 (synopsis "AWS Async API for Greengrassv2")
 (depends awso-async awso-greengrassv2))

(package
 (name awso-greengrassv2-lwt)
 (synopsis "AWS Lwt API for Greengrassv2")
 (depends awso-lwt awso-greengrassv2))

(package
 (name awso-groundstation)
 (synopsis "AWS API for Groundstation")
 (depends awso))

(package
 (name awso-groundstation-async)
 (synopsis "AWS Async API for Groundstation")
 (depends awso-async awso-groundstation))

(package
 (name awso-groundstation-lwt)
 (synopsis "AWS Lwt API for Groundstation")
 (depends awso-lwt awso-groundstation))

(package
 (name awso-guardduty)
 (synopsis "AWS API for Guardduty")
 (depends awso))

(package
 (name awso-guardduty-async)
 (synopsis "AWS Async API for Guardduty")
 (depends awso-async awso-guardduty))

(package
 (name awso-guardduty-lwt)
 (synopsis "AWS Lwt API for Guardduty")
 (depends awso-lwt awso-guardduty))

(package
 (name awso-healthlake)
 (synopsis "AWS API for Healthlake")
 (depends awso))

(package
 (name awso-healthlake-async)
 (synopsis "AWS Async API for Healthlake")
 (depends awso-async awso-healthlake))

(package
 (name awso-healthlake-lwt)
 (synopsis "AWS Lwt API for Healthlake")
 (depends awso-lwt awso-healthlake))

(package
 (name awso-honeycode)
 (synopsis "AWS API for Honeycode")
 (depends awso))

(package
 (name awso-honeycode-async)
 (synopsis "AWS Async API for Honeycode")
 (depends awso-async awso-honeycode))

(package
 (name awso-honeycode-lwt)
 (synopsis "AWS Lwt API for Honeycode")
 (depends awso-lwt awso-honeycode))

(package
 (name awso-iam)
 (synopsis "AWS API for Iam")
 (depends awso))

(package
 (name awso-iam-async)
 (synopsis "AWS Async API for Iam")
 (depends awso-async awso-iam))

(package
 (name awso-iam-lwt)
 (synopsis "AWS Lwt API for Iam")
 (depends awso-lwt awso-iam))

(package
 (name awso-identitystore)
 (synopsis "AWS API for Identitystore")
 (depends awso))

(package
 (name awso-identitystore-async)
 (synopsis "AWS Async API for Identitystore")
 (depends awso-async awso-identitystore))

(package
 (name awso-identitystore-lwt)
 (synopsis "AWS Lwt API for Identitystore")
 (depends awso-lwt awso-identitystore))

(package
 (name awso-imagebuilder)
 (synopsis "AWS API for Imagebuilder")
 (depends awso))

(package
 (name awso-imagebuilder-async)
 (synopsis "AWS Async API for Imagebuilder")
 (depends awso-async awso-imagebuilder))

(package
 (name awso-imagebuilder-lwt)
 (synopsis "AWS Lwt API for Imagebuilder")
 (depends awso-lwt awso-imagebuilder))

(package
 (name awso-importexport)
 (synopsis "AWS API for Importexport")
 (depends awso))

(package
 (name awso-importexport-async)
 (synopsis "AWS Async API for Importexport")
 (depends awso-async awso-importexport))

(package
 (name awso-importexport-lwt)
 (synopsis "AWS Lwt API for Importexport")
 (depends awso-lwt awso-importexport))

(package
 (name awso-inspector)
 (synopsis "AWS API for Inspector")
 (depends awso))

(package
 (name awso-inspector-async)
 (synopsis "AWS Async API for Inspector")
 (depends awso-async awso-inspector))

(package
 (name awso-inspector-lwt)
 (synopsis "AWS Lwt API for Inspector")
 (depends awso-lwt awso-inspector))

(package
 (name awso-inspector2)
 (synopsis "AWS API for Inspector2")
 (depends awso))

(package
 (name awso-inspector2-async)
 (synopsis "AWS Async API for Inspector2")
 (depends awso-async awso-inspector2))

(package
 (name awso-inspector2-lwt)
 (synopsis "AWS Lwt API for Inspector2")
 (depends awso-lwt awso-inspector2))

(package
 (name awso-iot)
 (synopsis "AWS API for Iot")
 (depends awso))

(package
 (name awso-iot-async)
 (synopsis "AWS Async API for Iot")
 (depends awso-async awso-iot))

(package
 (name awso-iot-lwt)
 (synopsis "AWS Lwt API for Iot")
 (depends awso-lwt awso-iot))

(package
 (name awso-iot-data)
 (synopsis "AWS API for Iot-data")
 (depends awso))

(package
 (name awso-iot-data-async)
 (synopsis "AWS Async API for Iot-data")
 (depends awso-async awso-iot-data))

(package
 (name awso-iot-data-lwt)
 (synopsis "AWS Lwt API for Iot-data")
 (depends awso-lwt awso-iot-data))

(package
 (name awso-iot-jobs-data)
 (synopsis "AWS API for Iot-jobs-data")
 (depends awso))

(package
 (name awso-iot-jobs-data-async)
 (synopsis "AWS Async API for Iot-jobs-data")
 (depends awso-async awso-iot-jobs-data))

(package
 (name awso-iot-jobs-data-lwt)
 (synopsis "AWS Lwt API for Iot-jobs-data")
 (depends awso-lwt awso-iot-jobs-data))

(package
 (name awso-iot1click-devices)
 (synopsis "AWS API for Iot1click-devices")
 (depends awso))

(package
 (name awso-iot1click-devices-async)
 (synopsis "AWS Async API for Iot1click-devices")
 (depends awso-async awso-iot1click-devices))

(package
 (name awso-iot1click-devices-lwt)
 (synopsis "AWS Lwt API for Iot1click-devices")
 (depends awso-lwt awso-iot1click-devices))

(package
 (name awso-iot1click-projects)
 (synopsis "AWS API for Iot1click-projects")
 (depends awso))

(package
 (name awso-iot1click-projects-async)
 (synopsis "AWS Async API for Iot1click-projects")
 (depends awso-async awso-iot1click-projects))

(package
 (name awso-iot1click-projects-lwt)
 (synopsis "AWS Lwt API for Iot1click-projects")
 (depends awso-lwt awso-iot1click-projects))

(package
 (name awso-iotanalytics)
 (synopsis "AWS API for Iotanalytics")
 (depends awso))

(package
 (name awso-iotanalytics-async)
 (synopsis "AWS Async API for Iotanalytics")
 (depends awso-async awso-iotanalytics))

(package
 (name awso-iotanalytics-lwt)
 (synopsis "AWS Lwt API for Iotanalytics")
 (depends awso-lwt awso-iotanalytics))

(package
 (name awso-iotdeviceadvisor)
 (synopsis "AWS API for Iotdeviceadvisor")
 (depends awso))

(package
 (name awso-iotdeviceadvisor-async)
 (synopsis "AWS Async API for Iotdeviceadvisor")
 (depends awso-async awso-iotdeviceadvisor))

(package
 (name awso-iotdeviceadvisor-lwt)
 (synopsis "AWS Lwt API for Iotdeviceadvisor")
 (depends awso-lwt awso-iotdeviceadvisor))

(package
 (name awso-iotevents)
 (synopsis "AWS API for Iotevents")
 (depends awso))

(package
 (name awso-iotevents-async)
 (synopsis "AWS Async API for Iotevents")
 (depends awso-async awso-iotevents))

(package
 (name awso-iotevents-lwt)
 (synopsis "AWS Lwt API for Iotevents")
 (depends awso-lwt awso-iotevents))

(package
 (name awso-iotevents-data)
 (synopsis "AWS API for Iotevents-data")
 (depends awso))

(package
 (name awso-iotevents-data-async)
 (synopsis "AWS Async API for Iotevents-data")
 (depends awso-async awso-iotevents-data))

(package
 (name awso-iotevents-data-lwt)
 (synopsis "AWS Lwt API for Iotevents-data")
 (depends awso-lwt awso-iotevents-data))

(package
 (name awso-iotfleethub)
 (synopsis "AWS API for Iotfleethub")
 (depends awso))

(package
 (name awso-iotfleethub-async)
 (synopsis "AWS Async API for Iotfleethub")
 (depends awso-async awso-iotfleethub))

(package
 (name awso-iotfleethub-lwt)
 (synopsis "AWS Lwt API for Iotfleethub")
 (depends awso-lwt awso-iotfleethub))

(package
 (name awso-iotsecuretunneling)
 (synopsis "AWS API for Iotsecuretunneling")
 (depends awso))

(package
 (name awso-iotsecuretunneling-async)
 (synopsis "AWS Async API for Iotsecuretunneling")
 (depends awso-async awso-iotsecuretunneling))

(package
 (name awso-iotsecuretunneling-lwt)
 (synopsis "AWS Lwt API for Iotsecuretunneling")
 (depends awso-lwt awso-iotsecuretunneling))

(package
 (name awso-iotsitewise)
 (synopsis "AWS API for Iotsitewise")
 (depends awso))

(package
 (name awso-iotsitewise-async)
 (synopsis "AWS Async API for Iotsitewise")
 (depends awso-async awso-iotsitewise))

(package
 (name awso-iotsitewise-lwt)
 (synopsis "AWS Lwt API for Iotsitewise")
 (depends awso-lwt awso-iotsitewise))

(package
 (name awso-iotthingsgraph)
 (synopsis "AWS API for Iotthingsgraph")
 (depends awso))

(package
 (name awso-iotthingsgraph-async)
 (synopsis "AWS Async API for Iotthingsgraph")
 (depends awso-async awso-iotthingsgraph))

(package
 (name awso-iotthingsgraph-lwt)
 (synopsis "AWS Lwt API for Iotthingsgraph")
 (depends awso-lwt awso-iotthingsgraph))

(package
 (name awso-iotwireless)
 (synopsis "AWS API for Iotwireless")
 (depends awso))

(package
 (name awso-iotwireless-async)
 (synopsis "AWS Async API for Iotwireless")
 (depends awso-async awso-iotwireless))

(package
 (name awso-iotwireless-lwt)
 (synopsis "AWS Lwt API for Iotwireless")
 (depends awso-lwt awso-iotwireless))

(package
 (name awso-ivs)
 (synopsis "AWS API for Ivs")
 (depends awso))

(package
 (name awso-ivs-async)
 (synopsis "AWS Async API for Ivs")
 (depends awso-async awso-ivs))

(package
 (name awso-ivs-lwt)
 (synopsis "AWS Lwt API for Ivs")
 (depends awso-lwt awso-ivs))

(package
 (name awso-kafka)
 (synopsis "AWS API for Kafka")
 (depends awso))

(package
 (name awso-kafka-async)
 (synopsis "AWS Async API for Kafka")
 (depends awso-async awso-kafka))

(package
 (name awso-kafka-lwt)
 (synopsis "AWS Lwt API for Kafka")
 (depends awso-lwt awso-kafka))

(package
 (name awso-kafkaconnect)
 (synopsis "AWS API for Kafkaconnect")
 (depends awso))

(package
 (name awso-kafkaconnect-async)
 (synopsis "AWS Async API for Kafkaconnect")
 (depends awso-async awso-kafkaconnect))

(package
 (name awso-kafkaconnect-lwt)
 (synopsis "AWS Lwt API for Kafkaconnect")
 (depends awso-lwt awso-kafkaconnect))

(package
 (name awso-kendra)
 (synopsis "AWS API for Kendra")
 (depends awso))

(package
 (name awso-kendra-async)
 (synopsis "AWS Async API for Kendra")
 (depends awso-async awso-kendra))

(package
 (name awso-kendra-lwt)
 (synopsis "AWS Lwt API for Kendra")
 (depends awso-lwt awso-kendra))

(package
 (name awso-keyspaces)
 (synopsis "AWS API for Keyspaces")
 (depends awso))

(package
 (name awso-keyspaces-async)
 (synopsis "AWS Async API for Keyspaces")
 (depends awso-async awso-keyspaces))

(package
 (name awso-keyspaces-lwt)
 (synopsis "AWS Lwt API for Keyspaces")
 (depends awso-lwt awso-keyspaces))

(package
 (name awso-kinesis)
 (synopsis "AWS API for Kinesis")
 (depends awso))

(package
 (name awso-kinesis-async)
 (synopsis "AWS Async API for Kinesis")
 (depends awso-async awso-kinesis))

(package
 (name awso-kinesis-lwt)
 (synopsis "AWS Lwt API for Kinesis")
 (depends awso-lwt awso-kinesis))

(package
 (name awso-kinesis-video-archived-media)
 (synopsis "AWS API for Kinesis-video-archived-media")
 (depends awso))

(package
 (name awso-kinesis-video-archived-media-async)
 (synopsis "AWS Async API for Kinesis-video-archived-media")
 (depends awso-async awso-kinesis-video-archived-media))

(package
 (name awso-kinesis-video-archived-media-lwt)
 (synopsis "AWS Lwt API for Kinesis-video-archived-media")
 (depends awso-lwt awso-kinesis-video-archived-media))

(package
 (name awso-kinesis-video-media)
 (synopsis "AWS API for Kinesis-video-media")
 (depends awso))

(package
 (name awso-kinesis-video-media-async)
 (synopsis "AWS Async API for Kinesis-video-media")
 (depends awso-async awso-kinesis-video-media))

(package
 (name awso-kinesis-video-media-lwt)
 (synopsis "AWS Lwt API for Kinesis-video-media")
 (depends awso-lwt awso-kinesis-video-media))

(package
 (name awso-kinesis-video-signaling)
 (synopsis "AWS API for Kinesis-video-signaling")
 (depends awso))

(package
 (name awso-kinesis-video-signaling-async)
 (synopsis "AWS Async API for Kinesis-video-signaling")
 (depends awso-async awso-kinesis-video-signaling))

(package
 (name awso-kinesis-video-signaling-lwt)
 (synopsis "AWS Lwt API for Kinesis-video-signaling")
 (depends awso-lwt awso-kinesis-video-signaling))

(package
 (name awso-kinesisanalytics)
 (synopsis "AWS API for Kinesisanalytics")
 (depends awso))

(package
 (name awso-kinesisanalytics-async)
 (synopsis "AWS Async API for Kinesisanalytics")
 (depends awso-async awso-kinesisanalytics))

(package
 (name awso-kinesisanalytics-lwt)
 (synopsis "AWS Lwt API for Kinesisanalytics")
 (depends awso-lwt awso-kinesisanalytics))

(package
 (name awso-kinesisanalyticsv2)
 (synopsis "AWS API for Kinesisanalyticsv2")
 (depends awso))

(package
 (name awso-kinesisanalyticsv2-async)
 (synopsis "AWS Async API for Kinesisanalyticsv2")
 (depends awso-async awso-kinesisanalyticsv2))

(package
 (name awso-kinesisanalyticsv2-lwt)
 (synopsis "AWS Lwt API for Kinesisanalyticsv2")
 (depends awso-lwt awso-kinesisanalyticsv2))

(package
 (name awso-kinesisvideo)
 (synopsis "AWS API for Kinesisvideo")
 (depends awso))

(package
 (name awso-kinesisvideo-async)
 (synopsis "AWS Async API for Kinesisvideo")
 (depends awso-async awso-kinesisvideo))

(package
 (name awso-kinesisvideo-lwt)
 (synopsis "AWS Lwt API for Kinesisvideo")
 (depends awso-lwt awso-kinesisvideo))

(package
 (name awso-kms)
 (synopsis "AWS API for Kms")
 (depends awso))

(package
 (name awso-kms-async)
 (synopsis "AWS Async API for Kms")
 (depends awso-async awso-kms))

(package
 (name awso-kms-lwt)
 (synopsis "AWS Lwt API for Kms")
 (depends awso-lwt awso-kms))

(package
 (name awso-lakeformation)
 (synopsis "AWS API for Lakeformation")
 (depends awso))

(package
 (name awso-lakeformation-async)
 (synopsis "AWS Async API for Lakeformation")
 (depends awso-async awso-lakeformation))

(package
 (name awso-lakeformation-lwt)
 (synopsis "AWS Lwt API for Lakeformation")
 (depends awso-lwt awso-lakeformation))

(package
 (name awso-lambda)
 (synopsis "AWS API for Lambda")
 (depends awso))

(package
 (name awso-lambda-async)
 (synopsis "AWS Async API for Lambda")
 (depends awso-async awso-lambda))

(package
 (name awso-lambda-lwt)
 (synopsis "AWS Lwt API for Lambda")
 (depends awso-lwt awso-lambda))

(package
 (name awso-lex-models)
 (synopsis "AWS API for Lex-models")
 (depends awso))

(package
 (name awso-lex-models-async)
 (synopsis "AWS Async API for Lex-models")
 (depends awso-async awso-lex-models))

(package
 (name awso-lex-models-lwt)
 (synopsis "AWS Lwt API for Lex-models")
 (depends awso-lwt awso-lex-models))

(package
 (name awso-lexv2-models)
 (synopsis "AWS API for Lexv2-models")
 (depends awso))

(package
 (name awso-lexv2-models-async)
 (synopsis "AWS Async API for Lexv2-models")
 (depends awso-async awso-lexv2-models))

(package
 (name awso-lexv2-models-lwt)
 (synopsis "AWS Lwt API for Lexv2-models")
 (depends awso-lwt awso-lexv2-models))

(package
 (name awso-license-manager)
 (synopsis "AWS API for License-manager")
 (depends awso))

(package
 (name awso-license-manager-async)
 (synopsis "AWS Async API for License-manager")
 (depends awso-async awso-license-manager))

(package
 (name awso-license-manager-lwt)
 (synopsis "AWS Lwt API for License-manager")
 (depends awso-lwt awso-license-manager))

(package
 (name awso-lightsail)
 (synopsis "AWS API for Lightsail")
 (depends awso))

(package
 (name awso-lightsail-async)
 (synopsis "AWS Async API for Lightsail")
 (depends awso-async awso-lightsail))

(package
 (name awso-lightsail-lwt)
 (synopsis "AWS Lwt API for Lightsail")
 (depends awso-lwt awso-lightsail))

(package
 (name awso-location)
 (synopsis "AWS API for Location")
 (depends awso))

(package
 (name awso-location-async)
 (synopsis "AWS Async API for Location")
 (depends awso-async awso-location))

(package
 (name awso-location-lwt)
 (synopsis "AWS Lwt API for Location")
 (depends awso-lwt awso-location))

(package
 (name awso-logs)
 (synopsis "AWS API for Logs")
 (depends awso))

(package
 (name awso-logs-async)
 (synopsis "AWS Async API for Logs")
 (depends awso-async awso-logs))

(package
 (name awso-logs-lwt)
 (synopsis "AWS Lwt API for Logs")
 (depends awso-lwt awso-logs))

(package
 (name awso-lookoutequipment)
 (synopsis "AWS API for Lookoutequipment")
 (depends awso))

(package
 (name awso-lookoutequipment-async)
 (synopsis "AWS Async API for Lookoutequipment")
 (depends awso-async awso-lookoutequipment))

(package
 (name awso-lookoutequipment-lwt)
 (synopsis "AWS Lwt API for Lookoutequipment")
 (depends awso-lwt awso-lookoutequipment))

(package
 (name awso-lookoutmetrics)
 (synopsis "AWS API for Lookoutmetrics")
 (depends awso))

(package
 (name awso-lookoutmetrics-async)
 (synopsis "AWS Async API for Lookoutmetrics")
 (depends awso-async awso-lookoutmetrics))

(package
 (name awso-lookoutmetrics-lwt)
 (synopsis "AWS Lwt API for Lookoutmetrics")
 (depends awso-lwt awso-lookoutmetrics))

(package
 (name awso-machinelearning)
 (synopsis "AWS API for Machinelearning")
 (depends awso))

(package
 (name awso-machinelearning-async)
 (synopsis "AWS Async API for Machinelearning")
 (depends awso-async awso-machinelearning))

(package
 (name awso-machinelearning-lwt)
 (synopsis "AWS Lwt API for Machinelearning")
 (depends awso-lwt awso-machinelearning))

(package
 (name awso-macie)
 (synopsis "AWS API for Macie")
 (depends awso))

(package
 (name awso-macie-async)
 (synopsis "AWS Async API for Macie")
 (depends awso-async awso-macie))

(package
 (name awso-macie-lwt)
 (synopsis "AWS Lwt API for Macie")
 (depends awso-lwt awso-macie))

(package
 (name awso-macie2)
 (synopsis "AWS API for Macie2")
 (depends awso))

(package
 (name awso-macie2-async)
 (synopsis "AWS Async API for Macie2")
 (depends awso-async awso-macie2))

(package
 (name awso-macie2-lwt)
 (synopsis "AWS Lwt API for Macie2")
 (depends awso-lwt awso-macie2))

(package
 (name awso-managedblockchain)
 (synopsis "AWS API for Managedblockchain")
 (depends awso))

(package
 (name awso-managedblockchain-async)
 (synopsis "AWS Async API for Managedblockchain")
 (depends awso-async awso-managedblockchain))

(package
 (name awso-managedblockchain-lwt)
 (synopsis "AWS Lwt API for Managedblockchain")
 (depends awso-lwt awso-managedblockchain))

(package
 (name awso-marketplace-catalog)
 (synopsis "AWS API for Marketplace-catalog")
 (depends awso))

(package
 (name awso-marketplace-catalog-async)
 (synopsis "AWS Async API for Marketplace-catalog")
 (depends awso-async awso-marketplace-catalog))

(package
 (name awso-marketplace-catalog-lwt)
 (synopsis "AWS Lwt API for Marketplace-catalog")
 (depends awso-lwt awso-marketplace-catalog))

(package
 (name awso-marketplace-entitlement)
 (synopsis "AWS API for Marketplace-entitlement")
 (depends awso))

(package
 (name awso-marketplace-entitlement-async)
 (synopsis "AWS Async API for Marketplace-entitlement")
 (depends awso-async awso-marketplace-entitlement))

(package
 (name awso-marketplace-entitlement-lwt)
 (synopsis "AWS Lwt API for Marketplace-entitlement")
 (depends awso-lwt awso-marketplace-entitlement))

(package
 (name awso-marketplacecommerceanalytics)
 (synopsis "AWS API for Marketplacecommerceanalytics")
 (depends awso))

(package
 (name awso-marketplacecommerceanalytics-async)
 (synopsis "AWS Async API for Marketplacecommerceanalytics")
 (depends awso-async awso-marketplacecommerceanalytics))

(package
 (name awso-marketplacecommerceanalytics-lwt)
 (synopsis "AWS Lwt API for Marketplacecommerceanalytics")
 (depends awso-lwt awso-marketplacecommerceanalytics))

(package
 (name awso-mediaconvert)
 (synopsis "AWS API for Mediaconvert")
 (depends awso))

(package
 (name awso-mediaconvert-async)
 (synopsis "AWS Async API for Mediaconvert")
 (depends awso-async awso-mediaconvert))

(package
 (name awso-mediaconvert-lwt)
 (synopsis "AWS Lwt API for Mediaconvert")
 (depends awso-lwt awso-mediaconvert))

(package
 (name awso-mediapackage)
 (synopsis "AWS API for Mediapackage")
 (depends awso))

(package
 (name awso-mediapackage-async)
 (synopsis "AWS Async API for Mediapackage")
 (depends awso-async awso-mediapackage))

(package
 (name awso-mediapackage-lwt)
 (synopsis "AWS Lwt API for Mediapackage")
 (depends awso-lwt awso-mediapackage))

(package
 (name awso-mediapackage-vod)
 (synopsis "AWS API for Mediapackage-vod")
 (depends awso))

(package
 (name awso-mediapackage-vod-async)
 (synopsis "AWS Async API for Mediapackage-vod")
 (depends awso-async awso-mediapackage-vod))

(package
 (name awso-mediapackage-vod-lwt)
 (synopsis "AWS Lwt API for Mediapackage-vod")
 (depends awso-lwt awso-mediapackage-vod))

(package
 (name awso-mediastore)
 (synopsis "AWS API for Mediastore")
 (depends awso))

(package
 (name awso-mediastore-async)
 (synopsis "AWS Async API for Mediastore")
 (depends awso-async awso-mediastore))

(package
 (name awso-mediastore-lwt)
 (synopsis "AWS Lwt API for Mediastore")
 (depends awso-lwt awso-mediastore))

(package
 (name awso-mediastore-data)
 (synopsis "AWS API for Mediastore-data")
 (depends awso))

(package
 (name awso-mediastore-data-async)
 (synopsis "AWS Async API for Mediastore-data")
 (depends awso-async awso-mediastore-data))

(package
 (name awso-mediastore-data-lwt)
 (synopsis "AWS Lwt API for Mediastore-data")
 (depends awso-lwt awso-mediastore-data))

(package
 (name awso-mediatailor)
 (synopsis "AWS API for Mediatailor")
 (depends awso))

(package
 (name awso-mediatailor-async)
 (synopsis "AWS Async API for Mediatailor")
 (depends awso-async awso-mediatailor))

(package
 (name awso-mediatailor-lwt)
 (synopsis "AWS Lwt API for Mediatailor")
 (depends awso-lwt awso-mediatailor))

(package
 (name awso-memorydb)
 (synopsis "AWS API for Memorydb")
 (depends awso))

(package
 (name awso-memorydb-async)
 (synopsis "AWS Async API for Memorydb")
 (depends awso-async awso-memorydb))

(package
 (name awso-memorydb-lwt)
 (synopsis "AWS Lwt API for Memorydb")
 (depends awso-lwt awso-memorydb))

(package
 (name awso-meteringmarketplace)
 (synopsis "AWS API for Meteringmarketplace")
 (depends awso))

(package
 (name awso-meteringmarketplace-async)
 (synopsis "AWS Async API for Meteringmarketplace")
 (depends awso-async awso-meteringmarketplace))

(package
 (name awso-meteringmarketplace-lwt)
 (synopsis "AWS Lwt API for Meteringmarketplace")
 (depends awso-lwt awso-meteringmarketplace))

(package
 (name awso-mgh)
 (synopsis "AWS API for Mgh")
 (depends awso))

(package
 (name awso-mgh-async)
 (synopsis "AWS Async API for Mgh")
 (depends awso-async awso-mgh))

(package
 (name awso-mgh-lwt)
 (synopsis "AWS Lwt API for Mgh")
 (depends awso-lwt awso-mgh))

(package
 (name awso-mgn)
 (synopsis "AWS API for Mgn")
 (depends awso))

(package
 (name awso-mgn-async)
 (synopsis "AWS Async API for Mgn")
 (depends awso-async awso-mgn))

(package
 (name awso-mgn-lwt)
 (synopsis "AWS Lwt API for Mgn")
 (depends awso-lwt awso-mgn))

(package
 (name awso-migration-hub-refactor-spaces)
 (synopsis "AWS API for Migration-hub-refactor-spaces")
 (depends awso))

(package
 (name awso-migration-hub-refactor-spaces-async)
 (synopsis "AWS Async API for Migration-hub-refactor-spaces")
 (depends awso-async awso-migration-hub-refactor-spaces))

(package
 (name awso-migration-hub-refactor-spaces-lwt)
 (synopsis "AWS Lwt API for Migration-hub-refactor-spaces")
 (depends awso-lwt awso-migration-hub-refactor-spaces))

(package
 (name awso-migrationhub-config)
 (synopsis "AWS API for Migrationhub-config")
 (depends awso))

(package
 (name awso-migrationhub-config-async)
 (synopsis "AWS Async API for Migrationhub-config")
 (depends awso-async awso-migrationhub-config))

(package
 (name awso-migrationhub-config-lwt)
 (synopsis "AWS Lwt API for Migrationhub-config")
 (depends awso-lwt awso-migrationhub-config))

(package
 (name awso-migrationhubstrategy)
 (synopsis "AWS API for Migrationhubstrategy")
 (depends awso))

(package
 (name awso-migrationhubstrategy-async)
 (synopsis "AWS Async API for Migrationhubstrategy")
 (depends awso-async awso-migrationhubstrategy))

(package
 (name awso-migrationhubstrategy-lwt)
 (synopsis "AWS Lwt API for Migrationhubstrategy")
 (depends awso-lwt awso-migrationhubstrategy))

(package
 (name awso-mobile)
 (synopsis "AWS API for Mobile")
 (depends awso))

(package
 (name awso-mobile-async)
 (synopsis "AWS Async API for Mobile")
 (depends awso-async awso-mobile))

(package
 (name awso-mobile-lwt)
 (synopsis "AWS Lwt API for Mobile")
 (depends awso-lwt awso-mobile))

(package
 (name awso-mturk)
 (synopsis "AWS API for Mturk")
 (depends awso))

(package
 (name awso-mturk-async)
 (synopsis "AWS Async API for Mturk")
 (depends awso-async awso-mturk))

(package
 (name awso-mturk-lwt)
 (synopsis "AWS Lwt API for Mturk")
 (depends awso-lwt awso-mturk))

(package
 (name awso-mwaa)
 (synopsis "AWS API for Mwaa")
 (depends awso))

(package
 (name awso-mwaa-async)
 (synopsis "AWS Async API for Mwaa")
 (depends awso-async awso-mwaa))

(package
 (name awso-mwaa-lwt)
 (synopsis "AWS Lwt API for Mwaa")
 (depends awso-lwt awso-mwaa))

(package
 (name awso-neptune)
 (synopsis "AWS API for Neptune")
 (depends awso))

(package
 (name awso-neptune-async)
 (synopsis "AWS Async API for Neptune")
 (depends awso-async awso-neptune))

(package
 (name awso-neptune-lwt)
 (synopsis "AWS Lwt API for Neptune")
 (depends awso-lwt awso-neptune))

(package
 (name awso-network-firewall)
 (synopsis "AWS API for Network-firewall")
 (depends awso))

(package
 (name awso-network-firewall-async)
 (synopsis "AWS Async API for Network-firewall")
 (depends awso-async awso-network-firewall))

(package
 (name awso-network-firewall-lwt)
 (synopsis "AWS Lwt API for Network-firewall")
 (depends awso-lwt awso-network-firewall))

(package
 (name awso-networkmanager)
 (synopsis "AWS API for Networkmanager")
 (depends awso))

(package
 (name awso-networkmanager-async)
 (synopsis "AWS Async API for Networkmanager")
 (depends awso-async awso-networkmanager))

(package
 (name awso-networkmanager-lwt)
 (synopsis "AWS Lwt API for Networkmanager")
 (depends awso-lwt awso-networkmanager))

(package
 (name awso-nimble)
 (synopsis "AWS API for Nimble")
 (depends awso))

(package
 (name awso-nimble-async)
 (synopsis "AWS Async API for Nimble")
 (depends awso-async awso-nimble))

(package
 (name awso-nimble-lwt)
 (synopsis "AWS Lwt API for Nimble")
 (depends awso-lwt awso-nimble))

(package
 (name awso-opensearch)
 (synopsis "AWS API for Opensearch")
 (depends awso))

(package
 (name awso-opensearch-async)
 (synopsis "AWS Async API for Opensearch")
 (depends awso-async awso-opensearch))

(package
 (name awso-opensearch-lwt)
 (synopsis "AWS Lwt API for Opensearch")
 (depends awso-lwt awso-opensearch))

(package
 (name awso-opsworks)
 (synopsis "AWS API for Opsworks")
 (depends awso))

(package
 (name awso-opsworks-async)
 (synopsis "AWS Async API for Opsworks")
 (depends awso-async awso-opsworks))

(package
 (name awso-opsworks-lwt)
 (synopsis "AWS Lwt API for Opsworks")
 (depends awso-lwt awso-opsworks))

(package
 (name awso-opsworkscm)
 (synopsis "AWS API for Opsworkscm")
 (depends awso))

(package
 (name awso-opsworkscm-async)
 (synopsis "AWS Async API for Opsworkscm")
 (depends awso-async awso-opsworkscm))

(package
 (name awso-opsworkscm-lwt)
 (synopsis "AWS Lwt API for Opsworkscm")
 (depends awso-lwt awso-opsworkscm))

(package
 (name awso-organizations)
 (synopsis "AWS API for Organizations")
 (depends awso))

(package
 (name awso-organizations-async)
 (synopsis "AWS Async API for Organizations")
 (depends awso-async awso-organizations))

(package
 (name awso-organizations-lwt)
 (synopsis "AWS Lwt API for Organizations")
 (depends awso-lwt awso-organizations))

(package
 (name awso-outposts)
 (synopsis "AWS API for Outposts")
 (depends awso))

(package
 (name awso-outposts-async)
 (synopsis "AWS Async API for Outposts")
 (depends awso-async awso-outposts))

(package
 (name awso-outposts-lwt)
 (synopsis "AWS Lwt API for Outposts")
 (depends awso-lwt awso-outposts))

(package
 (name awso-panorama)
 (synopsis "AWS API for Panorama")
 (depends awso))

(package
 (name awso-panorama-async)
 (synopsis "AWS Async API for Panorama")
 (depends awso-async awso-panorama))

(package
 (name awso-panorama-lwt)
 (synopsis "AWS Lwt API for Panorama")
 (depends awso-lwt awso-panorama))

(package
 (name awso-personalize)
 (synopsis "AWS API for Personalize")
 (depends awso))

(package
 (name awso-personalize-async)
 (synopsis "AWS Async API for Personalize")
 (depends awso-async awso-personalize))

(package
 (name awso-personalize-lwt)
 (synopsis "AWS Lwt API for Personalize")
 (depends awso-lwt awso-personalize))

(package
 (name awso-personalize-events)
 (synopsis "AWS API for Personalize-events")
 (depends awso))

(package
 (name awso-personalize-events-async)
 (synopsis "AWS Async API for Personalize-events")
 (depends awso-async awso-personalize-events))

(package
 (name awso-personalize-events-lwt)
 (synopsis "AWS Lwt API for Personalize-events")
 (depends awso-lwt awso-personalize-events))

(package
 (name awso-personalize-runtime)
 (synopsis "AWS API for Personalize-runtime")
 (depends awso))

(package
 (name awso-personalize-runtime-async)
 (synopsis "AWS Async API for Personalize-runtime")
 (depends awso-async awso-personalize-runtime))

(package
 (name awso-personalize-runtime-lwt)
 (synopsis "AWS Lwt API for Personalize-runtime")
 (depends awso-lwt awso-personalize-runtime))

(package
 (name awso-pi)
 (synopsis "AWS API for Pi")
 (depends awso))

(package
 (name awso-pi-async)
 (synopsis "AWS Async API for Pi")
 (depends awso-async awso-pi))

(package
 (name awso-pi-lwt)
 (synopsis "AWS Lwt API for Pi")
 (depends awso-lwt awso-pi))

(package
 (name awso-pinpoint-email)
 (synopsis "AWS API for Pinpoint-email")
 (depends awso))

(package
 (name awso-pinpoint-email-async)
 (synopsis "AWS Async API for Pinpoint-email")
 (depends awso-async awso-pinpoint-email))

(package
 (name awso-pinpoint-email-lwt)
 (synopsis "AWS Lwt API for Pinpoint-email")
 (depends awso-lwt awso-pinpoint-email))

(package
 (name awso-pinpoint-sms-voice)
 (synopsis "AWS API for Pinpoint-sms-voice")
 (depends awso))

(package
 (name awso-pinpoint-sms-voice-async)
 (synopsis "AWS Async API for Pinpoint-sms-voice")
 (depends awso-async awso-pinpoint-sms-voice))

(package
 (name awso-pinpoint-sms-voice-lwt)
 (synopsis "AWS Lwt API for Pinpoint-sms-voice")
 (depends awso-lwt awso-pinpoint-sms-voice))

(package
 (name awso-pinpoint-sms-voice-v2)
 (synopsis "AWS API for Pinpoint-sms-voice-v2")
 (depends awso))

(package
 (name awso-pinpoint-sms-voice-v2-async)
 (synopsis "AWS Async API for Pinpoint-sms-voice-v2")
 (depends awso-async awso-pinpoint-sms-voice-v2))

(package
 (name awso-pinpoint-sms-voice-v2-lwt)
 (synopsis "AWS Lwt API for Pinpoint-sms-voice-v2")
 (depends awso-lwt awso-pinpoint-sms-voice-v2))

(package
 (name awso-polly)
 (synopsis "AWS API for Polly")
 (depends awso))

(package
 (name awso-polly-async)
 (synopsis "AWS Async API for Polly")
 (depends awso-async awso-polly))

(package
 (name awso-polly-lwt)
 (synopsis "AWS Lwt API for Polly")
 (depends awso-lwt awso-polly))

(package
 (name awso-pricing)
 (synopsis "AWS API for Pricing")
 (depends awso))

(package
 (name awso-pricing-async)
 (synopsis "AWS Async API for Pricing")
 (depends awso-async awso-pricing))

(package
 (name awso-pricing-lwt)
 (synopsis "AWS Lwt API for Pricing")
 (depends awso-lwt awso-pricing))

(package
 (name awso-proton)
 (synopsis "AWS API for Proton")
 (depends awso))

(package
 (name awso-proton-async)
 (synopsis "AWS Async API for Proton")
 (depends awso-async awso-proton))

(package
 (name awso-proton-lwt)
 (synopsis "AWS Lwt API for Proton")
 (depends awso-lwt awso-proton))

(package
 (name awso-qldb)
 (synopsis "AWS API for Qldb")
 (depends awso))

(package
 (name awso-qldb-async)
 (synopsis "AWS Async API for Qldb")
 (depends awso-async awso-qldb))

(package
 (name awso-qldb-lwt)
 (synopsis "AWS Lwt API for Qldb")
 (depends awso-lwt awso-qldb))

(package
 (name awso-qldb-session)
 (synopsis "AWS API for Qldb-session")
 (depends awso))

(package
 (name awso-qldb-session-async)
 (synopsis "AWS Async API for Qldb-session")
 (depends awso-async awso-qldb-session))

(package
 (name awso-qldb-session-lwt)
 (synopsis "AWS Lwt API for Qldb-session")
 (depends awso-lwt awso-qldb-session))

(package
 (name awso-quicksight)
 (synopsis "AWS API for Quicksight")
 (depends awso))

(package
 (name awso-quicksight-async)
 (synopsis "AWS Async API for Quicksight")
 (depends awso-async awso-quicksight))

(package
 (name awso-quicksight-lwt)
 (synopsis "AWS Lwt API for Quicksight")
 (depends awso-lwt awso-quicksight))

(package
 (name awso-ram)
 (synopsis "AWS API for Ram")
 (depends awso))

(package
 (name awso-ram-async)
 (synopsis "AWS Async API for Ram")
 (depends awso-async awso-ram))

(package
 (name awso-ram-lwt)
 (synopsis "AWS Lwt API for Ram")
 (depends awso-lwt awso-ram))

(package
 (name awso-rbin)
 (synopsis "AWS API for Rbin")
 (depends awso))

(package
 (name awso-rbin-async)
 (synopsis "AWS Async API for Rbin")
 (depends awso-async awso-rbin))

(package
 (name awso-rbin-lwt)
 (synopsis "AWS Lwt API for Rbin")
 (depends awso-lwt awso-rbin))

(package
 (name awso-rds)
 (synopsis "AWS API for Rds")
 (depends awso))

(package
 (name awso-rds-async)
 (synopsis "AWS Async API for Rds")
 (depends awso-async awso-rds))

(package
 (name awso-rds-lwt)
 (synopsis "AWS Lwt API for Rds")
 (depends awso-lwt awso-rds))

(package
 (name awso-rds-data)
 (synopsis "AWS API for Rds-data")
 (depends awso))

(package
 (name awso-rds-data-async)
 (synopsis "AWS Async API for Rds-data")
 (depends awso-async awso-rds-data))

(package
 (name awso-rds-data-lwt)
 (synopsis "AWS Lwt API for Rds-data")
 (depends awso-lwt awso-rds-data))

(package
 (name awso-redshift)
 (synopsis "AWS API for Redshift")
 (depends awso))

(package
 (name awso-redshift-async)
 (synopsis "AWS Async API for Redshift")
 (depends awso-async awso-redshift))

(package
 (name awso-redshift-lwt)
 (synopsis "AWS Lwt API for Redshift")
 (depends awso-lwt awso-redshift))

(package
 (name awso-redshift-data)
 (synopsis "AWS API for Redshift-data")
 (depends awso))

(package
 (name awso-redshift-data-async)
 (synopsis "AWS Async API for Redshift-data")
 (depends awso-async awso-redshift-data))

(package
 (name awso-redshift-data-lwt)
 (synopsis "AWS Lwt API for Redshift-data")
 (depends awso-lwt awso-redshift-data))

(package
 (name awso-rekognition)
 (synopsis "AWS API for Rekognition")
 (depends awso))

(package
 (name awso-rekognition-async)
 (synopsis "AWS Async API for Rekognition")
 (depends awso-async awso-rekognition))

(package
 (name awso-rekognition-lwt)
 (synopsis "AWS Lwt API for Rekognition")
 (depends awso-lwt awso-rekognition))

(package
 (name awso-resiliencehub)
 (synopsis "AWS API for Resiliencehub")
 (depends awso))

(package
 (name awso-resiliencehub-async)
 (synopsis "AWS Async API for Resiliencehub")
 (depends awso-async awso-resiliencehub))

(package
 (name awso-resiliencehub-lwt)
 (synopsis "AWS Lwt API for Resiliencehub")
 (depends awso-lwt awso-resiliencehub))

(package
 (name awso-resource-groups)
 (synopsis "AWS API for Resource-groups")
 (depends awso))

(package
 (name awso-resource-groups-async)
 (synopsis "AWS Async API for Resource-groups")
 (depends awso-async awso-resource-groups))

(package
 (name awso-resource-groups-lwt)
 (synopsis "AWS Lwt API for Resource-groups")
 (depends awso-lwt awso-resource-groups))

(package
 (name awso-resourcegroupstaggingapi)
 (synopsis "AWS API for Resourcegroupstaggingapi")
 (depends awso))

(package
 (name awso-resourcegroupstaggingapi-async)
 (synopsis "AWS Async API for Resourcegroupstaggingapi")
 (depends awso-async awso-resourcegroupstaggingapi))

(package
 (name awso-resourcegroupstaggingapi-lwt)
 (synopsis "AWS Lwt API for Resourcegroupstaggingapi")
 (depends awso-lwt awso-resourcegroupstaggingapi))

(package
 (name awso-robomaker)
 (synopsis "AWS API for Robomaker")
 (depends awso))

(package
 (name awso-robomaker-async)
 (synopsis "AWS Async API for Robomaker")
 (depends awso-async awso-robomaker))

(package
 (name awso-robomaker-lwt)
 (synopsis "AWS Lwt API for Robomaker")
 (depends awso-lwt awso-robomaker))

(package
 (name awso-route53)
 (synopsis "AWS API for Route53")
 (depends awso))

(package
 (name awso-route53-async)
 (synopsis "AWS Async API for Route53")
 (depends awso-async awso-route53))

(package
 (name awso-route53-lwt)
 (synopsis "AWS Lwt API for Route53")
 (depends awso-lwt awso-route53))

(package
 (name awso-route53-recovery-cluster)
 (synopsis "AWS API for Route53-recovery-cluster")
 (depends awso))

(package
 (name awso-route53-recovery-cluster-async)
 (synopsis "AWS Async API for Route53-recovery-cluster")
 (depends awso-async awso-route53-recovery-cluster))

(package
 (name awso-route53-recovery-cluster-lwt)
 (synopsis "AWS Lwt API for Route53-recovery-cluster")
 (depends awso-lwt awso-route53-recovery-cluster))

(package
 (name awso-route53-recovery-control-config)
 (synopsis "AWS API for Route53-recovery-control-config")
 (depends awso))

(package
 (name awso-route53-recovery-control-config-async)
 (synopsis "AWS Async API for Route53-recovery-control-config")
 (depends awso-async awso-route53-recovery-control-config))

(package
 (name awso-route53-recovery-control-config-lwt)
 (synopsis "AWS Lwt API for Route53-recovery-control-config")
 (depends awso-lwt awso-route53-recovery-control-config))

(package
 (name awso-route53-recovery-readiness)
 (synopsis "AWS API for Route53-recovery-readiness")
 (depends awso))

(package
 (name awso-route53-recovery-readiness-async)
 (synopsis "AWS Async API for Route53-recovery-readiness")
 (depends awso-async awso-route53-recovery-readiness))

(package
 (name awso-route53-recovery-readiness-lwt)
 (synopsis "AWS Lwt API for Route53-recovery-readiness")
 (depends awso-lwt awso-route53-recovery-readiness))

(package
 (name awso-route53domains)
 (synopsis "AWS API for Route53domains")
 (depends awso))

(package
 (name awso-route53domains-async)
 (synopsis "AWS Async API for Route53domains")
 (depends awso-async awso-route53domains))

(package
 (name awso-route53domains-lwt)
 (synopsis "AWS Lwt API for Route53domains")
 (depends awso-lwt awso-route53domains))

(package
 (name awso-route53resolver)
 (synopsis "AWS API for Route53resolver")
 (depends awso))

(package
 (name awso-route53resolver-async)
 (synopsis "AWS Async API for Route53resolver")
 (depends awso-async awso-route53resolver))

(package
 (name awso-route53resolver-lwt)
 (synopsis "AWS Lwt API for Route53resolver")
 (depends awso-lwt awso-route53resolver))

(package
 (name awso-rum)
 (synopsis "AWS API for Rum")
 (depends awso))

(package
 (name awso-rum-async)
 (synopsis "AWS Async API for Rum")
 (depends awso-async awso-rum))

(package
 (name awso-rum-lwt)
 (synopsis "AWS Lwt API for Rum")
 (depends awso-lwt awso-rum))

(package
 (name awso-s3)
 (synopsis "AWS API for S3")
 (depends awso))

(package
 (name awso-s3-async)
 (synopsis "AWS Async API for S3")
 (depends awso-async awso-s3))

(package
 (name awso-s3-lwt)
 (synopsis "AWS Lwt API for S3")
 (depends awso-lwt awso-s3))

(package
 (name awso-s3outposts)
 (synopsis "AWS API for S3outposts")
 (depends awso))

(package
 (name awso-s3outposts-async)
 (synopsis "AWS Async API for S3outposts")
 (depends awso-async awso-s3outposts))

(package
 (name awso-s3outposts-lwt)
 (synopsis "AWS Lwt API for S3outposts")
 (depends awso-lwt awso-s3outposts))

(package
 (name awso-sagemaker)
 (synopsis "AWS API for Sagemaker")
 (depends awso))

(package
 (name awso-sagemaker-async)
 (synopsis "AWS Async API for Sagemaker")
 (depends awso-async awso-sagemaker))

(package
 (name awso-sagemaker-lwt)
 (synopsis "AWS Lwt API for Sagemaker")
 (depends awso-lwt awso-sagemaker))

(package
 (name awso-sagemaker-a2i-runtime)
 (synopsis "AWS API for Sagemaker-a2i-runtime")
 (depends awso))

(package
 (name awso-sagemaker-a2i-runtime-async)
 (synopsis "AWS Async API for Sagemaker-a2i-runtime")
 (depends awso-async awso-sagemaker-a2i-runtime))

(package
 (name awso-sagemaker-a2i-runtime-lwt)
 (synopsis "AWS Lwt API for Sagemaker-a2i-runtime")
 (depends awso-lwt awso-sagemaker-a2i-runtime))

(package
 (name awso-sagemaker-edge)
 (synopsis "AWS API for Sagemaker-edge")
 (depends awso))

(package
 (name awso-sagemaker-edge-async)
 (synopsis "AWS Async API for Sagemaker-edge")
 (depends awso-async awso-sagemaker-edge))

(package
 (name awso-sagemaker-edge-lwt)
 (synopsis "AWS Lwt API for Sagemaker-edge")
 (depends awso-lwt awso-sagemaker-edge))

(package
 (name awso-sagemaker-featurestore-runtime)
 (synopsis "AWS API for Sagemaker-featurestore-runtime")
 (depends awso))

(package
 (name awso-sagemaker-featurestore-runtime-async)
 (synopsis "AWS Async API for Sagemaker-featurestore-runtime")
 (depends awso-async awso-sagemaker-featurestore-runtime))

(package
 (name awso-sagemaker-featurestore-runtime-lwt)
 (synopsis "AWS Lwt API for Sagemaker-featurestore-runtime")
 (depends awso-lwt awso-sagemaker-featurestore-runtime))

(package
 (name awso-savingsplans)
 (synopsis "AWS API for Savingsplans")
 (depends awso))

(package
 (name awso-savingsplans-async)
 (synopsis "AWS Async API for Savingsplans")
 (depends awso-async awso-savingsplans))

(package
 (name awso-savingsplans-lwt)
 (synopsis "AWS Lwt API for Savingsplans")
 (depends awso-lwt awso-savingsplans))

(package
 (name awso-schemas)
 (synopsis "AWS API for Schemas")
 (depends awso))

(package
 (name awso-schemas-async)
 (synopsis "AWS Async API for Schemas")
 (depends awso-async awso-schemas))

(package
 (name awso-schemas-lwt)
 (synopsis "AWS Lwt API for Schemas")
 (depends awso-lwt awso-schemas))

(package
 (name awso-sdb)
 (synopsis "AWS API for Sdb")
 (depends awso))

(package
 (name awso-sdb-async)
 (synopsis "AWS Async API for Sdb")
 (depends awso-async awso-sdb))

(package
 (name awso-sdb-lwt)
 (synopsis "AWS Lwt API for Sdb")
 (depends awso-lwt awso-sdb))

(package
 (name awso-secretsmanager)
 (synopsis "AWS API for Secretsmanager")
 (depends awso))

(package
 (name awso-secretsmanager-async)
 (synopsis "AWS Async API for Secretsmanager")
 (depends awso-async awso-secretsmanager))

(package
 (name awso-secretsmanager-lwt)
 (synopsis "AWS Lwt API for Secretsmanager")
 (depends awso-lwt awso-secretsmanager))

(package
 (name awso-securityhub)
 (synopsis "AWS API for Securityhub")
 (depends awso))

(package
 (name awso-securityhub-async)
 (synopsis "AWS Async API for Securityhub")
 (depends awso-async awso-securityhub))

(package
 (name awso-securityhub-lwt)
 (synopsis "AWS Lwt API for Securityhub")
 (depends awso-lwt awso-securityhub))

(package
 (name awso-serverlessrepo)
 (synopsis "AWS API for Serverlessrepo")
 (depends awso))

(package
 (name awso-serverlessrepo-async)
 (synopsis "AWS Async API for Serverlessrepo")
 (depends awso-async awso-serverlessrepo))

(package
 (name awso-serverlessrepo-lwt)
 (synopsis "AWS Lwt API for Serverlessrepo")
 (depends awso-lwt awso-serverlessrepo))

(package
 (name awso-service-quotas)
 (synopsis "AWS API for Service-quotas")
 (depends awso))

(package
 (name awso-service-quotas-async)
 (synopsis "AWS Async API for Service-quotas")
 (depends awso-async awso-service-quotas))

(package
 (name awso-service-quotas-lwt)
 (synopsis "AWS Lwt API for Service-quotas")
 (depends awso-lwt awso-service-quotas))

(package
 (name awso-servicecatalog)
 (synopsis "AWS API for Servicecatalog")
 (depends awso))

(package
 (name awso-servicecatalog-async)
 (synopsis "AWS Async API for Servicecatalog")
 (depends awso-async awso-servicecatalog))

(package
 (name awso-servicecatalog-lwt)
 (synopsis "AWS Lwt API for Servicecatalog")
 (depends awso-lwt awso-servicecatalog))

(package
 (name awso-servicecatalog-appregistry)
 (synopsis "AWS API for Servicecatalog-appregistry")
 (depends awso))

(package
 (name awso-servicecatalog-appregistry-async)
 (synopsis "AWS Async API for Servicecatalog-appregistry")
 (depends awso-async awso-servicecatalog-appregistry))

(package
 (name awso-servicecatalog-appregistry-lwt)
 (synopsis "AWS Lwt API for Servicecatalog-appregistry")
 (depends awso-lwt awso-servicecatalog-appregistry))

(package
 (name awso-servicediscovery)
 (synopsis "AWS API for Servicediscovery")
 (depends awso))

(package
 (name awso-servicediscovery-async)
 (synopsis "AWS Async API for Servicediscovery")
 (depends awso-async awso-servicediscovery))

(package
 (name awso-servicediscovery-lwt)
 (synopsis "AWS Lwt API for Servicediscovery")
 (depends awso-lwt awso-servicediscovery))

(package
 (name awso-ses)
 (synopsis "AWS API for Ses")
 (depends awso))

(package
 (name awso-ses-async)
 (synopsis "AWS Async API for Ses")
 (depends awso-async awso-ses))

(package
 (name awso-ses-lwt)
 (synopsis "AWS Lwt API for Ses")
 (depends awso-lwt awso-ses))

(package
 (name awso-sesv2)
 (synopsis "AWS API for Sesv2")
 (depends awso))

(package
 (name awso-sesv2-async)
 (synopsis "AWS Async API for Sesv2")
 (depends awso-async awso-sesv2))

(package
 (name awso-sesv2-lwt)
 (synopsis "AWS Lwt API for Sesv2")
 (depends awso-lwt awso-sesv2))

(package
 (name awso-shield)
 (synopsis "AWS API for Shield")
 (depends awso))

(package
 (name awso-shield-async)
 (synopsis "AWS Async API for Shield")
 (depends awso-async awso-shield))

(package
 (name awso-shield-lwt)
 (synopsis "AWS Lwt API for Shield")
 (depends awso-lwt awso-shield))

(package
 (name awso-signer)
 (synopsis "AWS API for Signer")
 (depends awso))

(package
 (name awso-signer-async)
 (synopsis "AWS Async API for Signer")
 (depends awso-async awso-signer))

(package
 (name awso-signer-lwt)
 (synopsis "AWS Lwt API for Signer")
 (depends awso-lwt awso-signer))

(package
 (name awso-sms)
 (synopsis "AWS API for Sms")
 (depends awso))

(package
 (name awso-sms-async)
 (synopsis "AWS Async API for Sms")
 (depends awso-async awso-sms))

(package
 (name awso-sms-lwt)
 (synopsis "AWS Lwt API for Sms")
 (depends awso-lwt awso-sms))

(package
 (name awso-sms-voice)
 (synopsis "AWS API for Sms-voice")
 (depends awso))

(package
 (name awso-sms-voice-async)
 (synopsis "AWS Async API for Sms-voice")
 (depends awso-async awso-sms-voice))

(package
 (name awso-sms-voice-lwt)
 (synopsis "AWS Lwt API for Sms-voice")
 (depends awso-lwt awso-sms-voice))

(package
 (name awso-snow-device-management)
 (synopsis "AWS API for Snow-device-management")
 (depends awso))

(package
 (name awso-snow-device-management-async)
 (synopsis "AWS Async API for Snow-device-management")
 (depends awso-async awso-snow-device-management))

(package
 (name awso-snow-device-management-lwt)
 (synopsis "AWS Lwt API for Snow-device-management")
 (depends awso-lwt awso-snow-device-management))

(package
 (name awso-snowball)
 (synopsis "AWS API for Snowball")
 (depends awso))

(package
 (name awso-snowball-async)
 (synopsis "AWS Async API for Snowball")
 (depends awso-async awso-snowball))

(package
 (name awso-snowball-lwt)
 (synopsis "AWS Lwt API for Snowball")
 (depends awso-lwt awso-snowball))

(package
 (name awso-sns)
 (synopsis "AWS API for Sns")
 (depends awso))

(package
 (name awso-sns-async)
 (synopsis "AWS Async API for Sns")
 (depends awso-async awso-sns))

(package
 (name awso-sns-lwt)
 (synopsis "AWS Lwt API for Sns")
 (depends awso-lwt awso-sns))

(package
 (name awso-sqs)
 (synopsis "AWS API for Sqs")
 (depends awso))

(package
 (name awso-sqs-async)
 (synopsis "AWS Async API for Sqs")
 (depends awso-async awso-sqs))

(package
 (name awso-sqs-lwt)
 (synopsis "AWS Lwt API for Sqs")
 (depends awso-lwt awso-sqs))

(package
 (name awso-ssm)
 (synopsis "AWS API for Ssm")
 (depends awso))

(package
 (name awso-ssm-async)
 (synopsis "AWS Async API for Ssm")
 (depends awso-async awso-ssm))

(package
 (name awso-ssm-lwt)
 (synopsis "AWS Lwt API for Ssm")
 (depends awso-lwt awso-ssm))

(package
 (name awso-ssm-contacts)
 (synopsis "AWS API for Ssm-contacts")
 (depends awso))

(package
 (name awso-ssm-contacts-async)
 (synopsis "AWS Async API for Ssm-contacts")
 (depends awso-async awso-ssm-contacts))

(package
 (name awso-ssm-contacts-lwt)
 (synopsis "AWS Lwt API for Ssm-contacts")
 (depends awso-lwt awso-ssm-contacts))

(package
 (name awso-ssm-incidents)
 (synopsis "AWS API for Ssm-incidents")
 (depends awso))

(package
 (name awso-ssm-incidents-async)
 (synopsis "AWS Async API for Ssm-incidents")
 (depends awso-async awso-ssm-incidents))

(package
 (name awso-ssm-incidents-lwt)
 (synopsis "AWS Lwt API for Ssm-incidents")
 (depends awso-lwt awso-ssm-incidents))

(package
 (name awso-sso)
 (synopsis "AWS API for Sso")
 (depends awso))

(package
 (name awso-sso-async)
 (synopsis "AWS Async API for Sso")
 (depends awso-async awso-sso))

(package
 (name awso-sso-lwt)
 (synopsis "AWS Lwt API for Sso")
 (depends awso-lwt awso-sso))

(package
 (name awso-sso-admin)
 (synopsis "AWS API for Sso-admin")
 (depends awso))

(package
 (name awso-sso-admin-async)
 (synopsis "AWS Async API for Sso-admin")
 (depends awso-async awso-sso-admin))

(package
 (name awso-sso-admin-lwt)
 (synopsis "AWS Lwt API for Sso-admin")
 (depends awso-lwt awso-sso-admin))

(package
 (name awso-sso-oidc)
 (synopsis "AWS API for Sso-oidc")
 (depends awso))

(package
 (name awso-sso-oidc-async)
 (synopsis "AWS Async API for Sso-oidc")
 (depends awso-async awso-sso-oidc))

(package
 (name awso-sso-oidc-lwt)
 (synopsis "AWS Lwt API for Sso-oidc")
 (depends awso-lwt awso-sso-oidc))

(package
 (name awso-stepfunctions)
 (synopsis "AWS API for Stepfunctions")
 (depends awso))

(package
 (name awso-stepfunctions-async)
 (synopsis "AWS Async API for Stepfunctions")
 (depends awso-async awso-stepfunctions))

(package
 (name awso-stepfunctions-lwt)
 (synopsis "AWS Lwt API for Stepfunctions")
 (depends awso-lwt awso-stepfunctions))

(package
 (name awso-storagegateway)
 (synopsis "AWS API for Storagegateway")
 (depends awso))

(package
 (name awso-storagegateway-async)
 (synopsis "AWS Async API for Storagegateway")
 (depends awso-async awso-storagegateway))

(package
 (name awso-storagegateway-lwt)
 (synopsis "AWS Lwt API for Storagegateway")
 (depends awso-lwt awso-storagegateway))

(package
 (name awso-sts)
 (synopsis "AWS API for Sts")
 (depends awso))

(package
 (name awso-sts-async)
 (synopsis "AWS Async API for Sts")
 (depends awso-async awso-sts))

(package
 (name awso-sts-lwt)
 (synopsis "AWS Lwt API for Sts")
 (depends awso-lwt awso-sts))

(package
 (name awso-support)
 (synopsis "AWS API for Support")
 (depends awso))

(package
 (name awso-support-async)
 (synopsis "AWS Async API for Support")
 (depends awso-async awso-support))

(package
 (name awso-support-lwt)
 (synopsis "AWS Lwt API for Support")
 (depends awso-lwt awso-support))

(package
 (name awso-swf)
 (synopsis "AWS API for Swf")
 (depends awso))

(package
 (name awso-swf-async)
 (synopsis "AWS Async API for Swf")
 (depends awso-async awso-swf))

(package
 (name awso-swf-lwt)
 (synopsis "AWS Lwt API for Swf")
 (depends awso-lwt awso-swf))

(package
 (name awso-synthetics)
 (synopsis "AWS API for Synthetics")
 (depends awso))

(package
 (name awso-synthetics-async)
 (synopsis "AWS Async API for Synthetics")
 (depends awso-async awso-synthetics))

(package
 (name awso-synthetics-lwt)
 (synopsis "AWS Lwt API for Synthetics")
 (depends awso-lwt awso-synthetics))

(package
 (name awso-textract)
 (synopsis "AWS API for Textract")
 (depends awso))

(package
 (name awso-textract-async)
 (synopsis "AWS Async API for Textract")
 (depends awso-async awso-textract))

(package
 (name awso-textract-lwt)
 (synopsis "AWS Lwt API for Textract")
 (depends awso-lwt awso-textract))

(package
 (name awso-timestream-query)
 (synopsis "AWS API for Timestream-query")
 (depends awso))

(package
 (name awso-timestream-query-async)
 (synopsis "AWS Async API for Timestream-query")
 (depends awso-async awso-timestream-query))

(package
 (name awso-timestream-query-lwt)
 (synopsis "AWS Lwt API for Timestream-query")
 (depends awso-lwt awso-timestream-query))

(package
 (name awso-timestream-write)
 (synopsis "AWS API for Timestream-write")
 (depends awso))

(package
 (name awso-timestream-write-async)
 (synopsis "AWS Async API for Timestream-write")
 (depends awso-async awso-timestream-write))

(package
 (name awso-timestream-write-lwt)
 (synopsis "AWS Lwt API for Timestream-write")
 (depends awso-lwt awso-timestream-write))

(package
 (name awso-transcribe)
 (synopsis "AWS API for Transcribe")
 (depends awso))

(package
 (name awso-transcribe-async)
 (synopsis "AWS Async API for Transcribe")
 (depends awso-async awso-transcribe))

(package
 (name awso-transcribe-lwt)
 (synopsis "AWS Lwt API for Transcribe")
 (depends awso-lwt awso-transcribe))

(package
 (name awso-transfer)
 (synopsis "AWS API for Transfer")
 (depends awso))

(package
 (name awso-transfer-async)
 (synopsis "AWS Async API for Transfer")
 (depends awso-async awso-transfer))

(package
 (name awso-transfer-lwt)
 (synopsis "AWS Lwt API for Transfer")
 (depends awso-lwt awso-transfer))

(package
 (name awso-translate)
 (synopsis "AWS API for Translate")
 (depends awso))

(package
 (name awso-translate-async)
 (synopsis "AWS Async API for Translate")
 (depends awso-async awso-translate))

(package
 (name awso-translate-lwt)
 (synopsis "AWS Lwt API for Translate")
 (depends awso-lwt awso-translate))

(package
 (name awso-voice-id)
 (synopsis "AWS API for Voice-id")
 (depends awso))

(package
 (name awso-voice-id-async)
 (synopsis "AWS Async API for Voice-id")
 (depends awso-async awso-voice-id))

(package
 (name awso-voice-id-lwt)
 (synopsis "AWS Lwt API for Voice-id")
 (depends awso-lwt awso-voice-id))

(package
 (name awso-waf)
 (synopsis "AWS API for Waf")
 (depends awso))

(package
 (name awso-waf-async)
 (synopsis "AWS Async API for Waf")
 (depends awso-async awso-waf))

(package
 (name awso-waf-lwt)
 (synopsis "AWS Lwt API for Waf")
 (depends awso-lwt awso-waf))

(package
 (name awso-waf-regional)
 (synopsis "AWS API for Waf-regional")
 (depends awso))

(package
 (name awso-waf-regional-async)
 (synopsis "AWS Async API for Waf-regional")
 (depends awso-async awso-waf-regional))

(package
 (name awso-waf-regional-lwt)
 (synopsis "AWS Lwt API for Waf-regional")
 (depends awso-lwt awso-waf-regional))

(package
 (name awso-wafv2)
 (synopsis "AWS API for Wafv2")
 (depends awso))

(package
 (name awso-wafv2-async)
 (synopsis "AWS Async API for Wafv2")
 (depends awso-async awso-wafv2))

(package
 (name awso-wafv2-lwt)
 (synopsis "AWS Lwt API for Wafv2")
 (depends awso-lwt awso-wafv2))

(package
 (name awso-wellarchitected)
 (synopsis "AWS API for Wellarchitected")
 (depends awso))

(package
 (name awso-wellarchitected-async)
 (synopsis "AWS Async API for Wellarchitected")
 (depends awso-async awso-wellarchitected))

(package
 (name awso-wellarchitected-lwt)
 (synopsis "AWS Lwt API for Wellarchitected")
 (depends awso-lwt awso-wellarchitected))

(package
 (name awso-wisdom)
 (synopsis "AWS API for Wisdom")
 (depends awso))

(package
 (name awso-wisdom-async)
 (synopsis "AWS Async API for Wisdom")
 (depends awso-async awso-wisdom))

(package
 (name awso-wisdom-lwt)
 (synopsis "AWS Lwt API for Wisdom")
 (depends awso-lwt awso-wisdom))

(package
 (name awso-workdocs)
 (synopsis "AWS API for Workdocs")
 (depends awso))

(package
 (name awso-workdocs-async)
 (synopsis "AWS Async API for Workdocs")
 (depends awso-async awso-workdocs))

(package
 (name awso-workdocs-lwt)
 (synopsis "AWS Lwt API for Workdocs")
 (depends awso-lwt awso-workdocs))

(package
 (name awso-worklink)
 (synopsis "AWS API for Worklink")
 (depends awso))

(package
 (name awso-worklink-async)
 (synopsis "AWS Async API for Worklink")
 (depends awso-async awso-worklink))

(package
 (name awso-worklink-lwt)
 (synopsis "AWS Lwt API for Worklink")
 (depends awso-lwt awso-worklink))

(package
 (name awso-workmail)
 (synopsis "AWS API for Workmail")
 (depends awso))

(package
 (name awso-workmail-async)
 (synopsis "AWS Async API for Workmail")
 (depends awso-async awso-workmail))

(package
 (name awso-workmail-lwt)
 (synopsis "AWS Lwt API for Workmail")
 (depends awso-lwt awso-workmail))

(package
 (name awso-workspaces)
 (synopsis "AWS API for Workspaces")
 (depends awso))

(package
 (name awso-workspaces-async)
 (synopsis "AWS Async API for Workspaces")
 (depends awso-async awso-workspaces))

(package
 (name awso-workspaces-lwt)
 (synopsis "AWS Lwt API for Workspaces")
 (depends awso-lwt awso-workspaces))

(package
 (name awso-workspaces-web)
 (synopsis "AWS API for Workspaces-web")
 (depends awso))

(package
 (name awso-workspaces-web-async)
 (synopsis "AWS Async API for Workspaces-web")
 (depends awso-async awso-workspaces-web))

(package
 (name awso-workspaces-web-lwt)
 (synopsis "AWS Lwt API for Workspaces-web")
 (depends awso-lwt awso-workspaces-web))

(package
 (name awso-xray)
 (synopsis "AWS API for Xray")
 (depends awso))

(package
 (name awso-xray-async)
 (synopsis "AWS Async API for Xray")
 (depends awso-async awso-xray))

(package
 (name awso-xray-lwt)
 (synopsis "AWS Lwt API for Xray")
 (depends awso-lwt awso-xray))
