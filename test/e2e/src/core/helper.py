import pytest
import requests
import time

from kubernetes import client
from kubernetes_crd_utility import watch_crd_instance
from kubernetes_pod_utility import watch_pod_status, watch_pod_logs
from kubernetes_pod_utility import get_pod_list
from kubernetes_deployment_utility import watch_deployment_status, read_deployment
from kubernetes_daemonset_utility import watch_daemon_set_status, read_daemon_set
from kubernetes_configmap_utility import get_namespaced_configmap
from kubernetes_secret_utility import watch_kubernetes_secret
from kubernetes_namespace_utility import watch_namespace
from results_utility import append_result_output

# This function to check the status of deployment
def check_kubernetes_deployment_status(deployment_namespace, deployment_name, outfile=None):
    try:
       api_instance = client.AppsV1Api()
       deployment = read_deployment(
           api_instance, deployment_namespace, deployment_name)
       append_result_output(
           "deployment output {}\n".format(deployment), outfile)

       if not deployment:
           pytest.fail(
               "deployment is nil or empty for deployment {}.".format(deployment_name))

       deployment_status = deployment.status
       if not deployment_status:
           pytest.fail(
               "deployment_status is nil or empty {}.".format(deployment_name))

       availableReplicas = deployment_status.available_replicas
       readyReplicas = deployment_status.ready_replicas
       replicas = deployment_status.replicas

       if not availableReplicas:
          pytest.fail(
              "availableReplicas is 0 or empty for deployment: {}".format(deployment_name))

       if not readyReplicas:
          pytest.fail(
              "readyReplicas is 0 or empty for deployment: {}".format(deployment_name))

       if not replicas:
          pytest.fail(
              "readyReplicas is 0 or empty for deployment: {}".format(deployment_name))

       if (replicas != availableReplicas):
           pytest.fail("availableReplicas doesnt match with expected replicas for the deployment {}.".format(
               deployment_name))
       if (replicas != readyReplicas):
           pytest.fail("readyReplicas doesnt match with expected replicas for the deployment {}.".format(
               deployment_name))

    except Exception as e:
        pytest.fail("Error occured while checking deployment status: " + str(e))

# This function to check the status of daemonset
def check_kubernetes_daemonset_status(daemonset_namespace, daemonset_name, outfile=None):
    try:
       api_instance = client.AppsV1Api()
       daemonset = read_daemon_set(
           api_instance, daemonset_namespace, daemonset_name)
       append_result_output("daemonset output {}\n".format(daemonset), outfile)

       if not daemonset:
           pytest.fail(
               "daemonset is nil or empty for deployment {}.".format(daemonset_name))

       daemonset_status = daemonset.status
       if not daemonset_status:
           pytest.fail(
               "daemonset_status is nil or empty {}.".format(daemonset_name))

       currentNumberScheduled = daemonset_status.current_number_scheduled
       if not currentNumberScheduled:
           pytest.fail("currentNumberScheduled shouldnt be null or empty for  daemonset {}.".format(
               daemonset_name))

       desiredNumberScheduled = daemonset_status.desired_number_scheduled
       if not desiredNumberScheduled:
           pytest.fail("desiredNumberScheduled shouldnt be null or empty for  daemonset {}.".format(
               daemonset_name))

       numberAvailable = daemonset_status.number_available
       if not numberAvailable:
           pytest.fail("numberAvailable shouldnt be null or empty for  daemonset {}.".format(
               daemonset_name))

       numberReady = daemonset_status.number_ready
       if not numberReady:
           pytest.fail("numberReady shouldnt be null or empty for  daemonset {}.".format(
               daemonset_name))
       numberMisscheduled = daemonset_status.number_misscheduled     
       if desiredNumberScheduled <= 0:
           pytest.fail("desiredNumberScheduled shouldnt less than equal to 0 for the  daemonset {}.".format(
               daemonset_name))

       if (currentNumberScheduled != desiredNumberScheduled):
           pytest.fail("currentNumberScheduled doesnt match with desiredNumberScheduled for the daemonset {}.".format(
               daemonset_name))

       if (numberAvailable != numberReady):
           pytest.fail("numberAvailable doesnt match with expected numberReady for the daemonset {}.".format(
               daemonset_name))

       if (numberMisscheduled > 0):
           pytest.fail("numberMisscheduled shouldnt be greater than 0 for the daemonset {}.".format(
               daemonset_name))

    except Exception as e:
        pytest.fail("Error occured while checking daemonset status: " + str(e))

