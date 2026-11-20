# Glossary

**Slice**
One part of a large SAP view that a single QTC replication task loads. Slices do not overlap. Together they equal the whole view.
_Avoid_: partition, chunk

**Slice table**
The RAW table that holds one slice, for example `BILLOFMATERIALS_01`.

**Combined object**
The one object in the staging database that joins all slice tables of a view. Consumers read this object, never the slice tables.
_Avoid_: union view

**Raw database**
The `*_RAW` database. QTC writes here and nothing else does. Data is not changed after landing.

**Staging database**
The `*_STAGING` database. It holds the combined object, in the schema that matches the raw schema.
