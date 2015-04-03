#!/bin/bash

init_cluster_variables() {
	echo "Initialize cluster variables"

	local controller_host_id="$(fuel node "$@" | grep controller | awk '{print $1}' | head -1)"
	CONTROLLER_HOST="node-${controller_host_id}"
	echo "Controller host is '${CONTROLLER_HOST}'"

	OS_AUTH_URL="$(ssh root@${CONTROLLER_HOST} -q ". openrc; keystone catalog --service identity | grep publicURL | awk '{print \$4}'")"
	OS_AUTH_IP="$(echo "${OS_AUTH_URL}" | grep -Eo '([0-9]{1,3}[\.]){3}[0-9]{1,3}')"
	echo "OS_AUTH_URL = ${OS_AUTH_URL}"
}

test_cli_keystone()
{
	echo "Create user, tenant, role"
	ssh ${CONTROLLER_HOST} -q ". openrc; keystone user-create --name test1" || true
	ssh ${CONTROLLER_HOST} -q ". openrc; keystone tenant-create --name test2" || true
	ssh ${CONTROLLER_HOST} -q ". openrc; keystone role-create --name test3" || true
	echo "Add role for user"
	ssh ${CONTROLLER_HOST} -q ". openrc; keystone user-role-add --user test1 --role test3 --tenant test2" || true
	echo "List users, tenants, roles"
	ssh ${CONTROLLER_HOST} -q ". openrc; keystone user-list; keystone tenant-list; keystone role-list" || true
	USER_ID="$(ssh ${CONTROLLER_HOST} -q ". openrc; keystone user-list | grep test1 | awk '{print \$2}'")"
	TENANT_ID="$(ssh ${CONTROLLER_HOST} -q ". openrc; keystone tenant-list | grep test2 | awk '{print \$2}'")"
	ssh ${CONTROLLER_HOST} -q ". openrc; keystone user-role-list --user-id $USER_ID --tenant-id $TENANT_ID"
	sleep 5
	echo "Delete role, tenant, user"
	ssh ${CONTROLLER_HOST} -q ". openrc; keystone role-delete test3" || true
	ssh ${CONTROLLER_HOST} -q ". openrc; keystone tenant-delete test2" || true
	ssh ${CONTROLLER_HOST} -q ". openrc; keystone user-delete test1" || true
	echo "List users, tenants, roles"
	ssh ${CONTROLLER_HOST} -q ". openrc; keystone user-list; keystone tenant-list; keystone role-list" || true
}

test_cli_cinder()
{
	echo "Create Volume"
	ssh ${CONTROLLER_HOST} -q ". openrc; cinder create 1 --display-name test1" || true
	VOLUME_ID1="$(ssh ${CONTROLLER_HOST} -q ". openrc; cinder list | grep test1 | awk '{print \$2}'")"
	echo "Create Snapshot"
	ssh ${CONTROLLER_HOST} -q ". openrc; cinder snapshot-create $VOLUME_ID1 --display-name test1" || true
	SNAPSHOT_ID="$(ssh ${CONTROLLER_HOST} -q ". openrc; cinder snapshot-list | grep $VOLUME_ID1 | awk '{print \$2}'")"
	echo "Create Volume from Snapshot"
	ssh ${CONTROLLER_HOST} -q ". openrc; cinder create 1 --snapshot-id $SNAPSHOT_ID --display-name test2" || true
	VOLUME_ID2="$(ssh ${CONTROLLER_HOST} -q ". openrc; cinder list | grep test2 | awk '{print \$2}'")"
	sleep 5
	echo "Delete snapshot and volumes"
	ssh ${CONTROLLER_HOST} -q ". openrc; cinder delete $VOLUME_ID2" || true
	ssh ${CONTROLLER_HOST} -q ". openrc; cinder snapshot-delete $SNAPSHOT_ID" || true
	ssh ${CONTROLLER_HOST} -q ". openrc; cinder delete $VOLUME_ID1" || true
	echo "List volumes and snapshots"
	ssh ${CONTROLLER_HOST} -q ". openrc; cinder list; cinder snapshot-list" || true
}

main()
{
	init_cluster_variables
	test_cli_keystone
	test_cli_cinder
}

main "$@"

