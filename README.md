# Keycloak Realm Operator
A Kubernetes Operator based on the Operator SDK for managing Realm and its sub-resources in Keycloak. This Operator is
forked from the [legacy Keycloak Operator](https://github.com/keycloak/keycloak-operator) and stripped off of any functionality
related to Keycloak Deployment as it was designed for the WildFly distribution of Keycloak and is not compatible with the
new Quarkus distribution. The Realm Operator is meant as a **temporary workaround** to compensate for the missing
User and Client CR in the [new Keycloak Operator](https://github.com/keycloak/keycloak/tree/main/operator) and to work
as a side-car for it.

## Motivation

To provide the best experience, the new Keycloak Operator will use a new approach to manage Keycloak resources, such as Realms, Clients and Users. This approach will leverage the [new storage architecture](https://www.keycloak.org/2022/07/storage-map.html) and future immutability options, making the CRs the declarative single source of truth. In comparison to the [legacy Operator](https://github.com/keycloak/keycloak-operator), this will bring high robustness, reliability and predictability to the whole solution.

Before we would consider the new Keycloak Operator ready for leveraging CRs, we expect completing several features including but not
limited to:

* File store (expected in Keycloak 20) to persist data in a file instead of DB.
* Read-only administration REST API, UI Console and other interfaces. This is required for the new immutability concept
  which will be used to ensure any data coming from the CRs (and subsequently from the file store) are read-only from
  all interfaces.

All of this is critical to proper CRs implementation, hence the new Keycloak Operator is currently missing the CRDs for managing
Keycloak resources. The missing CRDs will be added once Keycloak has the necessary support for it, which is currently
expected in Keycloak 21.

There are two alternatives to mitigate the current lack of CRs in the new Keycloak Operator:
* Using the Realm Import CR from the new Keycloak Operator without using the Realm Operator
* Using the Realm Operator for managing Realm resources and new Keycloak Operator for deploying Keycloak

For details, please see the following chapters.

## Using the Realm Import CR and  the new Keycloak Operator

As the name suggests, the Realm Import CR is meant only for declarative Realm creation (no updates or deletion is supported), very much like the [Realm CR in the legacy Operator](https://github.com/keycloak/keycloak-operator/blob/main/deploy/crds/keycloak.org_keycloakrealms_crd.yaml) which was used the same way. The main advantage and difference of the Realm Import CR are that it contains the full Realm representation (incl. all sub-resources like Clients, Users, etc.) unlike the old Realm CR which included only selected fields.

To learn more about the Realm Import CR, see the [documentation](https://www.keycloak.org/operator/realm-import).

## Using the Realm Operator

Another temporary workaround to the missing CRs is to use this Realm Operator in *tandem* with the new Keycloak Operator. Due to the changes and enhancements in the Quarkus distribution of Keycloak, the Realm Operator is unable to deploy and manage its lifecycle and features related to this were removed. However, the Operator still can manage resources inside a running Quarkus distribution whose deployment is managed by the new Keycloak Operator.

### Example

1.  Deploy the new Keycloak Operator.
    ```
    kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/19.0.1/kubernetes/keycloaks.k8s.keycloak.org-v1.yml
    kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/19.0.1/kubernetes/keycloakrealmimports.k8s.keycloak.org-v1.yml
    kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/19.0.1/kubernetes/kubernetes.yml
    ```
    Notice that we're using a hardcoded `19.0.1` version here. Feel free to use a newer version. See also the [installation guide](https://www.keycloak.org/operator/installation#_vanilla_kubernetes_installation).

2.  Deploy the Realm Operator.
    ```
    kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/crds/legacy.k8s.keycloak.org_externalkeycloaks_crd.yml
    kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/crds/legacy.k8s.keycloak.org_keycloakclients_crd.yml
    kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/crds/legacy.k8s.keycloak.org_keycloakrealms_crd.yml
    kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/crds/legacy.k8s.keycloak.org_keycloakusers_crd.yml
    kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/role.yaml
    kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/role_binding.yaml
    kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/service_account.yaml
    kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-realm-operatpr/main/deploy/operator.yaml
    ```

3.  Deploy Quarkus distribution of Keycloak using the new Keycloak Operator.
    ```
    kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/examples/example-kc-deployment.yaml
    ```
    **WARNING:** For the simplicity of this example, the deployment is using a predefined `admin` username and password for the initial admin user.

    See also the [Basic Keycloak Deployment guide](https://www.keycloak.org/operator/basic-deployment).

4. Create resources for the Realm Operator to tell it where the external Keycloak lives.
    ```
   kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/examples/external-keycloak.yaml
   ```

5.  Create a Realm by using one of the following options.  
    1.  Import Realm using the new Keycloak Operator and a reference for the Realm Operator.  
        ```
        kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/examples/realm-new/example-realm.yaml
        kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/examples/realm-new/external-realm.yaml
        ```  
        This approach offers you the full Realm Representation.  
    2.  Create a Realm directly using the Realm Operator.  
        ```
        kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/examples/realm-legacy/example-realm.yaml
        ```  
        This approach offers you the same Realm CR experience as did the old Keycloak Operator. Only Realm creation and deletion are supported, any updates to the CR are ignored.

6.  Deploy a Client and a User using the Realm Operator to the `basic` Realm previously created by the new Keycloak Operator.
    ```
    kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/examples/example-client.yaml
    kubectl apply -f https://raw.githubusercontent.com/keycloak/keycloak-realm-operator/main/deploy/examples/example-user.yaml
    ```
    This Client and User are fully managed by the Realm Operator, which means any updates to the CR will be synced to Keycloak. **This is the main advantage over Realm Import CR (which can also contain Clients and Users) from the new Keycloak Operator.**

**NOTE:** Please notice that although the Realm Operator uses mostly the same CRDs as the legacy Keycloak Operator, the CRDs group was changed to `legacy.k8s.keycloak.org` to avoid conflicts.

## Local development

| *Command*                    | *Description*                                                                                                     |
|------------------------------|-------------------------------------------------------------------------------------------------------------------|
| `make cluster/prepare`       | Creates the `keycloak` namespace, applies all CRDs, sets up the RBAC files and installs the new Keycloak Operator |
| `make cluster/clean`         | Deletes the `keycloak` namespace, all and all RBAC files                                                          |
| `make code/run`              | Runs the Realm Operator locally                                                                                   | 
| `make code/run-as-container` | Builds Realm Operator image and deploys it to the cluster                                                         | 
| `make code/delete-container` | Deletes the container with Realm Operator                                                                         | 
| `make code/compile`          | Builds the operator                                                                                               |
| `make code/gen`              | Generates/Updates the operator files based on the CR status and spec definitions                                  |
| `make code/lint`             | Checks for linting errors in the code                                                                             |
| `./test/run-e2e-tests.sh`    | Runs tests                                                                                                        | 

## Help and Documentation

Please see the [archived legacy Operator repository](https://github.com/keycloak/keycloak-operator)

See also:
* [The legacy Operator documentation](https://www.keycloak.org/docs/19.0.1/server_installation/index.html#_operator) (serves as a documentation for Realm Operator too)
* [The new Keycloak Operator documentation](https://www.keycloak.org/guides#operator)

## License

* [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0)
