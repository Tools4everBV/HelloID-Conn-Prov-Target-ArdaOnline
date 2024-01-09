
# HelloID-Conn-Prov-Target-ArdaOnline

| :information_source: Information                                                                                                                                                                                                                                                                                                                                                       |
| :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements. |

<p align="center">
  <img src="https://arda.nl/assets/images/logo/logo_arda_dark_basic.png">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-ArdaOnline](#helloid-conn-prov-target-ardaonline)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Provisioning PowerShell V2 connector](#provisioning-powershell-v2-connector)
      - [Correlation configuration](#correlation-configuration)
      - [Field mapping](#field-mapping)
    - [Connection settings](#connection-settings)
        - [Complex mapping](#complex-mapping)
          - [lastName](#lastname)
          - [email](#email)
          - [expiresAt](#expiresat)
    - [Prerequisites](#prerequisites)
    - [Remarks](#remarks)
      - [expiresAt](#expiresat-1)
      - [voucherCode](#vouchercode)
      - [groupId](#groupid)
      - [`externalUserId` and `mail` always mandatory](#externaluserid-and-mail-always-mandatory)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-ArdaOnline_ is a _target_ connector. _ArdaOnline_ provides a set of REST API's that allow you to programmatically interact with its data. Contrary to most connectors, _ArdaOnline_ uses a _GraphQL_ API. The difference compared to _REST_ is that; with _GraphQL_ every request is a _POST_ containing a json payload. That payload consists of a query. Fore more information on _GraphQL_ please refer to: https://graphql.org/learn/

The following lifecycle actions are available:

| Action     | Description                         |
| ---------- | ----------------------------------- |
| create.ps1 | Create and/or correlate the Account |
| update.ps1 | Update the Account                  |
| enable.ps1 | Enable the Account                  |
| delete.ps1 | Disable the Account                 |

## Getting started

### Provisioning PowerShell V2 connector

#### Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within _ArdaOnline_ to a person in _HelloID_.

To properly set up the correlation:

1. Open the `Correlation` tab.

2. Specify the following configuration:

    | Setting                   | Value               |
    | ------------------------- | ------------------- |
    | Enable correlation        | `True`              |
    | Person correlation field  | `Person.ExternalId` |
    | Account correlation field | `externalUserId`    |

#### Field mapping

The _mapping_ plays a fundamental role in every connector and is essential for aligning the data fields between a HelloID person and the target system. The _Provisioning PowerShell V2_ connector comes with a UI-based field mapping and is therefore, more accessible to a broader audience, including people who may not have a programming background.

The following fields are used within the _ArdaOnline_ connector:

> ℹ️ Information <br> Note that field names are __case sensitive__ and be aware that both the _email_ and _lastName_ fields use a __complex__ mapping.

|                  |                                                | Create | Update | Enable | Disable | Delete |           |                                                       |               |
| ---------------- | ---------------------------------------------- | ------ | ------ | ------ | ------- | ------ | --------- | ----------------------------------------------------- | ------------- |
| _Field_          | _Mapped to value_                              |        |        |        |         |        | _Type_    | _Options:_                                            | _Description_ |
| _externalUserId_ | `Person.ExternalId`                            | x      | x      |        |         |        | `Field`   | - notifications: `false` <br> - account data: `false` |
| _email_          | [_See complex mapping_](#email)                | x      | x      |        |         |        | `Complex` | - notifications: `false` <br> - account data: `false` |
| _firstName_      | `Person.Name.NickName`                         | x      | x      |        |         |        | `Field`   | - notifications: `false` <br> - account data: `false` |
| _lastName_       | [_See complex mapping_](#lastName)             | x      | x      |        |         |        | `Complex` | - notifications: `false` <br> - account data: `false` |
| _locale_         | `nl`                                           | x      | x      |        |         |        | `Fixed`   | - notifications: `false` <br> - account data: `false` |
| _department_     | `Person.PrimaryContract.Department.ExternalId` | x      | x      |        |         |        | `Field`   | - notifications: `false` <br> - account data: `false` |
| _expiresAt_      | [_See complex mapping_](#expiresAt)                |        |        | x      |         | x      | `Field`   | - notifications: `false` <br> - account data: `false` | [_See expiresAt_](#expiresat)

### Connection settings

The following settings are required to connect to the API.

| Setting      | Description                                                           | Mandatory |
| ------------ | --------------------------------------------------------------------- | --------- |
| UserName     | The UserName to connect to Arda Online                                | Yes       |
| Password     | -                                                                     | Yes       |
| ClientId     | The CLientId to connect to Arda Online                                | Yes       |
| ClientSecret | The ClientSecret to connect to Arda Online                            | Yes       |
| BaseUrl      | The URL to Arda Online                                                | Yes       |
| VoucherCode  | The voucherCode                                                       | Yes       |
| GroupId      | The Id of the group that determines which courses the user can follow | Yes       |

##### Complex mapping

> ℹ️ Make sure to toggle `Use account data from other systems` on the `Account` tab and select `Active Directory`.

###### lastName

```javascript
function updatePersonSurnameToConvention(personObject) {
    let surname;

    switch (personObject.Name.Convention) {
        case 'B':
            surname = `${personObject.Name.FamilyName}`;
            if (personObject.Name.FamilyNamePrefix) {
                surname += `, ${personObject.Name.FamilyNamePrefix}`;
            }
            break;
        case 'BP':
            surname = `${personObject.Name.FamilyName} - ${personObject.Name.FamilyNamePartnerPrefix} ${personObject.Name.FamilyNamePartner}`;
            if (personObject.Name.FamilyNamePrefix) {
                surname += `, ${personObject.Name.FamilyNamePrefix}`;
            }
            break;
        case 'P':
            surname = `${personObject.Name.FamilyNamePartner}`;
            if (personObject.Name.FamilyNamePartnerPrefix) {
                surname += `, ${personObject.Name.FamilyNamePartnerPrefix}`;
            }
            break;
        case 'PB':
            surname = `${personObject.Name.FamilyNamePartner} - ${personObject.Name.FamilyNamePrefix} ${personObject.Name.FamilyName}`;
            if (personObject.Name.FamilyNamePartnerPrefix) {
                surname += `, ${personObject.Name.FamilyNamePartnerPrefix}`;
            }
            break;
        default:
            surname = `${personObject.Name.FamilyName}`;
            if (personObject.Name.FamilyNamePrefix) {
                surname += `, ${personObject.Name.FamilyNamePrefix}`;
            }
            break;
    }

    return surname;
}

updatePersonSurnameToConvention(Person);
```

###### email

```javascript
function getActiveDirectoryEmail(){
  return Person.Accounts.MicrosoftActiveDirectory.mail
}
getActiveDirectoryEmail();
```

###### expiresAt

```javascript
function GetCurrentDate(){
  return new Date()
}
GetCurrentDate();
```

### Prerequisites

### Remarks

#### expiresAt

The _expiresAt_ attribute will only be set within the _enable_ and _delete_ lifecycle actions.

- Set to `Person.PrimaryContract.EndDate` within the _enable_ lifecycle action.
- Set to current date within the _delete_ lifecycle action.

#### voucherCode

The _voucherCode_ is a fixed value that is the same for all users.

#### groupId

The _GroupId_ is a fixed value that is the same for all users.

#### `externalUserId` and `mail` always mandatory

Both the `externalUserId` and `mail` properties are __always__ mandatory when updating the account within _ArdaOnline_.

## Getting help

> ℹ️ _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems.html) pages_

> ℹ️ _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/

