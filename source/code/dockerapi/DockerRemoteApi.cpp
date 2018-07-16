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
#define SELECT_ERROR -1
#define SELECT_TIMEOUT -2
#define MAX_RETRIES 6

using namespace std;

/**
 *  read the size data from socket, support timeout
 *  return the size of data readed
 */
int readSocket(int fd, char* buf, int size, int timeout)
{
	try {
		int result = SELECT_ERROR;

		fd_set rfds;
		FD_ZERO(&rfds);
		FD_SET(fd, &rfds);

		struct timeval tv;
		tv.tv_sec = timeout;
		tv.tv_usec = 0;

		result = select(fd + 1, &rfds, NULL, NULL, &tv);
		if (result == 0)
		{
			result = SELECT_TIMEOUT;
		}
		else if ((result != -1) && FD_ISSET(fd, &rfds))
		{
			result = read(fd, buf, size);
		}

		return result;
	}
	catch (std::exception &e)
	{
		syslog(LOG_ERR, "DockerRemoteApi %s", e.what());
	}
	catch (...)
	{
		syslog(LOG_ERR, "DockerRemoteApi Unknown exception");
	}
}

/**
 *   create n connection to docker_socket
 */
void createConnection(unsigned int n, vector<int>& fds)
{
	try {
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
	catch (std::exception &e)
	{
		syslog(LOG_ERR, "DockerRemoteApi %s", e.what());
	}
	catch (...)
	{
		syslog(LOG_ERR, "DockerRemoteApi Unknown exception");
	}
}

cJSON* parseMultiJson(string &raw_response)
{
	try {
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

			json_array = json_array += raw_response.substr(json_begin, json_end - json_begin + 1);
		}

		json_array += "]";

		return cJSON_Parse(json_array.c_str());
	}
	catch (std::exception &e)
	{
		syslog(LOG_ERR, "DockerRemoteApi %s", e.what());
	}
	catch (...)
	{
		syslog(LOG_ERR, "DockerRemoteApi Unknown exception");
	}
}

