/* @migen@ */
#include <MI.h>
#include "Container_ContainerInventory_Class_Provider.h"

#include <map>
#include <set>
#include <string>
#include <syslog.h>
#include <unistd.h>
#include <vector>

#include "../cjson/cJSON.h"
#include "../dockerapi/DockerRemoteApi.h"
#include "../dockerapi/DockerRestHelper.h"
#include "Container_ContainerInventory_Serialization.h"
#include "Container_ContainerInventory_Validation.h"

using namespace std;

MI_BEGIN_NAMESPACE

class ContainerQuery
{
private:
    ///
    /// Seperate the repository, image, and image tag strings
    ///
    /// \param[in] id Image ID
    /// \param[in] properties Raw string of form image:imagetag or repository/image:imagetag
    ///
    /// \returns vector<string> of length 3 of form [repository, image, imagetag]
    ///
    static vector<string> SetImageRepositoryImageTag(string& properties)
    {
        vector<string> result(3, "");

        switch (properties.size())
        {
            default:
            {
				try {
					// Find delimiters in the string of format repository/image:imagetag
					int slashLocation = properties.find('/');
					int colonLocation = properties.find(':');

					if ((unsigned)colonLocation != string::npos)
					{
						if ((unsigned)slashLocation >= properties.size())
						{
							// image:imagetag
							result[1] = properties.substr(0, colonLocation);
						}
						else
						{
							// repository/image:imagetag
							result[0] = properties.substr(0, slashLocation);
							result[1] = properties.substr(slashLocation + 1, colonLocation - slashLocation - 1);
						}

						result[2] = properties.substr(colonLocation + 1);
						break;
					}
				}
				catch (std::exception &e)
				{
					syslog(LOG_ERR, "Container_ContainerInventory-SetImageRepositoryImageTag %s", e.what());
					break;
				}
				catch (...)
				{
					syslog(LOG_ERR, "Container_ContainerInventory -SetImageRepositoryImageTag- Unknown exception");
					break;
				}
            }
            case 0:
            {
                // Do not crash the program
                syslog(LOG_WARNING, "Container image name (%s) is improperly formed and could not be parsed in SetRepositoryImageTag", properties.c_str());
                break;
            }
        }

        return result;
    }

    ///
    /// Map the image name, repository, imagetag to ID
    ///
    /// /returns Map of values to ID
    ///
    static map<string, vector<string> > GenerateImageNameMap()
    {
        map<string, vector<string> > result;

		try {
			// Request images
			vector<string> request(1, DockerRestHelper::restDockerImages());
			vector<cJSON*> response = getResponse(request);

			// See http://docs.docker.com/reference/api/Container_remote_api_v1.21/#list-images for example output
			if (!response.empty() && response[0])
			{
				for (int i = 0; i < cJSON_GetArraySize(response[0]); i++)
				{
					cJSON* entry = cJSON_GetArrayItem(response[0], i);

					if (entry != NULL)
					{
						cJSON* tags = cJSON_GetObjectItem(entry, "RepoTags");

						if ((tags != NULL) && cJSON_GetArraySize(tags))
						{
							string value = "";
							cJSON* arrItem = cJSON_GetArrayItem(tags, 0);
							if (arrItem != NULL)
							{
								if (arrItem->valuestring != NULL)
								{
									value = string(arrItem->valuestring);
								}
							}

							string idvalue = "";
							cJSON* objItem = cJSON_GetObjectItem(entry, "Id");
							if (objItem != NULL)
							{
								if (objItem->valuestring != NULL)
								{
									idvalue = string(objItem->valuestring);
									result[idvalue] = SetImageRepositoryImageTag(value);
								}
							}
						}
					}
					else
					{
						syslog(LOG_WARNING, "Attempt in GenerateImageNameMap to get element %d of image list returned null", i);
					}
				}

				// Clean up object
				cJSON_Delete(response[0]);
			}
			else
			{
				syslog(LOG_WARNING, "API call in GenerateImageNameMap to list images returned null");
			}
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_ContainerInventory - GenerateImageNameMap %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_ContainerInventory - GenerateImageNameMap Unknown exception");
		}
        return result;
    }

