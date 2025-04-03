# -*- mode: Makefile; -*-
# Copyright (c) Microsoft Corporation

BASE_DIR := $(subst /build/linux,,$(PWD))

PF_POSIX := 1

# parameters required for the build
ENABLE_DEBUG=0
BUILD_TYPE=Release
PF=Linux
PF_MAJOR=1
PF_MINOR=0
PF_WIDTH=64
PF_DISTRO=ULINUX

ifeq ($(arch),)
	PF_ARCH=amd64
else
	PF_ARCH=$(arch)
endif

BUILD_CONFIGURATION=Linux_ULINUX_1.0_$(PF_ARCH)_64_Release

# RM - Remove a file
# RMDIR - Remove a directory
# MKPATH - Create a directory and all necessary dirs along the way
# NOOP - Command which is not executed on this platform
# pf_tp(path_list) - Transform the paths in the list to paths accepted by platform
# pf_fwrite(text,filename) - Creates/replaces a new file with 'text' as content
# pf_fappend(text,filename) - Append text to file at the end

ifdef PF_WINDOWS
	pf_tp=$(subst /,\,$(patsubst %,"%",$1))
	RM=cmd /c del /f /q
	RMDIR=cmd /c rmdir /S /Q
	MKPATH=cmd /c mkdir
	ECHO=cmd /c echo
	COPY=cmd /c copy
	COPYDIR=cmd /c robocopy
	pf_fwrite=echo $(1) > $(2)
	pf_fappend=echo $(1) >> $(2)

	NOOP=rem NOOP

endif


ifdef PF_POSIX
	pf_tp=$1
	RM=rm -f
	RMDIR=rm -rf
	MKPATH=mkdir -p
	ECHO=@echo
	COPY=cp
	COPYDIR=cp -r
	pf_fwrite=echo $(1) > $(2)
	pf_fappend=echo $(1) >> $(2)
	SOFTLINK=ln -sf
	NOOP=echo
	MV=mv
endif


ifndef ENABLE_DEBUG
$(error "ENABLE_DEBUG is not set.  Please re-run configure")
endif

# Include the version file
include $(BASE_DIR)/build/version

ifndef CONTAINER_BUILDVERSION_STATUS
$(error "version file is missing")
endif


SOURCE_DIR := $(BASE_DIR)/source

INTERMEDIATE_BASE_DIR := $(BASE_DIR)/intermediate
INTERMEDIATE_DIR := $(INTERMEDIATE_BASE_DIR)/$(BUILD_CONFIGURATION)
INTERMEDIATE_TESTFILES := $(INTERMEDIATE_DIR)/testfiles
TARGET_DIR := $(BASE_DIR)/kubernetes/linux/$(BUILD_CONFIGURATION)
PROVIDER_LIBRARY := $(INTERMEDIATE_DIR)/libcontainer.so

INSTALLER_TMPDIR := $(INTERMEDIATE_DIR)/installer_tmp


# GO Source dir for custom fluent bit plugin
GO_SOURCE_DIR := $(SOURCE_DIR)/plugins/go/src
GO_SOURCE_INPUT_DIR := $(SOURCE_DIR)/plugins/go/input

CMETRICS_VERSION = 0.6.0
AMD64_DEB_HEADERS = cmetrics_$(CMETRICS_VERSION)_amd64-headers.deb
AMD64_DEB = cmetrics_$(CMETRICS_VERSION)_amd64.deb
AMD64_URL = https://github.com/fluent/cmetrics/releases/download/v$(CMETRICS_VERSION)

ifeq ($(ENABLE_DEBUG),1)
PROV_DEBUG_FLAGS := -g
endif

# Support for installbuilder

STAGING_DIR := $(INTERMEDIATE_DIR)/staging

OUTPUT_PACKAGE_PREFIX=docker-cimprov-$(CONTAINER_BUILDVERSION_MAJOR).$(CONTAINER_BUILDVERSION_MINOR).$(CONTAINER_BUILDVERSION_PATCH)-$(CONTAINER_BUILDVERSION_BUILDNR).universal.$(PF_ARCH)


