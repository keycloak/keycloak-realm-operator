package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// KeycloakSpec defines the desired state of Keycloak.
// +k8s:openapi-gen=true
type KeycloakSpec struct {
	// The URL to use for the keycloak admin API. Needs to be set if external is true.
	// +optional
	URL string `json:"url,omitempty"`
	// Context root for Keycloak. If not set, the default "/auth/" is used.
	// Must end with "/".
	ContextRoot string `json:"contextRoot,omitempty"`
}

// KeycloakStatus defines the observed state of Keycloak.
// +k8s:openapi-gen=true
type KeycloakStatus struct {
	// Current phase of the operator.
	Phase StatusPhase `json:"phase"`
	// Human-readable message indicating details about current operator phase or error.
	Message string `json:"message"`
	// True if all resources are in a ready state and all work is done.
	Ready bool `json:"ready"`
	// A map of all the secondary resources types and names created for this CR. e.g "Deployment": [ "DeploymentName1", "DeploymentName2" ].
	SecondaryResources map[string][]string `json:"secondaryResources,omitempty"`
	// Version of Keycloak or RHSSO running on the cluster.
	Version string `json:"version"`
	// An internal URL (service name) to be used by the admin client.
	InternalURL string `json:"internalURL"`
	// External URL for accessing Keycloak instance from outside the cluster. Is identical to external.URL if it's specified, otherwise is computed (e.g. from Ingress).
	ExternalURL string `json:"externalURL,omitempty"`
	// The secret where the admin credentials are to be found.
	CredentialSecret string `json:"credentialSecret"`
}

type StatusPhase string

var (
	NoPhase           StatusPhase
	PhaseReconciling  StatusPhase = "reconciling"
	PhaseFailing      StatusPhase = "failing"
	PhaseInitialising StatusPhase = "initialising"
)

// Keycloak is the Schema for the keycloaks API.
// +genclient
// +k8s:openapi-gen=true
// +kubebuilder:subresource:status
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object
type ExternalKeycloak struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   KeycloakSpec   `json:"spec,omitempty"`
	Status KeycloakStatus `json:"status,omitempty"`
}

// KeycloakList contains a list of Keycloak.
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object
type ExternalKeycloakList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []ExternalKeycloak `json:"items"`
}

func init() {
	SchemeBuilder.Register(&ExternalKeycloak{}, &ExternalKeycloakList{})
}

func (i *ExternalKeycloak) UpdateStatusSecondaryResources(kind string, resourceName string) {
	i.Status.SecondaryResources = UpdateStatusSecondaryResources(i.Status.SecondaryResources, kind, resourceName)
}
