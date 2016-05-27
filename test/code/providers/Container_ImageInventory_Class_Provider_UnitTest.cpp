#include <set>
#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <unistd.h>
#include <uuid/uuid.h>
#include <vector>
#include <wchar.h>

#include <scxcorelib/scxcmn.h>
#include <scxcorelib/scxprocess.h>
#include <scxcorelib/stringaid.h>
#include <testutils/scxunit.h>
#include <testutils/providertestutils.h>

#include "Container_ImageInventory_Class_Provider.h"
#include "cjson/cJSON.h"
#include "TestScriptPath.h"

using namespace std;
using namespace SCXCoreLib;

class ImageInventoryTest : public CppUnit::TestFixture
{
	CPPUNIT_TEST_SUITE(ImageInventoryTest);
	CPPUNIT_TEST(TestEnumerateInstances);
	CPPUNIT_TEST(TestEnumerateVerifyAllValues);
	CPPUNIT_TEST(TestRunContainer);
	CPPUNIT_TEST(TestRunFailedContainer);
	CPPUNIT_TEST_SUITE_END();

private:
	vector<string> containers;

	static string NewGuid()
	{
		uuid_t uuid;
		uuid_generate_random(uuid);
		char s[37];
		uuid_unparse(uuid, s);
		return s;
	}

	static string RunCommand(const char* command)
	{
		istringstream processInput;
		ostringstream processOutput;
		ostringstream processErr;

		CPPUNIT_ASSERT(!SCXProcess::Run(StrFromMultibyte(string(command)), processInput, processOutput, processErr, 0));
		CPPUNIT_ASSERT_EQUAL(processErr.str(), string());

		return processOutput.str();
	}

public:
	void setUp()
	{
		// Get some images to use
		fputc('\n', stdout);
		RunCommand("docker pull hello-world");
		RunCommand("docker pull centos");
		RunCommand("rm -f /var/opt/microsoft/docker-cimprov/state/ImageInventory/*");
	}

	void tearDown()
	{
		char command[128];

		// Remove the containers that were started by the tests
		for (unsigned i = 0; i < containers.size(); i++)
		{
			sprintf(command, "docker rm -f %s", containers[i].c_str());
			RunCommand(command);
		}

		containers.clear();
	}

protected:
	void TestEnumerateInstances()
	{
		wstring errMsg;
		TestableContext context;

		vector<wstring> m_keyNames;
		m_keyNames.push_back(L"InstanceID");

		// Remove cached state
		RunCommand("rm -f /var/opt/microsoft/docker-cimprov/state/ContainerInventory/*");

		// Enumerate provider
		StandardTestEnumerateInstances<mi::Container_ImageInventory_Class_Provider>(m_keyNames, context, CALL_LOCATION(errMsg));

		// Get images using command line
		CPPUNIT_ASSERT(!system("docker images -q --no-trunc > /tmp/docker_image_ids.txt"));

		FILE* idFile = fopen("/tmp/docker_image_ids.txt", "r");
		CPPUNIT_ASSERT(idFile);

		wchar_t id[65];
		set<wstring> allIds;

		// Full image IDs (one per line)
		while (fwscanf(idFile, L"%ls", id) != EOF)
		{
			allIds.insert(wstring(id));
		}

		fclose(idFile);
		remove("/tmp/docker_image_ids.txt");

		CPPUNIT_ASSERT_EQUAL(allIds.size(), context.Size());

		for (unsigned i = 0; i < context.Size(); ++i)
		{
			// Verify the InstanceID
			CPPUNIT_ASSERT(allIds.count(context[i].GetKey(L"InstanceID", CALL_LOCATION(errMsg))));
		}
	}

