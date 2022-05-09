
# HelloID-Conn-Prov-Target-OutSystems

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements. |

<p align="center">
  <img src="https://www.outsystems.com/-/media/themes/outsystems/website/site-theme/imgs/new-logos/outsystems-black-logo.svg?updated=20220111091219"  title="Outsystems/" width="400">
</p>



## Table of contents

- [Introduction](#Introduction)
- [Getting started](#Getting-started)
  + [Connection settings](#Connection-settings)
  + [Connection Mapping](#Connection-Mapping)
  + [Prerequisites](#Prerequisites)
  + [Remarks](#Remarks)
- [Setup the connector](@Setup-The-Connector)
- [Getting help](#Getting-help)
- [HelloID Docs](#HelloID-docs)

## Introduction

_HelloID-Conn-Prov-Target-OutSystems_ is a _target_ connector. OutSystems provides a set of REST API's that allow you to programmatically interact with it's data. The HelloID connector created shown in the following table. The roles are not managed entitlements, because the role is required when create the initial account in Outsystems.
Therefore the roles cannot managed with the business rule in HelloId. The business rule or mapping are added in the connector configuration. *(See Mapping)*

| Action     | Action(s) Performed |
| ------------ | ----------- |
| Create.ps1      | Create + Apply Roles \| Correlate \| Correlate + Update + Apply Roles   |
| Update.ps1      | Update + Change roles \| Nochanges |
| Enable.ps1      |Isactive = $true    |
| Disable.ps1     |Isactive = $false   |
| Delete.ps1      | API does not supports Account deleting, The disable script should fit as delete script    |


## Getting started

### Connection settings

The following settings are required to connect to the API.

| Setting      | Description                            | Mandatory   |
| ------------ | -----------                            | ----------- |
| Token       | The [SCIM] Token to connect to the API  | Yes         |
| BaseUrl      | The URL to the API                     | Yes         |

### Connection Mapping
 - The connector configuration support mapping between Function/Title (Title.Code) and Outsystem roles. The Outsystem roles are statically defined in the configuration and expect a comma-separated list of the functions from the HelloID person and are matched from the primary contract.
- When the defined roles in the configuration do not match the business needs, you can add additional roles to the configuration. Make sure the role key matches the role Outsystems role name. The GUID of the role is retrieved from Outsystems.

<p align="center">
  <img src="assets\mapping.png"  title="Mapping">
</p>


### Prerequisites
- OutSystems uses IP-Whitelisting. Make sure your IP Address is white-listed. *Unless Outsystem supports DNS-whitelisting, you'll need an agent to gain a static public IP-address*

### Remarks
 - The webservice support managing:'ApplicationRoles' and 'Teams'. Managing this is not added to the connector due to the current requirements.

## Setup the connector

> _How to setup the connector in HelloID._ Are special settings required. Like the _primary manager_ settings for a source connector.

## Getting help

> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012558020-Configure-a-custom-PowerShell-target-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