#--------------------------------------------------------------------------------
# Build targets
# TODO - fix plugintests and enable it back
# all : PROVIDER_STATUS KIT_STATUS kit fluentbitplugin rubypluginstests
all : PROVIDER_STATUS KIT_STATUS kit fluentbitinputplugin fluentbitplugin

clean :
	$(RMDIR) $(BASE_DIR)/build/cppunit_result.* $(BASE_DIR)/installer/intermediate $(BASE_DIR)/intermediate $(BASE_DIR)/target
	-find $(BASE_DIR) -name \*~ -exec rm {} \;
	make -C $(GO_SOURCE_DIR) clean

distclean : clean

# Define the target
install_cmetrics:
# For amd64 architecture
ifeq ($(PF_ARCH),amd64)
	# Download and install header files
	wget $(AMD64_URL)/$(AMD64_DEB_HEADERS)
	sudo dpkg -i $(AMD64_DEB_HEADERS)
	# Download and install binary
	wget $(AMD64_URL)/$(AMD64_DEB)
	sudo dpkg -i $(AMD64_DEB)
endif

# For arm64 architecture
ifeq ($(PF_ARCH),arm64)
	sudo apt install cmake bison flex -y
	# Clone the repository and build from source
	git clone --recursive https://github.com/calyptia/cmetrics.git
	cd cmetrics && \
	git checkout v$(CMETRICS_VERSION) && \
	git submodule sync && \
	git -c protocol.version=2 submodule update --init --force --depth=1 && \
	git submodule foreach git config --local gc.auto 0 && \
	cmake -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
	-DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc . && \
	make && \
	make install
endif

PROVIDER_STATUS:
	@echo "========================= Performing Building provider"
	@echo "clean up everything under: $(INTERMEDIATE_BASE_DIR) to avoid picking up old binaries"
	sudo $(RMDIR) $(INTERMEDIATE_BASE_DIR)

KIT_STATUS:
	@echo "========================= Performing Building provider tests"


#---------------------------------------------------------------------------------
# fluentbit go plugin build. This is required to send container logs to ODS endpoint
#
fluentbitplugin :
	@echo "========================= Building fluentbit out_oms go plugin for logs"
	$(MKPATH) $(INTERMEDIATE_DIR)
	make -C $(GO_SOURCE_DIR) fbplugin arch=$(PF_ARCH)
	$(COPY) $(GO_SOURCE_DIR)/out_oms.so $(INTERMEDIATE_DIR)

fluentbitinputplugin:
	@echo "========================= Building fluentbit input go plugin"
	$(MKPATH) $(INTERMEDIATE_DIR)

	make -C $(GO_SOURCE_INPUT_DIR)/containerinventory containerinventory arch=$(PF_ARCH)
	$(COPY) $(GO_SOURCE_INPUT_DIR)/containerinventory/containerinventory.so $(INTERMEDIATE_DIR)
	make -C $(GO_SOURCE_INPUT_DIR)/perf perf arch=$(PF_ARCH)
	$(COPY) $(GO_SOURCE_INPUT_DIR)/perf/perf.so $(INTERMEDIATE_DIR)
	make -C $(GO_SOURCE_INPUT_DIR)/disk disk arch=$(PF_ARCH)
	$(COPY) $(GO_SOURCE_INPUT_DIR)/disk/disk.so $(INTERMEDIATE_DIR)

rubypluginstests :
	@echo "========================= Installing pre-reqs for running tests"
	sudo apt-add-repository ppa:brightbox/ruby-ng -y
	sudo apt-get update
	sudo apt-get install ruby2.4 rake -y
	sudo gem install minitest
	@echo "========================= Running tests..."
	rake test

#--------------------------------------------------------------------------------
# Build the distribution kit
#
# Build the packages via installbuilder
#
# While the "formal build" only builds ULINUX, we may build something else for DEV purposes.
# Assume we ALWAYS build DPKG, but only build RPM if --enable-ulinux is speified in configure.

