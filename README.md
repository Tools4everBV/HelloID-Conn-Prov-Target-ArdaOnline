# HelloID-Conn-Prov-Target-ArdaOnline

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.       |

<br />

<p align="center">
  <img src="https://arda.nl/assets/images/logo/logo_arda_dark_basic.png">
</p>

## Table of contents

- [Introduction](#Introduction)
- [Getting started](#Getting-started)
  + [Connection settings](#Connection-settings)
  + [Remarks](#Remarks)
- [Getting help](#Getting-help)
- [HelloID Docs](#HelloID-docs)

## Introduction

_HelloID-Conn-Prov-Target-ArdaOnline_ is a _target_ connector. Arda Online provides a GraphQL API that allows you to programmatically interact with it's data.

> _HelloID-Conn-Prov-Target-ArdaOnline_ is cloud only connector. It has not been tested in conjuction with the HelloID agent.

## Getting started

Arda Online provides a GraphQL API. GraphQL is a little different in contrary to REST. One of it's main differences is that every call is POST call and the jsonPayload of each call contains a query wrapped in JSON.

### Connection settings

The following settings are required to connect to Arda Online

| Setting      | Description                                | Mandatory   |
| ------------ | -----------                                | ----------- |
| UserName     | The UserName to connect to Arda Online     | Yes         |
| Password     | -                                          | Yes         |
| ClientId     | The CLientId to connect to Arda Online     | Yes         |
| ClientSecret | The ClientSecret to connect to Arda Online | Yes         |
| BaseUrl      | The URL to Arda Online                     | Yes         |
| VoucherCode  | The voucherCode                            | Yes         |
| GroupId      | The Id of the group that determines which courses the user can follow | Yes         |

### Remarks

#### voucherCode

The _voucherCode_ is a fixed value that is the same for all users.

#### GroupId

The _GroupId_ is a fixed value that is the same for all users.

> The connector is created for cloud only.

## Getting help

> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012558020-Configure-a-custom-PowerShell-target-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
