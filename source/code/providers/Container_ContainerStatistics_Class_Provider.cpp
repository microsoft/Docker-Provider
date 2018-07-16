/* @migen@ */
#include <MI.h>
#include "Container_ContainerStatistics_Class_Provider.h"

#include <map>
#include <stdlib.h>
#include <string>
#include <string.h>
#include <syslog.h>
#include <unistd.h>
#include <vector>

#include "../dockerapi/DockerRemoteApi.h"
#include "../dockerapi/DockerRestHelper.h"

#define NUMBYTESPERMB 1048576

using namespace std;

MI_BEGIN_NAMESPACE

class StatsQuery
{
private:
    ///
    /// Get network send/receive if available
    ///
    /// \param[in] instance The instance to set data on
    /// \param[in] stats JSON of stats returned by Docker
    ///
    static void TrySetContainerNetworkData(Container_ContainerStatistics_Class& instance, cJSON* stats)
    {
		try {
			int totalRx = 0;
			int totalTx = 0;

			if (stats)
			{
				cJSON* network = cJSON_GetObjectItem(stats, "networks");

				if (network)
				{
					// Docker 1.9+
					network = network->child;

					// Sum the number of bytes from each NIC if there is more than one
					while (network)
					{
						totalRx += cJSON_GetObjectItem(network, "rx_bytes")->valueint;
						totalTx += cJSON_GetObjectItem(network, "tx_bytes")->valueint;

						network = network->next;
					}
				}
				else
				{
					// Docker 1.8.x
					network = cJSON_GetObjectItem(stats, "network");
					if (network)
					{
						totalRx = cJSON_GetObjectItem(network, "rx_bytes")->valueint;
						totalTx = cJSON_GetObjectItem(network, "tx_bytes")->valueint;
					}
				}
			}
			else
			{
				syslog(LOG_WARNING, "Null stats JSON was passed to TrySetContainerNetworkData");
			}

			instance.NetRXBytes_value(totalRx);
			instance.NetTXBytes_value(totalTx);
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_ContainerStatistics %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_ContainerStatistics Unknown exception");
		}
    }

    ///
    /// Get memory usage if available
    ///
    /// \param[in] instance The instance to set data on
    /// \param[in] stats JSON of stats returned by Docker
    ///
    static void TrySetContainerMemoryData(Container_ContainerStatistics_Class& instance, cJSON* stats)
    {
		try {
			if (stats)
			{
				cJSON* memory_stats = cJSON_GetObjectItem(stats, "memory_stats");
				instance.MemUsedMB_value((unsigned long long)cJSON_GetObjectItem(memory_stats, "usage")->valuedouble / (unsigned long long)NUMBYTESPERMB);
			}
			else
			{
				syslog(LOG_WARNING, "Null stats JSON was passed to TrySetContainerMemoryData");
			}
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_ContainerStatistics %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_ContainerStatistics Unknown exception");
		}
    }

    ///
    /// Get disk read/write if available
    ///
    /// \param[in] instance The instance to set data on
    /// \param[in] stats JSON of stats returned by Docker
    ///
    static void TrySetContainerDiskData(Container_ContainerStatistics_Class& instance, cJSON* stats)
    {
		try {
			instance.DiskBytesRead_value(0);
			instance.DiskBytesWritten_value(0);

			if (stats)
			{
				cJSON* blkio_stats = cJSON_GetObjectItem(stats, "blkio_stats");

				if (blkio_stats)
				{
					cJSON* values = cJSON_GetObjectItem(blkio_stats, "io_service_bytes_recursive");

					bool readFlag = false;
					bool writeFlag = false;

					for (int i = 0; values && !(readFlag && writeFlag) && i < cJSON_GetArraySize(values); i++)
					{
						cJSON* entry = cJSON_GetArrayItem(values, i);

						if (entry)
						{
							cJSON* op = cJSON_GetObjectItem(entry, "op");
							cJSON* rawValue = cJSON_GetObjectItem(entry, "value");

							if (op && rawValue)
							{
								if (!strcmp(op->valuestring, "Read"))
								{
									instance.DiskBytesRead_value(rawValue->valueint / NUMBYTESPERMB);
									readFlag = true;
								}
								else if (!strcmp(op->valuestring, "Write"))
								{
									instance.DiskBytesWritten_value(rawValue->valueint / NUMBYTESPERMB);
									writeFlag = true;
								}
							}
						}
					}
				}
			}
			else
			{
				syslog(LOG_WARNING, "Null stats JSON was passed to TrySetContainerDiskData");
			}
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_ContainerStatistics %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_ContainerStatistics Unknown exception");
		}
    }

