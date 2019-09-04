# 3scaledump
Unofficial tool for dumping a Red Hat 3scale On-premises project.

Usage: ./3scale-dump.sh [3SCALE PROJECT] [COMPRESS UTIL (Optional)] 2>&1 | tee 3scale-dump-logs.txt

3SCALE PROJECT: The official project hosting 3scale in OpenShift.

COMPRESS UTIL: gzip, xz (leave empty or "auto" for auto-detect).

3scale-dump-logs.txt: If anything goes wrong, just send me this file (NOTE: Don't forget the '2>&1' redirect command before the '|' character).

DISCLAIMER: This project is not yet officially supported or endorsed by Red Hat.

---

File provided: '3scale-dump.tar' (it doesn't include a '.gz' or any other type of compression since the logs have already been compressed on the fly during the retrieval process)

Directory Structure: 3scale-dump/*

---

Part 1 - OpenShift related items: With the exception of logs, they are fetched both as a single .yaml file located in '3scale-dump/[category].yaml' and also as separate .yaml files (one for each object) under '3scale-dump/[category]/[object].yaml'

1. Logs and Events: Stored in '3scale-dump/status' (disussed in the "Part 2" further below).

2. DeploymentConfigs: '3scale-dump/dc.yaml' and '3scale-dump/dc/[object].yaml'.
  
3. Logs: Compressed as either '.gz' or '.xz' on '3scale-dump/logs/[pod].[gz,xz]
  
  NOTE: Shell Script included on '3scale-dump/logs/uncompress-logs.sh' to uncompress all the logs. This is adapted whether they are '.gz' or '.xz'.
  
4. Secrets: '3scale-dump/secrets.yaml' and '3scale-dump/secrets/[object].yaml'.
  
5. Routes: '3scale-dump/routes.yaml' and '3scale-dump/routes/[object].yaml'.
  
6. Services: '3scale-dump/services.yaml' and '3scale-dump/services/[object].yaml'.
  
7. Image Steams: '3scale-dump/images.yaml' and '3scale-dump/images/[object].yaml'.
  
8. ConfigMaps: '3scale-dump/configmaps.yaml' and '3scale-dump/configmaps/[object].yaml'.
  
9. PV: '3scale-dump/pv.yaml' and '3scale-dump/pv/[object].yaml'.
  
  NOTE: '3scale-dump/pv/describe.txt' and '3scale-dump/pv/describe/[object].txt' for more information (describe) on the PV's.
  
10. PVC: '3scale-dump/pvc.yaml' and '3scale-dump/pvc/[object].yaml'.
  
    NOTE: '3scale-dump/pvc/describe.txt' and '3scale-dump/pvc/describe/[object].txt' for more information (describe) on the PVC's.
  
11. ServiceAccounts: '3scale-dump/serviceaccounts.yaml' and '3scale-dump/serviceaccounts/[object].yaml'.
  
---

Part 2 - The '3scale-dump/status' directory:

From "Part 1 - Logs and Events":
  - '/status/pods-all.txt': All pods (unfiltered) list.
  - '/status/pods.txt': Filtered (non-deploy) pods list.
  - '/status/events.txt': Output from "oc get event".

12. Node (CPU and Memory consumption and limits): '/status/node.txt'

13. 3scale Echo API call from the APIcast pod: '/status/apicast-[staging/production]/3scale-echo-api-[staging/production].txt'

14. Backend JSON from the ${THREESCALE_PORTAL_ENDPOINT}/staging.json: '/status/apicast-staging/apicast-staging.json' and Backend JSON from the ${THREESCALE_PORTAL_ENDPOINT}/production.json: '/status/apicast-production/apicast-production.json'.

  NOTE: Debug files from both the 'curl' calls above are located on '/status/apicast-[staging/production]/apicast-[staging/production]-json-debug.txt' in case 14. fails.
  
15. Management API and Status: Depends on the value from the variable 'APICAST_MANAGEMENT_API'. Outputs the files 'mgmt-api-debug.json' (stderr to 'mgmt-api-debug-stderr.txt'), 'mgmt-api-debug-status-info.txt', 'mgmt-api-debug-status-live.txt' and 'mgmt-api-debug-status-ready.txt'. All of these are created for both the Sraging and Production versions from APIcast under '/status/apicast-[staging/production]'

  NOTE: The script 'python-json.sh' (generated on each dump) located in the same directory as the ones above converts the single lined .jsons from both 14. and 15. in multiple lines files.
  
16. APIcast Certificates: Tests and validates the 3scale certificates for 'apicast-staging' and 'apicast-production'. File: '/status/apicast-[staging/production]/certificate.txt'

17. Project and Pods 'runAsUser': Helps to further troubleshoot databases issues knowing the user that the PV/PVC's will be mounted from the pods: '/status/project.txt', '/status/pods-run-as-user.txt'.
