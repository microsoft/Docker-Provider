/* @migen@ */
#include <MI.h>
#include "Container_ImageInventory_Class_Provider.h"

#include <map>
#include <set>
#include <stdio.h>
#include <string>
#include <syslog.h>
#include <unistd.h>
#include <vector>

#include "../cjson/cJSON.h"
#include "../dockerapi/DockerRemoteApi.h"
#include "../dockerapi/DockerRestHelper.h"
#include "Container_ContainerInventory_Validation.h"
#include "Container_ImageInventory_Serialization.h"

#define NUMBYTESPERMB 1048576

using namespace std;

MI_BEGIN_NAMESPACE

class InventoryQuery
{
private:
    ///
    /// Select the tag which contains :latest, if not present, select the last tag
    ///
    /// \param[in] tags cJSON* representing an array of strings
    ///
    static string SelectTag(cJSON* tags)
    {
        string result = "";
		try {

			if ((tags != NULL) && cJSON_GetArraySize(tags))
			{
				bool flag = false;

				for (int j = cJSON_GetArraySize(tags) - 1; !flag && j > -1; j--)
				{
					// Get value of tag
					cJSON* arrItem = cJSON_GetArrayItem(tags, j);
					if (arrItem != NULL)
					{
						if (arrItem->valuestring != NULL)
						{
							result = string(arrItem->valuestring);
							// Use the tag which contains latest
							if (result.find(":latest") != string::npos)
							{
								flag = true;
							}
						}
					}
				}
			}
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_ImageInventory - SelectTag %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_ImageInventory - SelectTag - Unknown exception");
		}

        return result;
    }

