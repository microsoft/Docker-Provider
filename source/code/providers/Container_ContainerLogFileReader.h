#pragma once

#include <istream>
#include <iostream>
#include <sstream>
#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <syslog.h>
#include <unistd.h>
#include <vector>

#include "../cjson/cJSON.h"
#include "../dockerapi/DockerRemoteApi.h"
#include "../dockerapi/DockerRestHelper.h"

#define STDOUT_PATH "/dev/stdout"
#define STDERR_PATH "/dev/stderr"

using namespace std;

class ContainerLogFileReader
{
private:
    ///
    /// Parse value of environment variable
    ///
    /// \param containerId Container ID
    /// \param paths Environment variable string
    /// \param stderr Target stderr if true, else stdout
    ///
    static void ParseAndExec(string containerId, string paths, bool isstderr = false)
    {
        istringstream is(paths);
        string path;

        vector<string> createRequests;
		
        // File names delimited by comma
        while (is.good() && getline(is, path, ','))
        {
            vector<string> command;

            command.push_back("ln");
            command.push_back("-sbf");
            command.push_back(isstderr ? STDERR_PATH : STDOUT_PATH);
            command.push_back(path);

            createRequests.push_back(DockerRestHelper::restDockerExecCreate(containerId, command));
        }
		
        if (createRequests.size())
        {
            // POST exec create requests
            vector<cJSON*> response = getResponse(createRequests);
            vector<cJSON*> tempResponse ; //need a temp var so I can delete the response,usage will make this note clearer
            vector<string> startRequests;

            // See https://docs.docker.com/engine/reference/api/docker_remote_api_v1.21/#exec-create for example output
            for (unsigned i = 0; i < response.size(); i++)
            {
                if (response[i])
                {
                    // Get ID of exec instance
					cJSON* objItem = cJSON_GetObjectItem(response[i], "Id");
					if (objItem != NULL)
					{
						if (objItem->valuestring != NULL)
						{
							startRequests.push_back(DockerRestHelper::restDockerExecStart(string(objItem->valuestring)));
						}
					}
                }
                else
                {
                    syslog(LOG_ERR, "The request %s returned null", createRequests[i].c_str());
                }
            }
			
            if (startRequests.size())
            {
                // POST exec start requests
                tempResponse = getResponse(startRequests, false, true);
            }

            //clean up
            for (unsigned i = 0; i < response.size(); i++)
            {
                cJSON_Delete(response[i]);
            }
            for (unsigned i = 0; i < tempResponse.size(); i++)
            {
                cJSON_Delete(tempResponse[i]);
            }
        }
    }

public:
    ///
    /// Link files in a container to stdout/stderr
    ///
    /// \param containerId Container ID
    ///
    static void LinkFilesToStream(string containerId)
    {
        // Inspect container
        vector<string> request(1, DockerRestHelper::restDockerInspect(containerId));
        vector<cJSON*> response = getResponse(request);
		
        // See http://docs.docker.com/reference/api/Container_remote_api_v1.21/#inspect-a-container for example output
        if (!response.empty() && response[0])
        {
            // Get the container state
            cJSON* state = cJSON_GetObjectItem(response[0], "State");

            if(state != NULL)
            {			
                // Check if container is running first
                if ((cJSON_GetObjectItem(state, "Running") != NULL) && (cJSON_GetObjectItem(state, "Running")->valueint))
                {
                    // Get the container config
                    cJSON* config = cJSON_GetObjectItem(response[0], "Config");

                    if (config)
                    {
                        // Get environment variables
                        cJSON* env = cJSON_GetObjectItem(config, "Env");
                        
                        if (env)
                        {
                            int length = cJSON_GetArraySize(env);

                            // Allow exit from loop if both OMSLOGS and OMSERRLOGS were found so that the remaining environment variables don't have to be parsed
                            bool logfound = false;
                            bool errfound = false;

                            for (int i = 0; !logfound && !errfound && i < length; i++)
                            {
                                //Initialize an empty string
                                string var = "";
                                cJSON* arrItem = cJSON_GetArrayItem(env, i);
                                //Try a string cast only if the json object exists and is of type string, a cast of type string(NULL) results in a coredump
                                if(arrItem != NULL)
                                {
                                    if(arrItem->valuestring != NULL)
                                    {
                                        var = string(arrItem->valuestring);
                                    }
                                }
                                // Check beginning of string
                                if (!logfound && var.length() > 8 && !var.find("OMSLOGS="))
                                {
                                    logfound = true;
                                    ParseAndExec(containerId, var.substr(8));
                                }
                                else if (!errfound && var.length() > 11 && !var.find("OMSERRLOGS="))
                                {
                                    errfound = true;
                                    ParseAndExec(containerId, var.substr(11), true);
                                }
                            }
                        }
                    }
                }
                else
                {
                    syslog(LOG_NOTICE, "Container %s is not running; cannot exec", containerId.c_str());
                }
            }

            // Clean up object
            cJSON_Delete(response[0]);
        }
        else
        {
            syslog(LOG_ERR, "Attempt in LinkFilesToStream to inspect container %s failed", containerId.c_str());
        }
    }
};
