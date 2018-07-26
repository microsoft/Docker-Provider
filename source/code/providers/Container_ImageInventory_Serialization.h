#pragma once

#include <MI.h>
#include "Container_ImageInventory_Class_Provider.h"

#include <errno.h>
#include <stdio.h>
#include <string>
#include <string.h>
#include <syslog.h>

#include "../cjson/cJSON.h"

#define IMGDIRECTORY "/var/opt/microsoft/docker-cimprov/state/ImageInventory/"

using namespace std;

MI_BEGIN_NAMESPACE

class ImageInventorySerializer
{
public:
    ///
    /// Serialize the object to file
    ///
    static void SerializeObject(Container_ImageInventory_Class& object)
    {
		try {
			openlog("ImageInventorySerializer", LOG_PID | LOG_NDELAY, LOG_LOCAL1);

			char filename[128];
			const char* id = object.InstanceID_value().Str();
			sprintf(filename, "%s%s", IMGDIRECTORY, id);

			FILE* target = fopen(filename, "w");

			if (target)
			{
				cJSON* root = cJSON_CreateObject();

				// Add all fields to JSON
				cJSON_AddStringToObject(root, "Image", object.Image_value().Str());
				cJSON_AddStringToObject(root, "Repository", object.Repository_value().Str());
				cJSON_AddStringToObject(root, "ImageTag", object.ImageTag_value().Str());
				cJSON_AddStringToObject(root, "Computer", object.Computer_value().Str());

				char* imageInventoryStr = cJSON_PrintUnformatted(root);
				fprintf(target, "%s", imageInventoryStr);
				fclose(target);
				cJSON_Delete(root);
				if (imageInventoryStr) free(imageInventoryStr);
			}
			else
			{
				syslog(LOG_ERR, "Failed to serialize %s - file could not be opened: %s", id, strerror(errno));
			}

			closelog();
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_ImageInventorySerialization - SerializeObject %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_ImageInventorySerialization - SerializeObject - Unknown exception");
		}
    }

    ///
    /// Deserialize class object
    ///
    /// \param[in] id ID of object
    ///
    static Container_ImageInventory_Class DeserializeObject(string& id)
    {
        openlog("ImageInventorySerializer", LOG_PID | LOG_NDELAY, LOG_LOCAL1);

        // New inventory entry
        Container_ImageInventory_Class instance;

        instance.InstanceID_value(id.c_str());

        char filename[128];
        sprintf(filename, "%s%s", IMGDIRECTORY, id.c_str());

		try {
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
						cJSON* objItem = cJSON_GetObjectItem(root, "Image");
						if (objItem != NULL)
						{
							instance.Image_value(objItem->valuestring);
						}
						objItem = cJSON_GetObjectItem(root, "Repository");
						if (objItem != NULL)
						{
							instance.Repository_value(objItem->valuestring);
						}
						objItem = cJSON_GetObjectItem(root, "ImageTag");
						if (objItem != NULL)
						{
							instance.ImageTag_value(objItem->valuestring);
						}
						objItem = cJSON_GetObjectItem(root, "Computer");
						if (objItem != NULL)
						{
							instance.Computer_value(objItem->valuestring);
						}
						instance.Running_value(0);
						instance.Stopped_value(0);
						instance.Failed_value(0);
						instance.Paused_value(0);
						instance.Total_value(0);
						instance.ImageSize_value("0 MB");
						instance.VirtualSize_value("0 MB");

						cJSON_Delete(root);
					}
					else
					{
						syslog(LOG_ERR, "Could not parse deleted image info %s", cJSON_GetErrorPtr());
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
			syslog(LOG_ERR, "Container_ImageInventorySerialization - DeSerializeObject %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_ImageInventorySerialization - DeSerializeObject - Unknown exception");
		}

        closelog();
        return instance;
    }
};

MI_END_NAMESPACE