	void TestEnumerateVerifyAllValues()
	{
		wstring errMsg;
		TestableContext context;

		vector<wstring> m_keyNames;
		m_keyNames.push_back(L"InstanceID");

		// Remove cached state
		RunCommand("rm -f /var/opt/microsoft/docker-cimprov/state/ContainerInventory/*");

		// Enumerate provider
		StandardTestEnumerateInstances<mi::Container_ImageInventory_Class_Provider>(m_keyNames, context, CALL_LOCATION(errMsg));

		// Get image inventory using a script
		char command[256];
		sprintf(command, "python %sImageInventory.py > /tmp/docker_image_inventory.txt", TEST_SCRIPT_PATH);
		CPPUNIT_ASSERT(!system(command));

		FILE* imageFile = fopen("/tmp/docker_image_inventory.txt", "r");
		CPPUNIT_ASSERT(imageFile);

		char buffer[1024];
		vector<cJSON*> images;

		while (fgets(buffer, 1023, imageFile))
		{
			images.push_back(cJSON_Parse(buffer));
		}

		fclose(imageFile);
		remove("/tmp/docker_image_inventory.txt");

		// Should have same number of images
		CPPUNIT_ASSERT_EQUAL(images.size(), context.Size());

		wchar_t currentId[128];
		int imageCount = 0;

		// Verify every field of every object
		for (unsigned i = 0; i < images.size(); i++)
		{
			bool flag = false;
			int rc = mbstowcs(currentId, cJSON_GetObjectItem(images[i], "InstanceID")->valuestring, (sizeof(currentId)/sizeof(currentId[0])) - 1);
			if (rc > 0 && rc < sizeof(currentId)/sizeof(currentId[0])) currentId[rc] = 0;

			for (unsigned j = 0; !flag && j < context.Size(); j++)
			{
				if (!context[j].GetProperty(L"InstanceID", CALL_LOCATION(errMsg)).GetValue_MIString(CALL_LOCATION(errMsg)).compare(wstring(currentId)))
				{
					wchar_t temp[512];
					unsigned count = 0;

					mbstowcs(temp, cJSON_GetObjectItem(images[i], "Image")->valuestring, 511);
					CPPUNIT_ASSERT_EQUAL(wstring(temp), context[j].GetProperty(L"Image", CALL_LOCATION(errMsg)).GetValue_MIString(CALL_LOCATION(errMsg)));

					mbstowcs(temp, cJSON_GetObjectItem(images[i], "Repository")->valuestring, 511);
					CPPUNIT_ASSERT_EQUAL(wstring(temp), context[j].GetProperty(L"Repository", CALL_LOCATION(errMsg)).GetValue_MIString(CALL_LOCATION(errMsg)));

					mbstowcs(temp, cJSON_GetObjectItem(images[i], "ImageTag")->valuestring, 511);
					CPPUNIT_ASSERT_EQUAL(wstring(temp), context[j].GetProperty(L"ImageTag", CALL_LOCATION(errMsg)).GetValue_MIString(CALL_LOCATION(errMsg)));

					mbstowcs(temp, cJSON_GetObjectItem(images[i], "Computer")->valuestring, 511);
					CPPUNIT_ASSERT_EQUAL(wstring(temp), context[j].GetProperty(L"Computer", CALL_LOCATION(errMsg)).GetValue_MIString(CALL_LOCATION(errMsg)));

					mbstowcs(temp, cJSON_GetObjectItem(images[i], "ImageSize")->valuestring, 511);
					CPPUNIT_ASSERT_EQUAL(wstring(temp), context[j].GetProperty(L"ImageSize", CALL_LOCATION(errMsg)).GetValue_MIString(CALL_LOCATION(errMsg)));

					mbstowcs(temp, cJSON_GetObjectItem(images[i], "VirtualSize")->valuestring, 511);
					CPPUNIT_ASSERT_EQUAL(wstring(temp), context[j].GetProperty(L"VirtualSize", CALL_LOCATION(errMsg)).GetValue_MIString(CALL_LOCATION(errMsg)));

					count = cJSON_GetObjectItem(images[i], "Running")->valueint;
					CPPUNIT_ASSERT_EQUAL(count, context[j].GetProperty(L"Running", CALL_LOCATION(errMsg)).GetValue_MIUint32(CALL_LOCATION(errMsg)));

					count = cJSON_GetObjectItem(images[i], "Stopped")->valueint;
					CPPUNIT_ASSERT_EQUAL(count, context[j].GetProperty(L"Stopped", CALL_LOCATION(errMsg)).GetValue_MIUint32(CALL_LOCATION(errMsg)));

					count = cJSON_GetObjectItem(images[i], "Failed")->valueint;
					CPPUNIT_ASSERT_EQUAL(count, context[j].GetProperty(L"Failed", CALL_LOCATION(errMsg)).GetValue_MIUint32(CALL_LOCATION(errMsg)));

					count = cJSON_GetObjectItem(images[i], "Paused")->valueint;
					CPPUNIT_ASSERT_EQUAL(count, context[j].GetProperty(L"Paused", CALL_LOCATION(errMsg)).GetValue_MIUint32(CALL_LOCATION(errMsg)));

					count = cJSON_GetObjectItem(images[i], "Total")->valueint;
					CPPUNIT_ASSERT_EQUAL(count, context[j].GetProperty(L"Total", CALL_LOCATION(errMsg)).GetValue_MIUint32(CALL_LOCATION(errMsg)));

					flag = true;
					imageCount += 1;
				}
			}

			cJSON_Delete(images[i]);
		}

		// Ensure all objects were validated
		CPPUNIT_ASSERT_EQUAL(imageCount, context.Size());
	}

