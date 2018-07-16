#pragma once

#include <stdio.h>
#include <string>
#include <string.h>
#include <stdlib.h>

#include "../cjson/cJSON.h"

using std::string;

class DockerRestHelper
{
public:
    ///
    /// Create the REST request to list images
    /// https://docs.docker.com/engine/reference/api/docker_remote_api_v1.21/#list-images
    ///
    /// \returns Request in string format
    ///
    static string restDockerImages()
    {
        return "GET /images/json?all=0 HTTP/1.1\r\nHost: localhost\r\n\r\n";
    }

    ///
    /// Create the REST request to list containers
    /// https://docs.docker.com/engine/reference/api/docker_remote_api_v1.21/#list-containers
    ///
    /// \returns Request in string format
    ///
    static string restDockerPs()
    {
        return "GET /containers/json?all=1 HTTP/1.1\r\nHost: localhost\r\n\r\n";
    }

    ///
    /// Create the REST request to list running containers
    /// https://docs.docker.com/engine/reference/api/docker_remote_api_v1.21/#list-containers
    ///
    /// \returns Request in string format
    ///
    static string restDockerPsRunning()
    {
        return "GET /containers/json HTTP/1.1\r\nHost: localhost\r\n\r\n";
    }

    ///
    /// Create the REST request to inspect a container
    /// https://docs.docker.com/engine/reference/api/docker_remote_api_v1.21/#inspect-a-container
    ///
    /// \param[in] id ID of the container to be inspected
    /// \returns Request in string format
    ///
    static string restDockerInspect(string id)
    {
        return "GET /containers/" + id + "/json HTTP/1.1\r\nHost: localhost\r\n\r\n";
    }

    ///
    /// Create the REST request to list events
    /// https://docs.docker.com/engine/reference/api/docker_remote_api_v1.21/#monitor-docker-s-events
    ///
    /// \returns Request in string format
    ///
    static string restDockerEvents(int start, int end)
    {
        char result[128];
        snprintf(result, 128, "GET /events?since=%d&until=%d HTTP/1.1\r\nHost: localhost\r\n\r\n", start, end);
        return string(result);
    }

    ///
    /// Create the REST request to get container stats
    /// https://docs.docker.com/engine/reference/api/docker_remote_api_v1.21/#get-container-stats-based-on-resource-usage
    ///
    /// \param[in] id ID of the container to get stats of
    /// \returns Request in string format
    ///
    static string restDockerStats(string id)
    {
        return "GET /containers/" + id + "/stats?stream=false HTTP/1.1\r\nHost: localhost\r\n\r\n";
    }

    ///
    /// Create the REST request to get container logs
    /// https://docs.docker.com/engine/reference/api/docker_remote_api_v1.21/#get-container-stats-based-on-resource-usage
    ///
    /// \param[in] id ID of the container
    /// \param[in] start Time from where logs has to be collected
    /// \returns Request in string format
    ///
    static string restDockerLogs(string id, int start)
    {
        char result[516];
        snprintf(result, 516, "GET /containers/%s/logs?stderr=1&stdout=1&since=%d&timestamps=1 HTTP/1.1\r\nHost: localhost\r\n\r\n", id.c_str(), start);
        return string(result);
    }

    ///
    /// Create the REST request to get docker info
    /// https://docs.docker.com/engine/reference/api/docker_remote_api_v1.21/#get-container-stats-based-on-resource-usage
    ///
    /// \returns Request in string format
    ///
    static string restDockerInfo()
    {
        return "GET /info HTTP/1.1\r\nHost: localhost\r\n\r\n";
    }

    ///
    /// Create the REST request to create an exec instance
    /// https://docs.docker.com/engine/reference/api/docker_remote_api_v1.21/#exec-create
    ///
    /// \param[in] id ID of the container to exec in
    /// \param[in] command Command to exec
    /// \returns Request in string format
    ///
    static string restDockerExecCreate(string id, vector<string>& command)
    {
		try {
			// Request body
			cJSON* root = cJSON_CreateObject();

			cJSON_AddFalseToObject(root, "AttachStdin");
			cJSON_AddFalseToObject(root, "AttachStdout");
			cJSON_AddFalseToObject(root, "AttachStderr");
			cJSON_AddFalseToObject(root, "Tty");

			cJSON* cmd = cJSON_CreateArray();

			for (unsigned i = 0; i < command.size(); i++)
			{
				cJSON_AddItemToArray(cmd, cJSON_CreateString(command[i].c_str()));
			}

			cJSON_AddItemToObject(root, "Cmd", cmd);

			char* json = cJSON_PrintUnformatted(root);

			char result[2048];
			snprintf(result, 2048, "POST /containers/%s/exec HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: %zu\r\n\r\n%s", id.c_str(), strlen(json), json);

			if (root) cJSON_Delete(root);
			if (json) free(json);

			return string(result);
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "DockerRestHelper %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "DockerRestHelper Unknown exception");
		}
    }

    ///
    /// Create the REST request to start an exec instance
    /// https://docs.docker.com/engine/reference/api/docker_remote_api_v1.21/#exec-start
    ///
    /// \param[in] id ID of exec instance
    /// \returns Request in string format
    ///
    static string restDockerExecStart(string execId)
    {
		try {
			// Request body
			cJSON* root = cJSON_CreateObject();

			cJSON_AddTrueToObject(root, "Detach");
			cJSON_AddFalseToObject(root, "Tty");

			char* json = cJSON_PrintUnformatted(root);

			char result[512];
			snprintf(result, 512, "POST /exec/%s/start HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: %zu\r\n\r\n%s", execId.c_str(), strlen(json), json);

			if (root) cJSON_Delete(root);
			if (json) free(json);

			return string(result);
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "DockerRestHelper %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "DockerRestHelper Unknown exception");
		}
    }

    ///
    /// Create the REST request to list processes running inside container
    /// https://docs.docker.com/engine/api/v1.30/#operation/ContainerTop
    ///
    /// \returns Request in string format
    ///
    static string restDockerTop(string id)
    {
        char result[516];
        snprintf(result, 516, "GET /containers/%s/top HTTP/1.1\r\nHost: localhost\r\n\r\n", id.c_str());
        return string(result);
    }

};
