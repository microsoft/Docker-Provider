/* @migen@ */
#include <MI.h>
#include "Container_DaemonEvent_Class_Provider.h"

#include <map>
#include <stdio.h>
#include <string>
#include <string.h>
#include <syslog.h>
#include <time.h>
#include <unistd.h>
#include <uuid/uuid.h>
#include <vector>

#include "../cjson/cJSON.h"
#include "../dockerapi/DockerRemoteApi.h"
#include "../dockerapi/DockerRestHelper.h"
#include "Container_ContainerLogFileReader.h"
#include "Helper.h"

#define LASTQUERYTIMEFILE "/var/opt/microsoft/docker-cimprov/state/LastEventQueryTime.txt"
#define TEST_LASTQUERYTIMEFILE "./LastEventQueryTime.txt"

using namespace std;

MI_BEGIN_NAMESPACE

class EventQuery
{
private:
    ///
    /// Utility to get file path for LastEventQueryTime
    ///
    static const char* GetEventQueryTimeFilePath()
    {
        const char *cTestRun = getenv("CONTAINER_TESTRUN_ACTIVE");
        if (cTestRun != NULL)
        {
            return TEST_LASTQUERYTIMEFILE;
        }
        else
        {
            return LASTQUERYTIMEFILE;
        }
    }

    ///
    /// Get the previous time if it was stored, otherwise get the current time
    ///
    /// \returns Time of previous query if available
    ///
    static int GetPreviousTime()
    {
        int fileTime = time(NULL);
        int currentTime = fileTime;
		try {
			const char* lastQueryFile = GetEventQueryTimeFilePath();
			FILE* file = fopen(lastQueryFile, "r");

			if (file)
			{
				fscanf(file, "%d", &fileTime);
				fclose(file);

				if (fileTime > currentTime)
				{
					syslog(LOG_WARNING, "The time stored in %s is more recent than the current time", lastQueryFile);
				}
			}
			else
			{
				syslog(LOG_ERR, "Attempt in GetPreviousTime to open %s for reading failed", lastQueryFile);
			}
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_DaemonEvent - GetPreviousTime %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_DaemonEvent - GetPreviousTime - Unknown exception");
		}

        // Discard stored times that are more recent than the current time
        return fileTime > currentTime ? currentTime : fileTime;
    }

    ///
    /// Write the previous time to disk
    ///
    /// \param[in] t The time
    ///
    static void SetPreviousTime(int t)
    {
		try {
			const char* lastQueryFile = GetEventQueryTimeFilePath();
			FILE* file = fopen(lastQueryFile, "w");

			if (file)
			{
				fprintf(file, "%d", t);
				fclose(file);
			}
			else
			{
				syslog(LOG_ERR, "Attempt in SetPreviousTime to open %s for writing failed", lastQueryFile);
			}
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_DaemonEvent - SetPreviousTime %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_DaemonEvent - SetPreviousTime - Unknown exception");
		}
    }

    ///
    /// Map all container ID to name
    ///
    /// \returns Map object
    ///
    static map<string, string> MapContainerIdToName()
    {
        map<string, string> result;
		try {

			// Request list of containers
			vector<string> request(1, DockerRestHelper::restDockerPs());
			vector<cJSON*> response = getResponse(request);

			// See https://docs.docker.com/engine/reference/api/docker_remote_api_v1.21/#list-containers for example output
			if (!response.empty() && response[0])
			{
				for (int i = 0; i < cJSON_GetArraySize(response[0]); i++)
				{
					cJSON* entry = cJSON_GetArrayItem(response[0], i);

					if (entry != NULL)
					{
						cJSON* nameField = cJSON_GetObjectItem(entry, "Names");

						if ((nameField != NULL) && cJSON_GetArraySize(nameField))
						{
							// Docker API documentation says that this field contains the short ID but that is not the case; use full ID instead
							cJSON* objItem = cJSON_GetObjectItem(entry, "Id");
							if (objItem != NULL)
							{
								if (objItem->valuestring != NULL)
								{
									cJSON* arrItem = cJSON_GetArrayItem(nameField, 0);
									if (arrItem != NULL) {
										if (arrItem->valuestring != NULL)
										{
											result[string(objItem->valuestring)] = string(arrItem->valuestring + 1);
										}
									}
								}
							}
						}
					}
				}
				cJSON_Delete(response[0]);
			}
			else
			{
				syslog(LOG_ERR, "Attempt in MapContainerIdToName to list containers failed");
			}
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_DaemonEvent - MapContainerIdToName %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_DaemonEvent - MapContainerIdToName - Unknown exception");
		}

        return result;
    }