    ///
    /// Get information from container config field
    ///
    /// \param[in] instance Object representing the container
    /// \param[in] entry JSON from docker inspect
    ///
    static void ObtainContainerConfig(Container_ContainerInventory_Class& instance, cJSON* entry)
    {
		try {
			cJSON* config = cJSON_GetObjectItem(entry, "Config");

			if (config != NULL)
			{
				// Hostname of container
				string hostnamevalue = "";
				cJSON* objItem = cJSON_GetObjectItem(config, "Hostname");
				if (objItem != NULL)
				{
					if (objItem->valuestring != NULL)
					{
						instance.ContainerHostname_value(objItem->valuestring);
					}
				}

				// Environment variables
				string envValue = "";
				objItem = cJSON_GetObjectItem(config, "Env");
				if (objItem != NULL) {
					char* env = cJSON_Print(objItem);
					int envStringLength = strlen(env);
					//Restricting the ENV string value to 200kb since the limit on the packet size is 250kb.
					if (envStringLength > 200000)
					{
						string stringToTruncate = env;
						string quotestring = "\"";
						string quoteandbracestring = "\"]";
						string quoteandcommastring = "\",";
						string correctedstring;
						stringToTruncate.resize(200000);
						if (stringToTruncate.compare(stringToTruncate.size() - quotestring.size(), quotestring.size(), quotestring) == 0) {
							correctedstring = stringToTruncate + "]";
						}
						else if (stringToTruncate.compare(stringToTruncate.size() - quoteandbracestring.size(), quoteandbracestring.size(), quoteandbracestring) == 0) {
							correctedstring = stringToTruncate;
						}
						else if (stringToTruncate.compare(stringToTruncate.size() - quoteandcommastring.size(), quoteandcommastring.size(), quoteandcommastring) == 0) {
							correctedstring = stringToTruncate.substr(0, stringToTruncate.length() - 1);
							correctedstring = correctedstring + "]";
						}
						else {
							correctedstring = stringToTruncate + "\"]";
						}
						instance.EnvironmentVar_value(correctedstring.c_str());
						cJSON* idItem = cJSON_GetObjectItem(entry, "Id");
						if (idItem != NULL)
						{
							syslog(LOG_WARNING, "Environment variable truncated for container %s", idItem->valuestring);
						}
					}
					else {
						instance.EnvironmentVar_value(strcmp(env, "null") ? env : "");
					}
					if (env) free(env);
				}

				// Command
				string cmdValue = "";
				objItem = cJSON_GetObjectItem(config, "Cmd");
				if (objItem != NULL) {
					char *cmd = cJSON_Print(objItem);
					instance.Command_value(cmd);
					if (cmd) free(cmd);
				}

				cJSON* labels = cJSON_GetObjectItem(config, "Labels");

				// Compose group
				instance.ComposeGroup_value("");

				if (labels != NULL)
				{
					cJSON* groupName = cJSON_GetObjectItem(labels, "com.docker.compose.project");

					if (groupName)
					{
						instance.ComposeGroup_value(groupName->valuestring);
					}
				}
			}
			else
			{
				cJSON* idItem = cJSON_GetObjectItem(entry, "Id");
				if (idItem != NULL)
				{
					syslog(LOG_WARNING, "Attempt in ObtainContainerConfig to get container %s config information returned null", idItem->valuestring);
				}
			}
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_ContainerInventory - ObtainContainerConfig %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_ContainerInventory - - ObtainContainerConfig- Unknown exception");
		}
    }

    ///
    /// Get information from container state field
    ///
    /// \param[in] instance Object representing the container
    /// \param[in] entry JSON from docker inspect
    ///
    static void ObtainContainerState(Container_ContainerInventory_Class& instance, cJSON* entry)
    {
		try {
			cJSON* state = cJSON_GetObjectItem(entry, "State");

			if (state != NULL)
			{
				cJSON* objItem = cJSON_GetObjectItem(state, "ExitCode");
				if (objItem != NULL)
				{
					int exitCode = objItem->valueint;

					// Exit codes less than 0 are not supported by the engine
					if (exitCode < 0)
					{
						exitCode = 128;
						cJSON* idItem = cJSON_GetObjectItem(entry, "Id");
						if (idItem != NULL)
						{
							syslog(LOG_NOTICE, "Container %s returned negative exit code", idItem->valuestring);
						}
					}

					instance.ExitCode_value(exitCode);

					if (exitCode)
					{
						// Container failed
						instance.State_value("Failed");
					}
					else
					{
						cJSON* objItem = cJSON_GetObjectItem(state, "Running");
						if (objItem != NULL) {
							// Set the Container status : Running/Paused/Stopped
							if (objItem->valueint)
							{
								objItem = cJSON_GetObjectItem(state, "Paused");
								if (objItem != NULL) {
									// Container running
									if (objItem->valueint)
									{
										// Container paused
										instance.State_value("Paused");
									}
									else
									{
										instance.State_value("Running");
									}
								}
							}
							else
							{
								// Container exited
								instance.State_value("Stopped");
							}
						}
					}
				}

				objItem = cJSON_GetObjectItem(state, "StartedAt");
				if (objItem != NULL) {
					instance.StartedTime_value(objItem->valuestring);
				}
				objItem = cJSON_GetObjectItem(state, "FinishedAt");
				if (objItem != NULL) {
					instance.FinishedTime_value(objItem->valuestring);
				}
			}
			else
			{
				cJSON* idItem = cJSON_GetObjectItem(entry, "Id");
				if (idItem != NULL)
				{
					syslog(LOG_WARNING, "Attempt in ObtainContainerState to get container %s state information returned null", idItem->valuestring);
				}
			}
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_ContainerInventory-ObtainContainerState %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_ContainerInventory -ObtainContainerState- Unknown exception");
		}
    }

