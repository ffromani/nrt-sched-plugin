# Copyright 2020 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ARCHS = amd64 arm64
COMMONENVVAR=GOOS=$(shell uname -s | tr A-Z a-z)
BUILDENVVAR=CGO_ENABLED=0

LOCAL_REGISTRY=localhost:5000/scheduler-plugins
LOCAL_IMAGE=kube-scheduler:latest
LOCAL_CONTROLLER_IMAGE=controller:latest

# RELEASE_REGISTRY is the container registry to push
# into. The default is to push to the staging
# registry, not production(k8s.gcr.io).
RELEASE_REGISTRY?=gcr.io/k8s-staging-scheduler-plugins
RELEASE_VERSION?=v$(shell date +%Y%m%d)-$(shell git describe --tags --match "v*")
RELEASE_IMAGE:=kube-scheduler:$(RELEASE_VERSION)
RELEASE_CONTROLLER_IMAGE:=controller:$(RELEASE_VERSION)

# VERSION is the scheduler's version
#
# The RELEASE_VERSION variable can have one of two formats:
# v20201009-v0.18.800-46-g939c1c0 - automated build for a commit(not a tag) and also a local build
# v20200521-v0.18.800             - automated build for a tag
VERSION=$(shell echo $(RELEASE_VERSION) | awk -F - '{print $$2}')

.PHONY: all
all: build

.PHONY: build
build: build-noderesourcetopology-plugin

.PHONY: build.amd64
build.amd64: build-noderesourcetopology-plugin.amd64

.PHONY: build-noderesourcetopology-plugin
build-noderesourcetopology-plugin: autogen
	$(COMMONENVVAR) $(BUILDENVVAR) go build -ldflags '-X k8s.io/component-base/version.gitVersion=$(VERSION) -w' -o bin/noderesourcetopology-plugin cmd/noderesourcetopology-plugin/main.go

.PHONY: build-noderesourcetopology-plugin.amd64
build-noderesourcetopology-plugin.amd64: autogen
	$(COMMONENVVAR) $(BUILDENVVAR) GOARCH=amd64 go build -ldflags '-X k8s.io/component-base/version.gitVersion=$(VERSION) -w' -o bin/noderesourcetopology-plugin cmd/noderesourcetopology-plugin/main.go

.PHONY: local-noderesourcetopology-image
local-noderesourcetopology-image: clean
	docker build -f ./build/noderesourcetopology-plugin/Dockerfile --build-arg ARCH="amd64" --build-arg RELEASE_VERSION="$(RELEASE_VERSION)" -t $(LOCAL_REGISTRY)/$(LOCAL_IMAGE) .

.PHONY: update-vendor
update-vendor:
	hack/update-vendor.sh

.PHONY: unit-test
unit-test: autogen
	hack/unit-test.sh

.PHONY: unit-test-quick
unit-test-quick:
	hack/unit-test-quick.sh

.PHONY: install-etcd
install-etcd:
	hack/install-etcd.sh

.PHONY: autogen
autogen: update-vendor
	hack/update-generated-openapi.sh

.PHONY: integration-test
integration-test: install-etcd autogen
	hack/integration-test.sh

.PHONY: verify-gofmt
verify-gofmt:
	hack/verify-gofmt.sh

.PHONY: verify-crdgen
verify-crdgen: autogen
	hack/verify-crdgen.sh

.PHONY: clean
clean:
	rm -rf ./bin
