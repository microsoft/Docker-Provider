package querylogs_test

import (
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

func TestQuerylogs(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, "Querylogs Suite")
}
