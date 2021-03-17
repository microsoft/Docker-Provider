import pytest

def get_kubernetes_node_count(api_instance):
    node_list = list_kubernetes_nodes(api_instance)
    return len(node_list.items)

def list_kubernetes_nodes(api_instance):
    try:
        return api_instance.list_node()
    except Exception as e:
        pytest.fail("Error occured while retrieving node information: " + str(e))