    ///
    /// Get information from container host config field
    ///
    /// \param[in] instance Object representing the container
    /// \param[in] entry JSON from docker inspect
    ///
    static void ObtainContainerHostConfig(Container_ContainerInventory_Class& instance, cJSON* entry)
    {
		try {
			cJSON* hostConfig = cJSON_GetObjectItem(entry, "HostConfig");

			if (hostConfig != NULL)
			{
				// Links
				cJSON* objItem = cJSON_GetObjectItem(hostConfig, "Links");
				if (objItem != NULL) {
					char* links = cJSON_Print(objItem);
					instance.Links_value(strcmp(links, "null") ? links : "");
					if (links) free(links);
				}

				// Ports
				objItem = cJSON_GetObjectItem(hostConfig, "PortBindings");
				if (objItem != NULL) {
					char* ports = cJSON_Print(objItem);
					instance.Ports_value(strcmp(ports, "{\n}") ? ports : "");
					if (ports) free(ports);
				}
			}
			else
			{
				cJSON* idItem = cJSON_GetObjectItem(entry, "Id");
				if (idItem != NULL)
				{
					syslog(LOG_WARNING, "Attempt in ObtainContainerHostConfig to get container %s host config information returned null", idItem->valuestring);
				}
			}
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_ContainerInventory-ObtainContainerHostConfig %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_ContainerInventory -ObtainContainerHostConfig- Unknown exception");
		}
    }

