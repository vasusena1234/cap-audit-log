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
