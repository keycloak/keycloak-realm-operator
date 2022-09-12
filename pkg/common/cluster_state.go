package common

import (
	"context"

	kc "github.com/keycloak/keycloak-realm-operator/pkg/apis/keycloak/v1alpha1"
	"github.com/keycloak/keycloak-realm-operator/pkg/model"
	v1 "k8s.io/api/core/v1"
	apiErrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/api/meta"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

// The desired cluster state is defined by a list of actions that have to be run to
// get from the current state to the desired state
type DesiredClusterState []ClusterAction

func NewClusterState() *ClusterState {
	return &ClusterState{}
}

func (d *DesiredClusterState) AddAction(action ClusterAction) DesiredClusterState {
	if action != nil {
		*d = append(*d, action)
	}
	return *d
}

func (d *DesiredClusterState) AddActions(actions []ClusterAction) DesiredClusterState {
	for _, action := range actions {
		*d = d.AddAction(action)
	}
	return *d
}

type ClusterState struct {
	KeycloakAdminSecret *v1.Secret
}

func (i *ClusterState) Read(context context.Context, cr *kc.ExternalKeycloak, controllerClient client.Client) error {
	err := i.readKeycloakAdminSecretCurrentState(context, cr, controllerClient)
	if err != nil {
		return err
	}

	// Read other things
	return nil
}

func (i *ClusterState) readKeycloakAdminSecretCurrentState(context context.Context, cr *kc.ExternalKeycloak, controllerClient client.Client) error {
	keycloakAdminSecret := model.KeycloakAdminSecret(cr)
	keycloakAdminSecretSelector := model.KeycloakAdminSecretSelector(cr)

	err := controllerClient.Get(context, keycloakAdminSecretSelector, keycloakAdminSecret)

	if err != nil {
		// If the resource type doesn't exist on the cluster or does exist but is not found
		if meta.IsNoMatchError(err) || apiErrors.IsNotFound(err) {
			i.KeycloakAdminSecret = nil
		} else {
			return err
		}
	} else {
		i.KeycloakAdminSecret = keycloakAdminSecret.DeepCopy()
		cr.UpdateStatusSecondaryResources(i.KeycloakAdminSecret.Kind, i.KeycloakAdminSecret.Name)
	}
	return nil
}
