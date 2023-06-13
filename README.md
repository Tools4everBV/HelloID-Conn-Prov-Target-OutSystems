
# HelloID-Conn-Prov-Target-OutSystems

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements. |
<br />
<p align="center">
  <img src="https://www.tools4ever.nl/connector-logos/outsystems-logo.png" width="500">
</p>

## Versioning
| Version | Description | Date |
| - | - | - |
| 1.0.1   | Updated to support roles as permissions and set a default role | 2022/06/16  |
| 1.0.1   | Updated to support title and department combination and check on current data in system | 2022/06/9  |
| 1.0.0   | Initial release | 2020/05/09  |

## Table of contents

- [HelloID-Conn-Prov-Target-OutSystems](#helloid-conn-prov-target-outsystems)
  - [Versioning](#versioning)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Connection settings](#connection-settings)
    - [Connection Mapping](#connection-mapping)
    - [Prerequisites](#prerequisites)
    - [Remarks](#remarks)
  - [Setup the connector](#setup-the-connector)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-OutSystems_ is a _target_ connector. OutSystems provides a set of REST API's that allow you to programmatically interact with it's data. The HelloID connector created shown in the following table. The roles are not managed entitlements, because the role is required when create the initial account in Outsystems.
Therefore the roles cannot managed with the business rule in HelloId. The business rule or mapping are added in the connector configuration. *(See Mapping)*

| Action     | Action(s) Performed  | Comment   | 
| ------------ | ----------- | ----------- |
| Create.ps1        | Create + Set default role \| Correlate \| Correlate + Update   |
| Update.ps1        | Update \| Nochanges |
| Enable.ps1        |Isactive = $true    |
| Disable.ps1       |Isactive = $false   |
| Delete.ps1        | API does not supports Account deleting, The disable script should fit as delete script    |
| permissions.ps1   | Query the roles in OutSystems          |           |
| grant.ps1         | Grant a role to a user        |           |
| revoke.ps1        | Revert to default role for a user        | Because a role is required we can only revert to a default role and not actually revoke the current role |

## Getting started

### Connection settings

The following settings are required to connect to the API.

| Setting       | Description                             | Mandatory   |
| ------------- | -----------                             | ----------- |
| Token         | The [SCIM] Token to connect to the API  | Yes         |
| BaseUrl       | The URL to the API                      | Yes         |
| Default Role  | The Default role to grant when creating a user, as well as the default role to revert to when revoking a permissions  | Yes         |

### Connection Mapping
 - The connector configuration support mapping between Function/Title (Title.Code) and Outsystem roles. The Outsystem roles are statically defined in the configuration and expect a comma-separated list of the functions from the HelloID person and are matched from the primary contract.
- When the defined roles in the configuration do not match the business needs, you can add additional roles to the configuration. Make sure the role key matches the role Outsystems role name. The GUID of the role is retrieved from Outsystems.

<p align="center">
  <img src="assets\mapping.png"  title="Mapping">
</p>


### Prerequisites
- OutSystems uses IP-Whitelisting. Make sure your IP Address is white-listed. *Unless Outsystem supports DNS-whitelisting, you'll need an agent to gain a static public IP-address*

### Remarks
 - Because a role is required for user account we have to set a default role when creating a user, which can later be overwritten through configured permissions in the Business Rules.

## Setup the connector

> _How to setup the connector in HelloID._ Are special settings required. Like the _primary manager_ settings for a source connector.
s
## Getting help

> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012558020-Configure-a-custom-PowerShell-target-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
