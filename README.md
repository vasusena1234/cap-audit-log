# Audit Log Feature in SAP CAPM using System-Versioned Tables in HANA DB

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Database Schema](#database-schema)
4. [System Versioning in HANA](#system-versioning-in-hana)
5. [Service Layer](#service-layer)
6. [Custom Handler for Create Operation](#custom-handler-for-create-operation)
7. [How the Audit Log Works](#how-the-audit-log-works)
8. [Testing the Implementation](#testing-the-implementation)
9. [Conclusion](#conclusion)

## Introduction
This project demonstrates how to implement an **audit log feature** in an SAP CAPM application using **system-versioned tables** in **HANA DB**. The feature allows tracking changes in the `Books` entity while maintaining a history of all modifications in the `Books_History` table.

## Project Structure
```
project-root/
│-- db/
│   ├── schema.cds
│   ├── src/
│   │   └── schema.hdbsystemversioning
│   └── undeploy.json
│-- srv/
│   ├── cat-service.cds
│   ├── cat-service.js
│-- test/
│   └── http/
│       └── CatalogService.http
```

## Database Schema
### `schema.cds`
The database schema defines the `Books` entity and its corresponding history table `Books_History`.

```cds
namespace audit;

entity Books {
    key ID        : Integer;
        title     : String;
        stock     : Integer;
        validFrom : Timestamp not null @readonly @assert.notNull:false @cds.api.ignore @generated;
        validTo   : Timestamp not null @readonly @assert.notNull:false @cds.api.ignore @generated;
}

entity Books_History {
    ID        : Integer;
    title     : String;
    stock     : Integer;
    validFrom : Timestamp;
    validTo   : Timestamp;
}
```

## System Versioning in HANA
### `schema.hdbsystemversioning`
SAP HANA **system versioning** ensures that every change in `Books` is stored in `Books_History`. The history table keeps previous versions of each record.

```sql
SYSTEM VERSIONING "AUDIT_BOOKS"("VALIDFROM", "VALIDTO")
HISTORY TABLE "AUDIT_BOOKS_HISTORY" NOT VALIDATED;
```

- **`AUDIT_BOOKS`**: The main table (`Books`) where active records reside.
- **`AUDIT_BOOKS_HISTORY`**: Stores older versions of records when changes occur.
- **`VALIDFROM` & `VALIDTO`**: Automatically managed timestamps marking the start and end of a record’s validity.

## Service Layer
### `cat-service.cds`
The `CatalogService` exposes the `Books` entity as a projection, ensuring that only active records are accessible via OData.

```cds
using audit as my from '../db/schema';

service CatalogService {
    entity Books as projection on my.Books {
        ID,
        stock,
        title
    };
}
```

## Custom Handler for Create Operation
### `cat-service.js`
To prevent users from inserting values into the `validFrom` and `validTo` fields manually, we use a **custom handler** for the `CREATE` event.

```javascript
const cds = require('@sap/cds');

module.exports = cds.service.impl(async function (srv) {
    const { Books } = this.entities;

    srv.on('CREATE', 'Books', async (req) => {
        const { ID, title, stock } = req.data;

        // Ensure validFrom and validTo are NOT manually set
        delete req.data.validFrom;
        delete req.data.validTo;

        // Insert into Books (validFrom will be auto-generated)
        const newBook = await INSERT.into(Books).entries({
            ID,
            title,
            stock
        });

        return newBook;
    });
});
```

### Why This Custom Handler?
- Prevents users from inserting values into `validFrom` and `validTo`.
- Lets **HANA DB auto-generate timestamps** for tracking changes.

## How the Audit Log Works
1. **Create a New Record:**
   - A new entry is added to `Books` with `validFrom` set automatically.

2. **Update a Record:**
   - The current record’s `validTo` is updated with a timestamp.
   - A new record with the updated data is inserted with a new `validFrom` timestamp.
   - The old record is moved to `Books_History`.

3. **Read Active Records:**
   - The service fetches only active records (`validTo IS NULL`).

## Testing the Implementation
### 1. **Create a Book Entry**
#### `test/http/CatalogService.http`
```
POST http://localhost:4004/odata/v4/catalog/Books
Content-Type: application/json

{
    "ID": 1,
    "title": "SAP CAPM Guide",
    "stock": 100
}
```
#### Expected Response:
```json
{
    "ID": 1,
    "title": "SAP CAPM Guide",
    "stock": 100,
    "validFrom": "2024-02-09T12:00:00.000Z",
    "validTo": null
}
```

### 2. **Update a Book Entry**
```
PUT http://localhost:4004/odata/v4/catalog/Books(1)
Content-Type: application/json

{
    "title": "SAP CAPM Advanced Guide",
    "stock": 50
}
```
#### What Happens Internally?
- The old record moves to `Books_History` with `validTo` set.
- A new record with updated values is inserted with a fresh `validFrom` timestamp.

### 3. **Fetch Active Books**
```
GET http://localhost:4004/odata/v4/catalog/Books
```
#### Expected Response:
Only active books with `validTo IS NULL` are returned.

### 4. **View Audit Log (History Table)**
To retrieve all historical versions:
```
SELECT * FROM audit.Books_History;
```

## Conclusion
This guide explains how to implement an **audit log** feature using **SAP CAPM and system-versioned tables in HANA DB**. The **history table** captures all changes automatically, ensuring compliance with **audit requirements** and **data integrity**.

🚀 **With this setup, you can track every change made to your `Books` entity while ensuring a clean and scalable CAPM architecture.**

