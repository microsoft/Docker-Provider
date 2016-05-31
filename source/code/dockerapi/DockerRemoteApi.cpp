#include <errno.h>
#include <iostream>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>
#include <syslog.h>
#include <unistd.h>
#include <vector>

#include "DockerRemoteApi.h"
#include "DockerRestHelper.h"

#define SOCKET_PATH "/var/run/docker.sock"

using namespace std;

/**
*  read the size data from socket, support timeout
*  return the size of data readed
*/
int readSocket(int fd, char* buf, int size, int timeout)
{
	int result = -1;

	fd_set rfds;
	FD_ZERO(&rfds);
	FD_SET(fd, &rfds);

	struct timeval tv;
	tv.tv_sec = timeout;
	tv.tv_usec = 0;

	if (select(fd + 1, &rfds, NULL, NULL, &tv) != -1 && FD_ISSET(fd, &rfds))
	{
		result = read(fd, buf, size);
	}
	
	return result;
}

/**
*   create n connection to docker_socket
*/
void createConnection(unsigned int n, vector<int>& fds)
{
	fds.clear();
	fds.reserve(n);

	struct sockaddr_un addr;
	memset(&addr, 0, sizeof(addr));
	addr.sun_family = AF_UNIX;

	char socket_path[] = SOCKET_PATH;
	memcpy(addr.sun_path, socket_path, sizeof(socket_path));

	bool next = true;

	for (unsigned int i = 0; next && i < n; i++)
	{
		int fd = socket(AF_UNIX, SOCK_STREAM, 0);

		if (fd > 0)
		{
			if (connect(fd, (struct sockaddr*)&addr, sizeof(addr)) != -1)
			{
				fds.push_back(fd);
			}
			else
			{
				close(fd);
				next = false;
			}
		}
		else
		{
			next = false;
		}
	}

	for (unsigned int i = 0; !next && i < fds.size(); i++)
	{
		close(fds[i]);
	}
}

cJSON* parseMultiJson(string &raw_response)
{
	if (raw_response.find("\r\n0\r\n\r\n") == std::string::npos)
	{
		return NULL;
	}

	std::size_t json_begin = 0;
	string json_array = "[";

	while (true)
	{
		json_begin = raw_response.find("\r\n{\"", json_begin);

		if (json_begin == std::string::npos)
		{
			break;
		}

		json_begin += 2;
		std::size_t json_end = raw_response.find("}\n\r\n", json_begin);

		if (json_end == std::string::npos)
		{
			break;
		}

		if (json_array.length() > 1)
		{
			json_array += ",";
		}

		json_array = json_array+=raw_response.substr(json_begin, json_end - json_begin + 1);
	}

	json_array += "]";

	return cJSON_Parse(json_array.c_str());
}

cJSON* parseJson(string& raw_response)
{
	cJSON* result = NULL;
	std::size_t json_begin = raw_response.find("\r\n{\""); //Json object

	if (json_begin == std::string::npos)
	{
		json_begin = raw_response.find("\r\n["); //Json array
	}

	if (json_begin != std::string::npos)
	{
		result = cJSON_Parse(raw_response.c_str() + json_begin);
	}

	return result;
}

/**
*  Give multi request to docker remote api,
*  return multi cJSON* response
*/
void getResponseInBatch(vector<string>& request, vector<cJSON*>& response, unsigned int start, unsigned int end, bool isMultiJson = false, bool ignoreResponse = false)
{
	const int bufferSize = 4096;
	const int timeoutSecond = 5;
	vector<int> sockfd;
	end = (end == 0 || end > request.size()) ? request.size() : end;
	int n = end - start;
	createConnection(n, sockfd);

	for (int i = 0; i < n; i++)
	{
		size_t r = write(sockfd[i], request[start + i].c_str(), request[start + i].length());

		if (r != request[start + i].length())
		{
			throw string("Write to socket in getResponseInBatch failed");
		}
	}

	for (int i = 0; !ignoreResponse && i < n; i++)
	{
		char readBuf[bufferSize + 1];
		int read_n = 0;
		string raw_response;
		response.push_back(NULL);

		while ((read_n = readSocket(sockfd[i], readBuf, bufferSize, timeoutSecond)) > 0)
		{
			readBuf[read_n] = 0;
			raw_response.append(readBuf);
			cJSON* json = isMultiJson ? parseMultiJson(raw_response) : parseJson(raw_response);

			if (json)
			{
				response[start + i] = json;
				break;
			}
		}

		close(sockfd[i]);

		if (!ignoreResponse && raw_response.length() > 0 && response[start + i] == NULL)
		{
			throw string("Failed to parse data:`" + raw_response + "` to json" + " \n Request :" + request[start + i]);
		}
	}
}

vector<cJSON*> getResponse(vector<string>& request, bool isMultiJson, bool ignoreResponse)
{
	vector<cJSON*> response;

	try
	{
		for (unsigned int i = 0; i < request.size(); i += 100)
		{
			getResponseInBatch(request, response, i, i + 100, isMultiJson, ignoreResponse);
		}
	}
	catch (string str)
	{
		openlog("DockerRemoteApi", LOG_PID | LOG_NDELAY, LOG_LOCAL1);
		syslog(LOG_ERR, "%s", str.c_str());
	}

	return response;
}

///
/// Return vector of container IDs
///
/// \param[in] all true for all containers, false for running containers only
///
vector<string> listContainer(bool all)
{
	vector<string> ids;
	vector<string> request(1, all ? DockerRestHelper::restDockerPs() : DockerRestHelper::restDockerPsRunning());
	vector<cJSON*> response = getResponse(request);

	if (response[0])
	{
		int n = cJSON_GetArraySize(response[0]);

		for (int i = 0; i < n; i++)
		{
			cJSON* container = cJSON_GetArrayItem(response[0], i);
			ids.push_back(string(cJSON_GetObjectItem(container, "Id")->valuestring));
		}

		cJSON_Delete(response[0]);
	}

	return ids;
}

///
/// Return set of container IDs
///
/// \param[in] all true for all containers, false for running containers only
///
set<string> listContainerSet(bool all)
{
	set<string> ids;
	vector<string> request(1, all ? DockerRestHelper::restDockerPs() : DockerRestHelper::restDockerPsRunning());
	vector<cJSON*> response = getResponse(request);

	if (response[0])
	{
		int n = cJSON_GetArraySize(response[0]);

		for (int i = 0; i < n; i++)
		{
			cJSON* container = cJSON_GetArrayItem(response[0], i);
			ids.insert(string(cJSON_GetObjectItem(container, "Id")->valuestring));
		}

		cJSON_Delete(response[0]);
	}

	return ids;
}