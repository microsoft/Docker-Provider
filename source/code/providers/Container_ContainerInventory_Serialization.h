#pragma once

#include <MI.h>
#include "Container_ContainerInventory_Class_Provider.h"

#include <errno.h>
#include <stdio.h>
#include <string>
#include <string.h>
#include <syslog.h>
#include <stdlib.h>

#include "../cjson/cJSON.h"

#define DIRECTORY "/var/opt/microsoft/docker-cimprov/state/ContainerInventory/"

using namespace std;

MI_BEGIN_NAMESPACE

class ContainerInventorySerializer
{
public:
    ///
    /// Serialize the object to file
    ///
    static void SerializeObject(Container_ContainerInventory_Class& object)
    {
        openlog("ContainerInventorySerializer", LOG_PID | LOG_NDELAY, LOG_LOCAL1);

		try {
			char filename[128];
			const char* id = object.InstanceID_value().Str();
			sprintf(filename, "%s%s", DIRECTORY, id);

			FILE* target = fopen(filename, "w");

			if (target)
			{
				cJSON* root = cJSON_CreateObject();

				// Add all fields to JSON
				cJSON_AddStringToObject(root, "ElementName", object.ElementName_value().Str());
				cJSON_AddStringToObject(root, "CreatedTime", object.CreatedTime_value().Str());
				cJSON_AddStringToObject(root, "State", object.State_value().Str());
				cJSON_AddNumberToObject(root, "ExitCode", object.ExitCode_value());
				cJSON_AddStringToObject(root, "StartedTime", object.StartedTime_value().Str());
				cJSON_AddStringToObject(root, "FinishedTime", object.FinishedTime_value().Str());
				cJSON_AddStringToObject(root, "ImageId", object.ImageId_value().Str());
				cJSON_AddStringToObject(root, "Image", object.Image_value().Str());
				cJSON_AddStringToObject(root, "Repository", object.Repository_value().Str());
				cJSON_AddStringToObject(root, "ImageTag", object.ImageTag_value().Str());
				cJSON_AddStringToObject(root, "ComposeGroup", object.ComposeGroup_value().Str());
				cJSON_AddStringToObject(root, "ContainerHostname", object.ContainerHostname_value().Str());
				cJSON_AddStringToObject(root, "Computer", object.Computer_value().Str());
				cJSON_AddStringToObject(root, "Command", object.Command_value().Str());
				cJSON_AddStringToObject(root, "EnvironmentVar", object.EnvironmentVar_value().Str());
				cJSON_AddStringToObject(root, "Ports", object.Ports_value().Str());
				cJSON_AddStringToObject(root, "Links", object.Links_value().Str());

				char* containerInventoryStr = cJSON_PrintUnformatted(root);
				fprintf(target, "%s", containerInventoryStr);
				fclose(target);
				cJSON_Delete(root);
				if (containerInventoryStr) free(containerInventoryStr);
			}
			else
			{
				syslog(LOG_ERR, "Failed to serialize %s - file could not be opened: %s", id, strerror(errno));
			}
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_ContainerInventory-Serialization %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_ContainerInventory-Serialization Unknown exception");
		}
        closelog();
    }

    ///
    /// Deserialize class object
    ///
    /// \param[in] id ID of object
    ///
    static Container_ContainerInventory_Class DeserializeObject(string& id)
    {
        openlog("ContainerInventorySerializer", LOG_PID | LOG_NDELAY, LOG_LOCAL1);

        // New inventory entry
        Container_ContainerInventory_Class instance;

        instance.InstanceID_value(id.c_str());

		try {
			char filename[128];
			sprintf(filename, "%s%s", DIRECTORY, id.c_str());

			FILE* target = fopen(filename, "r");

			if (target)
			{
				//Go to EOF
				fseek(target, 0, SEEK_END);
				//Get file size
				long fileSize = ftell(target);
				//Rewind to beginning
				rewind(target);
				//Get a buffer for the size of the file being read
				char* buffer = (char*)malloc(fileSize + 1);

				if (fgets(buffer, fileSize + 1, target))
				{
					cJSON* root = cJSON_Parse(buffer);
					if (root != NULL)
					{
						// Get all fields from JSON
						instance.ElementName_value(cJSON_GetObjectItem(root, "ElementName")->valuestring);
						instance.CreatedTime_value(cJSON_GetObjectItem(root, "CreatedTime")->valuestring);
						instance.State_value(cJSON_GetObjectItem(root, "State")->valuestring);
						instance.ExitCode_value(cJSON_GetObjectItem(root, "ExitCode")->valueint);
						instance.StartedTime_value(cJSON_GetObjectItem(root, "StartedTime")->valuestring);
						instance.FinishedTime_value(cJSON_GetObjectItem(root, "FinishedTime")->valuestring);
						instance.ImageId_value(cJSON_GetObjectItem(root, "ImageId")->valuestring);
						instance.Image_value(cJSON_GetObjectItem(root, "Image")->valuestring);
						instance.Repository_value(cJSON_GetObjectItem(root, "Repository")->valuestring);
						instance.ImageTag_value(cJSON_GetObjectItem(root, "ImageTag")->valuestring);
						instance.ComposeGroup_value(cJSON_GetObjectItem(root, "ComposeGroup")->valuestring);
						instance.ContainerHostname_value(cJSON_GetObjectItem(root, "ContainerHostname")->valuestring);
						instance.Computer_value(cJSON_GetObjectItem(root, "Computer")->valuestring);
						instance.Command_value(cJSON_GetObjectItem(root, "Command")->valuestring);
						instance.EnvironmentVar_value(cJSON_GetObjectItem(root, "EnvironmentVar")->valuestring);
						instance.Ports_value(cJSON_GetObjectItem(root, "Ports")->valuestring);
						instance.Links_value(cJSON_GetObjectItem(root, "Links")->valuestring);

						cJSON_Delete(root);
					}
					else
					{
						syslog(LOG_ERR, "Could not parse deleted container info %s", cJSON_GetErrorPtr());
					}
				}
				else
				{
					syslog(LOG_ERR, "Failed to deserialize %s - file could not be read: %s", id.c_str(), strerror(errno));
				}

				fclose(target);

				if (buffer)
				{
					free(buffer);
					buffer = NULL;
				}

				if (remove(filename))
				{
					syslog(LOG_ERR, "Failed to remove %s after deserialization: %s", id.c_str(), strerror(errno));
				}
			}
			else
			{
				syslog(LOG_ERR, "Failed to deserialize %s - file could not be opened: %s", id.c_str(), strerror(errno));
			}
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_ContainerInventory-Deserialization %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_ContainerInventory-Deserialization Unknown exception");
		}
        closelog();
        return instance;
    }
};

MI_END_NAMESPACE