    ///
    /// Get CPU metrics if available
    ///
    /// \param[in] stats JSON of stats returned by Docker
    ///
    static map<string, unsigned long long> PreliminarySetContainerCpuData(cJSON* stats)
    {
		try {
			map<string, unsigned long long> result;

			result["container"] = 0;
			result["system"] = 0;

			if (stats)
			{
				cJSON* cpu_stats = cJSON_GetObjectItem(stats, "cpu_stats");

				if (cpu_stats)
				{
					cJSON* cpu_usage = cJSON_GetObjectItem(cpu_stats, "cpu_usage");

					if (cpu_usage)
					{
						result["container"] = (unsigned long long)cJSON_GetObjectItem(cpu_usage, "total_usage")->valuedouble;
						result["system"] = (unsigned long long)cJSON_GetObjectItem(cpu_stats, "system_cpu_usage")->valuedouble;
					}
				}
			}
			else
			{
				syslog(LOG_WARNING, "Null stats JSON was passed to PreliminarySetContainerCpuData");
			}

			return result;
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_ContainerStatistics %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_ContainerStatistics Unknown exception");
		}
    }

    ///
    /// Get CPU metrics if available
    ///
    /// \param[in] instance The instance to set data on
    /// \param[in] stats JSON of stats returned by Docker
    ///
    static void TrySetContainerCpuData(Container_ContainerStatistics_Class& instance, cJSON* stats, map<string, unsigned long long> previousStats)
    {
		try {
			instance.CPUTotal_value(0);
			instance.CPUTotalPct_value(0);

			if (stats)
			{
				cJSON* cpu_stats = cJSON_GetObjectItem(stats, "cpu_stats");

				if (cpu_stats)
				{
					cJSON* cpu_usage = cJSON_GetObjectItem(cpu_stats, "cpu_usage");

					if (cpu_usage)
					{
						unsigned long long containerUsage = (unsigned long long)cJSON_GetObjectItem(cpu_usage, "total_usage")->valuedouble;
						unsigned long long systemTotalUsage = (unsigned long long)cJSON_GetObjectItem(cpu_stats, "system_cpu_usage")->valuedouble;

						instance.CPUTotal_value((unsigned long)(containerUsage / (unsigned long long)1000000000));

						if (systemTotalUsage - previousStats["system"])
						{
							instance.CPUTotalPct_value((unsigned short)((containerUsage - previousStats["container"]) * 100 / (systemTotalUsage - previousStats["system"])));
						}
					}
				}
			}
		}
		catch (std::exception &e)
		{
			syslog(LOG_ERR, "Container_ContainerStatistics %s", e.what());
		}
		catch (...)
		{
			syslog(LOG_ERR, "Container_ContainerStatistics Unknown exception");
		}
    }

public:
    ///
    /// Get perf information about all running containers on the host
    ///
    /// \returns Vector containing objects representing each container
    ///
	static vector<Container_ContainerStatistics_Class> QueryAll()
	{
		try {
			openlog("Container_ContainerStatistics", LOG_PID | LOG_NDELAY, LOG_LOCAL1);

			vector<Container_ContainerStatistics_Class> result;

			// Request running containers
			vector<string> request(1, DockerRestHelper::restDockerPsRunning());
			vector<cJSON*> response = getResponse(request);

			// See http://docs.docker.com/engine/reference/api/docker_remote_api_v1.21/#list-containers for example output
			if (!response.empty() && response[0])
			{
				vector<map<string, unsigned long long> > previousStatsList;

				for (int i = 0; i < cJSON_GetArraySize(response[0]); i++)
				{
					cJSON* entry = cJSON_GetArrayItem(response[0], i);

					if (entry)
					{
						// New perf entry
						Container_ContainerStatistics_Class instance;

						// Set container ID
						char* id = cJSON_GetObjectItem(entry, "Id")->valuestring;
						instance.InstanceID_value(id);

						// Set container name
						cJSON* names = cJSON_GetObjectItem(entry, "Names");

						if (cJSON_GetArraySize(names))
						{
							instance.ElementName_value(cJSON_GetArrayItem(names, 0)->valuestring + 1);
						}
						else
						{
							syslog(LOG_WARNING, "Attempt in QueryAll to get name of container %s failed", id);
						}

						// Request container stats
						vector<string> subRequest(1, DockerRestHelper::restDockerStats(string(id)));
						vector<cJSON*> subResponse = getResponse(subRequest);

						// See http://docs.docker.com/engine/reference/api/docker_remote_api_v1.21/#get-container-stats-based-on-resource-usage for example output
						if (!subResponse.empty() && subResponse[0])
						{
							TrySetContainerNetworkData(instance, subResponse[0]);
							TrySetContainerMemoryData(instance, subResponse[0]);
							TrySetContainerDiskData(instance, subResponse[0]);
							previousStatsList.push_back(PreliminarySetContainerCpuData(subResponse[0]));

							// Clean up object
							cJSON_Delete(subResponse[0]);
						}

						result.push_back(instance);
					}
				}

				// Wait 1 second and query CPU time again to get % CPU usage
				sleep(1);

				for (unsigned i = 0; i < result.size(); i++)
				{
					// Request container stats
					vector<string> subRequest(1, DockerRestHelper::restDockerStats(string(result[i].InstanceID_value().Str())));
					vector<cJSON*> subResponse = getResponse(subRequest);

					// See http://docs.docker.com/engine/reference/api/docker_remote_api_v1.21/#get-container-stats-based-on-resource-usage for example output
					if (!subResponse.empty() && subResponse[0])
					{
						TrySetContainerCpuData(result[i], subResponse[0], previousStatsList[i]);

						// Set container name in 'InstanceName' field of Perf data.
						result[i].InstanceID_value(result[i].ElementName_value());

						// Clean up object
						cJSON_Delete(subResponse[0]);
					}
				}

				// Clean up object
				cJSON_Delete(response[0]);
			}

			closelog();
			return result;
		}
	}
	catch (std::exception &e)
	{
		syslog(LOG_ERR, "Container_ContainerStatistics %s", e.what());
	}
	catch (...)
	{
		syslog(LOG_ERR, "Container_ContainerStatistics Unknown exception");
	}
};