# This function checks the status of kubernetes pods
def check_kubernetes_pods_status(pod_namespace, label_selector, expectedPodRestartCount, outfile=None):
    try:
       api_instance = client.CoreV1Api()
       pod_list = get_pod_list(api_instance, pod_namespace, label_selector)
       append_result_output("podlist output {}\n".format(pod_list), outfile)
       if not pod_list:
           pytest.fail("pod_list shouldnt be null or empty")
       pods = pod_list.items
       if not pods:
           pytest.fail("pod items shouldnt be null or empty")
       if len(pods) <= 0:
           pytest.fail("pod count should be greater than 0")
       for pod in pods:
          status = pod.status
          podstatus = status.phase
          if not podstatus:
              pytest.fail("status should not be null or empty")
          if podstatus != "Running":
              pytest.fail("pod status should be in running state")
          containerStatuses = status.container_statuses
          if not containerStatuses:
              pytest.fail("containerStatuses shouldnt be nil or empty")
          if len(containerStatuses) <= 0:
              pytest.fail("length containerStatuses should be greater than 0")
          for containerStatus in containerStatuses:
              containerId = containerStatus.container_id
              if not containerId:
                 pytest.fail("containerId shouldnt be nil or empty")
              image = containerStatus.image
              if not image:
                  pytest.fail("image shouldnt be nil or empty")
              imageId = containerStatus.image_id
              if not imageId:
                  pytest.fail("imageId shouldnt be nil or empty")
              restartCount = containerStatus.restart_count
              if restartCount > expectedPodRestartCount:
                  pytest.fail("restartCount shouldnt be greater than expected pod restart count: {}".format(expectedPodRestartCount))
              ready = containerStatus.ready
              if not ready:
                 pytest.fail("container status should be in ready state")
              containerState = containerStatus.state
              if not containerState.running:
                pytest.fail("container state should be in running state")
    except Exception as e:
        pytest.fail("Error occured while checking pods status: " + str(e))


def check_namespace_status_using_watch(outfile=None, namespace_list=None, timeout=300):
    namespace_dict = {}
    for namespace in namespace_list:
        namespace_dict[namespace] = 0
    append_result_output(
        "Namespace dict: {}\n".format(namespace_dict), outfile)
    print("Generated the namespace dictionary.")

    # THe callback function to check the namespace status
    def namespace_event_callback(event):
        try:
            append_result_output("{}\n".format(event), outfile)
            namespace_name = event['raw_object'].get('metadata').get('name')
            namespace_status = event['raw_object'].get('status')
            if not namespace_status:
                return False
            if namespace_status.get('phase') == 'Active':
                namespace_dict[namespace_name] = 1
            if all(ele == 1 for ele in list(namespace_dict.values())):
                return True
            return False
        except Exception as e:
            pytest.fail(
                "Error occured while processing the namespace event: " + str(e))

    # Checking the namespace status
    api_instance = client.CoreV1Api()
    watch_namespace(api_instance, timeout, namespace_event_callback)