cJSON* parseJson(string& raw_response)
{
	try {
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
	catch (std::exception &e)
	{
		syslog(LOG_ERR, "DockerRemoteApi %s", e.what());
	}
	catch (...)
	{
		syslog(LOG_ERR, "DockerRemoteApi Unknown exception");
	}
}

/**
 *  Give multi request to docker remote api,
 *  return multi cJSON* response
 */
void getResponseInBatch(vector<string>& request, vector<cJSON*>& response, unsigned int start, unsigned int end, bool isMultiJson = false, bool ignoreResponse = false)
{
	try {
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
	catch (std::exception &e)
	{
		openlog("DockerRemoteApiBatch", LOG_PID | LOG_NDELAY, LOG_LOCAL1);
		syslog(LOG_ERR, "DockerRemoteApi-Batch response %s", e.what());
		closelog();
	}
	catch (...)
	{
		openlog("DockerRemoteApiBatch", LOG_PID | LOG_NDELAY, LOG_LOCAL1);
		syslog(LOG_ERR, "DockerRemoteApi-Batch response -unknown exception");
		closelog();
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
        closelog();
    }

    return response;
}

void readLine(char* str, int length, int& readPtr, string& line)
{
	try {
		while (str && (readPtr < length))
		{
			if ((readPtr + 1) < length &&
				str[readPtr] == '\r' && str[readPtr + 1] == '\n')
			{
				readPtr = readPtr + 2;
				break;
			}
			line.append(string(1, str[readPtr]));
			readPtr++;
		}
	}
	catch (std::exception &e)
	{
		syslog(LOG_ERR, "DockerRemoteApi %s", e.what());
	}
	catch (...)
	{
		syslog(LOG_ERR, "DockerRemoteApi Unknown exception");
	}
}

void parseLogs(char* str, int length, vector<string>& logs)
{
	try {
		int readPtr = 0;

		if (!str)
			return;

		// skip header
		while (readPtr < length)
		{
			if ((readPtr + 3) < length &&
				str[readPtr] == '\r' && str[readPtr + 1] == '\n' && str[readPtr + 2] == '\r' && str[readPtr + 3] == '\n')
			{
				readPtr = readPtr + 4;
				break;
			}
			readPtr++;
		}

		// read the logs
		while (readPtr < length)
		{
			// skip data length
			string dataLength;
			readLine(str, length, readPtr, dataLength);

			if (readPtr + 8 > length)
			{
				return;
			}

			// stream type
			string parsedLog;
			if (str[readPtr] == 1)
			{
				parsedLog = "stdout;";
			}
			else
			{
				parsedLog = "stderr;";
			}
			readPtr = readPtr + 8;

			string message;
			readLine(str, length, readPtr, message);
			parsedLog.append(message);
			logs.push_back(parsedLog);
		}
	}
	catch (std::exception &e)
	{
		syslog(LOG_ERR, "DockerRemoteApi %s", e.what());
	}
	catch (...)
	{
		syslog(LOG_ERR, "DockerRemoteApi Unknown exception");
	}
}

vector<string> getContainerLogs(string& request)
{
    vector<string> response;

    try
    {
        const int bufferSize = 4096;
        const int timeoutSecond = 1;
        int multiplier = 1;
        vector<int> sockfd;
        int n = 1;
        createConnection(n, sockfd);

        size_t r = write(sockfd[0], request.c_str(), request.length());
        if (r != request.length())
        {
            throw string("Write to socket in getContainerLogs failed");
        }

        char readBuf[bufferSize + 1];
        int read_n = 0;
        char* raw_response = 0;
        int raw_reponse_size = 0;

        for(int trial = 0; trial < MAX_RETRIES; trial++)
        {
            while ((read_n = readSocket(sockfd[0], readBuf, bufferSize, (timeoutSecond*multiplier))) > 0)
            {
                char* tempBuf = new char[raw_reponse_size + read_n];
                if(raw_reponse_size > 0)
                {
                    memcpy(tempBuf, raw_response, raw_reponse_size);
                    delete raw_response;
                    raw_response = 0;
                }

                memcpy(tempBuf + raw_reponse_size, readBuf, read_n);
                raw_response = tempBuf;
                raw_reponse_size = raw_reponse_size + read_n;
            }
            if(read_n == SELECT_TIMEOUT)
            {
                //back off and retry
                multiplier *= 2;
            }
            else
            {
                //read_n retunred either SELECT_ERROR, non zero number of bytes read or zero which says connection was closed
                break;
            }
        }

        if(raw_reponse_size != 0 && raw_response)
        {
            parseLogs(raw_response, raw_reponse_size, response);
            delete raw_response;
        }

        close(sockfd[0]);
    }
    catch (string str)
    {
        openlog("DockerRemoteApi", LOG_PID | LOG_NDELAY, LOG_LOCAL1);
        syslog(LOG_ERR, "%s", str.c_str());
        closelog();
    }

    return response;
}

string getDockerHostName()
{
	try {
		static string dockerHostName;

		if (dockerHostName.empty())
		{
			vector<string> request(1, DockerRestHelper::restDockerInfo());
			vector<cJSON*> response = getResponse(request);

			if (!response.empty() && response[0])
			{
				dockerHostName = string(cJSON_GetObjectItem(response[0], "Name")->valuestring);

				// in case get full name, extract up to '.'
				size_t dotpos = dockerHostName.find('.');
				if (dotpos != string::npos)
				{
					dockerHostName = dockerHostName.substr(0, dotpos);
				}

				cJSON_Delete(response[0]);
			}
		}

		return dockerHostName;
	}
	catch (std::exception &e)
	{
		syslog(LOG_ERR, "DockerRemoteApi %s", e.what());
	}
	catch (...)
	{
		syslog(LOG_ERR, "DockerRemoteApi Unknown exception");
	}
}

///
/// Return vector of container IDs
///
/// \param[in] all true for all containers, false for running containers only
///
vector<string> listContainer(bool all)
{
	try {
		vector<string> ids;
		vector<string> request(1, all ? DockerRestHelper::restDockerPs() : DockerRestHelper::restDockerPsRunning());
		vector<cJSON*> response = getResponse(request);

		if (!response.empty() && response[0])
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
	catch (std::exception &e)
	{
		syslog(LOG_ERR, "DockerRemoteApi %s", e.what());
	}
	catch (...)
	{
		syslog(LOG_ERR, "DockerRemoteApi Unknown exception");
	}
}

///
/// Return set of container IDs
///
/// \param[in] all true for all containers, false for running containers only
///
set<string> listContainerSet(bool all)
{
	try {
		set<string> ids;
		vector<string> request(1, all ? DockerRestHelper::restDockerPs() : DockerRestHelper::restDockerPsRunning());
		vector<cJSON*> response = getResponse(request);

		if (!response.empty() && response[0])
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
	catch (std::exception &e)
	{
		syslog(LOG_ERR, "DockerRemoteApi %s", e.what());
	}
	catch (...)
	{
		syslog(LOG_ERR, "DockerRemoteApi Unknown exception");
	}
}
