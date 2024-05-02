package lib

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

var inventoryDirectory string

func TestWriteAndReadContainerState(t *testing.T) {
	// Test case: WriteContainerState and ReadContainerState
	inventoryDirectory = os.Getenv("TESTDIR")
	err := os.Mkdir(inventoryDirectory, 0755)
	if err != nil {
		t.Fatalf("Failed to create test directory: %v", err)
	}
	containerData := Container{
		"InstanceID": "12345",
	}

	// Call WriteContainerState to write the container data to the test directory
	WriteContainerState(containerData)

	// Call ReadContainerState to read the container state for the given containerId
	readContainerData := ReadContainerState("12345")

	// Compare the original containerData with the readContainerData
	if !compareContainers(containerData, readContainerData) {
		t.Errorf("ReadContainerState did not return the expected container data.")
	}
	t.Cleanup(func() {
		err := os.RemoveAll(inventoryDirectory)
		if err != nil {
			t.Fatalf("Failed to remove test directory: %v", err)
		}
		inventoryDirectory = "/var/opt/microsoft/docker-cimprov/state/ContainerInventory/"
	})
}

func TestGetDeletedContainers(t *testing.T) {
	// Test case: GetDeletedContainers
	inventoryDirectory = os.Getenv("TESTDIR")
	err := os.Mkdir(inventoryDirectory, 0755)
	if err != nil {
		t.Fatalf("Failed to create test directory: %v", err)
	}
	// Create some test files in the test inventoryDirectory to represent existing containers
	createTestFile("testfile1", t)
	createTestFile("testfile2", t)
	createTestFile("testfile3", t)

	// Call GetDeletedContainers with a list of containerIds
	deletedContainers := GetDeletedContainers([]string{"testfile1", "testfile4", "testfile5"})

	// Verify that deletedContainers contains the expected deleted containerIds
	expectedDeletedContainers := []string{"testfile2", "testfile3"}
	if !compareStringSlices(deletedContainers, expectedDeletedContainers) {
		t.Errorf("GetDeletedContainers returned incorrect deleted containerIds.")
	}
	t.Cleanup(func() {
		err := os.RemoveAll(inventoryDirectory)
		if err != nil {
			t.Fatalf("Failed to remove test directory: %v", err)
		}
		inventoryDirectory = "/var/opt/microsoft/docker-cimprov/state/ContainerInventory/"
	})
}

func createTestFile(filename string, t *testing.T) {
	// Create a test file in the test inventoryDirectory
	inventoryDirectory = os.Getenv("TESTDIR")
	filePath := filepath.Join(inventoryDirectory, filename)
	file, err := os.Create(filePath)
	if err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}
	defer file.Close()

	// Write some dummy data to the file
	containerData := Container{"InstanceID": filename}
	containerBytes, _ := json.Marshal(containerData)
	_, err = file.Write(containerBytes)
	if err != nil {
		t.Fatalf("Failed to write data to test file: %v", err)
	}
}

func compareContainers(c1, c2 Container) bool {
	return reflect.DeepEqual(c1, c2)
}

func compareStringSlices(s1, s2 []string) bool {
	// Helper function to compare two string slices and return true if they are equal
	// (contain the same elements in the same order), otherwise return false.
	if len(s1) != len(s2) {
		return false
	}
	for i := range s1 {
		if s1[i] != s2[i] {
			return false
		}
	}
	return true
}

// setup function to be called before running any tests
func setup() {
	inventoryDirectory = "./testData" // A temporary test directory to use as inventoryDirectory
	os.Setenv("TESTDIR", inventoryDirectory)
	os.Setenv("GOUNITTEST", "true")
}

// teardown function to be called after running all tests
func teardown() {
	inventoryDirectory = "/var/opt/microsoft/docker-cimprov/state/ContainerInventory/"
}

func TestMain(m *testing.M) {
	// Call the setup function before running any tests
	setup()

	// Run all tests and get the exit code
	exitCode := m.Run()

	// Call the teardown function after running all tests
	teardown()

	// Exit with the same exit code as the tests
	os.Exit(exitCode)
}
