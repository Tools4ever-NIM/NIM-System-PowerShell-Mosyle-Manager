# Mosyle Manager

Read the [Mosyle integration documentation](https://docs.nimsuite.com/en/integrations/mosyle-manager) for connector details and related guides.

<img src="https://github.com/user-attachments/assets/fbe29735-5f30-433d-9f29-aa17e9206f8e" width="256px" />

# Description
This connector imports users, devices, classes, device groups, memberships, compliance results, and custom attributes from Mosyle Manager. It also supports user management, device assignment and updates, device locking, and device group membership changes.
The connector supports pagination, configurable request retries, optional proxy authentication, and cached authorization. Classes and device records are cached within the PowerShell session so related tables can share the same API results.

# Data Tables

- Users
- Devices
- DeviceCustomAttributeValues
- Classes
- ClassTeachers
- ClassStudents
- ClassCoordinators
- DynamicDeviceGroups
- DeviceGroupDevices
- DynamicGroupDevices
- SharedDeviceGroups
- IOSSecurityCompliance
- Accounts
- CustomDeviceAttributes

# Actions

- Users: Create/Update/Delete
- User devices: Assign
- Devices: Update attributes/Unassign/Update Limbo location/Lock
- Dynamic device group memberships: Add/Remove
- Shared device group memberships: Add/Remove
- Custom device attributes: Update

# NIM Docs

The official NIM documentation can be found at: https://docs.nimsuite.com