	void TestRunContainer()
	{
		wstring errMsg;
		TestableContext context;

		vector<wstring> m_keyNames;
		m_keyNames.push_back(L"InstanceID");

		// Remove cached state
		RunCommand("rm -f /var/opt/microsoft/docker-cimprov/state/ContainerInventory/*");

		char containerName[64];
		strcpy(containerName, NewGuid().c_str());
		containers.push_back(string(containerName));
		char command[128];
		sprintf(command, "docker run --name=%s hello-world", containerName);

		CPPUNIT_ASSERT(!system(command));
		sleep(5);

		bool flag = false;

		// Enumerate provider
		StandardTestEnumerateInstances<mi::Container_ImageInventory_Class_Provider>(m_keyNames, context, CALL_LOCATION(errMsg));

		for (unsigned i = 0; !flag && i < context.Size(); ++i)
		{
			if (!context[i].GetProperty(L"Image", CALL_LOCATION(errMsg)).GetValue_MIString(CALL_LOCATION(errMsg)).compare(L"hello-world"))
			{
				// Checke that the number of stopped containers is not 0
				CPPUNIT_ASSERT(context[i].GetProperty(L"Stopped", CALL_LOCATION(errMsg)).GetValue_MIUint32(CALL_LOCATION(errMsg)));
				flag = true;
			}
		}
	}

	void TestRunFailedContainer()
	{
		wstring errMsg;
		TestableContext context;

		vector<wstring> m_keyNames;
		m_keyNames.push_back(L"InstanceID");

		// Remove cached state
		RunCommand("rm -f /var/opt/microsoft/docker-cimprov/state/ContainerInventory/*");

		char containerName[64];
		strcpy(containerName, NewGuid().c_str());
		containers.push_back(string(containerName));
		char command[128];
		sprintf(command, "docker run --name=%s centos false", containerName);

		CPPUNIT_ASSERT(system(command));
		sleep(5);

		bool flag = false;

		// Enumerate provider
		StandardTestEnumerateInstances<mi::Container_ImageInventory_Class_Provider>(m_keyNames, context, CALL_LOCATION(errMsg));

		for (unsigned i = 0; !flag && i < context.Size(); ++i)
		{
			if (!context[i].GetProperty(L"Image", CALL_LOCATION(errMsg)).GetValue_MIString(CALL_LOCATION(errMsg)).compare(L"centos"))
			{
				// Check that the number of failed containers is not 0
				CPPUNIT_ASSERT(context[i].GetProperty(L"Failed", CALL_LOCATION(errMsg)).GetValue_MIUint32(CALL_LOCATION(errMsg)));
				flag = true;
			}
		}
	}
	
};

CPPUNIT_TEST_SUITE_REGISTRATION(ImageInventoryTest);