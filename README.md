## Disclaimer

This project is not yet officially supported or endorsed by Red Hat.

## Description

3scale dump is an unofficial shell script for dumping a Red Hat 3scale On-premises project, bringing more and better formatted information than the regular OpenShift dump script.

## Usage

```
$ ./3scale-dump.sh <3scale Project> [Compress Format] 2>&1 | tee 3scale-dump-logs.txt

    3scale Project: The official project hosting 3scale inside Red Hat OpenShift.

    Compress Format: How the log files from the pods are going to be compressed.
                     Possible values are: 'gzip', 'xz' or 'auto' for auto-detect.
                     NOTE: Leaving this value empty is equal to 'auto'.

    3scale-dump-logs.txt: File used to redirect the stdin/stderr (2>&1) to better troubleshoot any issues while executing the script.
```

## Dump File

After executing the script, a file named `3scale-dump.tar` will exist on the current directory containing the 3scale project information. Notice that it doesn't include any type of compression (e.g. `.tar.gz` or `.tar.xz`), since all the logs from the pods have already been compressed and hence its main purpose is to archive all the information.

### Temporary Directory

The directory '3scale-dump' is created under the currently running one and is used as a temporary location to store the configuration files while they are being retrieved and before being archived into the **Dump File**.

## Configuration Fetched

### OpenShift Related Configuration

With the exception of the pods and events, the OpenShift related configuration is fetched in the form of a `Single File` and several `Object Files`. The same information assembled on the `Single File` is present on the several `Object Files`.

##### Pods and Events Information

- Pods: `/status/pods-all.txt` (all pods) and `/status/pods.txt` (running pods).
- Events: `/status/events.txt`

##### DeploymentConfigs

- Single File: `3scale-dump/dc.yaml`
- Object Files: `3scale-dump/dc/[object].yaml`

##### Logs

- Files: `3scale-dump/logs/[pod].[gz,xz]`

    **NOTE:** Shell Script included on `3scale-dump/logs/uncompress-logs.sh` to uncompress all the logs.

##### Secrets

- Single File: `3scale-dump/secrets.yaml`
- Object Files: `3scale-dump/secrets/[object].yaml`

##### Routes

- Single File: `3scale-dump/routes.yaml`
- Object Files: `3scale-dump/routes/[object].yaml`

##### Services

- Single File: `3scale-dump/services.yaml`
- Object Files: `3scale-dump/services/[object].yaml`

##### Image Streams

- Single File: `3scale-dump/images.yaml`
- Object Files: `3scale-dump/images/[object].yaml`

##### ConfigMaps

- Single File: `3scale-dump/configmaps.yaml`
- Object Files: `3scale-dump/configmaps/[object].yaml`

##### PVs (Persistent Volumes)

- Single Files: `3scale-dump/pv.yaml` and `3scale-dump/pv/describe.txt`
- Object Files: `3scale-dump/pv/[object].yaml` and `3scale-dump/pv/describe/[object].txt`

##### PVCs (Persistent Volume Claims)

- Single Files: `3scale-dump/pvc.yaml` and `3scale-dump/pvc/describe.txt`
- Object Files: `3scale-dump/pvc/[object].yaml` and `3scale-dump/pvc/describe/[object].txt`

##### Service Accounts

- Single File: `3scale-dump/serviceaccounts.yaml`
- Object Files: `3scale-dump/serviceaccounts/[object].yaml`

##### Node (CPU and Memory Consumption and Limits)

- File: `/status/node.txt`

### 3scale configuration

The directories `apicast-staging` and `apicast-production` are created inside the `/status` one and should contain information related to both the pods. There might be also optional debug information from the retrieval process.

##### 3scale Echo API call (from the APIcast pod)

- Files: `/status/apicast-[staging/production]/3scale-echo-api-[staging/production].txt` 

##### APIcast Staging and Production JSON Configuration

- Files: `/status/apicast-[staging/production]/apicast-[staging/production].json`
- Debug: `/status/apicast-[staging/production]/apicast-[staging/production]-json-debug.txt`

##### Management API and Status

Depends on the value from the variable `APICAST_MANAGEMENT_API` on both the Staging and Production APIcast pods:

- Management API - Debug: `/status/apicast-[staging/production]/mgmt-api-debug.json`
- Management API - Status: `/status/apicast-[staging/production]/mgmt-api-debug-status-[info/live/ready].txt`

    **NOTE:** Shell Script included on `/status/apicast-[staging/production]/python-json.sh` to convert all the `.json` files inside the `/status/apicast-[staging/production]` directories from a single line into multiple lines in case the `python` utility is installed locally.

##### APIcast Certificates Validation

- Files: `/status/apicast-[staging/production]/certificate.txt`

##### Project and Pods 'runAsUser'

- Files: `/status/project.txt` and `/status/pods-run-as-user.txt`

    **NOTE:** Helps to further troubleshoot database level issues knowing the user that the PV/PVC's will be mounted from the pods.

##### Sidekiq Queue

- File: `/status/sidekiq.txt`