# This function checks the status of daemonset in a given namespace. The daemonset to be monitored are identified using the pod label list parameter.
def check_kubernetes_daemonset_status_using_watch(daemonset_namespace, outfile=None, daemonset_label_list=None, timeout=300):
    daemonset_label_dict = {}
    if daemonset_label_list:  # This parameter is a list of label values to identify the daemonsets that we want to monitor in the given namespace
        for daemonset_label in daemonset_label_list:
            daemonset_label_dict[daemonset_label] = 0
    append_result_output("daemonset label dict: {}\n".format(
        daemonset_label_dict), outfile)
    print("Generated the daemonset dictionary.")

    # The callback function to check if the pod is in running state
    def daemonset_event_callback(event):
        try:
            # append_result_output("{}\n".format(event), outfile)
            daemonset_status = event['raw_object'].get('status')
            daemonset_metadata = event['raw_object'].get('metadata')
            daemonset_metadata_labels = daemonset_metadata.get('labels')
            if not daemonset_metadata_labels:
                return False

            # It contains the list of all label values for the pod whose event was called.
            daemonset_metadata_label_values = daemonset_metadata_labels.values()
            # This label value will be common in pod event and label list provided and will be monitored
            current_label_value = None
            for label_value in daemonset_metadata_label_values:
                if label_value in daemonset_label_dict:
                    current_label_value = label_value
            if not current_label_value:
                return False

            currentNumberScheduled = daemonset_status.get(
                'currentNumberScheduled')
            desiredNumberScheduled = daemonset_status.get(
                'desiredNumberScheduled')
            numberAvailable = daemonset_status.get('numberAvailable')
            numberReady = daemonset_status.get('numberReady')
            numberMisscheduled = daemonset_status.get('numberMisscheduled')

            if (currentNumberScheduled != desiredNumberScheduled):
                pytest.fail("currentNumberScheduled doesnt match with currentNumberScheduled for the daemonset {}.".format(
                    daemonset_metadata.get('name')))

            if (numberAvailable != numberReady):
                pytest.fail("numberAvailable doesnt match with expected numberReady for the daemonset {}.".format(
                    daemonset_metadata.get('name')))

            if (numberMisscheduled > 0):
                pytest.fail("numberMisscheduled is greater than 0 for the daemonset {}.".format(
                    daemonset_metadata.get('name')))

            return True
        except Exception as e:
            print("Error occured while processing the pod event: " + str(e))

    # Checking status of all pods
    if daemonset_label_dict:
        api_instance = client.AppsV1Api()
        watch_daemon_set_status(
            api_instance, daemonset_namespace, timeout, daemonset_event_callback)

# This function checks the status of deployment in a given namespace. The deployment to be monitored are identified using the pod label list parameter.
def check_kubernetes_deployments_status_using_watch(deployment_namespace, outfile=None, deployment_label_list=None, timeout=300):
    deployment_label_dict = {}
    if deployment_label_list:  # This parameter is a list of label values to identify the deployments that we want to monitor in the given namespace
        for deployment_label in deployment_label_list:
            deployment_label_dict[deployment_label] = 0
    append_result_output("Deployment label dict: {}\n".format(
        deployment_label_dict), outfile)
    print("Generated the deployment dictionary.")

    # The callback function to check if the pod is in running state
    def deployment_event_callback(event):
        try:
            # append_result_output("{}\n".format(event), outfile)
            deployment_status = event['raw_object'].get('status')
            deployment_metadata = event['raw_object'].get('metadata')
            deployment_metadata_labels = deployment_metadata.get('labels')
            if not deployment_metadata_labels:
                return False

            # It contains the list of all label values for the deployment whose event was called.
            deployment_metadata_label_values = deployment_metadata_labels.values()
            # This label value will be common in deployment event and label list provided and will be monitored
            current_label_value = None
            for label_value in deployment_metadata_label_values:
                if label_value in deployment_label_dict:
                    current_label_value = label_value
            if not current_label_value:
                return False

            availableReplicas = deployment_status.get('availableReplicas')
            readyReplicas = deployment_status.get('readyReplicas')
            replicas = deployment_status.get('replicas')

            if (replicas != availableReplicas):
                pytest.fail("availableReplicas doesnt match with expected replicas for the deployment {}.".format(
                    deployment_metadata.get('name')))

            if (replicas != readyReplicas):
                pytest.fail("readyReplicas doesnt match with expected replicas for the deployment {}.".format(
                    deployment_metadata.get('name')))

            return True
        except Exception as e:
            print("Error occured while processing the pod event: " + str(e))

    # Checking status of all pods
    if deployment_label_dict:
        api_instance = client.AppsV1Api()
        watch_deployment_status(
            api_instance, deployment_namespace, timeout, deployment_event_callback)

