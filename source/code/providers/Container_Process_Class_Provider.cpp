/* @migen@ */
#include <MI.h>
#include "Container_Process_Class_Provider.h"

#include <vector>
#include <string>
#include <cstdlib>
#include <syslog.h>
#include <sstream>
#include "../cjson/cJSON.h"
#include "../dockerapi/DockerRemoteApi.h"
#include "../dockerapi/DockerRestHelper.h"

using namespace std;

MI_BEGIN_NAMESPACE

class ContainerProcessQuery
{
public:

    ///
    /// \returns vector of strings parsed based on delimiter
    ///
    static vector<string> delimiterParse(const string strToParse, const char delimiterChar)
    {
        vector<string> parsedList;
        stringstream  strStream(strToParse);

        string delmitedStr;
        while(getline(strStream,delmitedStr,delimiterChar))
        {
            parsedList.push_back(delmitedStr);
        }
        return parsedList;
    }

    ///
    /// \returns Object representing process info for each container
    ///
    static vector<Container_Process_Class> GetProcessInfoPerContainer()
    {
        vector<Container_Process_Class> runningProcessListInstance;

        // Get computer name
        string hostname = getDockerHostName();

		try {
			// Request containers
			vector<string> dockerPsRequest(1, DockerRestHelper::restDockerPsRunning());
			vector<cJSON*> dockerPsResponse = getResponse(dockerPsRequest);

			if (!dockerPsResponse.empty() && dockerPsResponse[0])
			{
				for (int i = 0; i < cJSON_GetArraySize(dockerPsResponse[0]); i++)
				{
					cJSON* containerEntry = cJSON_GetArrayItem(dockerPsResponse[0], i);
					if (containerEntry != NULL)
					{
						cJSON* objItem = cJSON_GetObjectItem(containerEntry, "Id");
						if (objItem != NULL)
						{
							if (objItem->valuestring != NULL)
							{
								string containerId = string(objItem->valuestring);
								string containerName;
								string containerPod;
								string containerNamespace;

								// Get container name
								cJSON* names = cJSON_GetObjectItem(containerEntry, "Names");
								if (cJSON_GetArraySize(names))
								{
									containerName = string(cJSON_GetArrayItem(names, 0)->valuestring + 1);
									vector <string> containerMetaInformation = delimiterParse(containerName, '_');
									//only k8 now
									if (containerMetaInformation[0].find("k8s") != string::npos)
									{
										//add namespace pod info
										containerPod = containerMetaInformation[2];
										containerNamespace = containerMetaInformation[3];
									}
									else
									{
										containerPod = "None";
										containerNamespace = "None";
									}
								}

								// Request container process info
								vector<string> dockerTopRequest(1, DockerRestHelper::restDockerTop(containerId));
								vector<cJSON*> dockerTopResponse = getResponse(dockerTopRequest);

								if (!dockerTopResponse.empty() && dockerTopResponse[0])
								{
									//Get process entry
									cJSON* processArr = cJSON_GetObjectItem(dockerTopResponse[0], "Processes");
									if (processArr != NULL)
									{
										for (int j = 0; j < cJSON_GetArraySize(processArr); j++)
										{
											Container_Process_Class processInstance;

											cJSON* processEntry = cJSON_GetArrayItem(processArr, j);
											//process scpecific values
											if ((processEntry != NULL) && (cJSON_GetArraySize(processEntry) >= 8))
											{
												processInstance.InstanceID_value(containerId.c_str());
												cJSON* arrItem = cJSON_GetArrayItem(processEntry, 0);
												if (arrItem != NULL)
												{
													processInstance.Uid_value(arrItem->valuestring);
												}
												arrItem = cJSON_GetArrayItem(processEntry, 1);
												if (arrItem != NULL)
												{
													processInstance.PID_value(arrItem->valuestring);
												}
												arrItem = cJSON_GetArrayItem(processEntry, 2);
												if (arrItem != NULL)
												{
													processInstance.PPID_value(arrItem->valuestring);
												}
												arrItem = cJSON_GetArrayItem(processEntry, 3);
												if (arrItem != NULL)
												{
													processInstance.C_value(arrItem->valuestring);
												}
												arrItem = cJSON_GetArrayItem(processEntry, 4);
												if (arrItem != NULL)
												{
													processInstance.STIME_value(arrItem->valuestring);
												}
												arrItem = cJSON_GetArrayItem(processEntry, 5);
												if (arrItem != NULL)
												{
													processInstance.Tty_value(arrItem->valuestring);
												}
												arrItem = cJSON_GetArrayItem(processEntry, 6);
												if (arrItem != NULL)
												{
													processInstance.TIME_value(arrItem->valuestring);
												}
												arrItem = cJSON_GetArrayItem(processEntry, 7);
												if (arrItem != NULL)
												{
													processInstance.Cmd_value(arrItem->valuestring);
												}
												//container specific values
												processInstance.Id_value(containerId.c_str());
												processInstance.Name_value(containerName.c_str());
												processInstance.Pod_value(containerPod.c_str());
												processInstance.Namespace_value(containerNamespace.c_str());
												processInstance.Computer_value(hostname.c_str());
											}
											runningProcessListInstance.push_back(processInstance);
										}
									}
								}
								cJSON_Delete(dockerTopResponse[0]);
							}
						}
					}
				}
			}
			if (!dockerPsResponse.empty() && dockerPsResponse[0])
			{
				cJSON_Delete(dockerPsResponse[0]);
			}
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_ContainerProcess - GetProcessInfoPerContainer %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_ContainerProcess - GetProcessInfoPerContainer - Unknown exception");
		}
        return runningProcessListInstance;
    }
};

