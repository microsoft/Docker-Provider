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

		// Get images info using command line
		wstring dockerimages = StrFromMultibyte(RunCommand("docker images --no-trunc"));
		// split into lines
		vector<wstring> lines;
		StrTokenize(dockerimages, lines, L"\n");

		set<wstring> allIds;

		int matched = 0;

		// Full image info (header plus one per line)
		if (lines.size() > 0)
		{
			// parse header to get column offsets
			vector<wstring>::iterator it = lines.begin();
			string hdrstr = StrToMultibyte(*it, true);
			it++;

			string::size_type repoix = hdrstr.find("REPOSITORY", 0);
			CPPUNIT_ASSERT_MESSAGE(string("Can't find 'REPOSITORY' keyword in docker output line: ").append(hdrstr), repoix != string::npos);
			string::size_type tagix = hdrstr.find("TAG", 0);
			CPPUNIT_ASSERT_MESSAGE(string("Can't find 'TAG' keyword in docker output line: ").append(hdrstr), tagix != string::npos);
			string::size_type idix = hdrstr.find("IMAGE ID", 0);
			CPPUNIT_ASSERT_MESSAGE(string("Can't find 'IMAGE ID' keyword in docker output line: ").append(hdrstr), idix != string::npos);
			string::size_type createdix = hdrstr.find("CREATED", 0);
			CPPUNIT_ASSERT_MESSAGE(string("Can't find 'CREATED' keyword in docker output line: ").append(hdrstr), createdix != string::npos);

			// loop over lines after the header
			for (; it != lines.end(); ++it)
			{
				wstring id = StrTrimR((*it).substr(idix, createdix - idix));
				bool match = false;
				for (unsigned i = 0; i < context.Size(); ++i)
				{
					// Verify the InstanceID
					if (id.compare(context[i].GetKey(L"InstanceID", CALL_LOCATION(errMsg))) == 0)
					{
						match = true;
						matched++;
						break;
					}
				}

				if (!match)
				{
					// not found. If the repo & tag are both "<none>", then this is ok since enumerate may filter these
					wstring repo = StrTrimR((*it).substr(repoix, tagix - repoix));
					CPPUNIT_ASSERT_EQUAL(wstring(L"<none>"), repo);
					wstring tag = StrTrimR((*it).substr(tagix, idix - tagix));
					CPPUNIT_ASSERT_EQUAL(wstring(L"<none>"), tag);
				}
			}
		}

		CPPUNIT_ASSERT_EQUAL(matched, context.Size());
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
			size_t rc = mbstowcs(currentId, cJSON_GetObjectItem(images[i], "InstanceID")->valuestring, (sizeof(currentId)/sizeof(currentId[0])) - 1);
			if (rc != (size_t)-1 && rc < (sizeof(currentId)/sizeof(currentId[0]))) currentId[rc] = 0;

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