    ///
    /// Inspect a container and get the necessary data
    ///
    /// \param[in] id Container ID
    /// \returns Object representing the container
    ///
    static Container_ContainerInventory_Class InspectContainer(string& id, map<string, vector<string> >& nameMap)
    {
        // New inventory entry
        Container_ContainerInventory_Class instance;

		try {
			// Inspect container
			vector<string> request(1, DockerRestHelper::restDockerInspect(id));
			vector<cJSON*> response = getResponse(request);

			// See http://docs.docker.com/reference/api/Container_remote_api_v1.21/#inspect-a-container for example output
			if (!response.empty() && response[0])
			{
				cJSON* objItem = cJSON_GetObjectItem(response[0], "Id");
				if (objItem != NULL) {
					instance.InstanceID_value(objItem->valuestring);
				}

				objItem = cJSON_GetObjectItem(response[0], "Created");
				if (objItem != NULL) {
					instance.CreatedTime_value(objItem->valuestring);
				}

				objItem = cJSON_GetObjectItem(response[0], "Name");
				if (objItem != NULL) {
					char* containerName = objItem->valuestring;

					if (strlen(containerName))
					{
						// Remove the leading / from the name if it exists (this is an API issue)
						instance.ElementName_value(containerName[0] == '/' ? containerName + 1 : containerName);
					}
				}

				objItem = cJSON_GetObjectItem(response[0], "Image");
				if (objItem != NULL) {
					string imageId = string(objItem->valuestring);
					instance.ImageId_value(imageId.c_str());

					if (nameMap.count(imageId))
					{
						instance.Repository_value(nameMap[imageId][0].c_str());
						instance.Image_value(nameMap[imageId][1].c_str());
						instance.ImageTag_value(nameMap[imageId][2].c_str());
					}
				}

				ObtainContainerConfig(instance, response[0]);
				ObtainContainerState(instance, response[0]);
				ObtainContainerHostConfig(instance, response[0]);

				// Clean up object
				cJSON_Delete(response[0]);
			}
			else
			{
				syslog(LOG_WARNING, "Attempt in InspectContainer to inspect %s returned null", id.c_str());
			}
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_ContainerInventory - GenerateImageNameMap %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_ContainerInventory - GenerateImageNameMap Unknown exception");
		}

        return instance;
    }

public:
    ///
    /// Get information about all containers on the host
    ///
    /// \returns Vector containing objects representing each container
    ///
    static vector<Container_ContainerInventory_Class> QueryAll()
    {
        openlog("Container_ContainerInventory", LOG_PID | LOG_NDELAY, LOG_LOCAL1);

        // Get computer name
        string hostname = getDockerHostName();

        vector<Container_ContainerInventory_Class> result;

		try {
			// Get all current containers
			set<string> containerIds = listContainerSet(true);

			/// Map the image name, repository, imagetag to ID
			map<string, vector<string> > nameMap = GenerateImageNameMap();

			for (set<string>::iterator i = containerIds.begin(); i != containerIds.end(); ++i)
			{
				// Set all data
				string id = string(*i);
				Container_ContainerInventory_Class instance = InspectContainer(id, nameMap);
				instance.Computer_value(hostname.c_str());

				ContainerInventorySerializer::SerializeObject(instance);
				result.push_back(instance);
			}

			// Find IDs of deleted containers
			ContainerInventoryValidation cv;
			set<string> deleted = cv.GetDeletedContainers(containerIds);

			for (set<string>::iterator i = deleted.begin(); i != deleted.end(); ++i)
			{
				// Putting string(*i) directly in the function call will cause compilation error
				string id = string(*i);
				Container_ContainerInventory_Class instance = ContainerInventorySerializer::DeserializeObject(id);
				instance.State_value("Deleted");

				result.push_back(instance);
			}
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_ContainerInventory - QueryAll %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_ContainerInventory - QueryAll Unknown exception");
		}
        closelog();
        return result;
    }
};

#ifdef _MSC_VER
#pragma region
#endif

Container_ContainerInventory_Class_Provider::Container_ContainerInventory_Class_Provider(Module* module) : m_Module(module){}

Container_ContainerInventory_Class_Provider::~Container_ContainerInventory_Class_Provider(){}

void Container_ContainerInventory_Class_Provider::Load(Context& context)
{
    context.Post(MI_RESULT_OK);
}

void Container_ContainerInventory_Class_Provider::Unload(Context& context)
{
    context.Post(MI_RESULT_OK);
}

void Container_ContainerInventory_Class_Provider::EnumerateInstances(Context& context, const String& nameSpace, const PropertySet& propertySet, bool keysOnly, const MI_Filter* filter)
{
    try
    {
    	vector<Container_ContainerInventory_Class> queryResult = ContainerQuery::QueryAll();

    	for (unsigned i = 0; i < queryResult.size(); i++)
    	{
        	context.Post(queryResult[i]);
    	}
    	context.Post(MI_RESULT_OK);
    }

    catch (std::exception &e)
    {
        syslog(LOG_ERR, "Container_ContainerInventory %s", e.what());
        context.Post(MI_RESULT_FAILED);
    }
    catch (...)
    {
        syslog(LOG_ERR, "Container_ContainerInventory Unknown exception");
        context.Post(MI_RESULT_FAILED);
    }
}

void Container_ContainerInventory_Class_Provider::GetInstance(Context& context, const String& nameSpace, const Container_ContainerInventory_Class& instanceName,
                                                              const PropertySet& propertySet)
{
    context.Post(MI_RESULT_NOT_SUPPORTED);
}

void Container_ContainerInventory_Class_Provider::CreateInstance(Context& context, const String& nameSpace, const Container_ContainerInventory_Class& newInstance)
{
    context.Post(MI_RESULT_NOT_SUPPORTED);
}

void Container_ContainerInventory_Class_Provider::ModifyInstance(Context& context, const String& nameSpace, const Container_ContainerInventory_Class& modifiedInstance, const PropertySet& propertySet)
{
    context.Post(MI_RESULT_NOT_SUPPORTED);
}

void Container_ContainerInventory_Class_Provider::DeleteInstance(Context& context, const String& nameSpace, const Container_ContainerInventory_Class& instanceName)
{
    context.Post(MI_RESULT_NOT_SUPPORTED);
}

#ifdef _MSC_VER
#pragma endregion
#endif

MI_END_NAMESPACE
