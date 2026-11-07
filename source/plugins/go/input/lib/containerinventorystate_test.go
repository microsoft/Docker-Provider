package lib

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"strings"
	"testing"
)

var inventoryDirectory string

func TestContainerStateSafeIDs(t *testing.T) {
	t.Setenv("TESTDIR", t.TempDir())
	for _, id := range []string{"12345", strings.Repeat("a", 64), "A12b34", "a1b2-1234-5678-90ab", "runtime.id+v1_2-3", ".runtime-id", "_id", "+id", "-id", strings.Repeat("a", 255)} {
		t.Run(id, func(t *testing.T) {
			container := Container{"InstanceID": id, "State": "Running"}
			WriteContainerState(container)
			container["State"] = "Terminated"
			WriteContainerState(container)
			if got := GetDeletedContainers(nil); !reflect.DeepEqual(got, []string{id}) {
				t.Fatalf("Expected deleted state %q, got %v", id, got)
			}
			if got := GetDeletedContainers([]string{id}); len(got) != 0 {
				t.Fatalf("Active state reported as deleted: %v", got)
			}
			if got := ReadContainerState(id); !reflect.DeepEqual(got, container) {
				t.Fatalf("Expected overwritten state %v, got %v", container, got)
			}
			if _, err := os.Stat(filepath.Join(os.Getenv("TESTDIR"), id)); !os.IsNotExist(err) {
				t.Fatalf("State file was not deleted: %v", err)
			}
		})
	}
}

func TestContainerStateRejectsInvalidIDs(t *testing.T) {
	parent := t.TempDir()
	stateDir := filepath.Join(parent, "inventory")
	if err := os.Mkdir(stateDir, 0755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("TESTDIR", stateDir)
	sentinel := filepath.Join(parent, "sentinel")
	original := []byte(`{"InstanceID":"sentinel","State":"Running"}`)
	if err := os.WriteFile(sentinel, original, 0644); err != nil {
		t.Fatal(err)
	}
	invalidIDs := []interface{}{
		nil, "", 42, false, []string{"id"}, map[string]string{"id": "value"},
		".", "..", "../sentinel", "nested/../../sentinel", sentinel, "/tmp/container-state",
		`..\sentinel`, `C:\sentinel`, `C:sentinel`, `\\server\share\sentinel`,
		"nested/id", "id//suffix", "id:stream", "id\x00", "id\n", "id\r", "id\t",
		"id ", "id.", "%2e%2e%2fsentinel", "id*", "id?", "id|",
		"CON", "nul.json", "COM1", "lpt9.txt", strings.Repeat("a", 256),
	}
	for _, id := range invalidIDs {
		t.Run(fmt.Sprint(id), func(t *testing.T) {
			WriteContainerState(Container{"InstanceID": id})
			if stringID, ok := id.(string); ok {
				if got := ReadContainerState(stringID); got != nil {
					t.Fatalf("Read invalid ID %q: %v", stringID, got)
				}
			}
			got, err := os.ReadFile(sentinel)
			if err != nil || !reflect.DeepEqual(got, original) {
				t.Fatalf("Outside sentinel changed or deleted: %q, %v", got, err)
			}
			files, err := os.ReadDir(stateDir)
			if err != nil || len(files) != 0 {
				t.Fatalf("Invalid ID created inventory entries: %v, %v", files, err)
			}
		})
	}
}

func TestContainerStateTraversal(t *testing.T) {
	parent := t.TempDir()
	stateDir := filepath.Join(parent, "inventory")
	if err := os.Mkdir(stateDir, 0755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("TESTDIR", stateDir)
	sentinel := filepath.Join(parent, "sentinel")
	original := []byte(`{"InstanceID":"sentinel","State":"Running"}`)
	if err := os.WriteFile(sentinel, original, 0644); err != nil {
		t.Fatal(err)
	}
	WriteContainerState(Container{"InstanceID": "../sentinel"})
	got, err := os.ReadFile(sentinel)
	if err != nil || !reflect.DeepEqual(got, original) {
		t.Fatalf("Traversal changed the outside sentinel: %q, %v", got, err)
	}
	if got := ReadContainerState("../sentinel"); got != nil {
		t.Fatalf("Traversal read the outside sentinel: %v", got)
	}
	if _, err := os.Stat(sentinel); err != nil {
		t.Fatalf("Traversal deleted the outside sentinel: %v", err)
	}
}

func TestContainerStateRejectsSymlinksAndDirectories(t *testing.T) {
	parent := t.TempDir()
	stateDir := filepath.Join(parent, "inventory")
	if err := os.Mkdir(stateDir, 0755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("TESTDIR", stateDir)
	sentinel := filepath.Join(parent, "sentinel")
	original := []byte(`{"InstanceID":"sentinel"}`)
	if err := os.WriteFile(sentinel, original, 0644); err != nil {
		t.Fatal(err)
	}
	for _, id := range []string{"link", "dangling"} {
		target := sentinel
		if id == "dangling" {
			target = filepath.Join(parent, "absent")
		}
		if err := os.Symlink(target, filepath.Join(stateDir, id)); err != nil {
			if runtime.GOOS == "windows" {
				t.Skipf("Creating test symlinks requires Windows symlink privileges: %v", err)
			}
			t.Fatal(err)
		}
		WriteContainerState(Container{"InstanceID": id})
		if got := ReadContainerState(id); got != nil {
			t.Fatalf("Read symlink %q: %v", id, got)
		}
		if _, err := os.Lstat(filepath.Join(stateDir, id)); err != nil {
			t.Fatalf("Symlink was removed: %v", err)
		}
	}
	if err := os.Mkdir(filepath.Join(stateDir, "directory"), 0755); err != nil {
		t.Fatal(err)
	}
	WriteContainerState(Container{"InstanceID": "directory"})
	if got := ReadContainerState("directory"); got != nil {
		t.Fatalf("Read directory: %v", got)
	}
	if err := os.WriteFile(filepath.Join(stateDir, "invalid name"), original, 0644); err != nil {
		t.Fatal(err)
	}
	if got := GetDeletedContainers(nil); len(got) != 0 {
		t.Fatalf("Unsafe entries reported as deleted containers: %v", got)
	}
	got, err := os.ReadFile(sentinel)
	if err != nil || !reflect.DeepEqual(got, original) {
		t.Fatalf("Symlink target changed or deleted: %q, %v", got, err)
	}
	if _, err := os.Stat(filepath.Join(parent, "absent")); !os.IsNotExist(err) {
		t.Fatalf("Dangling symlink target was created: %v", err)
	}
}

func TestContainerStateErrorsPreserveExistingFile(t *testing.T) {
	t.Setenv("TESTDIR", t.TempDir())
	path := filepath.Join(os.Getenv("TESTDIR"), "good-id")
	original := []byte(`{"InstanceID":"good-id","State":"Running"}`)
	if err := os.WriteFile(path, original, 0644); err != nil {
		t.Fatal(err)
	}
	WriteContainerState(Container{"InstanceID": "good-id", "invalid": make(chan int)})
	got, err := os.ReadFile(path)
	if err != nil || !reflect.DeepEqual(got, original) {
		t.Fatalf("Serialization failure truncated the existing state: %q, %v", got, err)
	}
	if err := os.WriteFile(path, []byte("invalid json"), 0644); err != nil {
		t.Fatal(err)
	}
	if got := ReadContainerState("good-id"); got != nil {
		t.Fatalf("Invalid JSON returned a container: %v", got)
	}
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("Failed read deleted the state file: %v", err)
	}
}

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
