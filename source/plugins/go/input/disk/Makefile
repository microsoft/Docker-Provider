BASE_DIR := $(subst /build/linux,,$(PWD))
include $(BASE_DIR)/build/version

ifeq ($(arch),)
	PF_ARCH=amd64
else
	PF_ARCH=$(arch)
endif

ifneq ($(PF_ARCH),amd64)
	OPTIONS=CGO_ENABLED=1 CC=aarch64-linux-gnu-gcc GOOS=linux GOARCH=arm64
endif

disk:
	@echo "========================= Building disk input plugin go code  ========================="
	export BUILDVERSION=$(CONTAINER_BUILDVERSION_MAJOR).$(CONTAINER_BUILDVERSION_MINOR).$(CONTAINER_BUILDVERSION_PATCH)-$(CONTAINER_BUILDVERSION_BUILDNR)
	export BUILDDATE=$(CONTAINER_BUILDVERSION_DATE)
	@echo $(BUILDVERSION)
	@echo $(BUILD_DATE)
	@echo "========================= cleanup existing .so and .h file  ========================="
	rm -rf *.so *.h *~
	@echo "========================= go get  ========================="
	go get
	@echo "========================= go build  ========================="
	$(OPTIONS) go build -ldflags "-X 'main.revision=$(BUILDVERSION)' -X 'main.builddate=$(BUILDDATE)' -s -w" -buildmode=c-shared -o disk-test.so .

test:
	go test -cover -race -coverprofile=coverage.txt -covermode=atomic

clean:
	rm -rf *.so *.h *~