# This function checks the status of pods in a given namespace. The pods to be monitored are identified using the pod label list parameter.
def check_kubernetes_pods_status_using_watch(pod_namespace, outfile=None, pod_label_list=None, timeout=300):
    pod_label_dict = {}
    if pod_label_list:  # This parameter is a list of label values to identify the pods that we want to monitor in the given namespace
        for pod_label in pod_label_list:
            pod_label_dict[pod_label] = 0
    append_result_output(
        "Pod label dict: {}\n".format(pod_label_dict), outfile)
    print("Generated the pods dictionary.")

    # The callback function to check if the pod is in running state
    def pod_event_callback(event):
        try:
            # append_result_output("{}\n".format(event), outfile)
            pod_status = event['raw_object'].get('status')
            pod_metadata = event['raw_object'].get('metadata')
            pod_metadata_labels = pod_metadata.get('labels')
            if not pod_metadata_labels:
                return False

            # It contains the list of all label values for the pod whose event was called.
            pod_metadata_label_values = pod_metadata_labels.values()
            # This label value will be common in pod event and label list provided and will be monitored
            current_label_value = None
            for label_value in pod_metadata_label_values:
                if label_value in pod_label_dict:
                    current_label_value = label_value
            if not current_label_value:
                return False

            if pod_status.get('containerStatuses'):
                for container in pod_status.get('containerStatuses'):
                    if container.get('restartCount') > 0:
                        pytest.fail("The pod {} was restarted. Please see the pod logs for more info.".format(
                            container.get('name')))
                    if not container.get('state').get('running'):
                        pod_label_dict[current_label_value] = 0
                        return False
                    else:
                        pod_label_dict[current_label_value] = 1
            if all(ele == 1 for ele in list(pod_label_dict.values())):
                return True
            return False
        except Exception as e:
            pytest.fail(
                "Error occured while processing the pod event: " + str(e))

    # Checking status of all pods
    if pod_label_dict:
        api_instance = client.CoreV1Api()
        watch_pod_status(api_instance, pod_namespace,
                         timeout, pod_event_callback)


# Function to check if the crd instance status has been updated with the status fields mentioned in the 'status_list' parameter
def check_kubernetes_crd_status_using_watch(crd_group, crd_version, crd_namespace, crd_plural, crd_name, status_dict={}, outfile=None, timeout=300):
    # The callback function to check if the crd event received has been updated with the status fields
    def crd_event_callback(event):
        try:
            append_result_output("{}\n".format(event), outfile)
            crd_status = event['raw_object'].get('status')
            if not crd_status:
                return False
            for status_field in status_dict:
                if not crd_status.get(status_field):
                    return False
                if crd_status.get(status_field) != status_dict.get(status_field):
                    pytest.fail(
                        "The CRD instance status has been updated with incorrect value for '{}' field.".format(status_field))
            return True
        except Exception as e:
            pytest.fail("Error occured while processing crd event: " + str(e))

    # Checking if CRD instance has been updated with status fields
    api_instance = client.CustomObjectsApi()
    watch_crd_instance(api_instance, crd_group, crd_version, crd_namespace,
                       crd_plural, crd_name, timeout, crd_event_callback)


# Function to monitor the pod logs. It will ensure that are logs passed in the 'log_list' parameter are present in the container logs.
def check_kubernetes_pod_logs_using_watch(pod_namespace, pod_name, container_name, logs_list=None, error_logs_list=None, outfile=None, timeout=300):
    logs_dict = {}
    for log in logs_list:
        logs_dict[log] = 0
    print("Generated the logs dictionary.")

    # The callback function to examine the pod log
    def pod_log_event_callback(event):
        try:
            append_result_output("{}\n".format(event), outfile)
            for error_log in error_logs_list:
                if error_log in event:
                    pytest.fail("Error log found: " + event)
            for log in logs_dict:
                if log in event:
                    logs_dict[log] = 1
            if all(ele == 1 for ele in list(logs_dict.values())):
                return True
            return False
        except Exception as e:
            pytest.fail(
                "Error occured while processing pod log event: " + str(e))

    # Checking the pod logs
    api_instance = client.CoreV1Api()
    watch_pod_logs(api_instance, pod_namespace, pod_name,
                   container_name, timeout, pod_log_event_callback)

# Function to monitor the kubernetes secret. It will determine if the secret has been successfully created.
def check_kubernetes_secret_using_watch(secret_namespace, secret_name, timeout=300):
    # The callback function to check if the secret event received has secret data
    def secret_event_callback(event):
        try:
            secret_data = event['raw_object'].get('data')
            if not secret_data:
                return False
            return True
        except Exception as e:
            pytest.fail(
                "Error occured while processing secret event: " + str(e))

    # Checking the kubernetes secret
    api_instance = client.CoreV1Api()
    watch_kubernetes_secret(api_instance, secret_namespace,
                            secret_name, timeout, secret_event_callback)