    ///
    /// Seperate the repository, image, and image tag strings
    ///
    /// \param[in] instance Object representing the image
    /// \param[in] properties Raw string of form image:imagetag or repository/image:imagetag
    ///
    /// \returns false if image name <none>, true otherwise
    ///
    static bool SetImageRepositoryImageTag(Container_ImageInventory_Class& instance, string properties)
    {
        bool result = true;

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
						string name = "<none>";

						if ((unsigned)slashLocation >= properties.size())
						{
							// image:imagetag
							name = properties.substr(0, colonLocation);
							instance.Repository_value("");
						}
						else
						{
							// repository/image:imagetag
							name = properties.substr(slashLocation + 1, colonLocation - slashLocation - 1);
							instance.Repository_value(properties.substr(0, slashLocation).c_str());
						}

						result = (name.compare("<none>") != 0) && !name.empty();

						instance.Image_value(name.c_str());
						instance.ImageTag_value(properties.substr(colonLocation + 1).c_str());
						break;
					}
				}
				catch (std::exception &e)
				{
					syslog(LOG_ERR, "Container_ImageInventory - SetImageRepositoryImageTag %s", e.what());
					instance.Image_value("");
					instance.Repository_value("");
					instance.ImageTag_value("");
					result = false;
					break;
				}
				catch (...)
				{
					syslog(LOG_ERR, "Container_ImageInventory - SetImageRepositoryImageTag - Unknown exception");
					instance.Image_value("");
					instance.Repository_value("");
					instance.ImageTag_value("");
					result = false;
					break;
				}
                // If the colon was not found, the name is invalid and execution will fall through to case 0
            }
            case 0:
            {
                // Do not crash the program
                syslog(LOG_WARNING, "Container image name (%s) is improperly formed and could not be parsed in SetRepositoryImageTag", properties.c_str());

                instance.Image_value("");
                instance.Repository_value("");
                instance.ImageTag_value("");
                result = false;
                break;
            }
        }

        return result;
    }

    ///
    /// Determine the state of a container and add it to the image count
    ///
    /// \param[in] instances Collection of objects representing all images on the host
    /// \param[in] idTable Maps image IDs to indices in the vector
    /// \param[in] entry containing container information
    ///
    static void ObtainContainerState(vector<Container_ImageInventory_Class>& instances, map<string, int>& idTable, cJSON* entry)
    {
		try {
			cJSON* state = cJSON_GetObjectItem(entry, "State");

			if (state != NULL)
			{
				cJSON* objItem = cJSON_GetObjectItem(entry, "Image");
				if (objItem != NULL)
				{
					if (objItem->valuestring != NULL)
					{
						string id = string(objItem->valuestring);
						//make this check to ensure that the value at address is not null
						if (idTable[id] > 0 && idTable[id] < instances.size())
						{
							cJSON* runningItem = cJSON_GetObjectItem(state, "Running");
							if (runningItem != NULL && runningItem->valueint)
							{
								// Running container
								cJSON* pausedItem = cJSON_GetObjectItem(state, "Paused");
								if (pausedItem != NULL && pausedItem->valueint)
								{
									// Paused container
									instances[idTable[id]].Paused_value(instances[idTable[id]].Paused_value() + 1);
								}
								else 
								{
									instances[idTable[id]].Running_value(instances[idTable[id]].Running_value() + 1);
								}
							}
							else
							{
								cJSON* exitCodeItem = cJSON_GetObjectItem(state, "ExitCode");
								if (exitCodeItem != NULL && exitCodeItem->valueint)
								{
									// Container exited nonzero
									instances[idTable[id]].Failed_value(instances[idTable[id]].Failed_value() + 1);
								}
								else 
								{
									// Container exited normally
									instances[idTable[id]].Stopped_value(instances[idTable[id]].Stopped_value() + 1);
								}
							}
							instances[idTable[id]].Total_value(instances[idTable[id]].Total_value() + 1);
						}
					}
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
			syslog(LOG_ERR, "Container_ImageInventory - ObtainContainerState %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_ImageInventory - ObtainContainerState - Unknown exception");
		}
    }

    ///
    /// Count the running, paused, stopped, and failed containers associated with each image
    ///
    /// \param[in] instances Collection of objects representing all images on the host
    /// \param[in] idTable Maps image IDs to indices in the vector
    ///
    static void AggregateContainerStatus(vector<Container_ImageInventory_Class>& instances, map<string, int>& idTable)
    {
		try {
			// Request containers
			vector<string> request(1, DockerRestHelper::restDockerPs());
			vector<cJSON*> response = getResponse(request);

			// See http://docs.docker.com/reference/api/Container_remote_api_v1.21/#list-containers for example output
			if (!response.empty() && response[0])
			{
				for (int i = 0; i < cJSON_GetArraySize(response[0]); i++)
				{
					cJSON* entry = cJSON_GetArrayItem(response[0], i);

					if (entry != NULL)
					{
						cJSON* objItem = cJSON_GetObjectItem(entry, "Id");
						if (objItem != NULL)
						{
							if (objItem->valuestring != NULL)
							{
								// Inspect container
								vector<string> subRequest(1, DockerRestHelper::restDockerInspect(string(objItem->valuestring)));
								vector<cJSON*> subResponse = getResponse(subRequest);

								// See http://docs.docker.com/reference/api/Container_remote_api_v1.21/#inspect-a-container for example output
								if (!subResponse.empty() && subResponse[0])
								{
									ObtainContainerState(instances, idTable, subResponse[0]);

									// Clean up object
									cJSON_Delete(subResponse[0]);
								}
								else
								{
									syslog(LOG_WARNING, "API call in AggregateContainerStatus to inspect container %s returned null", objItem->valuestring);
								}
							}
						}
					}
					else
					{
						syslog(LOG_WARNING, "Attempt in AggregateContainerStatus to get element %d of container list returned null", i);
					}
				}

				// Clean up object
				cJSON_Delete(response[0]);
			}
			else
			{
				syslog(LOG_WARNING, "API call in AggregateContainerStatus to list containers returned null");
			}
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_ImageInventory - AggregateContainerStatus %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_ImageInventory - AggregateContainerStatus - Unknown exception");
		}
    }

public:
    ///
    /// Get information about all images on the host
    ///
    /// \returns Vector containing objects representing each image
    ///
    static vector<Container_ImageInventory_Class> QueryAll()
    {
        openlog("Container_ImageInventory", LOG_PID | LOG_NDELAY, LOG_LOCAL1);

        vector<Container_ImageInventory_Class> result;
        vector<Container_ImageInventory_Class> filteredResult;
        map<string, int> idTable;
        set<string> imageIds;

        // Get computer name
        string hostname = getDockerHostName();

		try {
			// Request images
			vector<string> request(1, DockerRestHelper::restDockerImages());
			vector<cJSON*> response = getResponse(request);

			// See http://docs.docker.com/reference/api/Container_remote_api_v1.21/#list-images for example output
			if (!response.empty() && response[0])
			{
				vector<bool> imageNameIsNotNone;

				for (int i = 0; i < cJSON_GetArraySize(response[0]); i++)
				{
					cJSON* entry = cJSON_GetArrayItem(response[0], i);

					if (entry != NULL)
					{
						// New inventory entry
						Container_ImageInventory_Class instance;
						instance.Computer_value(hostname.c_str());

						// Get ID
						cJSON* objItem = cJSON_GetObjectItem(entry, "Id");
						if (objItem != NULL)
						{
							string instanceId = string(objItem->valuestring);
							instance.InstanceID_value(instanceId.c_str());

							// Get size
							char imageSize[128];
							char virtualSize[128];
							sprintf(imageSize, "%d MB", cJSON_GetObjectItem(entry, "Size")->valueint / NUMBYTESPERMB);
							sprintf(virtualSize, "%d MB", cJSON_GetObjectItem(entry, "VirtualSize")->valueint / NUMBYTESPERMB);
							instance.ImageSize_value(imageSize);
							instance.VirtualSize_value(virtualSize);

							// Get image
							imageNameIsNotNone.push_back(SetImageRepositoryImageTag(instance, SelectTag(cJSON_GetObjectItem(entry, "RepoTags"))));

							// Default container states
							instance.Running_value(0);
							instance.Paused_value(0);
							instance.Stopped_value(0);
							instance.Failed_value(0);
							instance.Total_value(0);

							// Map the image ID to the vector index
							idTable[instanceId] = result.size();
							result.push_back(instance);

							// Store all image IDs in set for deleted image check
							imageIds.insert(instanceId);
						}
					}
					else
					{
						syslog(LOG_WARNING, "Attempt in QueryAll to get element %d of image list returned null", i);
					}
				}

				// Clean up object
				cJSON_Delete(response[0]);

				// Get container status
				AggregateContainerStatus(result, idTable);

				// Remove intermediary images
				for (unsigned i = 0; i < result.size() && i < imageNameIsNotNone.size(); i++)
				{
					if (imageNameIsNotNone[i] || result[i].Total_value())
					{
						filteredResult.push_back(result[i]);

						// Serialize object for deleted image check
						ImageInventorySerializer::SerializeObject(result[i]);
					}
				}

				// Find IDs of deleted images
				ContainerInventoryValidation cv(true);
				set<string> deleted = cv.GetDeletedContainers(imageIds);

				for (set<string>::iterator i = deleted.begin(); i != deleted.end(); ++i)
				{
					// Putting string(*i) directly in the function call will cause compilation error
					string id = string(*i);
					Container_ImageInventory_Class instance = ImageInventorySerializer::DeserializeObject(id);
					filteredResult.push_back(instance);
				}
			}
			else
			{
				syslog(LOG_WARNING, "API call in QueryAll to list images returned null");
			}
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_ImageInventory - QueryAll %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_ImageInventory - QueryAll - Unknown exception");
		}

        closelog();
        return filteredResult;
    }
};

#ifdef _MSC_VER
#pragma region
#endif

Container_ImageInventory_Class_Provider::Container_ImageInventory_Class_Provider(Module* module) : m_Module(module){}

Container_ImageInventory_Class_Provider::~Container_ImageInventory_Class_Provider(){}

void Container_ImageInventory_Class_Provider::Load(Context& context)
{
    context.Post(MI_RESULT_OK);
}

void Container_ImageInventory_Class_Provider::Unload(Context& context)
{
    context.Post(MI_RESULT_OK);
}

void Container_ImageInventory_Class_Provider::EnumerateInstances(Context& context, const String& nameSpace, const PropertySet& propertySet, bool keysOnly, const MI_Filter* filter)
{
    vector<Container_ImageInventory_Class> queryResult = InventoryQuery::QueryAll();

    for (unsigned i = 0; i < queryResult.size(); i++)
    {
        context.Post(queryResult[i]);
    }

    context.Post(MI_RESULT_OK);
}

void Container_ImageInventory_Class_Provider::GetInstance(Context& context, const String& nameSpace, const Container_ImageInventory_Class& instanceName, const PropertySet& propertySet)
{
    context.Post(MI_RESULT_OK);
}

void Container_ImageInventory_Class_Provider::CreateInstance(Context& context, const String& nameSpace, const Container_ImageInventory_Class& newInstance)
{
    context.Post(MI_RESULT_OK);
}

void Container_ImageInventory_Class_Provider::ModifyInstance(Context& context, const String& nameSpace, const Container_ImageInventory_Class& modifiedInstance, const PropertySet& propertySet)
{
    context.Post(MI_RESULT_OK);
}

void Container_ImageInventory_Class_Provider::DeleteInstance(Context& context, const String& nameSpace, const Container_ImageInventory_Class& instanceName)
{
    context.Post(MI_RESULT_OK);
}

#ifdef _MSC_VER
#pragma endregion
#endif

MI_END_NAMESPACE
