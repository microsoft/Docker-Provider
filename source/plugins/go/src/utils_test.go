package main

import (
	"errors"
	"testing"
)

func Test_isValidUrl(t *testing.T) {
	type test_struct struct {
		isValid bool
		url     string
	}

	tests := []test_struct{
		{true, "https://www.microsoft.com"},
		{true, "http://abc.xyz"},
		{true, "https://www.microsoft.com/tests"},
		{false, "()"},
		{false, "https//www.microsoft.com"},
		{false, "https:/www.microsoft.com"},
		{false, "https:/www.microsoft.com*"},
		{false, ""},
	}

	for _, tt := range tests {
		t.Run(tt.url, func(t *testing.T) {
			got := isValidUrl(tt.url)
			if got != tt.isValid {
				t.Errorf("isValidUrl(%s) = %t, want %t", tt.url, got, tt.isValid)
			}
		})
	}
}

func Test_ReadFileContents(t *testing.T) {
	type mock_struct struct {
		expectedFilePath string
		fileContents     []byte
		err              error
	}
	type test_struct struct {
		testname       string
		calledFilePath string
		subcall_spec   mock_struct
		output         string
		err            bool
	}

	tests := []test_struct{
		{"normal", "foobar.txt", mock_struct{"foobar.txt", []byte("asdf"), nil}, "asdf", false},
		{"extra whitespace", "foobar.txt ", mock_struct{"foobar.txt", []byte("asdf   \t"), nil}, "asdf", false},
		{"empty filename", "", mock_struct{"", []byte(""), nil}, "", true},
		{"file doesn't exist", "asdf.txt", mock_struct{"asdf", []byte(""), errors.New("this error doesn't matter much")}, "", true},
	}

	for _, tt := range tests {
		t.Run(string(tt.testname), func(t *testing.T) {

			readfileFunc := func(filename string) ([]byte, error) {
				if filename == tt.subcall_spec.expectedFilePath {
					return tt.subcall_spec.fileContents, nil
				}
				return []byte(""), errors.New("file not found")
			}

			got, err := ReadFileContentsImpl(tt.calledFilePath, readfileFunc)

			if got != tt.output || !(tt.err == (err != nil)) {
				t.Errorf("ReadFileContents(%v) = (%v, %v), want (%v, %v)", tt.calledFilePath, got, err, tt.output, tt.err)
				if got != tt.output {
					t.Errorf("output strings are not equal")
				}
				if tt.err == (err != nil) {
					t.Errorf("errors are not equal")
				}
			}
		})
	}
}
