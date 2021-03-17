import pytest
from kubernetes import watch

# Returns a list of daemon_sets in a given namespace
def list_daemon_set(api_instance, namespace, field_selector="", label_selector=""):
    try:
        return api_instance.list_namespaced_daemon_set(namespace, field_selector=field_selector, label_selector=label_selector)
    except Exception as e:
        pytest.fail("Error occured when retrieving daemon_sets: " + str(e))

# Deletes a daemon_set
def delete_daemon_set(api_instance, namespace, daemon_set_name):
    try:
        return api_instance.delete_namespaced_daemon_set(daemon_set_name, namespace)
    except Exception as e:
        pytest.fail("Error occured when deleting daemon_set: " + str(e))

# Read a daemon_set
def read_daemon_set(api_instance, namespace, daemon_set_name):
    try:
        return api_instance.read_namespaced_daemon_set(daemon_set_name, namespace)
    except Exception as e:
        pytest.fail("Error occured when reading daemon_set: " + str(e))

# Function that watches events corresponding to daemon_sets in the given namespace and passes the events to a callback function
def watch_daemon_set_status(api_instance, namespace, timeout, callback=None):
    if not callback:
        return
    try:
        w = watch.Watch()
        for event in w.stream(api_instance.list_namespaced_daemon_set, namespace, timeout_seconds=timeout):
            if callback(event):
                return
    except Exception as e:
        print("Error occurred when checking daemon_set status: " + str(e))
    print("The watch on the daemon_set status has timed out. Please see the pod logs for more info.")
