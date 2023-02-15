# Other contants
NAMESPACE=keycloak
PROJECT=keycloak-realm-operator
PKG=github.com/keycloak/keycloak-realm-operator
OPERATOR_SDK_VERSION=v0.18.2
ifeq ($(shell uname),Darwin)
  OPERATOR_SDK_ARCHITECTURE=x86_64-apple-darwin
else
  OPERATOR_SDK_ARCHITECTURE=x86_64-linux-gnu
endif
OPERATOR_SDK_DOWNLOAD_URL=https://github.com/operator-framework/operator-sdk/releases/download/$(OPERATOR_SDK_VERSION)/operator-sdk-$(OPERATOR_SDK_VERSION)-$(OPERATOR_SDK_ARCHITECTURE)

# Compile constants
COMPILE_TARGET=./tmp/_output/bin/$(PROJECT)
GOOS=${GOOS:-${GOHOSTOS}}
GOARCH=${GOARCH:-${GOHOSTARCH}}
CGO_ENABLED=0

##############################
# Operator Management        #
##############################
.PHONY: cluster/prepare
cluster/prepare:
	@kubectl apply -f deploy/crds/ || true
	@kubectl create namespace $(NAMESPACE) || true
	@kubectl apply -f deploy/role.yaml -n $(NAMESPACE) || true
	@kubectl apply -f deploy/role_binding.yaml -n $(NAMESPACE) || true
	@kubectl apply -f deploy/service_account.yaml -n $(NAMESPACE) || true
	@$(MAKE) cluster/install-new-operator

.PHONY: cluster/clean
cluster/clean: cluster/uninstall-new-operator
	@kubectl delete -f deploy/service_account.yaml -n $(NAMESPACE) || true
	@kubectl delete -f deploy/role_binding.yaml -n $(NAMESPACE) || true
	@kubectl delete -f deploy/role.yaml -n $(NAMESPACE) || true
	@kubectl delete namespace $(NAMESPACE) || true
	@kubectl delete -f deploy/crds/ || true

.PHONY: cluster/install-new-operator
cluster/install-new-operator:
	@kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/nightly/kubernetes/keycloaks.k8s.keycloak.org-v1.yml
	@kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/nightly/kubernetes/keycloakrealmimports.k8s.keycloak.org-v1.yml
	@kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/nightly/kubernetes/kubernetes.yml -n $(NAMESPACE)

.PHONY: cluster/uninstall-new-operator
cluster/uninstall-new-operator:
	@kubectl delete -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/nightly/kubernetes/keycloaks.k8s.keycloak.org-v1.yml || true
	@kubectl delete -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/nightly/kubernetes/keycloakrealmimports.k8s.keycloak.org-v1.yml || true
	@kubectl delete -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/nightly/kubernetes/kubernetes.yml -n $(NAMESPACE) || true

##############################
# Tests                      #
##############################
.PHONY: test/unit
test/unit:
	@echo Running tests:
	@go test -v -tags=unit -coverpkg ./... -coverprofile cover-unit.coverprofile -covermode=count -mod=vendor ./pkg/...

##############################
# Local Development          #
##############################
.PHONY: setup
setup: setup/mod setup/githooks code/gen

.PHONY: setup/githooks
setup/githooks:
	@echo Setting up Git hooks:
	ln -sf $$PWD/.githooks/* $$PWD/.git/hooks/

.PHONY: setup/mod
setup/mod:
	@echo Adding vendor directory
	go mod vendor
	@echo setup complete

.PHONY: setup/mod/verify
setup/mod/verify:
	go mod verify

.PHONY: setup/operator-sdk
setup/operator-sdk:
	@echo Installing Operator SDK
	@curl -Lo operator-sdk ${OPERATOR_SDK_DOWNLOAD_URL} && chmod +x operator-sdk && sudo mv operator-sdk /usr/local/bin/

.PHONY: setup/linter
setup/linter:
	@echo Installing Linter
	@curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(shell go env GOPATH)/bin v1.26.0

.PHONY: code/run
code/run:
	@operator-sdk run local --watch-namespace=${NAMESPACE}

.PHONY: code/run-debug
code/run-debug:
	@operator-sdk run local --enable-delve --watch-namespace=${NAMESPACE}

.PHONY: code/run-as-container
code/run-as-container: code/delete-container
	eval $$(minikube -p minikube docker-env); \
	docker build . -t keycloak-realm-operator:test
	cp deploy/operator.yaml deploy/operator_test.yaml
	sed -i 's/imagePullPolicy: Always/imagePullPolicy: Never/g' deploy/operator_test.yaml
	sed -i -E 's/image: \S+/image: keycloak-realm-operator:test/g' deploy/operator_test.yaml
	kubectl apply -f deploy/operator_test.yaml -n $(NAMESPACE)
	rm deploy/operator_test.yaml

.PHONY: code/delete-container
code/delete-container:
	kubectl delete deployment keycloak-realm-operator -n $(NAMESPACE) || true

.PHONY: code/compile
code/compile:
	@GOOS=${GOOS} GOARCH=${GOARCH} CGO_ENABLED=${CGO_ENABLED} go build -o=$(COMPILE_TARGET) -mod=vendor ./cmd/manager

.PHONY: code/gen
code/gen:
	operator-sdk generate k8s
	operator-sdk generate crds --crd-version v1
	# This is a copy-paste part of `operator-sdk generate openapi` command (suggested by the manual)
	which ./bin/openapi-gen > /dev/null || go build -o ./bin/openapi-gen k8s.io/kube-openapi/cmd/openapi-gen
	./bin/openapi-gen --logtostderr=true -o "" -i ./pkg/apis/keycloak/v1alpha1 -O zz_generated.openapi -p ./pkg/apis/keycloak/v1alpha1 -h ./hack/boilerplate.go.txt -r "-"

.PHONY: code/check
code/check:
	@echo go fmt
	go fmt $$(go list ./... | grep -v /vendor/)

.PHONY: code/fix
code/fix:
	# goimport = gofmt + optimize imports
	@which goimports 2>/dev/null ; if [ $$? -eq 1 ]; then \
		go get golang.org/x/tools/cmd/goimports; \
	fi
	@goimports -w `find . -type f -name '*.go' -not -path "./vendor/*"`

.PHONY: code/lint
code/lint:
	@echo "--> Running golangci-lint"
	@$(shell go env GOPATH)/bin/golangci-lint run --timeout 10m