#ifdef _MSC_VER
#pragma region
#endif

Container_ContainerStatistics_Class_Provider::Container_ContainerStatistics_Class_Provider(Module* module) : m_Module(module){}

Container_ContainerStatistics_Class_Provider::~Container_ContainerStatistics_Class_Provider(){}

void Container_ContainerStatistics_Class_Provider::Load(Context& context)
{
    context.Post(MI_RESULT_OK);
}

void Container_ContainerStatistics_Class_Provider::Unload(Context& context)
{
    context.Post(MI_RESULT_OK);
}

void Container_ContainerStatistics_Class_Provider::EnumerateInstances(Context& context, const String& nameSpace, const PropertySet& propertySet, bool keysOnly, const MI_Filter* filter)
{
	try {
		string modeStr;
		if(getenv("MODE") != NULL)
		{
			modeStr = string(getenv("MODE"));
		}
		//Dont run only for container insights     
		if(modeStr.find("COIN") == string::npos)
		{
			vector<Container_ContainerStatistics_Class> queryResult = StatsQuery::QueryAll();
			for (unsigned i = 0; i < queryResult.size(); i++)
			{
				context.Post(queryResult[i]);
			}
		}
		context.Post(MI_RESULT_OK);
	}
	catch (std::exception &e) {
		syslog(LOG_ERR, "Container_ContainerStatistics %s", e.what());
		context.Post(MI_RESULT_FAILED);
	}
	catch (...) {
		syslog(LOG_ERR, "Container_ContainerStatistics Unknown exception");
		context.Post(MI_RESULT_FAILED);
	}
}

void Container_ContainerStatistics_Class_Provider::GetInstance(Context& context, const String& nameSpace, const Container_ContainerStatistics_Class& instanceName, const PropertySet& propertySet)
{
    context.Post(MI_RESULT_NOT_SUPPORTED);
}

void Container_ContainerStatistics_Class_Provider::CreateInstance(Context& context, const String& nameSpace, const Container_ContainerStatistics_Class& newInstance)
{
    context.Post(MI_RESULT_NOT_SUPPORTED);
}

void Container_ContainerStatistics_Class_Provider::ModifyInstance(Context& context, const String& nameSpace, const Container_ContainerStatistics_Class& modifiedInstance, const PropertySet& propertySet)
{
    context.Post(MI_RESULT_NOT_SUPPORTED);
}

void Container_ContainerStatistics_Class_Provider::DeleteInstance(Context& context, const String& nameSpace, const Container_ContainerStatistics_Class& instanceName)
{
    context.Post(MI_RESULT_NOT_SUPPORTED);
}

#ifdef _MSC_VER
#pragma endregion
#endif

MI_END_NAMESPACE
