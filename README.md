# Disclaimer

This project is not yet officially supported or endorsed by Red Hat.

# Description

3scale dump is an unofficial shell script for dumping a Red Hat 3scale On-premises project, bringing more and better formatted information than the regular OpenShift dump script.

# Table of Contents
- [Usage](#usage)
  * [Dump File](#dump-file)
  * [Temporary Directory](#temporary-directory)  
- [Information Fetched](#information-fetched)
  * [OpenShift Related Configuration](#openshift-related-configuration)
      - [Pods and Events Information](#pods-and-events-information)
      - [DeploymentConfigs](#deploymentconfigs)
      - [Logs](#logs)
      - [Secrets](#secrets)
      - [Routes](#routes)
      - [Services](#services)
      - [Image Streams](#image-streams)
      - [ConfigMaps](#configmaps)
      - [PVs - Persistent Volumes](#pvs---persistent-volumes)
      - [PVCs - Persistent Volume Claims](#pvcs---persistent-volume-claims)
      - [Service Accounts](#service-accounts)
      - [Node - CPU and Memory Consumption and Limits](#node---cpu-and-memory-consumption-and-limits)      
  * [3scale Configuration](#3scale-configuration)
      - [3scale Echo API call - from the APIcast pod](#3scale-echo-api-call---from-the-apicast-pod)
      - [APIcast Staging and Production JSON Configuration](#apicast-staging-and-production-json-configuration)
      - [Management API and Status](#management-api-and-status)
      - [APIcast Certificates Validation](#apicast-certificates-validation)
      - [Project and Pods - runAsUser](#project-and-pods---runasuser)
      - [Sidekiq Queue](#sidekiq-queue)
 - [Known Issues](#known-issues)

# Usage

```
$ ./3scale-dump.sh <3scale Project> [Compress Format] 2>&1 | tee 3scale-dump-logs.txt

    3scale Project:  The official project hosting 3scale inside Red Hat OpenShift.

    Compress Format: How the log files from the pods are going to be compressed.
                     Possible values are: 'gzip', 'xz' or 'auto' for auto-detect.
                     NOTE: Leaving this value empty is equal to 'auto'.

    The text file '3scale-dump-logs.txt' provides more information about the data
    retrieval process, including if anything goes wrong.
```

## Dump File

After successfully executing the script, a file named `3scale-dump.tar` will exist on the current directory containing the 3scale project information. Notice that it doesn't include any sort of compression (e.g. `.tar.gz` or `.tar.xz`), since all the logs from the pods have already been compressed and hence its main purpose is to just archive all the information.

## Temporary Directory

The directory `3scale-dump` is created under the currently working one and is used as a temporary location to store the configuration files while they are being retrieved and before being archived into the **Dump File**. It's typically cleaned up automatically, unless an unexpected file or directory is present inside it.

# Information Fetched

## OpenShift Related Configuration

With the exception of the `Pods and Events Information`, OpenShift related configuration is fetched both in the form of a `Single File` and several `Object Files`. The same information assembled on the `Single File` is also distributed within the several `Object Files` and it's up to the Engineer to choose the preferred format of reading the data retrieved.

#### Pods and Events Information

- Pods:
  - All Pods: `/status/pods-all.txt`
  - Running Pods: `/status/pods.txt`
- Events: `/status/events.txt`

#### DeploymentConfigs

- Single: `3scale-dump/dc.yaml`
- Objects: `3scale-dump/dc/[object].yaml`

#### Logs

- Files: `3scale-dump/logs/[pod].[gz,xz]`

    **NOTE:** Shell Script included on `3scale-dump/logs/uncompress-logs.sh` to uncompress all the logs.

#### Secrets

- Single: `3scale-dump/secrets.yaml`
- Objects: `3scale-dump/secrets/[object].yaml`

#### Routes

- Single: `3scale-dump/routes.yaml`
- Objects: `3scale-dump/routes/[object].yaml`

#### Services

- Single: `3scale-dump/services.yaml`
- Objects: `3scale-dump/services/[object].yaml`

#### Image Streams

- Single: `3scale-dump/images.yaml`
- Objects: `3scale-dump/images/[object].yaml`

#### ConfigMaps

- Single: `3scale-dump/configmaps.yaml`
- Objects: `3scale-dump/configmaps/[object].yaml`

#### PVs - Persistent Volumes

- Single: `3scale-dump/pv.yaml` and `3scale-dump/pv/describe.txt`
- Objects: `3scale-dump/pv/[object].yaml` and `3scale-dump/pv/describe/[object].txt`

#### PVCs - Persistent Volume Claims

- Single: `3scale-dump/pvc.yaml` and `3scale-dump/pvc/describe.txt`
- Objects: `3scale-dump/pvc/[object].yaml` and `3scale-dump/pvc/describe/[object].txt`

#### Service Accounts

- Single `3scale-dump/serviceaccounts.yaml`
- Objects: `3scale-dump/serviceaccounts/[object].yaml`

#### Node - CPU and Memory Consumption and Limits

- File: `/status/node.txt`

## 3scale Configuration

The directories `apicast-staging` and `apicast-production` are created inside `/status` and should contain information related to both pods (if running). There is also some additional debug (stderr) information from the retrieval process.

#### 3scale Echo API call - from the APIcast pod

- Files: `/status/apicast-[staging|production]/3scale-echo-api-[staging|production].txt` 

#### APIcast Staging and Production JSON Configuration

- Files: `/status/apicast-[staging|production]/apicast-[staging|production].json`
- Debug: `/status/apicast-[staging|production]/apicast-[staging|production]-json-debug.txt`

#### Management API and Status

Depends on the value from the variable `APICAST_MANAGEMENT_API` on both the Staging and Production APIcast pods:

- Management API - Debug: `/status/apicast-[staging|production]/mgmt-api-debug.json`
- Management API - Status: `/status/apicast-[staging|production]/mgmt-api-debug-status-[info|live|ready].txt`

    **NOTE:** Shell Script included on `/status/apicast-[staging|production]/python-json.sh` to convert all the `.json` files inside the `/status/apicast-[staging|production]` directories from a single line into multiple lines in case the `python` utility is installed locally.

#### APIcast Certificates Validation

- Files: `/status/apicast-[staging|production]/certificate.txt` and `/status/apicast-[staging|production]/certificate-showcerts.txt`

#### Project and Pods - runAsUser

- Files: `/status/project.txt` and `/status/pods-run-as-user.txt`

    **NOTE:** Helps to further troubleshoot database level issues knowing the user that the PV/PVC's will be mounted from the pods.

#### Sidekiq Queue

- File: `/status/sidekiq.txt`

# Known Issues

- On `2.6 On-premises`, the `apicast-wildcard-router` pod doesn't exist anymore. This is the single pod that contains the `openssl` utility to validate both the APIcast Staging and Production certificates. This process neeeds to be executed from inside a pod, since the OpenShift Node already adds any self-generated certificate as a valid Certificate Authority (CA).

- The script is not tested or validated against OpenShift Container Platform (OCP) 4.X, only 3.11. However, it's still not being widely used.

- Several items raised on the JIRA **THREESCALE-2588** will need to be addressed in a future stable release.