    ///
    /// Create symbolic links to /dev/stdout or /dev/stderr in the target containers
    ///
    /// \param[in] ids Vector of container IDs
    ///
    static void LinkFilesNewContainers(vector<string> ids)
    {
        for (unsigned i = 0; i < ids.size(); i++)
        {
            ContainerLogFileReader::LinkFilesToStream(ids[i]);
        }
    }

public:
    ///
    /// Get information about Docker events since the last query
    ///
    /// \returns Vector containing objects representing each event
    ///
    static vector<Container_DaemonEvent_Class> QueryAll()
    {
        openlog("Container_DaemonEvent", LOG_PID | LOG_NDELAY, LOG_LOCAL1);

        vector<Container_DaemonEvent_Class> result;
        int previousTime = GetPreviousTime();
        int currentTime = time(NULL);

		try {
			if (currentTime > previousTime)
			{
				// Get computer name
				string hostname = getDockerHostName();

				// Request events
				vector<string> request(1, DockerRestHelper::restDockerEvents(previousTime, currentTime));
				vector<cJSON*> response = getResponse(request, true);

				// See https://docs.docker.com/reference/api/Container_remote_api_v1.21/#monitor-docker-s-events for example output
				if (!response.empty() && response[0])
				{
					map<string, string> idMap = MapContainerIdToName();
					vector<string> newContainers;

					for (int i = 0; i < cJSON_GetArraySize(response[0]); i++)
					{
						cJSON* entry = cJSON_GetArrayItem(response[0], i);

						// the newer versions of the API may return objects that do not have status or id
						if ((entry != NULL) && cJSON_GetObjectItem(entry, "status") != NULL && cJSON_GetObjectItem(entry, "id") != NULL)
						{
							// New inventory entry
							Container_DaemonEvent_Class instance;
							instance.Computer_value(hostname.c_str());
							instance.InstanceID_value(Guid::NewToString().c_str());
							instance.Command_value(cJSON_GetObjectItem(entry, "status")->valuestring);

							cJSON* objItem = cJSON_GetObjectItem(entry, "time");
							if (objItem != NULL) {
								char buffer[33];
								snprintf(buffer, 33, "%d", objItem->valueint);
								instance.TimeOfCommand_value(buffer);
							}

							cJSON* tempImageName = cJSON_GetObjectItem(entry, "from");

							if (tempImageName != NULL)
							{
								// Container event

								instance.ElementName_value(tempImageName->valuestring);
								objItem = cJSON_GetObjectItem(entry, "id");
								if (objItem != NULL) {
									char* id = objItem->valuestring;
									instance.Id_value(id);
									string idStr = string(id);

									// Get the container name
									if (idMap.count(idStr))
									{
										instance.ContainerName_value(idMap[idStr].c_str());
										// Add newly created containers to list
										objItem = cJSON_GetObjectItem(entry, "status");
										if (objItem != NULL) {
											if (!strcmp(objItem->valuestring, "create"))
											{
												newContainers.push_back(string(id));
											}
										}
									}
									else
									{
										syslog(LOG_NOTICE, "No container name found for container %s", id);
									}
								}
							}
							else
							{
								// Image event
								cJSON* idItem = cJSON_GetObjectItem(entry, "id");
								if (idItem != NULL)
								{
									instance.ElementName_value(idItem->valuestring);
								}
								instance.Id_value("");
								instance.ContainerName_value("");
							}
							result.push_back(instance);
						}
						else
						{
							syslog(LOG_WARNING, "Attempt in QueryAll to get element %d of event list returned null", i);
						}
					}
					LinkFilesNewContainers(newContainers);
					// Clean up object
					cJSON_Delete(response[0]);
				}
				else
				{
					syslog(LOG_ERR, "Attempt in QueryAll to get Docker events failed");
				}
			}
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_DaemonEvent - QueryAll %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_DaemonEvent - QueryAll - Unknown exception");
		}
        SetPreviousTime(currentTime);
        closelog();
        return result;
    }
};

#ifdef _MSC_VER
#pragma region
#endif

Container_DaemonEvent_Class_Provider::Container_DaemonEvent_Class_Provider(Module* module) : m_Module(module){}

Container_DaemonEvent_Class_Provider::~Container_DaemonEvent_Class_Provider(){}

void Container_DaemonEvent_Class_Provider::Load(Context& context)
{
    context.Post(MI_RESULT_OK);
}

void Container_DaemonEvent_Class_Provider::Unload(Context& context)
{
    context.Post(MI_RESULT_OK);
}

void Container_DaemonEvent_Class_Provider::EnumerateInstances(Context& context, const String& nameSpace, const PropertySet& propertySet, bool keysOnly, const MI_Filter* filter)
{
    try
    {
        vector<Container_DaemonEvent_Class> queryResult = EventQuery::QueryAll();
        for (unsigned i = 0; i < queryResult.size(); i++)
        {
            context.Post(queryResult[i]);
        }
        context.Post(MI_RESULT_OK);
    }
    catch (std::exception &e)
    {
        syslog(LOG_ERR, "Container_DaemonEvent %s", e.what());
        context.Post(MI_RESULT_FAILED);
    }
    catch (...)
    {
        syslog(LOG_ERR, "Container_DaemonEvent Unknown exception");
        context.Post(MI_RESULT_FAILED);
    }
}

void Container_DaemonEvent_Class_Provider::GetInstance(Context& context, const String& nameSpace, const Container_DaemonEvent_Class& instanceName, const PropertySet& propertySet)
{
    context.Post(MI_RESULT_NOT_SUPPORTED);
}

void Container_DaemonEvent_Class_Provider::CreateInstance(Context& context, const String& nameSpace, const Container_DaemonEvent_Class& newInstance)
{
    context.Post(MI_RESULT_NOT_SUPPORTED);
}

void Container_DaemonEvent_Class_Provider::ModifyInstance(Context& context, const String& nameSpace, const Container_DaemonEvent_Class& modifiedInstance, const PropertySet& propertySet)
{
    context.Post(MI_RESULT_NOT_SUPPORTED);
}

void Container_DaemonEvent_Class_Provider::DeleteInstance(Context& context, const String& nameSpace, const Container_DaemonEvent_Class& instanceName)
{
    context.Post(MI_RESULT_NOT_SUPPORTED);
}

#ifdef _MSC_VER
#pragma endregion
#endif

MI_END_NAMESPACE