kit : CONTAINERLIB_FILENAME = libcontainer.so
kit : install_cmetrics fluentbitinputplugin fluentbitplugin


	@echo "========================= Performing Building RPM and DPKG packages"
	$(MKPATH) $(INSTALLER_TMPDIR)
	sudo $(RMDIR) $(STAGING_DIR)
	$(MKPATH) $(INTERMEDIATE_DIR)
	python $(BASE_DIR)/build/linux/installer/InstallBuilder/installbuilder.py \
		--BASE_DIR=$(BASE_DIR) \
		--TARGET_DIR=$(INTERMEDIATE_DIR) \
		--INTERMEDIATE_DIR=$(INSTALLER_TMPDIR) \
		--STAGING_DIR=$(STAGING_DIR) \
		--BUILD_TYPE=$(BUILD_TYPE) \
		--BUILD_CONFIGURATION=$(BUILD_CONFIGURATION) \
		--PFARCH=$(PF_ARCH) \
		--PFDISTRO=$(PF_DISTRO) \
		--PFMAJOR=$(PF_MAJOR) \
		--PFMINOR=$(PF_MINOR) \
		--VERSION=$(CONTAINER_BUILDVERSION_MAJOR).$(CONTAINER_BUILDVERSION_MINOR).$(CONTAINER_BUILDVERSION_PATCH) \
		--RELEASE=$(CONTAINER_BUILDVERSION_BUILDNR) \
		--CONTAINER_BUILD_LIBRARY=$(CONTAINERLIB_FILENAME) \
		--OUTPUTFILE=$(OUTPUT_PACKAGE_PREFIX) \
		--DATAFILE_PATH=$(BASE_DIR)/build/linux/installer/datafiles \
		base_container.data linux.data linux_rpm.data

	sudo $(RMDIR) $(STAGING_DIR)
	$(MKPATH) $(INTERMEDIATE_DIR)
	python $(BASE_DIR)/build/linux/installer/InstallBuilder/installbuilder.py \
		--BASE_DIR=$(BASE_DIR) \
		--TARGET_DIR=$(INTERMEDIATE_DIR) \
		--INTERMEDIATE_DIR=$(INSTALLER_TMPDIR) \
		--STAGING_DIR=$(STAGING_DIR) \
		--BUILD_TYPE=$(BUILD_TYPE) \
		--BUILD_CONFIGURATION=$(BUILD_CONFIGURATION) \
		--PFARCH=$(PF_ARCH) \
		--PFDISTRO=$(PF_DISTRO) \
		--PFMAJOR=$(PF_MAJOR) \
		--PFMINOR=$(PF_MINOR) \
		--VERSION=$(CONTAINER_BUILDVERSION_MAJOR).$(CONTAINER_BUILDVERSION_MINOR).$(CONTAINER_BUILDVERSION_PATCH) \
		--RELEASE=$(CONTAINER_BUILDVERSION_BUILDNR) \
		--CONTAINER_BUILD_LIBRARY=$(CONTAINERLIB_FILENAME) \
		--OUTPUTFILE=$(OUTPUT_PACKAGE_PREFIX) \
		--DATAFILE_PATH=$(BASE_DIR)/build/linux/installer/datafiles \
		base_container.data linux.data linux_dpkg.data

	# Strip the package extension from the package filename
	sed -re 's/.rpm$$|.deb$$//' $(INTERMEDIATE_DIR)/package_filename > $(INTERMEDIATE_DIR)/package_file.tmp; mv $(INTERMEDIATE_DIR)/package_file.tmp $(INTERMEDIATE_DIR)/package_filename

	# Build the tar file containing both .rpm and .deb packages
	cd $(INTERMEDIATE_DIR); tar cvf $(OUTPUT_PACKAGE_PREFIX).tar $(OUTPUT_PACKAGE_PREFIX).rpm $(OUTPUT_PACKAGE_PREFIX).deb

	bash installer/bundle/create_bundle.sh $(PF)_$(PF_DISTRO) $(INTERMEDIATE_DIR) $(OUTPUT_PACKAGE_PREFIX)
	# purge old files
	$(RMDIR) $(TARGET_DIR)
	# Copy the shell bundle to the target directory
	$(MKPATH) $(TARGET_DIR)
	cd $(INTERMEDIATE_DIR); $(COPY) `cat $(INTERMEDIATE_DIR)/package_filename`.sh $(TARGET_DIR)
