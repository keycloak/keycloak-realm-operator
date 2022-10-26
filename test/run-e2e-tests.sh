#!/bin/bash
set -euxo pipefail

NAMESPACE=keycloak
BASE_DIR=$(cd -P -- "$(dirname -- "$0")" && pwd -P)/..

assert_cr_ready() {
  max_retries=500
  resource=$1
  status_path=$2
  expected_status=${3:-"true"}

  c=0
  while [[ $(kubectl -n $NAMESPACE get "$resource" -o jsonpath="$status_path") != "$expected_status" ]]
  do
    echo "waiting for $resource status"
    ((c++)) && ((c==max_retries)) && exit 2
    sleep 1
  done
  echo "$resource is ready!"
}

test_user_and_client() {
  echo "--- Testing User and Client"
  kubectl apply -n $NAMESPACE -f "$BASE_DIR"/deploy/examples/example-client.yaml
  kubectl apply -n $NAMESPACE -f "$BASE_DIR"/deploy/examples/example-user.yaml
  assert_cr_ready keycloakuser/example-realm-user "{.status.phase}" "reconciled"
  assert_cr_ready keycloakclient/client-secret "{.status.ready}"
  kubectl delete -n $NAMESPACE -f "$BASE_DIR"/deploy/examples/example-client.yaml
  kubectl delete -n $NAMESPACE -f "$BASE_DIR"/deploy/examples/example-user.yaml
}

# Deploy resources
make -f "$BASE_DIR"/Makefile cluster/prepare
make -f "$BASE_DIR"/Makefile code/run-as-container

# Deploy KC
kubectl apply -n $NAMESPACE -f "$BASE_DIR"/deploy/examples/example-kc-deployment.yaml
kubectl apply -n $NAMESPACE -f "$BASE_DIR"/deploy/examples/external-keycloak.yaml
assert_cr_ready keycloak/example-kc "{.status.conditions[?(@.type == 'Ready')].status}"
assert_cr_ready externalkeycloak/external-keycloak "{.status.ready}"

# Test Realm using the old Operator
echo "------- Testing legacy Realm"
kubectl apply -n $NAMESPACE -f "$BASE_DIR"/deploy/examples/realm-legacy
assert_cr_ready keycloakrealm/example-keycloakrealm "{.status.ready}"
test_user_and_client
kubectl delete -n $NAMESPACE -f "$BASE_DIR"/deploy/examples/realm-legacy

# Import Realm using the new Operator and create the rest using the old
echo "------- Testing new Realm Import"
kubectl apply -n $NAMESPACE -f "$BASE_DIR"/deploy/examples/realm-new
assert_cr_ready keycloakrealmimport/example-keycloakrealm "{.status.conditions[?(@.type == 'Done')].status}"
assert_cr_ready keycloakrealm/external-realm "{.status.ready}"
test_user_and_client
kubectl delete -n $NAMESPACE -f "$BASE_DIR"/deploy/examples/realm-new

# Cleanup
make -f "$BASE_DIR"/Makefile cluster/clean