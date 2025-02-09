using audit as my from '../db/schema';

service CatalogService {
    entity Books as projection on my.Books{
        ID,
        stock,
        title
    };
}