Container_Process_Class_Provider::Container_Process_Class_Provider(
    Module* module) :
    m_Module(module)
{
}

Container_Process_Class_Provider::~Container_Process_Class_Provider()
{
}

void Container_Process_Class_Provider::Load(
        Context& context)
{
    context.Post(MI_RESULT_OK);
}

void Container_Process_Class_Provider::Unload(
        Context& context)
{
    context.Post(MI_RESULT_OK);
}

void Container_Process_Class_Provider::EnumerateInstances(
    Context& context,
    const String& nameSpace,
    const PropertySet& propertySet,
    bool keysOnly,
    const MI_Filter* filter)
{
    try
    {
        vector<Container_Process_Class> queryResult = ContainerProcessQuery::GetProcessInfoPerContainer();
        for (unsigned i = 0; i < queryResult.size(); i++)
        {
            context.Post(queryResult[i]);
        }
        context.Post(MI_RESULT_OK);
    }
    catch (std::exception &e)
    {
        syslog(LOG_ERR, "Container_Process %s", e.what());
        context.Post(MI_RESULT_FAILED);
    }
    catch (...)
    {
        syslog(LOG_ERR, "Container_Process Unknown exception");
        context.Post(MI_RESULT_FAILED);
    }
}

void Container_Process_Class_Provider::GetInstance(
    Context& context,
    const String& nameSpace,
    const Container_Process_Class& instanceName,
    const PropertySet& propertySet)
{
    context.Post(MI_RESULT_NOT_SUPPORTED);
}

void Container_Process_Class_Provider::CreateInstance(
    Context& context,
    const String& nameSpace,
    const Container_Process_Class& newInstance)
{
    context.Post(MI_RESULT_NOT_SUPPORTED);
}

void Container_Process_Class_Provider::ModifyInstance(
    Context& context,
    const String& nameSpace,
    const Container_Process_Class& modifiedInstance,
    const PropertySet& propertySet)
{
    context.Post(MI_RESULT_NOT_SUPPORTED);
}

void Container_Process_Class_Provider::DeleteInstance(
    Context& context,
    const String& nameSpace,
    const Container_Process_Class& instanceName)
{
    context.Post(MI_RESULT_NOT_SUPPORTED);
}


MI_END_NAMESPACE
