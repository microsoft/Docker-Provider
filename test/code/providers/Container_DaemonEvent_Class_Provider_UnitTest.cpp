#include <set>
#include <sstream>
#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <time.h>
#include <unistd.h>
#include <uuid/uuid.h>
#include <vector>
#include <wchar.h>

#include <scxcorelib/scxcmn.h>
#include <scxcorelib/scxprocess.h>
#include <scxcorelib/stringaid.h>
#include <testutils/scxunit.h>
#include <testutils/providertestutils.h>

#include "Container_DaemonEvent_Class_Provider.h"
#include "cjson/cJSON.h"

#define LASTQUERYTIMEFILE "/var/opt/microsoft/docker-cimprov/state/LastEventQueryTime.txt"
#define TEST_LASTQUERYTIMEFILE "./LastEventQueryTime.txt"

using namespace std;
using namespace SCXCoreLib;

class DaemonEventTest : public CppUnit::TestFixture
{
    CPPUNIT_TEST_SUITE(DaemonEventTest);
    CPPUNIT_TEST(TestEnumerateVerifyAllValues);
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
    void TestEnumerateVerifyAllValues()
    {
        wstring errMsg;
        TestableContext context;

        istringstream processInput;
        ostringstream processOutput;
        ostringstream processErr;

        vector<wstring> m_keyNames;
        m_keyNames.push_back(L"InstanceID");

        // Read the time from disk
        FILE* file = fopen(TEST_LASTQUERYTIMEFILE, "r");
        // initialize previous time to now - 60 seconds
        int fileTime = time(NULL) - 60;

        if (file)
        {
            fscanf(file, "%d", &fileTime);
        }
        else
        {
            file = fopen(TEST_LASTQUERYTIMEFILE, "w");
            CPPUNIT_ASSERT(file);
            fprintf(file, "%d", fileTime);
        }

        fclose(file);

        // Run a container to ensure that there is at lease one result
        string containerName = NewGuid();
        containers.push_back(containerName);
        char command[128];
        sprintf(command, "docker run --name=%s hello-world", containerName.c_str());
        RunCommand(command);

        // Enumerate provider
        StandardTestEnumerateInstances<mi::Container_DaemonEvent_Class_Provider>(m_keyNames, context, CALL_LOCATION(errMsg));

        wstring allowedCommandsList[] = { L"attach", L"commit", L"copy", L"create", L"destroy", L"die", L"exec_create", L"exec_start", L"export", L"kill", L"oom", L"pause", L"rename", L"resize", L"restart", L"start", L"stop", L"top", L"unpause", L"delete", L"import", L"pull", L"push", L"tag", L"untag" };
        set<wstring> allowedCommands(allowedCommandsList, allowedCommandsList + 25);

        // Check validity of every field of every object
        for (unsigned i = 0; i < context.Size(); i++)
        {
            // This field is a GUID and the value does not need verification
            CPPUNIT_ASSERT(context[i].GetProperty(L"InstanceID", CALL_LOCATION(errMsg)).GetValue_MIString(CALL_LOCATION(errMsg)).length());

            // These fields cannot be validated directly against Docker because events cannot be uniquely identified
            wstring temp = context[i].GetProperty(L"TimeOfCommand", CALL_LOCATION(errMsg)).GetValue_MIString(CALL_LOCATION(errMsg));
            int t = -1;
            swscanf(temp.c_str(), L"%d", &t);
            CPPUNIT_ASSERT(t >= fileTime);

            CPPUNIT_ASSERT(allowedCommands.count(context[i].GetProperty(L"Command", CALL_LOCATION(errMsg)).GetValue_MIString(CALL_LOCATION(errMsg))));
            CPPUNIT_ASSERT(context[i].GetProperty(L"ElementName", CALL_LOCATION(errMsg)).GetValue_MIString(CALL_LOCATION(errMsg)).length());
        }
    }
};

CPPUNIT_TEST_SUITE_REGISTRATION(DaemonEventTest);
